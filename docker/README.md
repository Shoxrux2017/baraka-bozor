# Docker

Local development and test runtime: PostgreSQL 17 plus a PHP 8.4 container that
has `pdo_pgsql`. Introduced by the approved Wave 0 task `W0-INT-001`.

PHP runs in the container, not on the host. The host PHP is Herd-lite, which has
no loadable extension directory and cannot provide `pdo_pgsql`. Running in the
container also keeps local runs, CI and production on the same Linux PHP, which
is what makes a green check on a pull request mean something.

This stack is for development and tests only. It is not a deployment target; see
`docs/07-architecture.md` Section 34 for production topology.

## PHP configuration is set explicitly

`docker/php.ini` is copied into the image as
`/usr/local/etc/php/conf.d/zz-baraka-bozor.ini`, and it is the one place any value
this project sets deliberately belongs. Nothing repeats those values: not
`compose.yaml`, not `.github/workflows/backend.yml`, not a flag on any command.
Two copies of a number drift silently.

**The main `php.ini` stays absent by design.** The `php:8.4-cli` image activates
none — it ships `php.ini-development` and `php.ini-production` and expects the
build to pick one — and both of those set `memory_limit = 128M` themselves,
identical to PHP's compiled-in fallback, so picking one would have changed
nothing. A small file in `conf.d/` holding only what this project sets is
reviewable instead. So `php --ini` reports `Loaded Configuration File: (none)`,
which is correct and does **not** mean the settings are missing; look under
`Additional .ini files parsed`:

```text
docker compose -f docker/compose.yaml exec app php --ini
docker compose -f docker/compose.yaml exec app php -r 'echo ini_get("memory_limit"), PHP_EOL;'
```

What is set, and why, is in the file's own comments. It currently sets one value,
`memory_limit`, because PHPStan's peak straddled the `128M` default — observed at
`170.5 MB` with the ceiling raised, and pinned at `126.5 MB` whenever `128M` was
the limit. `--debug` is the one mode that names the file PHPStan died on, so the
tool you reach for when the analyser crashes was itself crashing. These peaks move
with container state; the task contract `W0-INT-004` records the ranges rather
than one figure.

A change to `docker/php.ini` or to `docker/app.Dockerfile` needs
`up -d --build`. Without `--build` Compose keeps the existing image and the
change appears to have done nothing.

## Start

```text
docker compose -f docker/compose.yaml up -d --build
docker compose -f docker/compose.yaml ps
```

`db` must report `healthy` before the application can connect. The first build
takes a few minutes; later starts are immediate.

Then, once per clone or git worktree, prepare `backend/`:

```text
docker compose -f docker/compose.yaml exec app composer install
docker compose -f docker/compose.yaml exec app cp .env.example .env
docker compose -f docker/compose.yaml exec app php artisan key:generate
docker compose -f docker/compose.yaml exec app php artisan migrate --force
```

Both `vendor/` and `.env` are gitignored, so a fresh clone or a new worktree has
neither, and both are required. Without `vendor/` nothing runs at all. Without
`.env` the feature tests do not fail — they report warnings and silently
exercise nothing, which is worse than a red run. Install dependencies inside the
container rather than on the host, so the tree is built by the same Linux PHP
that will execute it.

## CI runs these same commands

`.github/workflows/backend.yml` brings up this same stack from this same
Dockerfile and runs the same commands as below — `composer install`, the `.env`
and key steps, `migrate`, then `php artisan test`, `vendor/bin/pint --test` and
`vendor/bin/phpstan analyse` — with the non-interactive flags a runner needs.

That is deliberate. It keeps local, CI and production on one runtime, and it
makes this document continuously tested. **A change here and a change in that
workflow must be made together** — if the procedure below drifts from what CI
runs, CI goes red instead of a new developer discovering it later.

## Several worktrees at once

The wave model runs one git worktree per track, so two stacks can be wanted at
the same time. Give each worktree its own project name and host port, in a
`.env` file next to `docker/compose.yaml` or exported in the shell:

```text
COMPOSE_PROJECT_NAME=bb-auth
DB_HOST_PORT=5433
```

Without this, `up` from a second worktree does not start a second stack: Compose
recognises the same project name, recreates the `app` container with the new bind
mount, and the first worktree's running environment silently starts serving the
second worktree's code — with one shared database underneath.

## Run the test suite

```text
docker compose -f docker/compose.yaml exec app php artisan test
```

The suite uses the separate `baraka_bozor_test` database, so it never touches
development data. `backend/phpunit.xml` pins that connection with `force="true"`,
which is load-bearing: without it PHPUnit would defer to any `DB_*` already in
the environment and the suite would quietly run against `baraka_bozor`. For the
same reason the `app` service deliberately sets no `DB_*` variables.

Other checks, same shape:

```text
docker compose -f docker/compose.yaml exec app php artisan migrate --force
docker compose -f docker/compose.yaml exec app php artisan db:show
docker compose -f docker/compose.yaml exec app vendor/bin/pint --test
docker compose -f docker/compose.yaml exec app vendor/bin/phpstan analyse
```

For an interactive shell:

```text
docker compose -f docker/compose.yaml exec app bash
```

## Stop

```text
docker compose -f docker/compose.yaml down
```

Containers stop; database contents survive in the `db-data` volume.

## Reset the data

```text
docker compose -f docker/compose.yaml down -v
docker compose -f docker/compose.yaml up -d
```

`-v` removes the volume, so the next start runs `initdb/` again and recreates
both databases empty. This is also the only way a change to
`initdb/01-create-test-database.sql` takes effect: PostgreSQL runs those scripts
once, on an empty volume.

## Databases

| Database | Used by |
|---|---|
| `baraka_bozor` | development, `php artisan migrate` |
| `baraka_bozor_test` | the test suite, via `backend/phpunit.xml` |

Reachable as host `db` from the `app` container, and as `127.0.0.1:5432` from a
database client on the host.

## Credentials

The values in `compose.yaml` and `backend/.env.example` are local development
defaults and are deliberately not secret. The database is published on
`127.0.0.1` only, so those defaults are not reachable from the network.
Production credentials come from the server environment and are never
committed — `AGENTS.md` Section 13.

## Two things to know about the bind mount

**File ownership.** The `app` container runs as root, so files it creates through
the mount — `vendor/`, `.env`, `storage/logs/*`, `bootstrap/cache/*` — are
root-owned. Docker Desktop on Windows and macOS hides this. On Linux it means you
may be unable to edit or clean your own tree; run the commands with
`--user "$(id -u):$(id -g)"` there.

**Do not run `config:cache`.** Nothing here needs it, and it would bake absolute
paths — `/app/...` inside the container, `G:\project\...` on the host — so a
cache written on one side breaks the other. If one gets written by accident,
`php artisan config:clear` removes it.
