#!/usr/bin/env bash
# Docker Compose for the production stack, with the running release's image tag
# (DL-141 (7)): the way a person runs Compose on the server.
#
#   docker/stack.sh ps
#   docker/stack.sh logs --tail 100 app
#   docker/stack.sh exec app php artisan about
set -euo pipefail
export MSYS_NO_PATHCONV=1

# shellcheck source=docker/lib-stack.sh
. "$(dirname "$0")/lib-stack.sh"

compose "$@"
