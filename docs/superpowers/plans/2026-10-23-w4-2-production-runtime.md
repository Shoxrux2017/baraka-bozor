# W4-2 — Production Runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task (one `plan-implementer` per task, the lead checks each diff). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The backend, the queue worker, the scheduler, the images and the web panel run as one production Docker Compose stack behind Caddy with TLS, and the same stack comes up on the development machine and passes the Wave 3 walkthrough.

**Architecture:** One multi-stage image (PHP 8.4 FPM, opcache, no dev dependencies, code baked in) runs as `app`, `worker` (`queue:work`) and `scheduler` (`schedule:work`); each container builds its Laravel caches at start, and a boot check refuses an incomplete production configuration before anything is served. Caddy alone publishes ports: `api.<domain>` goes to PHP-FPM over FastCGI and serves `/storage` images straight from the images volume, `panel.<domain>` serves the panel's static build. Caddy and `app` share a small `edge` network whose subnet is the one value of `TRUSTED_PROXIES`; the database lives on an `internal` network.

**Tech Stack:** Laravel 13, PHP 8.4 FPM (`php:8.4-fpm`, Debian, the dev image's family), PostgreSQL 17 (`postgres:17-alpine`, as dev), Caddy 2 (`caddy:2.<minor>-alpine`, pinned by minor), Docker Compose v2.

**Spec:** `tasks/WAVE_4.md` task note W4-2; `docs/DECISIONS.md` `DL-104` items (3), (4), (5), (8); `docs/07-architecture.md` sections 10, 25, 31, 34. Finer decisions of this task go into `DL-107` (Task 8 carries its text).

**Found before the plan (2026-10-23):**
- No `config/cors.php`: Laravel's default allows any origin on `api/*`. The panel reads `Retry-After` (`frontend/lib/core/network/api_failure.dart:75`), which a browser hides cross-origin unless it is exposed.
- `config/trustedproxy.php` already parses `TRUSTED_PROXIES`; the per-IP limits key on `$request->ip()` (`RequestCustomerLoginCode.php:53`, `AuthenticateStaff.php:47`).
- Boot checks exist only for the test phones (`TestPhones`, resolved in `AuthServiceProvider::boot`). The driver check throws at first resolve, not at boot. `config/login_codes.php` defaults the driver to `null` in production.
- Laravel's environment defaults to `production` when `APP_ENV` is unset, so any artisan command in the production image without an env file meets the boot check (useful in Task 5).
- Tables: `idempotency_keys` (`state` processing|completed, `completed_at`, `lease_expires_at`, raw access in `App\Support\Idempotency\IdempotencyStore`), `customer_otp_challenges` (model `App\Modules\Auth\Models\LoginChallenge`, `created_at`, no `updated_at`), `failed_jobs`. `notification_deliveries` does not exist yet (W4-7), nor does `push-devices:prune` (W4-8): their scheduler entries come with them.
- Dev database: `UTF8`, `en_US.utf8` collate and ctype, libc provider, on `postgres:17-alpine` defaults.
- `composer.lock`: `symfony/http-foundation` v8.0.15 and `league/commonmark` 2.10.1 carry the three advisories of the wave's risk row.
- `tasks/scripts/wave3_api_walkthrough.py` runs `approvals:expire` through the dev stack's `docker compose exec` (line 216) and checks that nothing wrote the expiry before it (line 579). With a scheduler running every minute that check would race it.

## Global Constraints

- Branch `task/w4-2-production-runtime` from `main` `f492f05`. Never commit to `main`.
- Every backend command runs in the dev container: `docker compose -f docker/compose.yaml exec -T app <command>` from the repository root.
- Never run `migrate:fresh`, `migrate:refresh`, `migrate:reset`, `migrate:rollback`, `db:wipe`, `db:seed` or any `--env=testing` artisan command against the dev stack. Tests use phpunit's `baraka_bozor_test` only. `backend/.env.testing` stays as it is.
- Never stop, remove or recreate containers or volumes of another Compose project: `testlabuz-*`, `bb-schema`, and the dev stack `baraka-bozor` (exec into it is fine). The rehearsal stack is the project `bb-prod-local`; `down -v` is used only with `-p bb-prod-local`.
- `README.md` at the root carries the Owner's own uncommitted edit and `.superpowers/` is untracked: neither is staged, ever.
- No dependency is added. The lockfile changes only in Task 1, with the reason in the commit message (`AGENTS.md` §7).
- No secret in the repository, an image, a commit or a log. Local rehearsal env files live in `G:/tools/bb-prod-local/`, outside the repository.
- Code comments match the surrounding density: a doc block saying why, citing `DL-`/`docs/` references, as `ExpireApprovalsCommand` and `config/trustedproxy.php` do.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Before the pull request: the full backend suite (sequential, about 2.5 minutes), `vendor/bin/pint --test`, `vendor/bin/phpstan analyse`, `git diff --check`, and `/security-review` once (the branch touches CORS, proxies and the boot check).

## Review Focus

1. **PHP-FPM drops the container's environment.** FPM's default `clear_env = yes` would hand PHP no `APP_KEY`, no `DB_PASSWORD`: the pool sets `clear_env = no`, and the boot check makes the failure loud. Task 5 Step 3 (`php-fpm -tt`) and Task 9 Step 3.
2. **An upload in the running stack.** The images volume is written by `www-data`, not root; an Admin's upload must land on the volume and be served by Caddy with its cache and origin headers. Task 5 Step 2 (ownership), Task 9 Step 6.
3. **A client that sends its own `X-Forwarded-For`.** Only a request from the trusted subnet may name the client; any other sender is counted by its own address. Task 2 Step 1 (`test_an_untrusted_sender_cannot_choose_its_address`), Task 9 Step 5.
4. **The panel reads `Retry-After` cross-origin.** A `429` on the panel must still show its countdown. Task 2 Step 1 (`test_retry_after_is_readable_cross_origin`).
5. **Phone digits in Caddy's log.** Caddy keeps no access log, but its error log names the request: during a deploy's `502` a board search's query string would land there. The global log filter strips query strings. Task 9 Step 7.

---

### Task 1: Security updates from `composer audit`

**Files:**
- Modify: `backend/composer.lock`

- [ ] **Step 1: Update the two packages only.** `docker compose -f docker/compose.yaml exec -T app composer update symfony/http-foundation league/commonmark --with-dependencies`. Expected: only these two and their own dependencies move; `git diff --stat` shows `composer.lock` alone.
- [ ] **Step 2: Audit.** `... exec -T app composer audit`. Expected: no advisory. If one remains that no release fixes, stop and report it.
- [ ] **Step 3: Full backend suite, Pint, PHPStan.** Expected: all green.
- [ ] **Step 4: Commit** `chore: update symfony/http-foundation and league/commonmark for composer audit` with the advisories' identifiers in the body (the reason, `AGENTS.md` §7).

### Task 2: The API behind the proxy — CORS and the client's address

**Files:**
- Create: `backend/config/cors.php`
- Modify: `backend/.env.example` (one line beside `TRUSTED_PROXIES`)
- Test: `backend/tests/Feature/Http/CorsTest.php`, `backend/tests/Feature/Http/TrustedProxyTest.php`

**Interfaces:**
- Produces: `config('cors.allowed_origins')` is a `list<string>`; Task 3's boot check reads it.

- [ ] **Step 1: Write the failing tests.**

`CorsTest` (each test sets `config(['cors.allowed_origins' => ['https://panel.example.test']])`):
  - `test_a_preflight_from_the_panel_is_allowed`: `OPTIONS /api/v1/auth/staff/login` with `Origin: https://panel.example.test`, `Access-Control-Request-Method: POST`, `Access-Control-Request-Headers: authorization, content-type, idempotency-key` → `204`, `Access-Control-Allow-Origin: https://panel.example.test`, `Access-Control-Max-Age: 7200`, no `Access-Control-Allow-Credentials` header.
  - `test_another_origin_gets_no_allow_header`: same preflight from `https://elsewhere.example.test` → no `Access-Control-Allow-Origin`.
  - `test_retry_after_is_readable_cross_origin`: a `POST /api/v1/auth/customer/code/request` from the panel origin → `Access-Control-Expose-Headers` contains `Retry-After`.
  - `test_the_public_pages_are_not_under_cors`: `GET /legal/privacy` with the panel origin → no `Access-Control-Allow-Origin`.

`TrustedProxyTest` (the trusted subnet `172.30.250.0/28`, set by `config(['trustedproxy.proxies' => [...]])`; ten distinct phones per address as in `CustomerLoginCodeTest::test_ten_requests_per_address_per_minute`):
  - `test_behind_the_proxy_the_limit_counts_each_client`: ten code requests with `REMOTE_ADDR=172.30.250.2` and `X-Forwarded-For: 203.0.113.10` → `200`; the eleventh from the same client → `429 rate_limited`; one with `X-Forwarded-For: 203.0.113.11` → `200`.
  - `test_an_untrusted_sender_cannot_choose_its_address`: `REMOTE_ADDR=198.51.100.7` sends ten requests, each with a different `X-Forwarded-For` → `200`; the eleventh → `429`.

- [ ] **Step 2: Run them.** `... exec -T app php artisan test --filter='CorsTest|TrustedProxyTest'`. Expected: the CORS tests FAIL (no max age, no exposed header, any origin allowed); the proxy tests may already pass, which proves the existing `config/trustedproxy.php` and is kept as the guard the wave note asks for.
- [ ] **Step 3: Write `config/cors.php`.** Laravel's own keys: `paths` `['api/*']`; `allowed_methods` `['*']`; `allowed_origins` parsed from `CORS_ALLOWED_ORIGINS` as `config/trustedproxy.php` parses its list (comma-separated, trimmed, empties dropped), defaulting to `'*'` when the variable is unset everywhere except production, as `config/login_codes.php` does for its driver; `allowed_origins_patterns` `[]`; `allowed_headers` `['*']`; `exposed_headers` `['Retry-After']`; `max_age` `7200`; `supports_credentials` `false`. The doc block says why: bearer tokens, no cookies (`docs/07` section 8), the panel's countdown, Chrome's two-hour preflight cap, `DL-104` (4).
- [ ] **Step 4: `.env.example`.** `CORS_ALLOWED_ORIGINS=*` with a one-line comment: development only; production names the panel's origin.
- [ ] **Step 5: Run the two tests and `MalformedInputTest`.** Expected: PASS.
- [ ] **Step 6: Commit** `feat: allow only the panel's origin by CORS and prove the client address behind the proxy (DL-104 (4))`.

### Task 3: The production boot check

**Files:**
- Create: `backend/app/Support/Runtime/ProductionConfiguration.php`
- Modify: `backend/app/Providers/AppServiceProvider.php` (`boot`)
- Test: `backend/tests/Feature/Runtime/ProductionConfigurationTest.php`

**Interfaces:**
- Consumes: `config('cors.allowed_origins')` (Task 2), `config('trustedproxy.proxies')`, `config('login_codes.driver')`, `config('accounts.phone_fingerprint.key')`, `CodeDeliveryGateway`, `PhoneFingerprint::of(string $phone): string`.
- Produces: `final class ProductionConfiguration` with
  - `public static function problems(): array` — `list<string>` of setting names that are missing or unsafe, in this order: `APP_KEY` (empty), `APP_DEBUG` (true), `DB_PASSWORD` (empty, for the connection `database.default` names), `LOGIN_CODE_DRIVER` (not a non-empty string), `CORS_ALLOWED_ORIGINS` (empty, or containing `*`), `TRUSTED_PROXIES` (null or empty), `PHONE_FINGERPRINT_KEY` (empty).
  - `public static function assertComplete(Application $app): void` — throws `RuntimeException('Production configuration is incomplete or unsafe: '.implode(', ', $problems).'.')` when `problems()` is not empty; otherwise resolves `CodeDeliveryGateway` and calls `PhoneFingerprint::of('+998900000000')` once, so an unknown driver or a malformed key fails with its own existing message at boot rather than at the first sign-in or erasure.

- [ ] **Step 1: Write the failing tests.** `setUp` sets a complete production configuration through `config([...])`: a non-empty `app.key`, `app.debug` false, `database.connections.pgsql.password` `'db-secret-value'`, `login_codes.driver` `'fake'`, `cors.allowed_origins` `['https://panel.example.test']`, `trustedproxy.proxies` `['172.30.250.0/28']`; the fingerprint key stays the testing one.
  - `test_a_complete_configuration_passes`: `assertComplete` throws nothing.
  - `test_each_gap_is_named` with a data provider of eight cases: `app.key` `''`; `app.debug` `true`; the password `''`; the driver `null`; origins `[]`; origins `['*']`; proxies `null`; the fingerprint key `null`. For each, `problems()` equals exactly `[<name>]`, and `assertComplete` throws a message containing it.
  - `test_the_message_never_carries_a_value`: with `app.debug` true and `app.key` `''`, the message contains `APP_DEBUG` and `APP_KEY` and not `db-secret-value`.
  - `test_an_unknown_driver_fails_at_the_check`: driver `'telegram'` → `RuntimeException` whose message contains `LOGIN_CODE_DRIVER`.
  - `test_the_boot_runs_the_check_in_production_only`: with `app.key` `''`, booting `AppServiceProvider` again under `$this->app['env'] = 'production'` throws; under `testing` it does not. Restore `env` in `finally`.
- [ ] **Step 2: Run them.** Expected: FAIL, class not found.
- [ ] **Step 3: Implement** `ProductionConfiguration` and call `ProductionConfiguration::assertComplete($this->app)` from `AppServiceProvider::boot` when `$this->app->environment('production')`, after the route patterns. The doc block says why: a production box with a missing secret must not start serving in silence; the message names settings and never values (`AGENTS.md` §5).
- [ ] **Step 4: Run the tests, then the full suite.** Expected: PASS; nothing else changes, since phpunit runs as `testing`.
- [ ] **Step 5: Commit** `feat: refuse to boot an incomplete production configuration (DL-107)`.

### Task 4: The scheduler's pruning

**Files:**
- Modify: `backend/app/Support/Idempotency/IdempotencyStore.php` (one method)
- Create: `backend/app/Console/Commands/PruneIdempotencyKeysCommand.php`, `backend/app/Console/Commands/PruneLoginChallengesCommand.php`
- Modify: `backend/routes/console.php`
- Test: `backend/tests/Feature/Console/PruneIdempotencyKeysCommandTest.php`, `backend/tests/Feature/Console/PruneLoginChallengesCommandTest.php`, `backend/tests/Feature/Console/ScheduleTest.php`

**Interfaces:**
- Produces:
  - `IdempotencyStore::prune(CarbonInterface $cutoff): int` — deletes `completed` rows whose `completed_at < $cutoff`, and `processing` rows whose `lease_expires_at < $cutoff` (a dead attempt, which a retry would take over anyway); returns the count.
  - `idempotency-keys:prune` — cutoff `now()->subDays(30)`; prints `Pruned {n} idempotency key(s).`
  - `login-challenges:prune` — deletes `LoginChallenge` rows with `created_at < now()->subDays(30)`; prints `Pruned {n} login challenge(s).`

- [ ] **Step 1: Write the failing tests.** Time is fixed with `$this->travelTo(...)`; rows are inserted with the columns the migrations require.
  - `PruneIdempotencyKeysCommandTest::test_it_prunes_only_what_is_thirty_days_dead_and_a_second_run_changes_nothing`: rows completed 31 and 29 days ago, processing with the lease expired 31 days and 1 day ago, and one processing with a live lease. Run → `Pruned 2 idempotency key(s).`, the three others remain. Run again → `Pruned 0 idempotency key(s).`, the same three remain.
  - `PruneLoginChallengesCommandTest::test_it_prunes_challenges_older_than_thirty_days_and_a_second_run_changes_nothing`: challenges created 31 days ago, 29 days ago, and an open one now → run → `Pruned 1 login challenge(s).`; again → `Pruned 0 ...`, two remain.
  - `ScheduleTest::test_the_schedule_is_exactly_the_wave_4_entries`: the commands of `app(Schedule::class)->events()`, each with its expression and time zone, equal: `approvals:expire` `* * * * *`; `idempotency-keys:prune` `0 4 * * *` `Asia/Tashkent`; `login-challenges:prune` `0 4 * * *` `Asia/Tashkent`; `queue:prune-failed --hours=720` `0 4 * * *` `Asia/Tashkent`. Compare on the part of `$event->command` after `artisan`.
- [ ] **Step 2: Run them.** Expected: FAIL, unknown commands.
- [ ] **Step 3: Implement** the method and the two commands in the style of `ExpireApprovalsCommand` (`final`, a doc block on what is pruned, why 30 days — `docs/08` section 27 for the keys, the phones of people who never became Customers for the challenges, `DL-104` (8) — and that a second run finds nothing). Add the three daily entries to `routes/console.php` at `04:00` `Asia/Tashkent`, after the 03:00 backup of W4-3, with a comment that the notification deliveries' and the devices' pruning arrive with W4-7 and W4-8.
- [ ] **Step 4: Run the three tests and `ApprovalExpiryApiTest`.** Expected: PASS.
- [ ] **Step 5: Commit** `feat: prune dead idempotency keys, old login challenges and failed jobs daily (DL-104 (8))`.

### Task 5: The production image

**Files:**
- Create: `docker/app.prod.Dockerfile`, `backend/.dockerignore`, `docker/php.prod.ini`, `docker/php-fpm.prod.conf`, `docker/entrypoint.prod.sh` (LF line endings; `.gitattributes` gains `*.sh text eol=lf` if it lacks a rule for it)

**Interfaces:**
- Produces: an image built with context `backend/` and the additional build context `runtime` = `docker/`; FPM listens on `9000`; the entrypoint is `/usr/local/bin/entrypoint.prod.sh`; default command `php-fpm`; user `www-data`; `/app/storage/app/public` exists, owned by `www-data`. Task 6 builds it under the tag `barakabozor-app:${BB_RELEASE}`.

- [ ] **Step 1: Write the image.**
  - Stage `base` `FROM php:8.4-fpm`: `pdo_pgsql`, `intl`, `opcache`, `pcntl` (`queue:work` needs it for its timeout and a graceful stop), building against `libpq-dev`/`libicu-dev` and purging the `-dev` packages with the official images' `apt-mark` pattern so only the runtime libraries stay.
  - Stage `vendor` from `base` with `composer:2`'s binary: `composer.json` and `composer.lock` first, `composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction`, then the source, then `composer dump-autoload --no-dev --optimize --no-scripts`. No artisan runs at build time: the boot check would refuse it, and Laravel writes the package manifest at the first boot.
  - Final stage from `base`: `COPY --from=runtime php.ini` as `conf.d/zz-baraka-bozor.ini` (the shared file, unchanged), `php.prod.ini` as `conf.d/zzz-baraka-bozor-prod.ini`, `php-fpm.prod.conf` as `/usr/local/etc/php-fpm.d/zz-baraka-bozor.conf`, the entrypoint; `/app` from `vendor`; recreate `storage/framework/{cache/data,sessions,views}`, `storage/logs`, `storage/app/public`, `bootstrap/cache`, owned by `www-data`; `USER www-data`; `ENTRYPOINT`, `CMD ["php-fpm"]`.
  - `backend/.dockerignore`: `vendor/`, `.env`, `.env.*` (keep `.env.example` out too: nothing reads it), `tests/`, `phpunit.xml`, `.phpunit*`, `storage/` contents, `bootstrap/cache/*.php`, `node_modules/`, `.ai/`, `*.log`.
  - `php.prod.ini`: `opcache.enable=1`, `opcache.validate_timestamps=0` (the code never changes inside a running container), `opcache.memory_consumption=128`, `opcache.interned_strings_buffer=16`, `opcache.max_accelerated_files=20000`, `realpath_cache_size=4096K`, `realpath_cache_ttl=600`, `expose_php=Off`, each with a one-line reason as `docker/php.ini` does.
  - `php-fpm.prod.conf` `[www]`: `clear_env = no` (else FPM hands PHP an empty environment), `access.log = /dev/null` (no access log, `DL-104` (3)), `pm = dynamic`, `pm.max_children = 12`, `pm.start_servers = 3`, `pm.min_spare_servers = 2`, `pm.max_spare_servers = 4`, `pm.max_requests = 500` (sized for the 4 GB server of the Owner gate).
  - `entrypoint.prod.sh`: `#!/bin/sh`, `set -eu`, `php artisan optimize`, `exec "$@"`. A comment: each container builds its own caches at start, since a cache in an old container dies with it (`DL-104` (7)), and the boot check stops a misconfigured container here.
- [ ] **Step 2: Build and inspect.** From the repository root: `docker build -f docker/app.prod.Dockerfile --build-context runtime=docker -t barakabozor-app:check backend`. Then, with `--entrypoint` overridden:
  - `php -m` lists `pdo_pgsql`, `intl`, `Zend OPcache`, `pcntl`;
  - `sh -c 'id -un; stat -c %U storage/app/public; test ! -e vendor/laravel/boost && test ! -e vendor/phpunit && test ! -e .env && test ! -e tests && echo clean'` → `www-data`, `www-data`, `clean`;
  - `php -r 'echo ini_get("opcache.validate_timestamps"), ini_get("expose_php"), ini_get("zend.exception_ignore_args"), PHP_EOL;'` → `001`.
- [ ] **Step 3: FPM's pool.** `php-fpm -tt` (entrypoint overridden) prints `clear_env = no` and `access.log = /dev/null` for `[www]`.
- [ ] **Step 4: The boot check in the image.** `docker run --rm barakabozor-app:check php artisan about` (the entrypoint runs, `APP_ENV` unset means production) → exits non-zero with `Production configuration is incomplete or unsafe: APP_KEY, DB_PASSWORD, LOGIN_CODE_DRIVER, CORS_ALLOWED_ORIGINS, TRUSTED_PROXIES, PHONE_FINGERPRINT_KEY.` (`APP_DEBUG` defaults to off, so it is not named).
- [ ] **Step 5: The dev stack is untouched.** `docker compose -f docker/compose.yaml up -d --build app` still builds from `docker/app.Dockerfile`, and `php artisan test --filter=GlobalMiddlewareTest` passes in it.
- [ ] **Step 6: Commit** `feat: the production image, PHP 8.4 FPM with opcache and no dev dependencies (DL-104 (3), DL-107)`. Remove the `barakabozor-app:check` image afterwards.

### Task 6: The production stack — Compose, Caddy, the env example

**Files:**
- Create: `docker/compose.prod.yaml`, `docker/caddy/Caddyfile`, `docker/production.env.example`
- Modify: `.gitignore` (`/docker/*.env`)

**Interfaces:**
- Consumes: Task 5's image (context, additional context, entrypoint, port 9000, `/app/storage/app/public`).
- Produces: the variables Task 9 fills in: `COMPOSE_PROJECT_NAME`, `BB_ENV_FILE`, `BB_RELEASE`, `BB_PUBLISH_ADDRESS`, `BB_HTTP_PORT`, `BB_HTTPS_PORT`, `API_HOST`, `PANEL_HOST`, `PANEL_ROOT`, `EDGE_SUBNET`, and the application's own.

- [ ] **Step 1: `docker/compose.prod.yaml`.** Run as `docker compose --env-file <file> -f docker/compose.prod.yaml up -d --build`; the env file is read by Compose for interpolation and, through `BB_ENV_FILE`, which names that same file, by the PHP services as `env_file`. Required variables use `${NAME:?message}`.
  - `name: ${COMPOSE_PROJECT_NAME:-barakabozor}`.
  - A `x-logging` anchor: `json-file`, `max-size: "10m"`, `max-file: "5"`, on every service.
  - A `x-php` anchor shared by `app`, `worker`, `scheduler`: the build of Task 5 (`context: ../backend`, `dockerfile: ../docker/app.prod.Dockerfile`, `additional_contexts: {runtime: .}`), `image: barakabozor-app:${BB_RELEASE:-latest}`, `env_file: ${BB_ENV_FILE:?...}`, `environment: {TRUSTED_PROXIES: ${EDGE_SUBNET:?...}}` (one value for the subnet and the trust), `restart: unless-stopped` (a worker that exits after `--max-time` must come back), `init: true`, `depends_on: db` healthy, network `internal`.
  - `app`: networks `edge` and `internal`; volume `public-images:/app/storage/app/public`; healthcheck `php -r "exit(@fsockopen('127.0.0.1', 9000) ? 0 : 1);"`.
  - `worker`: `command: ["php", "artisan", "queue:work", "--sleep=3", "--max-time=3600"]`, `stop_grace_period: 60s`.
  - `scheduler`: `command: ["php", "artisan", "schedule:work"]`.
  - `db`: `postgres:17-alpine`, `POSTGRES_DB/USER/PASSWORD` from `${DB_DATABASE}`, `${DB_USERNAME}`, `${DB_PASSWORD}` (required), `POSTGRES_INITDB_ARGS: "--encoding=UTF8 --locale=en_US.utf8"` (what the dev database has; `DL-20` needs a UTF-8 character type), volume `db-data`, the dev stack's TCP `pg_isready` healthcheck, no ports, network `internal`.
  - `caddy`: `caddy:2.<minor>-alpine`, the newest minor that `docker pull` finds, pinned; ports `${BB_PUBLISH_ADDRESS:-0.0.0.0}:${BB_HTTP_PORT:-80}:80` and `...:${BB_HTTPS_PORT:-443}:443` (TCP only); `environment` with only `API_HOST`, `PANEL_HOST`, `CORS_ALLOWED_ORIGINS`, so no application secret reaches it; volumes `./caddy/Caddyfile:/etc/caddy/Caddyfile:ro`, `caddy-data:/data` (the certificates: losing them meets Let's Encrypt's rate limits), `caddy-config:/config`, `public-images:/srv/storage:ro`, `${PANEL_ROOT:?...}:/srv/panel:ro`; `depends_on: app` healthy; network `edge`.
  - Networks: `edge` with `ipam.config[0].subnet: ${EDGE_SUBNET}`; `internal` plain (the app and the worker reach Telegram and Firebase through it).
  - Volumes: `db-data`, `public-images`, `caddy-data`, `caddy-config`.
  - A header comment: what runs, how to run it, that only Caddy publishes ports, and why two networks.
- [ ] **Step 2: `docker/caddy/Caddyfile`.** In the syntax of the pinned Caddy version:

```caddyfile
{
	# No access log: a query string such as a board search can carry phone
	# digits (docs/07 section 31). The error log still names the request, so
	# every logged URI loses its query string.
	log {
		output stderr
		format filter {
			wrap json
			fields {
				request>uri regexp \?.*$ ?redacted
			}
		}
	}
	# UDP 443 is not opened, so HTTP/3 is not offered.
	servers {
		protocols h1 h2
	}
	skip_install_trust
}

{$API_HOST} {
	encode zstd gzip
	header {
		-Server
		Strict-Transport-Security "max-age=31536000"
		X-Content-Type-Options nosniff
	}
	# Above PHP's post_max_size (8M), so an oversized upload still meets
	# Laravel's 413 envelope up to this bound.
	request_body {
		max_size 10MB
	}

	# Product images, straight from the volume. A new image gets a new URL
	# (docs/07 section 10), so a year's cache is safe; the panel draws them
	# from another origin (DL-34).
	handle_path /storage/* {
		root * /srv/storage
		header Cache-Control "public, max-age=31536000, immutable"
		header Access-Control-Allow-Origin {$CORS_ALLOWED_ORIGINS}
		file_server
	}

	handle {
		rewrite * /index.php
		reverse_proxy app:9000 {
			transport fastcgi {
				root /app/public
				split .php
			}
		}
	}
}

{$PANEL_HOST} {
	root * /srv/panel/current
	encode zstd gzip
	header {
		-Server
		Strict-Transport-Security "max-age=31536000"
		X-Content-Type-Options nosniff
		X-Frame-Options DENY
		Referrer-Policy strict-origin-when-cross-origin
		# Flutter's file names are not content-hashed: index.html,
		# flutter_bootstrap.js and main.dart.js keep their names across
		# releases, so every file revalidates (ETag) instead of being cached.
		Cache-Control no-cache
	}
	try_files {path} /index.html
	file_server
}
```

  Validate: `docker run --rm -e API_HOST=api.example.test -e PANEL_HOST=panel.example.test -e CORS_ALLOWED_ORIGINS=https://panel.example.test -v <abs>/docker/caddy:/etc/caddy:ro caddy:<tag> caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile` (`MSYS_NO_PATHCONV=1` in Git Bash). Expected: `Valid configuration`. If the pinned version spells the filter differently, follow its documentation; the behaviour stays.
- [ ] **Step 3: `docker/production.env.example`.** Every variable the server needs, grouped with a one-line comment each, secrets and site values empty. Structural values are filled because they are the decisions: `APP_ENV=production`, `APP_DEBUG=false`, `LOG_CHANNEL=stderr`, `LOG_LEVEL=info`, `DB_CONNECTION=pgsql`, `DB_HOST=db`, `DB_PORT=5432`, `QUEUE_CONNECTION=database`, `CACHE_STORE=database`, `SESSION_DRIVER=array` (no route uses a session; confirm by `route:list` that no route carries the `web` group's `StartSession`), `FILESYSTEM_DISK=local`, `BCRYPT_ROUNDS=12`, `LOGIN_CODE_TEST_PHONES=` with a comment that it stays empty (`BR-ROLE-011`). Empty: `COMPOSE_PROJECT_NAME`, `BB_ENV_FILE`, `BB_RELEASE`, `API_HOST`, `PANEL_HOST`, `PANEL_ROOT`, `EDGE_SUBNET` (comment: a private /28 no other network on the server uses; it becomes `TRUSTED_PROXIES`), `APP_NAME`, `APP_KEY`, `APP_URL` (`https://` + `API_HOST`), `APP_LOCALE`, `APP_FALLBACK_LOCALE`, `CORS_ALLOWED_ORIGINS` (`https://` + `PANEL_HOST`, one origin), `LOGIN_CODE_DRIVER`, `PHONE_FINGERPRINT_KEY`, `PHONE_FINGERPRINT_PREVIOUS_KEYS`, `DELIVERY_HANDOFF_POINT` (Owner question 2, W4-5), `GOOGLE_MAPS_GEOCODING_KEY`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`. Then compare against `backend/.env.example`: every variable there is either listed or is development-only (Boost, walkthrough, faker, Redis, Memcached, mail, AWS, broadcast) — say so in the file's header.
- [ ] **Step 4: `docker compose config`.** With a scratch env file outside the repository holding placeholder values: `docker compose --env-file <scratch> -f docker/compose.prod.yaml config --quiet`. Expected: exit 0. With `EDGE_SUBNET` removed: exit non-zero naming it.
- [ ] **Step 5: Commit** `feat: the production stack, Caddy in front of PHP-FPM, the worker and the scheduler (DL-104 (3)-(5), DL-107)`.

### Task 7: The walkthrough against a stack with a scheduler

**Files:**
- Modify: `tasks/scripts/wave3_api_walkthrough.py`

- [ ] **Step 1: A scheduler mode.** When the environment variable `WALKTHROUGH_SCHEDULER` is `1`, the expiry part neither runs `artisan()` nor checks that nothing wrote the expiry; it checks instead `"The scheduler writes the expiry"`: within 150 seconds of the expiry, polling `history_events` every 10 seconds, the third order's history holds exactly one `approval_expired`. Every other check is unchanged. The docstring gains two sentences: the mode, and that the production stack (`docker/README.md`) uses it.
- [ ] **Step 2: Syntax check.** `python -m py_compile tasks/scripts/wave3_api_walkthrough.py`. Expected: no output.
- [ ] **Step 3: Commit** `test: the Wave 3 walkthrough waits for a running scheduler when asked`.

### Task 8: Documents

**Files:**
- Modify: `docs/DECISIONS.md` (new `DL-107`), `docs/07-architecture.md` (sections 10, 25, 34), `docker/README.md` (new section), `tasks/WAVE_4.md`

- [ ] **Step 1: `DL-107 — The production runtime from W4-2 (2026-10-23, agent)`,** numbered items:
  1. **The image.** One multi-stage image, context `backend/`, built from `docker/app.prod.Dockerfile`; PHP 8.4 FPM with `pdo_pgsql`, `intl`, `opcache`, `pcntl`; no dev dependencies, no tests, runs as `www-data`. `docker/php.ini` is shared with development; `docker/php.prod.ini` adds opcache without timestamp checks and hides the PHP version. FPM keeps the container's environment (`clear_env = no`) and writes no access log.
  2. **The start.** Each container runs `php artisan optimize` before its process, so it builds its own caches and a misconfigured container stops there.
  3. **The boot check.** In production the boot refuses a missing `APP_KEY`, `DB_PASSWORD`, `LOGIN_CODE_DRIVER`, `CORS_ALLOWED_ORIGINS` (or `*`), `TRUSTED_PROXIES` or `PHONE_FINGERPRINT_KEY`, and `APP_DEBUG` on; it resolves the code driver and the fingerprint key once. The message names settings, never values. `W4-4` adds the refusal of the `fake` driver in production once `telegram` exists.
  4. **Networks and trust.** Caddy and `app` alone share the `edge` network; its subnet, `EDGE_SUBNET`, is also the value of `TRUSTED_PROXIES`, so the two cannot drift. Caddy replaces any `X-Forwarded-For` a client sends.
  5. **Caddy.** No access log; the error log loses query strings. HTTP/1.1 and 2 only. Images from the volume with a year's immutable cache and the panel's origin; every panel file revalidates, because Flutter's file names are not content-hashed. Bodies above 10 MB stop at Caddy.
  6. **CORS.** `api/*`, the origins of `CORS_ALLOWED_ORIGINS` (any origin outside production when unset), `Retry-After` exposed for the panel's countdown, preflights cached two hours, no credentials.
  7. **Pruning.** Daily at 04:00 Tashkent, after the backup: completed idempotency keys after 30 days and processing ones whose lease expired 30 days ago; login challenges after 30 days; failed jobs after 30 days. The deliveries' and the devices' pruning come with W4-7 and W4-8.
  8. **Restarts and logs.** Every service `unless-stopped`; Docker keeps 5 × 10 MB of each service's log.
  9. **The rehearsal.** On the development machine the stack runs as `bb-prod-local` on `127.0.0.1:8080`/`8443`, the API at `https://localhost:8443`, the panel at `https://127.0.0.1:8443`, on Caddy's internal CA, which Caddy uses by itself for `localhost` and addresses. A production env file proves the boot, the edge and the processes; the walkthrough runs on the same image and stack with `APP_ENV=local`, because test phones are refused in production by design (`BR-ROLE-011`) and the walkthrough's seeder is local-only (`DL-35`).
  10. **Security updates** of `symfony/http-foundation` and `league/commonmark` before the first deployment.
- [ ] **Step 2: `docs/07`.** Section 25: the scheduler list names the login challenges after 30 days and that pruning runs at 04:00 Tashkent; section 34: the `edge` network and `EDGE_SUBNET` as the trusted proxy range; section 10 unchanged unless it contradicts.
- [ ] **Step 3: `docker/README.md`.** The opening paragraph no longer says the stack is not a deployment target without pointing at the new section. New section "The production stack": the files and their roles; that the dev `app.Dockerfile` stays for development and CI; how to run it (`--env-file`); the rehearsal on this machine (project name, ports, hostnames, exporting Caddy's root certificate from `/data/caddy/pki/authorities/local/root.crt` for `SSL_CERT_FILE`, `WALKTHROUGH_SCHEDULER=1`); that `docker/DEPLOY.md` (W4-5) is the server runbook.
- [ ] **Step 4: `tasks/WAVE_4.md`.** W4-2 row `In progress`; the risk rows: CORS in production closed by W4-2 (device pruning and the token stream stay with W4-8 and W4-9); the `composer audit` row closed; the W4-2 note's scheduler bullet says which entries came now and which come with W4-7 and W4-8.
- [ ] **Step 5: Commit** `docs: W4-2 production runtime (DL-107)`.

### Task 9: Rehearsal on the development machine (the lead runs it)

Env files in `G:/tools/bb-prod-local/` (outside the repository): `production.env` (`APP_ENV=production`, `COMPOSE_PROJECT_NAME=bb-prod-local`, `BB_PUBLISH_ADDRESS=127.0.0.1`, `BB_HTTP_PORT=8080`, `BB_HTTPS_PORT=8443`, `API_HOST=localhost`, `PANEL_HOST=127.0.0.1`, `APP_URL=https://localhost:8443`, `CORS_ALLOWED_ORIGINS=https://127.0.0.1:8443`, `PANEL_ROOT=G:/tools/bb-prod-local/panel`, `EDGE_SUBNET` a free private /28, fresh `APP_KEY`, `PHONE_FINGERPRINT_KEY`, DB password, `LOGIN_CODE_DRIVER=fake`) and `rehearsal.env` (the same with `APP_ENV=local`, the dev `.env`'s test phones, test code and `WALKTHROUGH_STAFF_PASSWORD`). The panel is `flutter build web --release --dart-define=BB_API_BASE_URL=https://localhost:8443/api/v1`, copied to `G:/tools/bb-prod-local/panel/current`.

- [ ] **Step 1: Up on the production file.** `docker compose --env-file G:/tools/bb-prod-local/production.env -f docker/compose.prod.yaml up -d --build`, then `run --rm app php artisan migrate --force`. Expected: five services up, `app` healthy, `docker ps` shows only Caddy publishing, on 127.0.0.1.
- [ ] **Step 2: The boot check live.** With `APP_KEY` blanked in a copy of the file, `run --rm app php artisan about` fails naming `APP_KEY`.
- [ ] **Step 3: Processes and logs.** `worker` logs that it processes the `database` queue; `scheduler` runs `approvals:expire` each minute; `app`'s environment reaches PHP (`/up` answers `200` through Caddy); no `laravel.log` exists in any container; the database reports `UTF8` and `en_US.utf8`.
- [ ] **Step 4: The edge.** With `curl --cacert <exported root>`: `/legal/privacy` and `/account-deletion` `200`; a preflight from the panel's origin carries the allow, max-age and no credentials; another origin gets no allow; `https://127.0.0.1:8443/` serves `index.html` with `Cache-Control: no-cache`; a deep link serves `index.html`; no `Server` or `X-Powered-By` header.
- [ ] **Step 5: The client's address.** Eleven code requests in a minute from the host, each with a different spoofed `X-Forwarded-For` → the eleventh `429`.
- [ ] **Step 6: Switch to `rehearsal.env`** (`up -d` recreates the PHP services), seed with `WalkthroughSeeder`, upload a product image as the Admin, and fetch its URL through Caddy with the panel's `Origin`: `200`, `Cache-Control: public, max-age=31536000, immutable`, `Access-Control-Allow-Origin` the panel's origin.
- [ ] **Step 7: No phone digits in Caddy's log.** `stop app`, request `https://localhost:8443/api/v1/operations/orders?search=998901234567` (`502`), `start app`; `docker logs bb-prod-local-caddy-1` holds no `998901234567` and no access line.
- [ ] **Step 8: The walkthrough.** `WALKTHROUGH_SCHEDULER=1 SSL_CERT_FILE=<exported root> python tasks/scripts/wave3_api_walkthrough.py https://localhost:8443/api/v1` (about 35 minutes). Expected: every check passes, the scheduler's expiry among them.
- [ ] **Step 9: The panel.** Headless Chrome on `https://127.0.0.1:8443` (its own profile, `--ignore-certificate-errors`), signed in as the Operator: the board and the catalog with product images, one screenshot for the Owner.
- [ ] **Step 10: Down.** `docker compose -p bb-prod-local -f docker/compose.prod.yaml down -v`; the dev stack and other projects' containers are as they were (`docker ps -a` before and after).
- [ ] **Step 11: Record** the outcome in `tasks/WAVE_4.md` (W4-2 note) and commit `docs: W4-2 rehearsal on the development machine`.
