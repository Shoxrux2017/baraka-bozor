#!/usr/bin/env bash
# Restores one snapshot into an empty stack: the database from the dump, the
# product images into their volume (DL-104 (6)). Only into an empty stack: it
# refuses when the database already holds tables, so a restore aimed at a live
# stack stops before touching anything. The `backup` role is cluster-wide and not
# in the dump, so a production stack restored from scratch runs `create-role.sh`
# again.
#
#   docker/backup/restore.sh <stack env file> [<snapshot id>]
#
# Without a snapshot id it lists the snapshots and exits 2.
set -euo pipefail
export MSYS_NO_PATHCONV=1

cd "$(dirname "$0")/../.."

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ] || [ ! -f "$1" ]; then
  echo "usage: docker/backup/restore.sh <stack env file> [<snapshot id>]" >&2
  exit 2
fi
stack_env="$1"
snapshot="${2:-}"

compose() {
  docker compose --env-file "$stack_env" -f docker/compose.prod.yaml \
    ${BB_COMPOSE_OVERRIDE:+-f "$BB_COMPOSE_OVERRIDE"} "$@"
}

if [ -z "$snapshot" ]; then
  compose run --rm --no-deps -T backup restic snapshots --host barakabozor
  echo "usage: docker/backup/restore.sh <stack env file> <snapshot id>" >&2
  exit 2
fi

project="$(compose config | sed -n 's/^name: //p')"

compose up -d --wait db

# shellcheck disable=SC2016
tables="$(compose exec -T db sh -c \
  'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA -c "select count(*) from pg_tables where schemaname = '"'public'"'"' \
  | tr -d '\r')"
if [ "$tables" != 0 ]; then
  echo "restore.sh: the database of $project is not empty; restore only into a new stack" >&2
  exit 1
fi

# shellcheck disable=SC2016
compose run --rm --no-deps -T backup restic dump "$snapshot" /backup/db/barakabozor.dump \
  | compose exec -T db sh -c '
      f="$(mktemp)"
      cat > "$f"
      code=0
      pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner --no-privileges \
        --single-transaction --exit-on-error "$f" || code=$?
      rm -f "$f"
      exit "$code"'

compose run --rm --no-deps -T backup restic dump "$snapshot" /backup/images \
  | compose run --rm --no-deps -T --entrypoint tar app \
      -x -f - -C /app/storage/app/public --strip-components=2

compose run --rm app php artisan migrate --force
compose up -d

echo "restore.sh: snapshot $snapshot restored into $project"
