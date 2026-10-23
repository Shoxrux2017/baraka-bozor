# Docker

Local development and test runtime: PostgreSQL 17 plus a PHP 8.4 container that
has `pdo_pgsql`. Introduced by the approved Wave 0 task `W0-INT-001`.

PHP runs in the container, not on the host. The host PHP is Herd-lite, which has
no loadable extension directory and cannot provide `pdo_pgsql`. Running in the
container also keeps local runs, CI and production on the same Linux PHP, which
is what makes a green check on a pull request mean something.

This stack is for development and tests only. The production stack is a separate
file set, described in "The production stack" below; `docs/07-architecture.md`
Section 34 gives the topology.

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
docker compose -f docker/compose.yaml exec app php artisan storage:link
```

`storage:link` publishes the `public` disk under `/storage`, where product images are served from (`DL-21`). Image URLs are absolute and built from `APP_URL`, so `APP_URL` in `backend/.env` must be the address the clients use: `http://10.0.2.2:8000` for the Android emulator, the machine's LAN address for a phone. A change to `docker/php.ini` (the upload limits among them) needs `up -d --build`.

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

## Walk a wave on the real stack

`compose.yaml` publishes no port. Serve the API on the loopback address from a
one-off container, and stop it when done:

```text
docker compose -f docker/compose.yaml run --rm -d --name baraka-bozor-serve -p 127.0.0.1:8000:8000 app php artisan serve --host 0.0.0.0 --port 8000
docker stop baraka-bozor-serve
```

The walkthrough's staff accounts are the Shopper, the Courier (behind the
first-login gate), the Operator, the Admin and the Manager on +998 90 000 00 02
to 06. A seeder creates them in the local environment only, with the password
set as `WALKTHROUGH_STAFF_PASSWORD` in `backend/.env` (`DL-35`); a second run
leaves them as they are:

```text
docker compose -f docker/compose.yaml exec app php artisan db:seed --class=WalkthroughSeeder
```

Customers sign in with a phone from `LOGIN_CODE_TEST_PHONES` and the code
`LOGIN_CODE_TEST_CODE`. Each wave's API walkthrough is a script under
`tasks/scripts/`, which reads the same three settings from `backend/.env`:
`python tasks/scripts/wave1_api_walkthrough.py`, `python
tasks/scripts/wave2_api_walkthrough.py`, `python
tasks/scripts/wave3_api_walkthrough.py`. The Wave 2 walkthrough also orders
from the Shopper's own phone in Customer mode, so +998 90 000 00 02 must be
among the test phones. The Wave 3 walkthrough takes about thirty-five
minutes: a question to the Customer must really expire, which it waits for,
and it runs `approvals:expire` through `docker compose exec`, checking in the
order's history that the command wrote the expiry (`DL-73` (1)). It
creates its own two Couriers, so the seeded Courier keeps its first-login
gate. Each script takes the API's address as its argument when it is not
`http://127.0.0.1:8000/api/v1`.

## Laravel Boost for the agent

`laravel/boost`, a dev dependency on trial (`DL-103`, `DL-106`), gives the
implementing agent an MCP server that reads the running app: the schema, read-only
queries, absolute URLs, the application log, the last error, and Laravel's
documentation for the exact installed versions. It runs inside the `app`
container, so the stack must be up. Claude Code starts it from a registration in
the developer's own Claude configuration, never from a file in this repository:

```text
claude mcp add --scope local laravel-boost -- docker compose -f <repository>/docker/compose.yaml exec -T app php artisan boost:mcp
```

Never run `boost:install` or `boost:update`. They write `AGENTS.md`, `CLAUDE.md`,
`.mcp.json`, guidelines and skills over the project's own rules. Two lines of
`backend/.env.example`, which `backend/.env` must carry too, switch off two
features: the browser log watcher, because Laravel serves no
JavaScript page and the watcher adds a route that takes writes without a sign-in,
and the rule recorder, because project rules live in `AGENTS.md` and
`docs/DECISIONS.md`. Its `tinker` tool stays off, as it is by default.
`database-query` runs in a read-only transaction that is always rolled back.
`search-docs` sends the question and the list of installed packages to
boost.laravel.com, so a question must never carry data from the database.

Boost and `laravel/mcp` are kept out of package discovery, because `laravel/mcp`
would add a global middleware to every request, the test suite's too.
`AppServiceProvider` loads them only for console commands in the `local`
environment, so served requests and the tests run the same global
middleware stack as production, and the production image installs no dev
dependencies.

## The production stack

`DL-107` records the decisions. The files:

| File | Role |
|---|---|
| `docker/app.prod.Dockerfile` | The production image, built from `backend/`: PHP 8.4 FPM, no dev dependencies, runs as `www-data` |
| `backend/.dockerignore` | Keeps `vendor/`, `.env*`, tests and `storage/` contents out of the image |
| `docker/php.prod.ini` | Opcache without timestamp checks; hides the PHP version |
| `docker/php-fpm.prod.conf` | The FPM pool: the container's environment, no access log, 12 workers |
| `docker/entrypoint.prod.sh` | Runs `php artisan optimize`, then the container's process |
| `docker/compose.prod.yaml` | `caddy`, `app`, `worker`, `scheduler` and `db`; only Caddy publishes ports |
| `docker/caddy/Caddyfile` | The API host, the panel host and the images |
| `docker/production.env.example` | Every variable the server needs, with no values |

The development `app.Dockerfile` and `compose.yaml` stay for development and CI.
The production image holds no Composer and no tests.

Run it from the repository root with one env file, kept outside the repository:

```text
docker compose --env-file <file> -f docker/compose.prod.yaml up -d --build
```

In production the boot refuses an incomplete configuration and names the
settings that are wrong, never their values (`DL-107` (3)).

**The rehearsal on this machine.** The project is `bb-prod-local`
(`COMPOSE_PROJECT_NAME=bb-prod-local`), with Caddy on `127.0.0.1:8080` and
`8443`, the API at `https://localhost:8443` and the panel at
`https://127.0.0.1:8443`. The env files live outside the repository. Caddy signs
with its own internal CA. To trust it, export its root certificate from
`/data/caddy/pki/authorities/local/root.crt` in the `caddy` container and point
`SSL_CERT_FILE` at the copy.

A production env file proves the boot, the edge and the processes. The Wave 3
walkthrough runs on the same image and stack with `APP_ENV=local`, since test
phones are refused in production. Start it with `WALKTHROUGH_SCHEDULER=1`: the
script then waits for the stack's scheduler to write the expiry instead of
running `approvals:expire` itself. Remove the rehearsal only with
`down -v -p bb-prod-local`.

`docker/DEPLOY.md` (W4-5) will be the server runbook.

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
