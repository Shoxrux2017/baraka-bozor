#!/usr/bin/env bash
# Creates, or refreshes, the database role the backup connects as: it reads
# every table and writes nothing, so a leaked backup credential cannot alter the
# data (DL-104 (6)). Idempotent; run it once after the first `up` and after any
# change of PGPASSWORD in the backup env file.
#
#   docker/backup/create-role.sh <stack env file>
#
# The password is read from the backup container itself, so Compose's own
# env-file parsing applies, and reaches psql on stdin: never on a command line.
set -euo pipefail
export MSYS_NO_PATHCONV=1

cd "$(dirname "$0")/../.."

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: docker/backup/create-role.sh <stack env file>" >&2
  exit 2
fi
stack_env="$1"

compose() {
  docker compose --env-file "$stack_env" -f docker/compose.prod.yaml \
    ${BB_COMPOSE_OVERRIDE:+-f "$BB_COMPOSE_OVERRIDE"} "$@"
}

password="$(compose run --rm --no-deps -T backup printenv PGPASSWORD | tr -d '\r')"
if [ -z "$password" ]; then
  echo "create-role: PGPASSWORD is empty in the backup env file" >&2
  exit 1
fi

# shellcheck disable=SC2016
{
  printf '%s\n' "$password"
  cat <<'SQL'
\getenv pw BB_BACKUP_PASSWORD
SELECT 'CREATE ROLE barakabozor_backup LOGIN'
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'barakabozor_backup')
\gexec
ALTER ROLE barakabozor_backup PASSWORD :'pw';
GRANT pg_read_all_data TO barakabozor_backup;
SQL
} | compose exec -T db sh -c \
  'read -r BB_BACKUP_PASSWORD; export BB_BACKUP_PASSWORD; psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -q'
