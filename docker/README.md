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
A second job, `Production image, backup and restore`, runs
`docker build -f docker/app.prod.Dockerfile --build-context runtime=docker backend`
so the production image is proven against the current `php:8.4-fpm` on every
pull request. It then builds the backup image and runs the backup cycle below.

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
| `docker/backup/` | The backup image and its scripts, described in "Backups" below |
| `docker/backup.env.example` | The backup service's own env file, with no values |

The development `app.Dockerfile` and `compose.yaml` stay for development and CI.
The production image holds no Composer and no tests.

Run it from the repository root with one env file, kept outside the repository:

```text
docker compose --env-file <file> -f docker/compose.prod.yaml up -d --build
```

A fresh stack has an empty database; migrate it once:

```text
docker compose --env-file <file> -f docker/compose.prod.yaml run --rm app php artisan migrate --force
```

In production the boot refuses an incomplete configuration and names the
settings that are wrong, never their values (`DL-107` (3)).

**The rehearsal on this machine.** The project is `bb-prod-local`
(`COMPOSE_PROJECT_NAME=bb-prod-local`), with Caddy on `127.0.0.1:8080` and
`8443`, the API at `https://localhost:8443` and the panel at
`https://panel.localhost:8443` (with
`CORS_ALLOWED_ORIGINS=https://panel.localhost:8443`; a client sends no SNI for
an IP address, so the panel needs a host name). The env files live outside the
repository. Caddy signs with its own internal CA. To trust it, export its root
certificate from `/data/caddy/pki/authorities/local/root.crt` in the `caddy`
container and point `SSL_CERT_FILE` at the copy.

A production env file proves the boot, the edge and the processes. The Wave 3
walkthrough runs on the same image and stack with `APP_ENV=local`, since test
phones are refused in production. Start it with `WALKTHROUGH_SCHEDULER=1`: the
script then waits for the stack's scheduler to write the expiry instead of
running `approvals:expire` itself. Remove the rehearsal only with
`docker compose --env-file <the rehearsal's env file> -f docker/compose.prod.yaml down -v`.

`docker/DEPLOY.md` (W4-5) will be the server runbook.

## Backups

`DL-109` records the decisions. A `backup` container, in the production stack under
the Compose profile `backup`, dumps the database and copies the product images into
an encrypted restic repository every night at 03:00 Tashkent. The files:

| File | Role |
|---|---|
| `docker/backup/Dockerfile` | The image: Alpine with `restic`, `supercronic`, `postgresql17-client` and `tzdata`; runs as uid 10001 |
| `docker/backup/crontab` | The nightly backup at 03:00 and the weekly check on Sunday at 05:00 |
| `docker/backup/lib.sh` | Shared by the jobs: the log and the status files |
| `docker/backup/backup.sh` | The night: dump, snapshot, retention, optional ping |
| `docker/backup/check.sh` | The weekly `restic check` over 10% of the data |
| `backup-tool` (a service in `docker/compose.prod.yaml`) | The backup image for the host scripts' one-off runs, under the profile `tools` with no Docker log (`DL-109`) |
| `docker/backup/create-role.sh` | Creates the read-only database role (host script) |
| `docker/backup/restore.sh` | Restores one snapshot into an empty stack (host script) |
| `docker/backup/test-cycle.sh` | Back up, wipe, restore and compare, on a scratch stack (host script) |
| `docker/backup/compose.local-repo.yaml` | Mounts a host directory as the repository, for the test and for a disk-only setup |

**Switching it on.** Once, on the server:

1. Copy `docker/backup.env.example` to a file outside the repository and fill it:
   the repository address, the restic password, the storage keys, and a generated
   `PGPASSWORD` for the role `barakabozor_backup`. Keep the restic password with the
   Owner as well: a lost password means copies nobody can read.
2. In the stack's env file set `COMPOSE_PROFILES=backup` and `BACKUP_ENV_FILE` to
   that file's absolute path. Compose requires `BACKUP_ENV_FILE` in every stack,
   even one that does not run the backup.
3. Start the stack, then create the role and the repository:

```text
docker compose --env-file <file> -f docker/compose.prod.yaml up -d --build
docker/backup/create-role.sh <file>
docker compose --env-file <file> -f docker/compose.prod.yaml exec backup restic init
```

`create-role.sh` is safe to run again, and again after `PGPASSWORD` changes. The job
never runs `restic init` (`DL-109` (7)).

**Reading the outcome.** Each run overwrites a small file in the `backup-status`
volume, and the container's log keeps the history:

```text
docker compose --env-file <file> -f docker/compose.prod.yaml exec backup cat /status/backup.json
docker compose --env-file <file> -f docker/compose.prod.yaml exec backup cat /status/check.json
docker compose --env-file <file> -f docker/compose.prod.yaml logs backup
```

`result` is `success` or `failure`; a failure names its `step` (`config`, `dump`,
`backup` or `forget`). A success counts only when `finished_at` is from the last
night, so a `success` older than about 26 hours means the night did not run: a
stopped container or a run killed outright leaves the previous status. The W4-5
deploy check tests the age of `finished_at`, and so does the Owner's checklist. Only one run goes at a
time; a second one stops with "another backup is running" and leaves the status
alone. A backup by hand is the same script the night runs:

```text
docker compose --env-file <file> -f docker/compose.prod.yaml exec backup backup.sh
```

To see the schedule, `exec backup supercronic -test /etc/backup/crontab` validates
the file and `exec backup date` shows the container's time (+05).

**Keeping the keys.** The stack's env file is in no backup. Keep `APP_KEY` and
`PHONE_FINGERPRINT_KEY` with the Owner beside the restic password: after a lost
server, without the fingerprint key the restored blocked-phone fingerprints
(`BR-ROLE-013`, `DL-95`) can no longer be matched.

**Restoring.** Only into an empty stack: `restore.sh` stops with "not empty" when
the database already holds tables. Without a snapshot id it lists the snapshots:

```text
docker/backup/restore.sh <env file>
docker/backup/restore.sh <env file> <snapshot id>
```

A restore is tried in a scratch stack with its own env file: another
`COMPOSE_PROJECT_NAME`, other published ports and `EDGE_SUBNET`, no
`COMPOSE_PROFILES=backup`, and the same `BACKUP_ENV_FILE`, since `restore.sh` reads
the repository through the backup image. Remove the scratch stack only with
`docker compose --env-file <that stack's env file> -f docker/compose.prod.yaml down -v`.
A scratch stack uses fake drivers and no production credentials
(`LOGIN_CODE_DRIVER=fake`, no Telegram or Firebase keys): the final `up -d` of
`restore.sh` starts the worker and the scheduler on copied Customer data. Roles are
not in the dump, so `restore.sh` ends by printing a reminder and does not run
`create-role.sh` itself: a scratch stack that kept `COMPOSE_PROFILES=backup` would
otherwise write snapshots into the production repository. After a real recovery run
`docker/backup/create-role.sh <env file>`, and the restored stack's nights work. If a restore fails after the database
committed (the images or the migration), a rerun is refused as "not empty": run
`down -v` on that stack, with its `--env-file`, and restore again.

**The test cycle.** `docker/backup/test-cycle.sh` runs the whole path in the project
`bb-backup-test` against a repository on a host directory: a failing night, a good
night, the read-only role, the restore with a fingerprint of every table and the
images, and the refusal of a second restore. CI runs it on every pull request. On
Windows give it a path Docker Desktop can mount:

```text
BACKUP_TEST_DIR=G:/tmp/backup-test bash docker/backup/test-cycle.sh
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
