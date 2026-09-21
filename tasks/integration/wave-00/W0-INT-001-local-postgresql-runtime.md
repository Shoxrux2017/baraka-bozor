# W0-INT-001 — Local PostgreSQL and PHP runtime in Docker

## Metadata

| Field | Value |
|---|---|
| Task ID | `W0-INT-001` |
| Wave | `0 — Foundation` |
| Area | `Integration` |
| Status | `Approved` — Project Owner, 2026-09-21 |
| Depends on | `S01-BE-001` (Accepted) |
| Blocks | `W0-INT-002`, and every later task that touches the database |
| Track | `wave-owner` |
| Branch | `task/w0-int-001-local-postgresql-runtime` |

Start only when Status is `Approved` and the Git preflight in `tasks/README.md` Section 8A is safe.

## Goal

`docker compose up` produces a runtime in which the existing backend test suite runs against a real PostgreSQL database, not SQLite, reproducibly and identically to what CI will later run.

## Scope

**In:**

- A Compose stack under `docker/` with two services: `db` (PostgreSQL, pinned major version, healthcheck, named volume) and `app` (PHP with `pdo_pgsql`, Composer, the repository's `backend/` mounted).
- Two separate databases on the `db` service: one for development, one for tests, created on first boot.
- `backend/.env.example` describing the Compose connection, with no real secret.
- `backend/config/database.php` default connection becomes `pgsql`.
- `backend/phpunit.xml` runs the suite against the PostgreSQL **test** database. Every SQLite reference is removed.
- `docker/README.md` documenting four operations: start, run tests, stop, reset data.

**Out:**

- Continuous integration — `W0-INT-002`.
- Any table, migration or model change — `W0-BE-011` owns the identity schema. This task changes no migration.
- Redis, queue workers, a mail catcher, a web server container, or any production topology (`docs/07-architecture.md` Section 34). `AGENTS.md` Section 5 forbids mandatory Redis and Section 8 forbids speculative infrastructure; `php artisan serve` inside the `app` container is sufficient for Wave 0.
- Flutter tooling — the frontend track has its own tasks.
- Any change to API behavior, the error envelope, routes, or application code.

## Governing Specification

| Source | Section | What it governs here |
|---|---|---|
| `docs/07-architecture.md` | §2 Technology Baseline | PHP 8.3+, Laravel 13, PostgreSQL, PHPUnit, Pint, Larastan are the stack |
| `docs/07-architecture.md` | §3 Repository Baseline | `docker/` is where runtime configuration lives |
| `docs/07-architecture.md` | §33 Testing Architecture | integration runs against real PostgreSQL, not a substitute engine |
| `docs/07-architecture.md` | §34 Production Topology | the shape this local runtime must not contradict, and must not try to reproduce |
| `AGENTS.md` | §5 | modular monolith baseline; no extra infrastructure |
| `AGENTS.md` | §10 | tests stay deterministic and must not depend on the local environment |
| `AGENTS.md` | §13 | no credential, key or secret is committed |
| `tasks/OWNERSHIP.md` | Wave 0 | `wave-owner` owns every path this task touches |

## Decisions

| # | Decision | Why |
|---|---|---|
| 1 | PHP and the test suite run **inside a container**, not on the host. | The host PHP is Herd-lite: `php -m` shows only `pdo_mysql` and `pdo_sqlite`, extensions are compiled in, there is no `ext/` directory, and `extension_dir` points at a path that does not exist. `pdo_pgsql` cannot be enabled there. Running in a container also makes local, CI and production behave identically, which the merge queue depends on. |
| 2 | Tests run against a **separate PostgreSQL database**, not a separate instance, and not SQLite. | `docs/07` §33 requires the real engine. SQLite diverges on column types, partial unique indexes and transaction behavior — `S-1` is about a partial unique index, which SQLite does not support, and `S01-BE-001` already hit a SQLite/PostgreSQL type mismatch on `personal_access_tokens`. |
| 3 | PostgreSQL **17**, pinned in Compose rather than floating on `latest`. | A floating tag makes the runtime non-reproducible and can change behavior between two agents' machines. 17 is the current stable branch, so a new project starts on it rather than migrating within its first year. This is the engine production will run. |
| 5 | **Amendment, 2026-09-21.** `backend/tests/**` is opened for exactly one new guard test, after the independent review showed acceptance criterion 6 was provable only by inspection. | A misconfigured test connection destroys the developer schema on the first `RefreshDatabase`, which arrives in `W0-BE-011`. The guard belongs before that task, not with it. The Project Owner chose this over deferring the assertion. |
| 4 | The `app` image is built from an official `php:8.4-cli` base with `pdo_pgsql` added. | 8.4 matches the host version already in use and satisfies `docs/07` §2's `PHP 8.3+`. |

## Implementation Notes

- **Do not add a migration and do not run one as part of setup.** `W0-BE-011` owns the identity schema. Only the three migrations already on `main` exist, and `php artisan migrate` must succeed with exactly those.
- **`phpunit.xml` currently pins `DB_CONNECTION=sqlite` and `DB_DATABASE=:memory:`.** Both must go. Leaving either means the suite silently keeps testing the wrong engine while appearing to pass.
- **`config/database.php` line 20 defaults to `sqlite`.** Change the default, do not delete the `sqlite` connection block itself — removing a framework connection definition is out of scope.
- **The test database must be created before the suite runs**, because Laravel will not create it. Use a PostgreSQL init script, which only runs on an empty volume; document in `docker/README.md` that resetting requires removing the volume.
- **`vendor/` is mounted from the host.** It was installed by Herd-lite PHP on Windows. PHP packages are platform-independent, but if any native build is required the container must be able to run `composer install` itself; make sure the image has Composer.
- **No credential in the repository.** Compose may carry local-only development values inline; `backend/.env` stays gitignored and is not created by this task.
- **`docker compose` is the v2 plugin command**, not `docker-compose`. Report the exact command run.

## Acceptance Criteria

- [ ] `docker compose -f docker/compose.yaml up -d` brings `db` up healthy and `app` running.
- [ ] `docker compose exec app php -m` lists `pdo_pgsql`.
- [ ] `docker compose exec app php artisan migrate --force` succeeds against PostgreSQL with only the three existing migrations.
- [ ] `docker compose exec app php artisan test` passes, and the suite's active connection is `pgsql`.
- [ ] `backend/phpunit.xml` contains no `sqlite` and no `:memory:`.
- [ ] Development and test databases are separate; running the suite leaves development data untouched, **and the suite itself asserts this** — see `TestDatabaseIsolationTest`.
- [ ] No `.sqlite` file exists anywhere in the repository or working tree after a full run.
- [ ] `backend/.env.example` documents the Compose connection and contains no real secret.
- [ ] `backend/.gitignore` still ignores `.env`; no `.env` is committed.
- [ ] `docker/README.md` documents start, run tests, stop, and reset data.
- [ ] Pint and PHPStan pass inside the container.
- [ ] The two existing test files still pass — `ApiFoundationTest` and `ApiExceptionRendererTest`.
- [ ] `git diff --check` passes.
- [ ] No API behavior, route, migration or application-code change.
- [ ] Independent review completed; P1 and P2 findings resolved.

## Verification

**Environment evidence**

```text
docker compose -f docker/compose.yaml up -d
docker compose -f docker/compose.yaml ps
docker compose -f docker/compose.yaml exec app php -v
docker compose -f docker/compose.yaml exec app php -m | grep pdo_pgsql
docker compose -f docker/compose.yaml exec app php artisan --version
```

**Database**

```text
docker compose -f docker/compose.yaml exec app php artisan migrate --force
docker compose -f docker/compose.yaml exec app php artisan db:show
```

`db:show` must report the `pgsql` driver and the development database name.

**Tests**

```text
docker compose -f docker/compose.yaml exec app php artisan test
```

The whole suite, not a single file. That is a deliberate exception to `AGENTS.md` Section 11 for one concrete risk: the point of this task is that the suite runs on a different database engine, and only running all of it proves that.

**Format / static**

```text
docker compose -f docker/compose.yaml exec app vendor/bin/pint --test
docker compose -f docker/compose.yaml exec app vendor/bin/phpstan analyse
```

**Directly affected regression**

The two existing test files are the regression surface and are covered by the suite run above. No further regression check is required — no application code, route or migration changes.

**Project Owner manual check**

Run `docker compose -f docker/compose.yaml up -d` and then the test command, from a clean clone, and confirm both succeed without installing PHP on the host.

**Always**

```text
git diff --check
git status --short
```

## Allowed Areas

Track: `wave-owner`

| Path or area | Action | Reason |
|---|---|---|
| `docker/compose.yaml` | Create | the `db` and `app` services |
| `docker/app.Dockerfile` | Create | PHP 8.4 with `pdo_pgsql` and Composer |
| `docker/initdb/` | Create | init script creating the test database |
| `docker/README.md` | Modify | start, test, stop, reset |
| `backend/.env.example` | Modify | PostgreSQL connection defaults, no secret |
| `backend/config/database.php` | Modify | default connection becomes `pgsql` |
| `backend/phpunit.xml` | Modify | suite runs against the PostgreSQL test database |
| `backend/tests/Feature/TestDatabaseIsolationTest.php` | Create | **Contract amendment, Project Owner, 2026-09-21.** One guard asserting the suite runs on PostgreSQL and on a `_test` database, so acceptance criterion 6 is enforced by the suite instead of by inspection. Nothing else under `backend/tests/**` may change under this contract. |
| `backend/.gitignore` | Inspect | confirm `.env` and `*.sqlite` stay ignored |
| `tasks/OWNERSHIP.md` | Modify | approved simplification: `wave-owner` owns `backend/**` except the Auth trees |
| `tasks/WAVE_00_TASK_INDEX.md` | Modify | task status bookkeeping |

Changes outside these areas need a concrete necessity within scope and must be reported.

Do not modify: `backend/database/migrations/**`, `backend/routes/**`, `backend/app/**`, `backend/bootstrap/app.php`, `backend/composer.json`, `backend/composer.lock`, `frontend/**`, `docs/01`–`docs/09`. Under `backend/tests/**` only the one new file named above may be created; the two existing test files and `TestCase.php` stay byte-identical.

## Delivery

PR title: `W0-INT-001 — Local PostgreSQL and PHP runtime in Docker`, target `main`.

The implementing agent commits, pushes, and opens the PR. The Project Owner merges. The task becomes `Accepted` only after the merge, with local `main == origin/main`, `0/0`, and a clean worktree.

## Independent Review

Filled in before the PR is opened.

Reviewed by an agent with no implementation context, 2026-09-21. Result: 1 P1, 2 P2, 10 P3.

| ID | Severity | Finding | Resolution |
|---|---|---|---|
| R-01 | **P1** | The `app` service set `DB_*` in the container environment. PHPUnit applies an `<env>` only when the variable is absent from the real environment, so `phpunit.xml` was discarded and the suite resolved to the **development** database. Latent data loss: the first `RefreshDatabase` would have dropped the developer's schema. | **Fixed.** `DB_*` removed from the `app` service, and `force="true"` added to every `DB_*` entry in `phpunit.xml` so no outer environment — including CI — can override them. Verified through PHPUnit's own loader and `PhpHandler`: the suite now resolves to `baraka_bozor_test`. The original verification was itself unsound — it injected the variables with `-e`, proving only what happens when they are forced by hand. |
| R-02 | **P2** | A fixed Compose project name plus a fixed host port break the one-worktree-per-track model: `up` from a second worktree recreates the first one's containers against the second one's code, sharing one database. | **Fixed.** `name` and the published port are now `COMPOSE_PROJECT_NAME` and `DB_HOST_PORT`, and `docker/README.md` gained a "Several worktrees at once" section explaining the failure mode. |
| R-03 | **P2** | PostgreSQL published on all interfaces while its password is committed, so anyone on the same network could connect as the owning role. | **Fixed.** Bound to `127.0.0.1` only; `ps` confirms `127.0.0.1:5432->5432/tcp`. A host database client is unaffected. |
| R-04 | P3 | `tail -f /dev/null` as PID 1 catches no signals, so `down` waits the full grace period then kills the container. | **Fixed.** `init: true` adds tini, which forwards SIGTERM. |
| R-05 | P3 | The healthcheck used the unix socket, which the image's init-time server also serves, so `db` could report healthy before `initdb/` had created the test database. | **Fixed.** The check now goes over TCP, which the init-time server does not listen on. |
| R-06 | P3 | The build context was the repository root, shipping ~118 MB of `vendor/` to the daemon on every rebuild although the Dockerfile copies nothing from it. | **Fixed.** Context is now the `docker/` directory. |
| R-07 | P3 | `apt-get purge -y --auto-remove` removed nothing — the official images' idiom needs its `apt-mark` half — leaving a line that only looked like it did something. | **Fixed.** Line removed, with a comment recording why the `-dev` packages stay. |
| R-08 | P3 | The container runs as root, so files it creates through the bind mount are root-owned. Invisible on Windows and macOS, a real obstacle on Linux. | **Documented**, not changed. Changing the container user would need a decision about host UID mapping that Wave 0 does not need; `docker/README.md` now names the symptom and the `--user` workaround. |
| R-09 | P3 | The comment suggesting `php artisan serve` pointed at something unreachable: the service publishes no port and `serve` binds loopback inside the container. | **Fixed.** The comment now names `--host 0.0.0.0` and the need to publish a port. |
| R-10 | P3 | A stray `config:cache` on either side of the bind mount would bake absolute paths and break the other side. | **Documented** in `docker/README.md` with the `config:clear` remedy. |
| R-11 | P3 | The index claimed the `pdo_pgsql` risk was "Closed" and the change log credited the Project Owner with an implementation, both while the work was unmerged. | **Fixed.** The risk now says it closes when the task is `Accepted`; the change-log row names who did what and records `In Review`. |
| R-12 | P3 | `phpunit.xml` still contains the word "SQLite" — in a comment saying never to use it — so acceptance criterion 5 passes only when read case-sensitively. | **Not acted on.** The criterion's intent is that no SQLite *configuration* remains, which holds: no `sqlite` connection, no `:memory:`. Deleting a comment that explains why would make the file worse. Reported for the Project Owner's judgement. |
| R-13 | P3 | The reviewer could not reproduce the `docker/README.md` claim that a missing `.env` produces warnings rather than failures, and suspected it was wrong. | **Not acted on — the claim is correct.** Verified by moving `.env` aside and running the suite: `12 warnings, 12 passed` instead of `24 passed`. The reviewer could not see this because it correctly refused to modify the tree. The warning is exactly why the claim is in the README. |

**Open for the Project Owner.** Acceptance criterion 6 — development and test databases separate — is now proven by inspection, not by a test. Proving it inside the suite needs one assertion in `backend/tests/**`, which this contract lists under *Do not modify*. Either amend this contract to allow that single assertion, or require `W0-BE-011` to assert the active test database name with its first database test. The reviewer raised the same point.
