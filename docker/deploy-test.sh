#!/usr/bin/env bash
# docker/deploy.sh against a scratch server (DL-141): a scratch origin and clone,
# a real stack in the Compose project `bb-deploy-test`, six release tags. It
# never touches another project's containers, volumes or images.
#
#   DEPLOY_TEST_DIR=<dir> bash docker/deploy-test.sh
#
# The scripts under test are the working tree's docker/ directory, committed
# into the scratch repository as its first release, so an uncommitted change is
# tested too. deploy.sh runs from the scratch clone, never from this checkout.
#
# Without DEPLOY_TEST_DIR the work directory is a fresh `mktemp -d` and is
# removed at the end. A given directory is emptied of its generated files first
# and kept; it must be empty or carry the marker `.bb-deploy-test` of an earlier
# run, so a mistyped path never loses files. On Windows pass a path Docker
# Desktop can bind-mount (G:/...).
set -euo pipefail
export MSYS_NO_PATHCONV=1

# Absolute before the cd below; pwd -W gives Windows paths in Git Bash.
if [ -n "${DEPLOY_TEST_DIR:-}" ]; then
  case "$DEPLOY_TEST_DIR" in
    /*|[A-Za-z]:*) ;;
    *)
      mkdir -p "$DEPLOY_TEST_DIR"
      DEPLOY_TEST_DIR="$(cd "$DEPLOY_TEST_DIR" && { pwd -W 2>/dev/null || pwd; })"
      ;;
  esac
fi

cd "$(dirname "$0")/.."
SRC="$(pwd -W 2>/dev/null || pwd)"

CREATED_DIR=0
if [ -z "${DEPLOY_TEST_DIR:-}" ]; then
  DEPLOY_TEST_DIR="$(mktemp -d)"
  CREATED_DIR=1
fi
W="$DEPLOY_TEST_DIR"
mkdir -p "$W"
if [ "$CREATED_DIR" = 0 ] && [ -n "$(ls -A "$W")" ] && [ ! -e "$W/.bb-deploy-test" ]; then
  echo "deploy-test: $W is not empty and has no .bb-deploy-test marker; refusing to delete files in it" >&2
  exit 2
fi
touch "$W/.bb-deploy-test"
rm -rf "$W/origin.git" "$W/work" "$W/home" "$W/root.crt" "$W/headers" "$W/body" "$W/empty.env"

export BB_HOME="$W/home"
export BB_STACK_ENV="$BB_HOME/stack.env"
unset BB_RELEASE BB_COMPOSE_OVERRIDE
REPO="$BB_HOME/repo"
DEPLOY="$REPO/docker/deploy.sh"
STACK="$REPO/docker/stack.sh"
PORT=18443
PANEL_ORIGIN="https://panel.localhost:$PORT"
T1=r2000.01.01.1 T2=r2000.01.01.2 T3=r2000.01.01.3 T4=r2000.01.01.4 T5=r2000.01.01.5 T6=r2000.01.01.6

fail() {
  echo "deploy-test: FAILED: $1" >&2
  if [ -n "${DEPLOY_OUT:-}" ]; then
    echo "deploy-test: the last deploy.sh output was:" >&2
    printf '%s\n' "$DEPLOY_OUT" | tail -n 30 >&2
  fi
  exit 1
}
ok() { echo "ok $1 $2"; }

cleanup() {
  if [ -f "$BB_STACK_ENV" ]; then
    docker compose --env-file "$BB_STACK_ENV" -f "$SRC/docker/compose.prod.yaml" \
      down -v --remove-orphans > /dev/null 2>&1 || true
  fi
  # Only the release images of this test.
  for tag in $T1 $T2 $T3 $T4 $T5 $T6; do
    docker image rm "barakabozor-app:$tag" "barakabozor-backup:$tag" > /dev/null 2>&1 || true
  done
  if [ "$CREATED_DIR" = 1 ]; then
    rm -rf "$W"
  fi
}
trap cleanup EXIT

# --- The scratch repository ---------------------------------------------------
git_work() { git -C "$W/work" -c core.autocrlf=false -c user.name=deploy-test -c user.email=deploy-test@localhost "$@"; }

git clone -q -c core.autocrlf=false "$SRC" "$W/work"
git_work remote remove origin
git_work checkout -q -B main
git init -q --bare -b main "$W/origin.git"
git_work remote add origin "$W/origin.git"

# 1: the checkout's HEAD, with this working tree's docker/ on top.
rm -rf "$W/work/docker"
cp -R "$SRC/docker" "$W/work/docker"
git_work add -A docker
git_work commit -q --allow-empty -m "release 1: the checkout"
git_work tag $T1

# 2: a migration that creates a table.
cat > "$W/work/backend/database/migrations/2999_01_01_000000_create_deploy_test_marker_table.php" <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('deploy_test_marker', function (Blueprint $table): void {
            $table->id();
        });
    }
};
PHP
git_work add backend/database/migrations
git_work commit -q -m "release 2: a migration"
git_work tag $T2

# 3: documentation only.
printf 'A release that changes only the documentation.\n' > "$W/work/docs/deploy-test-note.md"
git_work add docs/deploy-test-note.md
git_work commit -q -m "release 3: docs only"
git_work tag $T3

# 4: a migration that throws.
cat > "$W/work/backend/database/migrations/2999_01_02_000000_fail_on_purpose.php" <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;

return new class extends Migration
{
    public function up(): void
    {
        throw new RuntimeException('deploy-test: this migration fails on purpose');
    }
};
PHP
git_work add backend/database/migrations
git_work commit -q -m "release 4: a migration that fails"
git_work tag $T4

# 5: an invalid Caddyfile, inside the API host.
sed -i '0,/encode zstd gzip/s//encode zstd gzip\n\tnot_a_directive/' "$W/work/docker/caddy/Caddyfile"
grep -q not_a_directive "$W/work/docker/caddy/Caddyfile" || fail "the invalid Caddyfile was not written"
git_work add docker/caddy/Caddyfile
git_work commit -q -m "release 5: an invalid Caddyfile"
git_work tag $T5

git_work push -q origin main
git_work push -q origin --tags

# 6: a commit on a branch that never reaches main; only its tag is pushed.
git_work checkout -q -b other
printf 'Only on a side branch.\n' > "$W/work/docs/deploy-test-other.md"
git_work add docs/deploy-test-other.md
git_work commit -q -m "release 6: not on main"
git_work tag $T6
git_work push -q origin $T6
git_work checkout -q main

# --- The scratch server -------------------------------------------------------
mkdir -p "$BB_HOME/maintenance" "$BB_HOME/panel"
: > "$W/empty.env"
git clone -q -c core.autocrlf=false "$W/origin.git" "$REPO"
git -C "$REPO" checkout -q --detach $T1

cat > "$BB_STACK_ENV" <<STACK
COMPOSE_PROJECT_NAME=bb-deploy-test
BB_ENV_FILE=$BB_STACK_ENV
BACKUP_ENV_FILE=$W/empty.env
BB_PUBLISH_ADDRESS=127.0.0.1
BB_HTTP_PORT=18080
BB_HTTPS_PORT=$PORT
API_HOST=localhost
PANEL_HOST=panel.localhost
PANEL_ROOT=$BB_HOME/panel
MAINTENANCE_DIR=$BB_HOME/maintenance
EDGE_SUBNET=${EDGE_SUBNET:-172.30.252.0/28}
APP_NAME=BarakaBozorDeployTest
APP_ENV=local
APP_DEBUG=false
APP_KEY=base64:$(openssl rand -base64 32)
APP_URL=http://localhost:18080
CORS_ALLOWED_ORIGINS=$PANEL_ORIGIN
LOG_CHANNEL=stderr
LOGIN_CODE_DRIVER=fake
PUSH_DRIVER=fake
PHONE_FINGERPRINT_KEY=base64:$(openssl rand -base64 32)
DB_CONNECTION=pgsql
DB_HOST=db
DB_PORT=5432
DB_DATABASE=barakabozor
DB_USERNAME=barakabozor
DB_PASSWORD=$(openssl rand -hex 16)
QUEUE_CONNECTION=database
CACHE_STORE=database
SESSION_DRIVER=array
FILESYSTEM_DISK=local
STACK

# --- Helpers ------------------------------------------------------------------
DEPLOY_OUT=""
DEPLOY_CODE=0
run_deploy() {
  set +e
  DEPLOY_OUT="$(bash "$DEPLOY" "$@" 2>&1)"
  DEPLOY_CODE=$?
  set -e
}

HTTP_CODE=000
http() {
  HTTP_CODE="$(curl -sS --max-time 20 --ssl-no-revoke --cacert "$W/root.crt" \
    -D "$W/headers" -o "$W/body" -w '%{http_code}' "https://localhost:$PORT$1" 2> /dev/null)" || HTTP_CODE=000
}

release() { tr -d '\r\n' < "$BB_HOME/state/$1"; }
dump_count() { ls -1 "$BB_HOME/dumps" | wc -l | tr -d ' '; }
# shellcheck disable=SC2016
db() { bash "$STACK" exec -T db sh -c "psql -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -tA -c \"$1\"" | tr -d '\r'; }

# --- 1. The first deploy, no stack yet -----------------------------------------
run_deploy $T1
[ "$DEPLOY_CODE" = 0 ] || fail "1: deploy.sh $T1 exited $DEPLOY_CODE"
bash "$STACK" exec -T caddy cat /data/caddy/pki/authorities/local/root.crt > "$W/root.crt"
http /up
[ "$HTTP_CODE" = 200 ] || fail "1: /up answered $HTTP_CODE"
[ "$(release release)" = $T1 ] || fail "1: state/release is not $T1"
[ ! -e "$BB_HOME/state/release.previous" ] || fail "1: state/release.previous exists after the first deploy"
ok 1 "the first deploy: /up 200, release $T1, no previous"

# --- 2. The maintenance answer -------------------------------------------------
touch "$BB_HOME/maintenance/on"
http /api/v1/catalog/categories
[ "$HTTP_CODE" = 503 ] || fail "2: the API answered $HTTP_CODE, not 503"
grep -q '"code":"service_unavailable"' "$W/body" || fail "2: the body has no service_unavailable code"
grep -qi '^retry-after: 30' "$W/headers" || fail "2: no Retry-After: 30"
grep -qi "^access-control-allow-origin: $PANEL_ORIGIN" "$W/headers" || fail "2: no Access-Control-Allow-Origin for the panel"
http /storage/missing.webp
[ "$HTTP_CODE" != 503 ] || fail "2: images were answered with 503"
rm -f "$BB_HOME/maintenance/on"
http /up
[ "$HTTP_CODE" = 200 ] || fail "2: /up answered $HTTP_CODE after maintenance"
ok 2 "maintenance: 503 envelope with Retry-After and CORS, images served, lifted"

# --- 3. A release with a migration ---------------------------------------------
run_deploy $T2
[ "$DEPLOY_CODE" = 0 ] || fail "3: deploy.sh $T2 exited $DEPLOY_CODE"
[ "$(db "select to_regclass('public.deploy_test_marker')")" = deploy_test_marker ] || fail "3: the migration did not run"
[ "$(dump_count)" = 1 ] || fail "3: expected one dump, found $(dump_count)"
DUMP="$(ls -1 "$BB_HOME/dumps"/*.dump | head -n 1)"
bash "$STACK" exec -T db pg_restore -l < "$DUMP" > /dev/null || fail "3: pg_restore cannot read the dump"
[ "$(release release)" = $T2 ] && [ "$(release release.previous)" = $T1 ] || fail "3: the state files are wrong"
docker image inspect "barakabozor-app:$T1" > /dev/null 2>&1 || fail "3: the image of $T1 is gone"
ok 3 "a migration release: table created, dump readable, release $T2 after $T1, old image kept"

# --- 4. A rollback across a migration ------------------------------------------
run_deploy --rollback
[ "$DEPLOY_CODE" = 2 ] || fail "4: --rollback exited $DEPLOY_CODE, not 2"
printf '%s\n' "$DEPLOY_OUT" | grep -q 'migrations' || fail "4: the refusal does not name migrations"
[ "$(release release)" = $T2 ] || fail "4: the release changed"
ok 4 "rollback refused across a migration, release still $T2"

# --- 5. A rollback without one -------------------------------------------------
run_deploy $T3
[ "$DEPLOY_CODE" = 0 ] || fail "5: deploy.sh $T3 exited $DEPLOY_CODE"
run_deploy --rollback
[ "$DEPLOY_CODE" = 0 ] || fail "5: --rollback exited $DEPLOY_CODE"
[ "$(release release)" = $T2 ] && [ "$(release release.previous)" = $T3 ] || fail "5: the state files are wrong after the rollback"
[ "$(bash "$STACK" ps app --format '{{.Image}}' | tr -d '\r')" = "barakabozor-app:$T2" ] || fail "5: the app container is not on $T2"
http /up
[ "$HTTP_CODE" = 200 ] || fail "5: /up answered $HTTP_CODE"
ok 5 "rollback: release $T2, previous $T3, the app runs the $T2 image"

# --- 6. A failed migration -----------------------------------------------------
run_deploy $T4
[ "$DEPLOY_CODE" = 1 ] || fail "6: deploy.sh $T4 exited $DEPLOY_CODE, not 1"
[ -e "$BB_HOME/maintenance/on" ] || fail "6: maintenance was lifted after a failed migration"
printf '%s\n' "$DEPLOY_OUT" | grep -q "$BB_HOME/dumps/" || fail "6: the output does not name the dump"
printf '%s\n' "$DEPLOY_OUT" | grep -q -- '--rollback' || fail "6: the output does not name --rollback"
[ "$(release release)" = $T2 ] || fail "6: state/release moved"
http /api/v1/catalog/categories
[ "$HTTP_CODE" = 503 ] || fail "6: the API answered $HTTP_CODE, not 503, after a failed migration"
rm -f "$BB_HOME/maintenance/on"
ok 6 "a failed migration: exit 1, maintenance stays, dump and --rollback named, release $T2"

# --- 7. A Caddyfile that does not validate -------------------------------------
run_deploy $T5
[ "$DEPLOY_CODE" = 2 ] || fail "7: deploy.sh $T5 exited $DEPLOY_CODE, not 2"
[ ! -e "$BB_HOME/maintenance/on" ] || fail "7: maintenance began"
[ "$(git -C "$REPO" rev-parse HEAD)" = "$(git -C "$REPO" rev-parse "$T2^{commit}")" ] || fail "7: the clone is not back on $T2"
http /up
[ "$HTTP_CODE" = 200 ] || fail "7: /up answered $HTTP_CODE"
ok 7 "an invalid Caddyfile: refused before maintenance, clone back on $T2"

# --- 8. Refusals ---------------------------------------------------------------
run_deploy $T6
[ "$DEPLOY_CODE" = 2 ] || fail "8: a tag off main exited $DEPLOY_CODE, not 2"
run_deploy 1.0
[ "$DEPLOY_CODE" = 2 ] || fail "8: a malformed tag exited $DEPLOY_CODE, not 2"
run_deploy $T2
[ "$DEPLOY_CODE" = 2 ] || fail "8: the running tag exited $DEPLOY_CODE, not 2"
ok 8 "refused: a tag off main, a malformed tag, the running tag"

# --- 9. A dropped session ------------------------------------------------------
set +e
bash "$DEPLOY" $T3 > /dev/full 2> /dev/null
HANGUP_CODE=$?
set -e
[ "$HANGUP_CODE" = 0 ] || fail "9: deploy.sh with an unwritable stdout exited $HANGUP_CODE"
grep -q "release $T3 is running" "$BB_HOME/state/deploy.log" || fail "9: state/deploy.log does not hold the run"
[ "$(release release)" = $T3 ] || fail "9: the release is not $T3"
ok 9 "an unwritable stdout: the deploy finished and state/deploy.log holds it"

# --- 10. The backup warning ----------------------------------------------------
grep -q 'backup: not running here' "$BB_HOME/state/deploy.log" || fail "10: no 'backup: not running here' in the log"
ok 10 "no backup service: the output says so"

echo "deploy-test: passed"
