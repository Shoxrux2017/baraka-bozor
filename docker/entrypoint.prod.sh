#!/bin/sh
# Each container builds its own caches at start, because a cache baked into an
# image or left in an old container dies with it (DL-104 (7)). `optimize` boots
# the application, so the production boot check (DL-107) stops a misconfigured
# container here, before it serves a single request.
set -eu

php artisan optimize

exec "$@"
