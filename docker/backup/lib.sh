# shellcheck shell=sh
# Shared by backup.sh and check.sh. Sourced, never run.

# ISO 8601 with the offset: busybox date prints +0500, so the colon is added.
bb_now() {
  zone="$(date +%z)"
  printf '%s%s:%s' "$(date +%Y-%m-%dT%H:%M:%S)" "${zone%??}" "${zone#???}"
}

# bb_write_status <name> <json>: the temp file and mv keep a reader from ever
# seeing half a file.
bb_write_status() {
  printf '%s\n' "$2" > "/status/.$1.tmp"
  mv "/status/.$1.tmp" "/status/$1.json"
}

bb_log() {
  printf '%s: %s\n' "$(basename "$0")" "$1"
}
