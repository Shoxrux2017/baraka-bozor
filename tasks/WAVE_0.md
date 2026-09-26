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
| W0-6 | Client auth screens and shells: code request and verify, staff login and password change, six role shells, wrong-surface screen, web build of the panel shell | Merged |
| W0-7 | Wave closure: full suites, Android and web builds, real-stack login walk-through for every role, Owner checklist and report | Done, see Closure |

## Task notes

**W0-1.** Replaces the interim rules of `S01-BE-001`: `400 → malformed_request`; `409 → business_conflict`, keeping its status, as the default for a lifecycle conflict thrown without a more specific code; `405` keeps folding to a scope-safe `404 resource_not_found` so the `Allow` header discloses nothing; `502/503 → provider_unavailable`; `request_id` generated per request and written to log context. `details` is emitted when a thrown domain exception carries values. Update the two tests that assert the interim behaviour; the envelope gains `details` (optional) and `request_id`.

**W0-2.** Staff-only endpoints; a Customer token is refused on `/auth/staff/login` by construction (no password) and on change-password (`403`). Sliding lifetime: reject when `last_used_at` (or `created_at`) is older than 30 days; Sanctum's absolute `expiration` stays null; a stale token is deleted on sight. Blocking deletes every token and the `account.active` middleware re-reads status. Rate limits per `09` Section 8 and 10; per-token counter keyed by token ID; a password change revokes the account's other tokens (`DL-9`). `preferred_language` migration on `users`. Middleware group `protected` = `auth:sanctum, account.active, password.changed` for every later feature endpoint; `StrictFormRequest` rejects undeclared fields for every mutation.

**W0-3.** The challenge is created and delivered by `CodeDeliveryGateway`; the fake records the code in a test-only in-process sink; a listed test phone gets a stored challenge for the fixed code and no delivery (`config/login_codes.php`: `LOGIN_CODE_DRIVER`, `LOGIN_CODE_TEST_PHONES`, `LOGIN_CODE_TEST_CODE`, empty by default). Rate limits per `09` Section 6 through the cache-backed limiter. Verify resolves the active Customer or creates one; a blocked Customer answers `account_blocked` only after the code was valid. Mechanics in `DL-10`.

**W0-4.** Middleware `role:<roles>` (`RequireRole::of(Role::Operator, Role::Admin)`) after the `protected` group refuses a role outside the list with `403 forbidden`; the Operator surface is the route rule of `DL-12`, enforced structurally. `ScopedLookup::firstOrNotFound` and `lockOrNotFound` take a query already narrowed to the actor and answer the scope-safe `404 resource_not_found` for a foreign or missing record alike; the lock variant refuses to run outside a transaction. `UuidRouteParameters` constrains every id parameter so a malformed id is the same 404. Probe routes in tests only prove all six roles against three surfaces (generated, not listed), the order blocked → gate → role with a role that is not admitted, and that a foreign, a missing and a malformed id answer the same bytes apart from the request id. `ProtectedRoutesTest` holds the structural rules: status re-check on every authenticated route, role after token/status/gate, real role names, Operator only under `/operations`, constrained parameters.

**W0-5.** `TokenStore` has two slots (`staff`, `customer`) under `bb_session_staff` and `bb_session_customer`; `AuthInterceptor` attaches the token of the request's slot (the active mode by default, or what `RequestSlot.of()` names) and on `401 authentication_required` or `401 account_blocked` drops that slot alone through `SessionController.dropSession`. `ApiFailure` is the sealed failure the application layer handles: `ApiRefusal` with the envelope's `code`, `details` and `Retry-After`, `NetworkFailure`, `MalformedResponseFailure`, `CancelledFailure`. `SessionController` (`AsyncNotifier`) bootstraps both slots against `/auth/me`, keeps tokens when the server is unreachable (`SessionUnreachable`, with `retry`), opens the staff mode first when both exist, and owns login, mode switch, logout, password change and language reporting. Strings: `flutter gen-l10n` from `lib/core/localization/l10n/app_uz.arb` and `app_ru.arb` into the committed `generated/` directory (`flutter_localizations` and `intl` added for that); `LanguageController` defaults to the device language, persists the choice in `PreferenceStore`, and reports it for every confirmed session. Every auth and common error code of `docs/09` Sections 51 and 52 that a screen can meet has a text in both languages, and `failureText()` maps a failure to it with a status fallback. The review of this task fixed the slot being resolved at error time rather than send time, added the token-identity check before a session is dropped, discarded stale completions, and made an unconfirmable bootstrap keep every token. Mechanics in `DL-13` and `DL-14`.

**W0-6.** Screens per `04` Sections 2 and 3 (`features/auth/presentation/`): phone, code, staff login, password change, plus the Customer-mode entry, the unreachable-server retry and the wrong-surface screen per `02` Section 10. Six placeholder shells under `features/shells/` with the language switch, logout of the active mode, the active-mode chip while two sessions exist, and the Customer-mode switch for a Shopper or Courier. The session guard (`core/routing/session_redirect.dart`) and its rules in `DL-15`. `web/` added, `windows/` removed, `flutter build web --release` passes locally and in the new frontend CI job (`.github/workflows/frontend.yml`: format, analyze, tests, localization regeneration check, web build). `frontend/README.md` replaced.

**W0-7.** Also close the risk items below that are cheap. Closed: the obsolete `synthetic-package` option in `frontend/l10n.yaml` (Flutter warned on every build). The real-stack walkthrough runs the HTTP entry point as a one-off container, `docker compose run --rm -d --name baraka-bozor-serve -p 127.0.0.1:8000:8000 app php artisan serve --host 0.0.0.0`, so `docker/compose.yaml` publishes no port until the deployment task; the walkthrough fixtures are local only (test phones in the gitignored `backend/.env`, staff accounts seeded through `backend/storage/app/`).

## Risks and housekeeping

| Item | Status |
|---|---|
| `backend/phpunit.xml` lacks `failOnEmptyTestSuite="true"` | Closed in W0-1 |
| `backend/phpunit.xml` `DB_URL` lacks `force="true"` | Closed in W0-1, differently: a forced `<env>` never beats an exported variable (Laravel reads `$_SERVER` first), so every `DB_*` is now also set through `<server>`, and `tests/TestCase.php` refuses to migrate a database not named `*_test` (`DL-8`) |
| Inert Sanctum stateful-domain configuration | Closed in W0-2: `stateful` is empty, bearer tokens everywhere |
| CI runs bare `phpstan analyse`, a dead worker names no file | Closed in W0-1: a single-process `--debug` step runs only after the normal analysis failed |
| A recreated `app` container ran the stale image without `docker/php.ini`; PHPStan died at 128M locally | Closed: `up -d --build`. Rebuild after any Dockerfile or php.ini change, as `docker/README.md` says |
| `frontend/README.md` is `flutter create` boilerplate | Closed in W0-6 |
| `personal_access_tokens` instants are `timestamp` not `timestamptz` | Closed in W0-2 by a forward `ALTER` migration |
| Feature tests: the auth guards cache the first request's user for the whole test, so a second request with another token was served as the first user | Closed in W0-2: `tests/TestCase.php` forgets the guards before every request and re-applies an `actingAs()` user; `Sanctum::actingAs()` is unsupported |
| Per-IP login limit behind the production proxy: without `TRUSTED_PROXIES` every client is the proxy and twenty wrong attempts lock staff login for everyone | Open until deployment (Wave 4): `config/trustedproxy.php` reads `TRUSTED_PROXIES`; the deployment task sets it to the proxy's address |
| Worktree `G:/project/bb-flutter` could not be removed (Windows path length); harmless | Open, Owner may delete the folder |
| `frontend/pubspec.yaml` has `generate: true`, so `flutter test`, `run` and `build` regenerate `lib/core/localization/generated/` from the ARB files; a forgotten regeneration shows up as a dirty tree, never as a stale build | Closed in W0-6: the frontend CI job runs `flutter gen-l10n` and fails on a dirty tree |
| The frontend CI job is not yet a required check on `main`; only the Owner can change branch protection | Open, asked in the W0-7 report |
| The first frame renders in the device language until the stored choice is read; invisible today because the bootstrap screen shows no text | Accepted |
| Uzbek strings use the ASCII apostrophe (`O'zbekcha`) rather than the orthographic ʻ (U+02BB), as most Uzbek apps do; the Shopper is `Yig'uvchi`, the Courier `Kuryer` | Open for the Owner's word in the W0-7 report; a change is an ARB edit |
| `401 code_invalid`, `code_expired` and `code_attempts_exhausted` carry the generic developer `message` "Authentication is required." because `ApiException::unauthenticated()` has one message; the client never shows it, so only logs read oddly | Open, P3; a message per code when the auth module is next touched |
| The launcher icon and the Android splash are Flutter's defaults; no brand assets exist (`docs/07` section 27) | Open until a designer supplies assets; visible in the Owner's check |
| `frontend/pubspec.lock` and `backend/composer.lock` are pinned by the tasks that added packages; no dependency was added in W0-5 to W0-7 | Closed, nothing to do |

## Independent-review findings not acted on

None. Every finding of the six reviews (W0-1 to W0-6) was acted on before merge; the records are on pull requests #20 to #26.

## Closure

Closed on 2026-09-26 at `main` = merge of PR #26 (`e957301`) plus this closure record.

**Verified by the agent:**

| Check | Result |
|---|---|
| Backend suite in the Compose container, `php artisan test` | 222 passed, 1170 assertions |
| Backend Pint, `vendor/bin/pint --test` | 106 files pass |
| Backend CI on the last merged head (tests, Pint, PHPStan on PostgreSQL) | pass |
| Frontend suite, `flutter test` | 182 passed |
| Frontend analyze and format | no issues, 0 files changed |
| Frontend CI on the last merged head (format, analyze, tests, gen-l10n check, web build) | pass |
| `flutter build web --release` | built |
| `flutter build apk --debug` | built (Flutter 3.47.5) |
| Real stack (PostgreSQL 17 + PHP 8.4 in Compose, `php artisan serve` in a one-off container), API walkthrough | 21 of 21 steps pass: Customer code login on a test phone (`channel = test`), wrong code `401 code_invalid`, `/auth/me`, language through `PATCH /auth/me`; staff login for Shopper, Courier, Operator, Admin, Manager; wrong password `401 invalid_credentials`; first-login gate set, cleared through `/auth/change-password`, new password accepted; a customer session for a Shopper's own phone with `role = customer`; logout revokes the token (`204`, then `401 authentication_required`); `404 resource_not_found` envelope with `request_id` |
| Real stack, Android app on the emulator (API 36 image, `BB_API_BASE_URL=http://10.0.2.2:8000/api/v1`) | Customer login by phone and code; the stored session survives an app restart; logout; staff login as Shopper; Customer mode with a code to the staff phone; the active-mode chip; switch back; logout of one mode keeps the other; language switch to Russian across every string; an Admin on the phone sees the wrong-surface screen and can log out |

**Not verified by the agent, on the Owner's checklist:** the web panel in a real browser (built and tested with the web surface, not driven in Chrome); a real phone; Telegram and SMS delivery (no provider until Wave 4 and 5 — the fake gateway records codes, test phones use the fixed code).

**Owner's manual check** (the app: install `frontend/build/app/outputs/flutter-apk/app-debug.apk` built with the `BB_API_BASE_URL` of the running stack, or run `flutter run` against it; the panel: `flutter run -d chrome --dart-define=BB_API_BASE_URL=...`):

1. Customer: enter a test phone, receive the code screen naming the channel and the phone, enter the fixed code, land in the Customer shell. Close and reopen the app: still signed in. Log out: back to the phone screen.
2. Wrong input: an incomplete phone and a five-digit code are refused before anything is sent; a wrong code shows "Kod noto'g'ri"; after five wrong codes the text says to request a new one.
3. Staff: "Xodim sifatida kirish", phone and password. A wrong password shows its text and the form stays usable. A staff account with a temporary password lands on the password change and nowhere else; a pair shorter than ten characters or not matching is refused before sending; after the change the role shell opens.
4. Customer mode: as a Shopper or Courier, "Mijoz sifatida davom etish", the code goes to your own phone, the Customer shell opens with the "Mijoz rejimi" chip; "Xodim rejimiga qaytish" switches back without a code; logging out of one mode keeps the other.
5. Language: the globe icon switches every string between Uzbek and Russian and the choice survives a restart.
6. Wrong surface: an Operator, Admin or Manager on the phone, or a Customer, Shopper or Courier in the browser, sees the screen naming the right surface and can log out.
7. Web panel: Operator, Admin and Manager sign in in Chrome and see their shell; a mistyped address inside the panel returns to the shell, never an English error page.

**What remains open:** the risk rows above marked Open; the frontend CI job as a required check; the Owner's word on the Uzbek terms; Wave 1 needs the Yandex MapKit API key (`tasks/README.md` section 5).
