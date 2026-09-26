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
| W0-2 | Staff auth: login, logout, me, `PATCH /auth/me`, change-password, rate limits, sliding 30-day token, blocked re-check, `preferred_language` column | Merged |
| W0-3 | Customer login codes: `channel` column, `CodeDeliveryGateway` with the fake and the test numbers, request and verify endpoints | Merged |
| W0-4 | Authorization foundation: role and scope middleware, scope-safe not-found helpers, Operator-as-restricted-Admin capability check, probe tests | Merged |
| W0-5 | Client session foundation: two token slots, auth repository and DTOs, error-code mapping, language selection with device default | Merged |
| W0-6 | Client auth screens and shells: code request and verify, staff login and password change, six role shells, wrong-surface screen, web build of the panel shell | Planned |
| W0-7 | Wave closure: full suites, Android and web builds, real-stack login walk-through for every role, Owner checklist and report | Planned |

## Task notes

**W0-1.** Replaces the interim rules of `S01-BE-001`: `400 → malformed_request`; `409 → business_conflict`, keeping its status, as the default for a lifecycle conflict thrown without a more specific code; `405` keeps folding to a scope-safe `404 resource_not_found` so the `Allow` header discloses nothing; `502/503 → provider_unavailable`; `request_id` generated per request and written to log context. `details` is emitted when a thrown domain exception carries values. Update the two tests that assert the interim behaviour; the envelope gains `details` (optional) and `request_id`.

**W0-2.** Staff-only endpoints; a Customer token is refused on `/auth/staff/login` by construction (no password) and on change-password (`403`). Sliding lifetime: reject when `last_used_at` (or `created_at`) is older than 30 days; Sanctum's absolute `expiration` stays null; a stale token is deleted on sight. Blocking deletes every token and the `account.active` middleware re-reads status. Rate limits per `09` Section 8 and 10; per-token counter keyed by token ID; a password change revokes the account's other tokens (`DL-9`). `preferred_language` migration on `users`. Middleware group `protected` = `auth:sanctum, account.active, password.changed` for every later feature endpoint; `StrictFormRequest` rejects undeclared fields for every mutation.

**W0-3.** The challenge is created and delivered by `CodeDeliveryGateway`; the fake records the code in a test-only in-process sink; a listed test phone gets a stored challenge for the fixed code and no delivery (`config/login_codes.php`: `LOGIN_CODE_DRIVER`, `LOGIN_CODE_TEST_PHONES`, `LOGIN_CODE_TEST_CODE`, empty by default). Rate limits per `09` Section 6 through the cache-backed limiter. Verify resolves the active Customer or creates one; a blocked Customer answers `account_blocked` only after the code was valid. Mechanics in `DL-10`.

**W0-4.** Middleware `role:<roles>` (`RequireRole::of(Role::Operator, Role::Admin)`) after the `protected` group refuses a role outside the list with `403 forbidden`; the Operator surface is the route rule of `DL-12`, enforced structurally. `ScopedLookup::firstOrNotFound` and `lockOrNotFound` take a query already narrowed to the actor and answer the scope-safe `404 resource_not_found` for a foreign or missing record alike; the lock variant refuses to run outside a transaction. `UuidRouteParameters` constrains every id parameter so a malformed id is the same 404. Probe routes in tests only prove all six roles against three surfaces (generated, not listed), the order blocked → gate → role with a role that is not admitted, and that a foreign, a missing and a malformed id answer the same bytes apart from the request id. `ProtectedRoutesTest` holds the structural rules: status re-check on every authenticated route, role after token/status/gate, real role names, Operator only under `/operations`, constrained parameters.

**W0-5.** `TokenStore` has two slots (`staff`, `customer`) under `bb_session_staff` and `bb_session_customer`; `AuthInterceptor` attaches the token of the request's slot (the active mode by default, or what `RequestSlot.of()` names) and on `401 authentication_required` or `401 account_blocked` drops that slot alone through `SessionController.dropSession`. `ApiFailure` is the sealed failure the application layer handles: `ApiRefusal` with the envelope's `code`, `details` and `Retry-After`, `NetworkFailure`, `MalformedResponseFailure`, `CancelledFailure`. `SessionController` (`AsyncNotifier`) bootstraps both slots against `/auth/me`, keeps tokens when the server is unreachable (`SessionUnreachable`, with `retry`), opens the staff mode first when both exist, and owns login, mode switch, logout, password change and language reporting. Strings: `flutter gen-l10n` from `lib/core/localization/l10n/app_uz.arb` and `app_ru.arb` into the committed `generated/` directory (`flutter_localizations` and `intl` added for that); `LanguageController` defaults to the device language, persists the choice in `PreferenceStore`, and reports it for every confirmed session. Every error code of `docs/09` Sections 51–56 that a screen can meet has a text in both languages. Mechanics in `DL-13`.

**W0-6.** Screens per `04` Sections 2 and 3; role shells are placeholders with navigation only; the wrong-surface screen per `02` Section 10; `flutter build web` of the panel shell runs in CI-equivalent local verification.

**W0-7.** Also close the risk items below that are cheap.

## Risks and housekeeping

| Item | Status |
|---|---|
| `backend/phpunit.xml` lacks `failOnEmptyTestSuite="true"` | Closed in W0-1 |
| `backend/phpunit.xml` `DB_URL` lacks `force="true"` | Closed in W0-1, differently: a forced `<env>` never beats an exported variable (Laravel reads `$_SERVER` first), so every `DB_*` is now also set through `<server>`, and `tests/TestCase.php` refuses to migrate a database not named `*_test` (`DL-8`) |
| Inert Sanctum stateful-domain configuration | Closed in W0-2: `stateful` is empty, bearer tokens everywhere |
| CI runs bare `phpstan analyse`, a dead worker names no file | Closed in W0-1: a single-process `--debug` step runs only after the normal analysis failed |
| A recreated `app` container ran the stale image without `docker/php.ini`; PHPStan died at 128M locally | Closed: `up -d --build`. Rebuild after any Dockerfile or php.ini change, as `docker/README.md` says |
| `frontend/README.md` is `flutter create` boilerplate | Open, replace in W0-6 |
| `personal_access_tokens` instants are `timestamp` not `timestamptz` | Closed in W0-2 by a forward `ALTER` migration |
| Feature tests: the auth guards cache the first request's user for the whole test, so a second request with another token was served as the first user | Closed in W0-2: `tests/TestCase.php` forgets the guards before every request and re-applies an `actingAs()` user; `Sanctum::actingAs()` is unsupported |
| Per-IP login limit behind the production proxy: without `TRUSTED_PROXIES` every client is the proxy and twenty wrong attempts lock staff login for everyone | Open until deployment (Wave 4): `config/trustedproxy.php` reads `TRUSTED_PROXIES`; the deployment task sets it to the proxy's address |
| Worktree `G:/project/bb-flutter` could not be removed (Windows path length); harmless | Open, Owner may delete the folder |

## Independent-review findings not acted on

None yet.

## Closure

Not yet.
