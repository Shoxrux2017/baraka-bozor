#!/usr/bin/env bash
# The backup cycle against a scratch stack (DL-104 (6)): a real database and a
# real restic repository on a bind-mounted directory, in the Compose project
# `bb-backup-test`. It never touches another project's containers or volumes.
#
#   BACKUP_TEST_DIR=<dir> bash docker/backup/test-cycle.sh
#
# Without BACKUP_TEST_DIR the work directory is a fresh `mktemp -d` and is
# removed at the end. A given directory is emptied of its generated files first
# and kept. On Windows pass a path Docker Desktop can bind-mount (G:/...).
set -euo pipefail
export MSYS_NO_PATHCONV=1

cd "$(dirname "$0")/../.."

CREATED_DIR=0
if [ -z "${BACKUP_TEST_DIR:-}" ]; then
  BACKUP_TEST_DIR="$(mktemp -d)"
  CREATED_DIR=1
fi
W="$BACKUP_TEST_DIR"
mkdir -p "$W"

BB_COMPOSE_OVERRIDE=docker/backup/compose.local-repo.yaml
export BB_COMPOSE_OVERRIDE

compose() {
  docker compose --env-file "$W/stack.env" \
    -f docker/compose.prod.yaml -f "$BB_COMPOSE_OVERRIDE" "$@"
}

fail() {
  echo "test-cycle: FAILED: $1" >&2
  exit 1
}

cleanup() {
  if [ -f "$W/stack.env" ]; then
    # restic makes its directories 0700 for the container user; only that user
    # can empty the repository so the host can remove the directory.
    compose run --rm --no-deps -T --entrypoint sh backup \
      -c 'find /repository -mindepth 1 -delete' > /dev/null 2>&1 || true
    compose down -v --remove-orphans > /dev/null 2>&1 || true
  fi
  if [ "$CREATED_DIR" = 1 ]; then
    rm -rf "$W"
  fi
}
trap cleanup EXIT

random_hex() { openssl rand -hex "$1"; }

rm -rf "$W/repository" "$W/panel"
mkdir -p "$W/repository" "$W/panel"
chmod 0777 "$W/repository"

cat > "$W/stack.env" <<STACK
COMPOSE_PROJECT_NAME=bb-backup-test
COMPOSE_PROFILES=backup
BB_ENV_FILE=$W/stack.env
BACKUP_ENV_FILE=$W/backup.env
BACKUP_LOCAL_REPOSITORY=$W/repository
BB_RELEASE=backup-test
BB_PUBLISH_ADDRESS=127.0.0.1
BB_HTTP_PORT=18080
BB_HTTPS_PORT=18443
API_HOST=localhost
PANEL_HOST=panel.localhost
PANEL_ROOT=$W/panel
EDGE_SUBNET=10.203.41.0/28
APP_NAME=BarakaBozorBackupTest
APP_ENV=local
APP_DEBUG=false
APP_KEY=base64:$(openssl rand -base64 32)
APP_URL=http://localhost:18080
CORS_ALLOWED_ORIGINS=https://panel.localhost
LOG_CHANNEL=stderr
LOGIN_CODE_DRIVER=fake
PHONE_FINGERPRINT_KEY=base64:$(openssl rand -base64 32)
WALKTHROUGH_STAFF_PASSWORD=$(random_hex 12)
DB_CONNECTION=pgsql
DB_HOST=db
DB_PORT=5432
DB_DATABASE=barakabozor
DB_USERNAME=barakabozor
DB_PASSWORD=$(random_hex 16)
QUEUE_CONNECTION=database
CACHE_STORE=database
SESSION_DRIVER=array
FILESYSTEM_DISK=local
STACK

cat > "$W/backup.env" <<BACKUP
RESTIC_REPOSITORY=/repository
RESTIC_PASSWORD=$(random_hex 16)
PGUSER=barakabozor_backup
PGPASSWORD=$(random_hex 16)
BACKUP_PING_URL=http://127.0.0.1:9/
BACKUP

bexec() { compose exec -T backup "$@"; }
status_has() { bexec cat "/status/$1.json" | grep -q "$2"; }
fingerprint() {
  # shellcheck disable=SC2016
  compose exec -T db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA -v ON_ERROR_STOP=1' <<'SQL' | tr -d '\r'
SELECT c.relname || ' ' || md5(query_to_xml(format('SELECT t::text AS r FROM %I t ORDER BY 1', c.relname), false, false, '')::text)
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p') AND c.relname NOT IN ('cache', 'cache_locks')
ORDER BY c.relname;
SELECT sequencename || ' ' || coalesce(last_value::text, 'unused')
FROM pg_sequences WHERE schemaname = 'public' ORDER BY sequencename;
SQL
}
snapshot_count() { bexec restic snapshots --json | grep -o '"short_id"' | wc -l | tr -d ' \r'; }

compose up -d --build --wait

# The backup mounts the images volume last while it is still empty. Docker gives
# an empty volume the owner of the mounting image's directory, so the volume must
# still be www-data's (uid 33 in the app image): otherwise Admin uploads fail.
# Checked from the backup container, since mounting the volume in the app would
# set the owner right again.
compose up -d --force-recreate backup
[ "$(bexec stat -c %u /backup/images | tr -d '')" = 33 ]   || fail "the images volume is not owned by www-data"

compose run --rm app php artisan migrate --force
compose run --rm app php artisan db:seed --class=WalkthroughSeeder --force
bash docker/backup/create-role.sh "$W/stack.env"

MARKER=/app/storage/app/public/products/backup-test.webp
compose run --rm --no-deps -T --entrypoint sh app -c \
  "mkdir -p /app/storage/app/public/products && head -c 4096 /dev/urandom > $MARKER" \
  || fail "the marker image was not written"
MARKER_SHA="$(compose run --rm --no-deps -T --entrypoint sh app -c "sha256sum $MARKER" | cut -d' ' -f1 | tr -d '\r')"
[ -n "$MARKER_SHA" ] || fail "the marker image has no checksum"

bexec restic init > /dev/null || fail "restic init failed"

if bexec psql -c 'create table backup_probe ()' > /dev/null 2>&1; then
  fail "the backup role could write to the database"
fi

bexec backup.sh || fail "backup.sh failed on a healthy stack"
status_has backup '"result":"success"' || fail "backup.json is not a success"
status_has backup '"snapshot":"[0-9a-f]\{8\}"' || fail "backup.json names no snapshot"
SNAPSHOT="$(bexec cat /status/backup.json | sed -n 's/.*"snapshot":"\([0-9a-f]\{8\}\)".*/\1/p' | tr -d '\r')"
[ -n "$SNAPSHOT" ] || fail "no snapshot id in backup.json"
bexec restic snapshots --json | grep -q '"hostname":"barakabozor"' \
  || fail "no snapshot with the host barakabozor"
bexec test ! -e /backup/db/barakabozor.dump || fail "the dump file was left behind"
BEFORE="$(snapshot_count)"
[ "$BEFORE" = 1 ] || fail "expected one snapshot, found $BEFORE"

if bexec env PGPASSWORD=wrong backup.sh > /dev/null 2>&1; then
  fail "backup.sh succeeded with a wrong database password"
fi
status_has backup '"result":"failure"' || fail "backup.json is not a failure after a dump error"
status_has backup '"step":"dump"' || fail "backup.json does not name the dump step"
[ "$(snapshot_count)" = "$BEFORE" ] || fail "the snapshot count changed after a dump failure"

if bexec env RESTIC_PASSWORD=wrong backup.sh > /dev/null 2>&1; then
  fail "backup.sh succeeded with a wrong repository password"
fi
status_has backup '"step":"backup"' || fail "backup.json does not name the backup step"
bexec test ! -e /backup/db/barakabozor.dump || fail "a dump file was left after a repository failure"

bexec check.sh || fail "check.sh failed on a healthy repository"
status_has check '"result":"success"' || fail "check.json is not a success"

compose up -d --force-recreate backup
bexec test -f /status/check.json || fail "check.json did not survive a container recreate"

FINGERPRINT="$(fingerprint)"
[ "$(printf '%s\n' "$FINGERPRINT" | wc -l)" -gt 10 ] || fail "the fingerprint covers too few tables"

compose down -v --remove-orphans > /dev/null

set +e
NO_ID_OUTPUT="$(bash docker/backup/restore.sh "$W/stack.env" 2>&1)"
NO_ID_CODE=$?
set -e
[ "$NO_ID_CODE" = 2 ] || fail "restore.sh without a snapshot id exited $NO_ID_CODE, not 2"
printf '%s\n' "$NO_ID_OUTPUT" | grep -q "$SNAPSHOT" || fail "restore.sh without an id did not list the snapshot"

bash docker/backup/restore.sh "$W/stack.env" "$SNAPSHOT" || fail "restore.sh failed"
[ "$(fingerprint)" = "$FINGERPRINT" ] || fail "the database differs after the restore"

RESTORED="$(compose run --rm --no-deps -T --entrypoint sh app -c "sha256sum $MARKER; stat -c %U $MARKER" | tr -d '\r')"
[ "$(printf '%s\n' "$RESTORED" | sed -n 1p | cut -d' ' -f1)" = "$MARKER_SHA" ] \
  || fail "the marker image differs after the restore"
[ "$(printf '%s\n' "$RESTORED" | sed -n 2p)" = www-data ] || fail "the marker image is not owned by www-data"

set +e
AGAIN_OUTPUT="$(bash docker/backup/restore.sh "$W/stack.env" "$SNAPSHOT" 2>&1)"
AGAIN_CODE=$?
set -e
[ "$AGAIN_CODE" != 0 ] || fail "a second restore into a live stack succeeded"
printf '%s\n' "$AGAIN_OUTPUT" | grep -q 'not empty' || fail "the second restore did not say the database is not empty"
[ "$(fingerprint)" = "$FINGERPRINT" ] || fail "the second restore changed the database"

echo "test-cycle: passed"
