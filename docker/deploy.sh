#!/usr/bin/env bash
# Deploys a release tag into the clone on the server, or goes back one release
# (DL-141 (6), (7)). Run it on the server, as the deploy user:
#
#   docker/deploy.sh r2026.11.19.1
#   docker/deploy.sh --rollback   the release before the running one
#   docker/deploy.sh --resume     the running release, back in service
#
# Exit 0: done. Exit 1: a failure; after maintenance began the API keeps
# answering 503 and the output names the dump and the way out (--resume, or a
# fixed tag). Exit 2: a refusal or a usage error; the running release is
# untouched.
#
# The whole run is in main(): a checkout may replace this file while it runs.
# SIGHUP is ignored and the output is mirrored to state/deploy.log, so a dropped
# SSH session neither stops the deploy nor loses its record.
set -euo pipefail
export MSYS_NO_PATHCONV=1

# shellcheck source=docker/lib-stack.sh
. "$(dirname "$0")/lib-stack.sh"

# These stay global on purpose: the EXIT trap reads them after main() returned.
mode=deploy
tag=""
current=""
phase=pre
maint=""
dump=""
tee_pid=""

say() { printf 'deploy: %s\n' "$*"; }
warn() { printf 'deploy: warning: %s\n' "$*"; }
refuse() { printf 'deploy: %s\n' "$*" >&2; exit 2; }
git_repo() { git -C "$BB_REPO" "$@"; }

# Files keep the mode git records: the image copies the working tree, and a
# umask of 077 there would leave the application unreadable to www-data.
checkout() { ( umask 022; git_repo -c advice.detachedHead=false checkout --quiet --detach "$1" ); }

# The exit path of every run: restores the clone after an early failure, names
# the way out after a late one, releases the lock, lets the log finish.
finish() {
  local code=$?
  trap - EXIT
  if [ "$code" != 0 ]; then
    case "$phase" in
      pre)
        if [ -n "$current" ]; then
          checkout "$current" || warn "could not return the clone to $current"
        fi
        if [ "$code" != 2 ]; then
          code=1
        fi
        ;;
      maintenance)
        code=1
        say "FAILED with maintenance on: the API answers 503 until this is settled"
        if [ -n "$dump" ]; then
          say "the database before this deploy: $dump"
        fi
        if [ "$mode" = resume ]; then
          say "run docker/deploy.sh --resume again once the cause is fixed"
        elif [ -n "$current" ]; then
          say "to return to the running release $current: docker/deploy.sh --resume; or deploy a fixed tag"
          say "--rollback only goes one release further back (refused when migrations differ; then fix forward, with the dump as the last resort)"
        else
          say "there is no running release: fix the cause and deploy again"
        fi
        ;;
    esac
  fi
  rmdir "$BB_HOME/state/deploy.lock" 2> /dev/null || true
  if [ -n "$tee_pid" ]; then
    exec > /dev/null 2>&1
    wait "$tee_pid" 2> /dev/null || true
  fi
  exit "$code"
}

# record_release NEW OLD: both state files through a temp file and mv.
record_release() {
  local state="$BB_HOME/state"
  if [ -n "$2" ]; then
    printf '%s\n' "$2" > "$state/.release.previous.tmp"
    mv "$state/.release.previous.tmp" "$state/release.previous"
  fi
  printf '%s\n' "$1" > "$state/.release.tmp"
  mv "$state/.release.tmp" "$state/release"
}

# Warnings only; a failed check never fails the deploy.
after_checks() {
  local url running status
  url="$(stack_value APP_URL)"
  if curl -fsS --max-time 10 "$url/up" > /dev/null 2>&1; then
    say "$url/up answers"
  else
    warn "$url/up did not answer"
  fi

  running="$(compose ps --status running --format '{{.Service}}' 2> /dev/null | tr -d '\r' || true)"
  if ! printf '%s\n' "$running" | grep -qx backup; then
    say "backup: not running here"
    return 0
  fi
  if ! status="$(compose exec -T backup cat /status/backup.json 2> /dev/null)"; then
    say "backup: no night yet"
    return 0
  fi
  backup_report "$status" "$(date +%s)"
}

# prune_images CURRENT PREVIOUS: only release-tagged images go, so other tags
# of the same repositories (latest, rehearsal) stay.
prune_images() {
  local repo t
  for repo in barakabozor-app barakabozor-backup; do
    { docker image ls "$repo" --format '{{.Tag}}' | tr -d '\r' | grep -E '^r[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+$' || true; } \
      | while read -r t; do
        if [ "$t" != "$1" ] && [ "$t" != "$2" ]; then
          docker image rm "$repo:$t" > /dev/null 2>&1 || warn "could not remove $repo:$t"
        fi
      done
  done
  # The build cache is shared by everything on the machine; only the server,
  # which sets BB_BUILDER_PRUNE=1, trims it.
  if [ "$(stack_value BB_BUILDER_PRUNE)" = 1 ]; then
    docker builder prune -f --filter until=168h > /dev/null || warn "docker builder prune failed"
  fi
}

rollback() {
  local previous="" newest
  if [ -f "$BB_HOME/state/release.previous" ]; then
    previous="$(tr -d '\r\n' < "$BB_HOME/state/release.previous")"
  fi
  [ -n "$current" ] || refuse "no release is running; there is nothing to roll back"
  [ -n "$previous" ] || refuse "there is no previous release to go back to"
  if ! git_repo diff --quiet "$previous" "$current" -- backend/database/migrations; then
    # shellcheck disable=SC2012
    newest="$(ls -1 "$BB_HOME/dumps"/*.dump 2> /dev/null | sort -r | head -n 1 || true)"
    refuse "$previous and $current differ in backend/database/migrations; migrations only go forward, so fix forward. The newest dump: ${newest:-none}"
  fi
  docker image inspect "barakabozor-app:$previous" > /dev/null 2>&1 \
    || refuse "the image barakabozor-app:$previous is gone; deploy $previous again instead"

  checkout "$previous"
  phase=maintenance
  touch "$maint/on"
  say "maintenance on"
  BB_RELEASE="$previous" compose up -d --wait --wait-timeout 180
  compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
  rm -f "$maint/on"
  say "maintenance off"
  # The two files swap places.
  printf '%s\n' "$current" > "$BB_HOME/state/.release.previous.tmp"
  printf '%s\n' "$previous" > "$BB_HOME/state/.release.tmp"
  mv "$BB_HOME/state/.release.previous.tmp" "$BB_HOME/state/release.previous"
  mv "$BB_HOME/state/.release.tmp" "$BB_HOME/state/release"
  phase=post
  say "release $previous is running again"
}

# resume: the running release back in service after a failed deploy. Refused
# when the database already holds a migration the running release lacks.
resume() {
  local files extra
  [ -n "$current" ] || refuse "no release is running; deploy a tag instead"
  [ -z "$(git_repo status --porcelain --untracked-files=no)" ] || refuse "tracked files in $BB_REPO are modified"
  compose up -d --no-recreate --wait db
  files="$(git_repo ls-tree --name-only "$current" backend/database/migrations/ | sed 's|.*/||; s|\.php$||' | sort)"
  # shellcheck disable=SC2016
  extra="$(compose exec -T db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA -c "select migration from migrations"' \
    | tr -d '\r' | sort | comm -23 - <(printf '%s\n' "$files"))"
  if [ -n "$extra" ]; then
    refuse "the database holds migrations that $current lacks: $(printf '%s' "$extra" | tr '\n' ' '); fix forward with a new tag"
  fi

  checkout "$current"
  phase=maintenance
  BB_RELEASE="$current" compose up -d --wait --wait-timeout 180
  compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
  rm -f "$maint/on"
  phase=post
  say "maintenance off"
  say "release $current is running again"
}

main() {
  trap '' HUP
  umask 077

  local tag_pattern='^r[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]+$' old

  case "${1:-}" in
    --resume)
      [ "$#" = 1 ] || refuse "usage: docker/deploy.sh <tag> | --rollback | --resume"
      mode=resume
      ;;
    --rollback)
      [ "$#" = 1 ] || refuse "usage: docker/deploy.sh <tag> | --rollback | --resume"
      mode=rollback
      ;;
    "" | -*) refuse "usage: docker/deploy.sh <tag> | --rollback | --resume" ;;
    *)
      [ "$#" = 1 ] || refuse "usage: docker/deploy.sh <tag> | --rollback | --resume"
      tag="$1"
      ;;
  esac

  # The scripts act on the repository they live in. Only the server's clone is
  # allowed, so a run from another checkout never moves its tags and files.
  if [ ! -d "$BB_HOME/repo" ] || [ "$(cd "$BB_HOME/repo" && pwd -P)" != "$(cd "$BB_REPO" && pwd -P)" ]; then
    refuse "this checkout is not $BB_HOME/repo; deploy.sh deploys only the server's clone"
  fi
  [ -f "$STACK_ENV" ] || refuse "the stack env file $STACK_ENV does not exist"
  maint="$(stack_value MAINTENANCE_DIR)"
  [ -n "$maint" ] || refuse "MAINTENANCE_DIR is not set in the stack env file"

  mkdir -p "$BB_HOME/state" "$BB_HOME/dumps" "$maint"
  if ! mkdir "$BB_HOME/state/deploy.lock" 2> /dev/null; then
    refuse "another deploy holds $BB_HOME/state/deploy.lock"
  fi
  trap finish EXIT

  exec > >(tee -a --output-error=warn "$BB_HOME/state/deploy.log") 2>&1
  tee_pid=$!

  current="$(current_release)"
  say "$(date -u +%Y-%m-%dT%H:%M:%SZ) start: ${tag:-$mode} (running: ${current:-none})"

  if [ "$mode" = rollback ]; then
    rollback
    return 0
  fi
  if [ "$mode" = resume ]; then
    resume
    return 0
  fi

  # 1. Checks.
  [[ "$tag" =~ $tag_pattern ]] || refuse "'$tag' is not a release tag (r<yyyy>.<mm>.<dd>.<n>)"
  if ! git_repo fetch --quiet --tags origin; then
    say "git fetch failed"
    return 1
  fi
  git_repo rev-parse -q --verify "refs/tags/$tag^{commit}" > /dev/null || refuse "the tag $tag does not exist on origin"
  git_repo merge-base --is-ancestor "$tag^{commit}" origin/main || refuse "$tag is not on origin/main"
  [ "$tag" != "$current" ] || refuse "$tag is already the running release"
  [ -z "$(git_repo status --porcelain --untracked-files=no)" ] || refuse "tracked files in $BB_REPO are modified"

  # 2. The tag's files.
  checkout "$tag"
  say "checked out $tag"

  # 3. The Caddyfile, before anything running is touched.
  if ! compose run --rm -T --no-deps --entrypoint caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile > /dev/null; then
    refuse "the Caddyfile of $tag is not valid; $tag was not deployed"
  fi

  # 4. The images.
  BB_RELEASE="$tag" compose build

  # 5. The database, before maintenance.
  if [ -n "$current" ]; then
    dump="$BB_HOME/dumps/$(date -u +%Y%m%dT%H%M%SZ)-before-$tag.dump"
    # shellcheck disable=SC2016
    if ! compose exec -T db sh -c 'pg_dump -Fc -U "$POSTGRES_USER" "$POSTGRES_DB"' > "$dump" || [ ! -s "$dump" ]; then
      rm -f "$dump"
      say "the database dump failed; $tag was not deployed"
      return 1
    fi
    say "dump: $dump"
    # The newest five stay.
    # shellcheck disable=SC2012
    ls -1 "$BB_HOME/dumps"/*.dump | sort -r | tail -n +6 | while read -r old; do rm -f "$old"; done
  fi

  # 6. Maintenance. From here a failure leaves it on.
  phase=maintenance
  touch "$maint/on"
  say "maintenance on"

  # 7. Nothing may write while the schema changes (the first deploy has no
  # stack yet, only a database to start).
  if [ -n "$current" ]; then
    compose stop worker scheduler
  else
    compose up -d --no-recreate --wait db
  fi

  # 8. The schema, from the new image.
  BB_RELEASE="$tag" compose run --rm -T --no-deps app php artisan migrate --force

  # 9. The new release.
  BB_RELEASE="$tag" compose up -d --wait --wait-timeout 180

  # 10. The checked-out Caddyfile.
  compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile

  # 11. The API answers again and the release is recorded.
  rm -f "$maint/on"
  say "maintenance off"
  record_release "$tag" "$current"
  phase=post
  say "release $tag is running"

  # 12 and 13.
  after_checks
  prune_images "$tag" "$current"
}

main "$@"
exit 0
