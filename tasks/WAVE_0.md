# Wave 0 — Foundation

Status: **In Progress**. Plan under workflow v6 (`tasks/README.md`), written 2026-09-24. Earlier Wave 0 records: `WAVE_00_TASK_INDEX.md`, `backend/`, `frontend/`, `integration/` (history).

## Goal

A runnable, verifiable stack and six secure role entries: every role signs in on its surface, the backend enforces role, status and scope, and the client has the session foundation the next waves build on.

## Done before this plan

| Merged | Outcome |
|---|---|
| PR #2 | Laravel `/api/v1` scaffold, error envelope, Pint, PHPStan |
| PR #6, #7, #11 | Docker runtime (PostgreSQL 17, PHP 8.4), CI required on `main`, explicit `php.ini` |
| PR #9 | Module route registry |
| PR #17 | `users` and `customer_otp_challenges` tables, `User` model and factory, first-Admin command, module provider registry |
| PR #16 | Flutter scaffold: route-fragment registry, one Dio client, secure token store, theme |

## Tasks

| # | Task | Status |
|---|---|---|
| W0-1 | Error renderer to the final contract: `malformed_request`, `business_conflict`, `provider_unavailable`, `details`, `request_id` | Merged |
| W0-2 | Staff auth: login, logout, me, `PATCH /auth/me`, change-password, rate limits, sliding 30-day token, blocked re-check, `preferred_language` column | Planned |
| W0-3 | Customer login codes: `channel` column, `CodeDeliveryGateway` with the fake and the test numbers, request and verify endpoints | Planned |
| W0-4 | Authorization foundation: role and scope middleware, scope-safe not-found helpers, Operator-as-restricted-Admin capability check, probe tests | Planned |
| W0-5 | Client session foundation: two token slots, auth repository and DTOs, error-code mapping, language selection with device default | Planned |
| W0-6 | Client auth screens and shells: code request and verify, staff login and password change, six role shells, wrong-surface screen, web build of the panel shell | Planned |
| W0-7 | Wave closure: full suites, Android and web builds, real-stack login walk-through for every role, Owner checklist and report | Planned |

## Task notes

**W0-1.** Replaces the interim rules of `S01-BE-001`: `400 → malformed_request`; `409 → business_conflict`, keeping its status, as the default for a lifecycle conflict thrown without a more specific code; `405` keeps folding to a scope-safe `404 resource_not_found` so the `Allow` header discloses nothing; `502/503 → provider_unavailable`; `request_id` generated per request and written to log context. `details` is emitted when a thrown domain exception carries values. Update the two tests that assert the interim behaviour; the envelope gains `details` (optional) and `request_id`.

**W0-2.** Staff-only endpoints; a Customer token is refused on `/auth/staff/login` by construction (no password) and on change-password (`403`). Sliding lifetime: reject when `last_used_at` (or `created_at`) is older than 30 days; Sanctum's absolute `expiration` stays null. Blocking deletes every token and the auth middleware re-reads status. Rate limits per `09` Section 8 and 10; per-token counter keyed by token ID. `preferred_language` migration on `users`.

**W0-3.** The challenge is created and delivered by `CodeDeliveryGateway`; the fake records the code in a test-only sink; a listed test phone bypasses delivery and verifies with the fixed code (config `auth.test_phones`, `auth.test_code`, empty by default). Rate limits per `09` Section 6. Verify resolves the active Customer or creates one; a blocked Customer answers `account_blocked` only after the code was valid.

**W0-4.** Middleware `role:<roles>` plus policy helpers that scope queries by actor; a protected probe route set in tests only proves 401, 403 and scope-safe 404 for every role. Operator inherits Admin's operational endpoints through one capability map, not duplicated routes.

**W0-5.** `TokenStore` grows two slots (`staff`, `customer`) with a stable key scheme; the Dio interceptor attaches the active mode's token; a `401` with `authentication_required` or `account_blocked` clears only the refused slot. Error mapping from `code` to localized text lives in `core/`, with both languages from the start. Language: device default, in-app switch, persisted on device, sent through `PATCH /auth/me` after login.

**W0-6.** Screens per `04` Sections 2 and 3; role shells are placeholders with navigation only; the wrong-surface screen per `02` Section 10; `flutter build web` of the panel shell runs in CI-equivalent local verification.

**W0-7.** Also close the risk items below that are cheap.

## Risks and housekeeping

| Item | Status |
|---|---|
| `backend/phpunit.xml` lacks `failOnEmptyTestSuite="true"` | Closed in W0-1 |
| `backend/phpunit.xml` `DB_URL` lacks `force="true"` | Closed in W0-1, differently: a forced `<env>` never beats an exported variable (Laravel reads `$_SERVER` first), so every `DB_*` is now also set through `<server>`, and `tests/TestCase.php` refuses to migrate a database not named `*_test` (`DL-8`) |
| Inert Sanctum stateful-domain configuration | Open, remove in W0-2 |
| CI runs bare `phpstan analyse`, a dead worker names no file | Closed in W0-1: a single-process `--debug` step runs only after the normal analysis failed |
| A recreated `app` container ran the stale image without `docker/php.ini`; PHPStan died at 128M locally | Closed: `up -d --build`. Rebuild after any Dockerfile or php.ini change, as `docker/README.md` says |
| `frontend/README.md` is `flutter create` boilerplate | Open, replace in W0-6 |
| `personal_access_tokens` instants are `timestamp` not `timestamptz` | Open, convert in W0-2 (forward `ALTER`) |
| Worktree `G:/project/bb-flutter` could not be removed (Windows path length); harmless | Open, Owner may delete the folder |

## Independent-review findings not acted on

None yet.

## Closure

Not yet.
