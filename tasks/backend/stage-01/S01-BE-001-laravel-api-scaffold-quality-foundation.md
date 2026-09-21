# S01-BE-001 — Laravel `/api/v1` Scaffold, Error & Quality Foundation

## Metadata

| Field | Value |
|---|---|
| Task ID | `S01-BE-001` |
| Stage | `Stage 1 — Authentication & Role-Based Entry` |
| Area | `Backend` |
| Status | `Approved` |
| Depends on | `Stage 0 — CLOSED` |
| Blocks | `S01-INT-001` |
| Branch | `task/s01-be-001-laravel-api-foundation` |
| Workflow | `v4 Two-Party` |

Start only when Status is `Approved` and Git preflight from `tasks/README.md` is safe.

## Goal

A genuine Laravel 13 application exists under `backend/`, serves the client API at `/api/v1`, renders every framework-level API error through the locked JSON envelope, and is covered by focused tests plus a formatter and a static analyser.

No authentication behavior, no BarakaBozor business table, no PostgreSQL runtime.

## Scope

**In:**

- Laravel 13 scaffold inside the existing `backend/`, preserving `backend/AGENTS.md`.
- Laravel API installation, which brings Sanctum as the approved API-authentication infrastructure.
- `/api/v1` prefix for the client API, with no generated demo endpoint left behind.
- Centralized JSON error rendering for `422`, `401`, `403`, `404`, `429`, `500` under `/api/v1/*`.
- Production-safe unexpected-error rendering.
- Focused API-foundation tests.
- Composer lock state, Laravel Pint, and Larastan.

**Out:**

- PostgreSQL, Docker, local runtime — `S01-INT-001`.
- `users` persistence, role columns, initial Admin CLI bootstrap — `S01-BE-002`.
- Staff login, logout, me, change-password — `S01-BE-003`.
- Customer OTP and `SmsGateway` — `S01-BE-004`.
- Six-role authorization middleware — `S01-BE-005`.
- SMS provider adapter — `S01-BE-006`.
- Flutter; all product features; product web UI, Blade auth, Livewire, Inertia, starter kits; Node/NPM.
- A custom exception framework for future domain conflicts, and any `409` business-conflict code. Later tasks own those.
- Redis, queues, WebSockets, or any other speculative infrastructure.

## Governing Specification

Cite, do not copy.

| Source | Section | What it governs here |
|---|---|---|
| `docs/09-api-contracts.md` | §1–§5 | `/api/v1` base, success and error envelopes, HTTP status baseline, strict request shape |
| `docs/09-api-contracts.md` | §54 | stable machine codes, including `server_error` |
| `docs/09-api-contracts.md` | §60 | never expose raw provider errors, SQL, stack traces, secrets |
| `docs/07-architecture.md` | §2, §6, §27, §30 | Laravel 13 / Sanctum / PHPUnit / Pint / Larastan baseline, thin HTTP boundary, Flutter as the only client, versioned REST |
| `docs/08-database.md` | §1, §3 | UUID primary keys on domain tables; `users` is owned by `S01-BE-002` |
| `backend/AGENTS.md` | §3, §6, §10 | thin controllers, forward migrations, stable error codes |

## Decisions

| # | Decision | Why |
|---|---|---|
| 1 | The published Sanctum migration must use `uuidMorphs('tokenable')`, not the default `morphs('tokenable')`. | `docs/08-database.md` §1 and §3 make `users.id` a UUID. The stock migration creates a bigint `tokenable_id`, which cannot reference it. Correcting it after delivery would mean destructively editing a delivered migration, which `backend/AGENTS.md` §6 forbids. |
| 2 | Set `SESSION_DRIVER=file` in `backend/.env.example` and in `backend/config/session.php`'s default. | Removing the framework identity migration also removes the `sessions` table, because the 13.x skeleton creates `users`, `password_reset_tokens` and `sessions` in one file. The skeleton ships `SESSION_DRIVER=database`, so the first real request after `S01-INT-001` wires a database would fail on a missing table. Tests would not catch it: `phpunit.xml` forces the array driver. This is an API-only backend using bearer tokens, so no session table is needed at all. |
| 3 | `server_error` is the machine code for HTTP `500`. | `docs/09-api-contracts.md` §54 had no code for `500`. Added under `AUD-019`; see `docs/CONTRACT_ALIGNMENT_REPORT.md`. |
| 4 | Add `larastan/larastan` (v3, which requires PHPStan 2) at level 5, configured in `backend/phpstan.neon`. | Project Owner approved the dependency. Root `AGENTS.md` §11 names "required static checks" without naming a tool, and `docs/07-architecture.md` §2 listed only PHPUnit and Pint; §2 now lists Larastan, recorded as `AUD-021`. Adding an analyser after code exists would re-baseline every accepted task. Level 5 is the practical floor on a fresh Laravel tree; raising it is a later decision. |
| 5 | Keep the skeleton's own `.gitattributes` and `.editorconfig` in `backend/`. | They are part of a genuine Laravel application. The skeleton's `.gitattributes` pins `eol=lf`, which keeps `artisan` executable inside the Linux container that `S01-INT-001` introduces. The repository root also has its own copies; the nested ones win for paths beneath them. |
| 6 | Delete the skeleton's asset-build and demo-web half: `package.json`, `package-lock.json`, `vite.config.js`, `resources/js/`, `resources/css/`, and `resources/views/welcome.blade.php`. Leave `routes/web.php` present but with no route registered. | The Laravel 13 skeleton ships Vite, Tailwind and a `welcome` view. `docs/07-architecture.md` §2 and §27 make Flutter the only client, so this backend serves JSON only. Keeping an unused Node toolchain would contradict the "no Node/NPM" acceptance criterion and add a dependency surface nothing builds. `routes/web.php` stays so the framework's web middleware group keeps a home, which also keeps the session decision in row 2 meaningful. |

## Implementation Notes

- **Scaffold safely.** `backend/` already contains `AGENTS.md`. Create the app in a temporary directory outside the repository, verify it, then move the contents in. Preserve `backend/AGENTS.md` byte for byte. Ensure no nested `backend/.git/` survives, and remove the temporary directory afterwards.
- **Use the official tooling.** Composer plus the Laravel installer, then the supported API install mechanism for this Laravel version. Do not hand-build a Laravel tree.
- **Identity migration.** Delete the skeleton's `0001_01_01_000000_create_users_table.php` outright; it is the demo identity schema and `S01-BE-002` owns the real one. Keep the cache and jobs migrations. A minimal framework `User` model may remain, with no BarakaBozor role or account fields added.
- **Error rendering must be centralized** through `bootstrap/app.php`'s exception configuration, not repeated in controllers, and it must apply to failures that happen before any controller runs.
- **Prove the contract with test-only routes**, registered from the test case or a test service provider. Do not add fake production endpoints to `routes/api.php` just to make an assertion pass.
- **The `429` case** needs a route with a throttle middleware; register it as a test-only route with a low limit rather than throttling a real endpoint.
- **The `500` case** must be asserted with debug disabled, otherwise Laravel returns the debug payload and the test proves nothing.
- **Composer is Herd-lite on this machine.** In PowerShell `composer` resolves; under Git Bash use `php ~/.config/herd-lite/bin/composer.phar`. Report the exact command run.
- **Pint and PHPStan on Windows:** if the shell cannot execute the Unix shim, invoke the vendor binary the equivalent way and report what was actually run. Do not change project configuration for shell convenience.
- **`install:api` offers to run migrations and defaults to yes.** Decline it, or pass the non-interactive flag. There is no database in this task.
- **The installer leaves a migrated SQLite file.** `laravel/laravel`'s `post-create-project-cmd` runs `touch('database/database.sqlite')` then `php artisan migrate --graceful`, so the scaffold arrives with a populated `backend/database/database.sqlite` whose `personal_access_tokens` table still has the bigint column. Delete that file. The repository root `.gitignore` now excludes `*.sqlite`, so it cannot be committed by accident, but it must not be left on disk either: `S01-INT-001` configures PostgreSQL and a stale SQLite file invites a wrong-database test run.
- **Order matters.** Publish Sanctum, apply the `uuidMorphs` edit, and only then consider any migration run. Never migrate before the edit.

## Acceptance Criteria

- [ ] A genuine Laravel `13.x` application exists under `backend/`; `php artisan --version` reports `13.x`.
- [ ] `backend/AGENTS.md` is unchanged. No nested `backend/.git/` exists.
- [ ] Sanctum is installed through the supported mechanism, and its published migration uses `uuidMorphs('tokenable')`.
- [ ] The skeleton identity migration is gone; cache and jobs migrations remain.
- [ ] `SESSION_DRIVER` defaults to `file`, and no configuration still points at a `sessions` table.
- [ ] The client API is rooted at `/api/v1`; no `/api/user` endpoint responds successfully.
- [ ] Under `/api/v1`: validation returns `422 validation_failed` with a field-keyed `errors` object.
- [ ] Under `/api/v1`: unauthenticated returns `401 authentication_required`, `errors` `{}`.
- [ ] Under `/api/v1`: denied authorization returns `403 forbidden`, `errors` `{}`.
- [ ] An unknown `/api/v1/...` path returns `404 resource_not_found`, `errors` `{}`.
- [ ] Throttling returns `429 rate_limited`, `errors` `{}`.
- [ ] With debug disabled, an unexpected failure returns `500 server_error`, `errors` `{}`, and no exception message, stack trace, SQL, path, class internal, or configuration value.
- [ ] `errors` is a JSON object in every error response.
- [ ] Tests use test-only routes, need no network, and need no database.
- [ ] `backend/database/database.sqlite` does not exist and is not tracked.
- [ ] `package.json`, `vite.config.js`, `resources/js/`, `resources/css/` and `welcome.blade.php` are absent; `routes/web.php` registers no route.
- [ ] `composer.lock` is committed. No `.env`, secret, key, `vendor/`, runtime log or cache, temporary scaffold, or nested Git metadata is tracked.
- [ ] No Node/NPM, product web UI, auth behavior, business table, or speculative infrastructure was introduced.
- [ ] Focused tests, Pint, PHPStan and `composer validate` pass.
- [ ] `git diff --check` passes.
- [ ] Independent review completed; P1 and P2 findings resolved.

## Verification

**Environment evidence**

```text
php -v
composer --version
php artisan --version
```

**Focused tests** — from `backend/`

```text
php artisan test tests/Feature/Api/V1/ApiFoundationTest.php
```

Required cases:

1. unknown `/api/v1/...` → `404 resource_not_found`, `errors` `{}`;
2. validation failure → `422 validation_failed`, field-keyed `errors`;
3. unauthenticated → `401 authentication_required`, `errors` `{}`;
4. authorization denied → `403 forbidden`, `errors` `{}`;
5. throttled → `429 rate_limited`, `errors` `{}`;
6. unexpected exception with debug disabled → `500 server_error`, `errors` `{}`, no sensitive detail;
7. `/api/user` is not a successful public endpoint;
8. the API foundation answers under `/api/v1`.

**Format / static** — from `backend/`

```text
./vendor/bin/pint --test
./vendor/bin/phpstan analyse
composer validate --strict
```

**Directly affected regression**

```text
None required — initial backend scaffold; no prior backend behavior exists.
```

**Project Owner manual check**

`Not required. Runtime and PostgreSQL belong to S01-INT-001.`

**Always** — from repository root

```text
git diff --check
git status --short
```

Then inspect the complete diff: every file necessary for the scaffold; no change under `docs/`, `frontend/`, `docker/`; no secrets; no temporary scaffold directory; no nested `.git`; no demo route; no later-Stage behavior; no weakened test.

## Allowed Areas

| Path or area | Action | Reason |
|---|---|---|
| `backend/AGENTS.md` | Preserve | Approved backend rules; must stay unchanged |
| `backend/` | Create | Genuine Laravel 13 application, framework-generated files included |
| `backend/bootstrap/app.php` | Modify | `/api/v1` routing and centralized exception rendering |
| `backend/routes/api.php` | Modify | Versioned API route file; no demo endpoint |
| `backend/database/migrations/` | Clean | Remove demo identity migration; fix Sanctum `uuidMorphs` |
| `backend/phpstan.neon` | Create | Larastan level 5 |
| `backend/.env.example` | Modify | `SESSION_DRIVER=file`; safe example values only |
| `backend/routes/web.php` | Modify | Keep the file, register no route |
| `backend/package.json`, `backend/vite.config.js`, `backend/resources/js/`, `backend/resources/css/`, `backend/resources/views/welcome.blade.php` | Delete | Decision 6; Flutter is the only client |
| `backend/tests/Feature/Api/V1/ApiFoundationTest.php` | Create | Focused contract evidence |
| `tasks/STAGE_01_TASK_INDEX.md` | Bookkeeping | Task status and contract path |

Do not modify: `docs/`, `frontend/`, `docker/`, root `.gitignore`, root `.gitattributes`.

## Delivery

PR title: `S01-BE-001 — Laravel API Scaffold & Quality Foundation`, target `main`.

Suggested commit subject: `feat: establish Laravel API foundation`.

The implementing agent commits, pushes and opens the PR, and does not merge. The task becomes `Accepted` after the Project Owner merges, with local `main == origin/main`, `0/0`, and a clean worktree.

## Independent Review

Filled in before the PR is opened.

| ID | Severity | Finding | Resolution |
|---|---|---|---|
| | | | |
