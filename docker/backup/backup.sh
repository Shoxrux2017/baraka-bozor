#!/bin/sh
# The nightly job: dump the database, put the dump and the product images into
# the restic repository, thin out old snapshots. Any failure leaves a status
# naming its step, a non-zero exit and no dump file behind. It never runs
# `restic init`: a mistyped repository address must fail, not start a new
# repository (DL-104 (6)).
set -eu
# shellcheck source=/dev/null
. /usr/local/bin/lib.sh

DUMP=/backup/db/barakabozor.dump
STEP=config

on_exit() {
  code=$?
  rm -f "$DUMP"
  if [ "$code" -ne 0 ]; then
    bb_write_status backup "{\"result\":\"failure\",\"finished_at\":\"$(bb_now)\",\"step\":\"$STEP\"}"
    bb_log "failed at step $STEP"
  fi
}
trap on_exit EXIT
trap 'exit 1' INT TERM

for name in RESTIC_REPOSITORY RESTIC_PASSWORD PGHOST PGDATABASE PGUSER PGPASSWORD; do
  eval "value=\${$name:-}"
  if [ -z "$value" ]; then
    bb_log "$name is not set"
    exit 1
  fi
done

STEP=dump
# Uncompressed, so restic deduplicates night to night and compresses itself.
pg_dump --format=custom --compress=0 --file="$DUMP"

STEP=backup
output="$(restic backup --host barakabozor --retry-lock 30m --json "$DUMP" /backup/images)"
snapshot="$(printf '%s\n' "$output" | grep '"message_type":"summary"' \
  | sed -n 's/.*"snapshot_id":"\([0-9a-f]\{8\}\)[0-9a-f]*".*/\1/p')"
if [ -z "$snapshot" ]; then
  bb_log "restic reported no snapshot"
  exit 1
fi

STEP=forget
restic forget --host barakabozor --keep-daily 7 --keep-weekly 4 --keep-monthly 6 \
  --prune --retry-lock 30m

bb_write_status backup "{\"result\":\"success\",\"finished_at\":\"$(bb_now)\",\"snapshot\":\"$snapshot\"}"
bb_log "snapshot $snapshot done"

if [ -n "${BACKUP_PING_URL:-}" ]; then
  wget -q -T 10 -O /dev/null "$BACKUP_PING_URL" || bb_log "the ping failed"
fi
