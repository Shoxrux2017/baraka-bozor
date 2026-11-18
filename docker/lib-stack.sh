# shellcheck shell=bash
# Sourced by docker/stack.sh and docker/deploy.sh, never run. It finds the
# server's layout (DL-141) and wraps Docker Compose for the production stack.
#
#   BB_HOME       the server's directory (default /opt/barakabozor): repo/,
#                 stack.env, state/, dumps/, maintenance/
#   BB_STACK_ENV  the stack env file (default $BB_HOME/stack.env)
#
# The repository is the one this file lives in, so the scripts act on the
# checkout they were started from.

BB_HOME="${BB_HOME:-/opt/barakabozor}"
STACK_ENV="${BB_STACK_ENV:-$BB_HOME/stack.env}"
# pwd -W: git for Windows does not read the /g/... form.
BB_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && { pwd -W 2>/dev/null || pwd; })"

# stack_value NAME: the last NAME=value line of the stack env file.
stack_value() {
  { grep -E "^$1=" "$STACK_ENV" || true; } | tail -n 1 | cut -d= -f2- | tr -d '\r'
}

# current_release: the tag of the running release, or nothing before the first.
current_release() {
  if [ -f "$BB_HOME/state/release" ]; then
    tr -d '\r\n' < "$BB_HOME/state/release"
  fi
}

# compose ARGS...: docker compose for the production stack, from the repository
# root. BB_RELEASE, when not already set, is the running release, so a plain
# `compose up` never moves the stack to another image.
compose() {
  local release="${BB_RELEASE:-$(current_release)}"
  local override="${BB_COMPOSE_OVERRIDE:-$(stack_value BB_COMPOSE_OVERRIDE)}"
  local args=(--env-file "$STACK_ENV" -f docker/compose.prod.yaml)
  if [ -n "$override" ]; then
    args+=(-f "$override")
  fi
  (
    cd "$BB_REPO"
    if [ -n "$release" ]; then
      export BB_RELEASE="$release"
    fi
    docker compose "${args[@]}" "$@"
  )
}
