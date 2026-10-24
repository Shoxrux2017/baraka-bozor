#!/bin/sh
# The weekly job: restic reads back a tenth of the repository's data and checks
# the rest of its structure, so a damaged copy shows before a restore needs it.
set -eu
# shellcheck source=/dev/null
. /usr/local/bin/lib.sh

if restic check --read-data-subset=10% --retry-lock 30m; then
  bb_write_status check "{\"result\":\"success\",\"finished_at\":\"$(bb_now)\"}"
  bb_log "repository check passed"
else
  bb_write_status check "{\"result\":\"failure\",\"finished_at\":\"$(bb_now)\",\"step\":\"check\"}"
  bb_log "repository check failed"
  exit 1
fi
