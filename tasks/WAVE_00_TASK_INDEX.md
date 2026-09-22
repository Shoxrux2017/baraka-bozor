# Wave 0 Task Index — Foundation

## 1. Wave Metadata

| Field | Value |
|---|---|
| Roadmap wave | `Wave 0 — Foundation` |
| Wave status | `In Progress` |
| Verification model | `Workflow v5 — Concurrent Tracks` |
| Declared track width | `3` |
| Ownership map approved | `Yes — tasks/OWNERSHIP.md, 2026-09-21` |
| Decomposition approved on | `2026-09-07 as Stage 1; re-approved as Wave 0 on 2026-09-21` |
| Implementation started | `Yes — S01-BE-001 Accepted` |
| Backend checkpoint | `Not started` |
| Frontend checkpoint | `Not started` |
| Integration gate | `Not started` |
| Wave closed | `No` |

Valid Wave statuses: `Draft`, `Approved`, `In Progress`, `Blocked`, `Closed`.

This index supersedes `STAGE_01_TASK_INDEX.md`, which stays in place as the historical record of the pre-wave decomposition. Tasks already named under the `S01-*` scheme keep their IDs and contract paths; new tasks use `W0-*` (`tasks/README.md` Section 4).

Every task must start from the latest clean, synchronized `origin/main` and verify the actual SHA during Git preflight rather than relying on a hash recorded here.

## 2. Goal and Boundary

### Goal

A runnable, verifiable stack plus six secure role entries: local PostgreSQL runtime, CI as a required check on `main`, the module registries that make concurrent tracks possible, backend-authoritative identity/role/account state, Customer OTP behind a fake `SmsGateway`, Staff password with first-login gate, blocked-account enforcement, and the Flutter client foundation with session and account-switch isolation.

### Included

- Local Laravel + PostgreSQL development and test runtime.
- GitHub Actions running backend tests, Pint and PHPStan against PostgreSQL, made a required check on `main`.
- Module registries (`D-8`): per-module backend route files collected by one loop; Flutter feature route fragments collected by one registry.
- Shared API fixture directory (`D-9`).
- Identity schema: six-role user persistence, Sanctum tokens, one-time initial Admin CLI bootstrap.
- Staff login/logout/me, blocking, password-change gate.
- Customer OTP challenge/verify/rate-limit contract behind `SmsGateway`, with a fake gateway.
- Six-role authorization foundation and scope-safe denial.
- Flutter scaffold with Riverpod/GoRouter/Dio/secure storage.
- Customer OTP UX, Staff login and mandatory first-password-change UX.
- Role/device shells for Customer, Shopper, Courier, Operator, Admin, Manager.
- Previous-session isolation and direct-route blocking.
- Real-stack Wave 0 authentication verification.

### Excluded

- Catalog, Products, Cart, Orders, Shopper market workflow, payments, delivery, operational dashboards, analytics.
- Staff-management product UI beyond the controlled bootstrap and fixtures Wave 0 requires. Staff administration is Wave 1.
- A real SMS provider adapter. Provider selection is a Wave 2 gate; the contract, alpha-name and live verification are Wave 5.
- Custom roles, multi-role account switching, 2FA, device-management center.
- Any schema table beyond identity. Later waves own their own schema tasks.

## 3. Authoritative Planning Inputs

| Source | Section/reference | Why it governs |
|---|---|---|
| `docs/06-roadmap.md` | Sections 1, 2, 4, 16, 17 | wave model, Wave 0 content, Definition of Done |
| `docs/02-user-roles.md` | roles, active/blocked state, first-login | role and account-state behavior |
| `docs/04-user-flows.md` | Section 2 | Customer OTP flow |
| `docs/07-architecture.md` | Sections 2, 3, 8, 9, 23, 27, 29, 30, 33 | architecture, identity and token lifetime, OTP, Flutter, client-owned localization, API style, testing |
| `docs/08-database.md` | Section 3 | identity persistence |
| `docs/09-api-contracts.md` | Sections 3, 6, 7, 8, 10, 11, 54, 55 | error envelope and `request_id`, OTP, staff login and its rate limit, password policy, error-code and account-state vocabulary |
| `AGENTS.md`, `backend/AGENTS.md`, `frontend/AGENTS.md` | all | engineering and safety |
| `tasks/OWNERSHIP.md` | Wave 0 | path ownership per track |
| `docs/superpowers/specs/2026-09-21-parallel-execution-model-design.md` | all | execution model and its constraints |
| current `origin/main` | verified at preflight | implementation baseline |
| Stage 0 closure | `tasks/STAGE_00_CLOSURE_REVIEW.md` | dependency |

## 4. Entry Gate

- [x] Stage 0 is explicitly closed. Wave 0 is the first wave, so no previous wave applies.
- [x] Locked `docs/01–09` are present on the audited `origin/main`.
- [x] Repository and engineering workflow baseline delivered.
- [x] Scope and task order reviewed against the locked roadmap, auth and API contracts.
- [x] Execution model approved (2026-09-21, `AUD-022`).
- [x] `D-8` module registries and `D-9` shared fixtures decided (2026-09-21).
- [x] This Wave 0 decomposition, its three-track split and `tasks/OWNERSHIP.md` approved by the Project Owner on 2026-09-21, separately from the execution model itself, as `tasks/README.md` Section 5 step 7 requires. Individual task contracts still each need their own sign-off.
- [x] Wave 0 specification decisions all resolved. `S-1` and `S-2` on 2026-09-21 (`AUD-023`); `S-3`, `S-4`, `S-5`, `S-16`, `S-17` and `S-19` on 2026-09-22 (`AUD-024`); `S-28` on 2026-09-22 (`AUD-025`). Resolving `S-1` opened `S-19`; `S-3` opened `S-21` to `S-24`; the independent review of `AUD-024` opened `S-25` to `S-31`, of which `S-28` was the only Wave 0 row. The rest are filed against Waves 1 and 2 and are resolved at those gates — see `docs/SPEC_DECISIONS_BACKLOG.md`. Note that `S-29`, password strength and failed-attempt alerting, is filed in Wave 1 but reaches `09` §8 and §10, which Wave 0 builds; `AUD-025`’s reasoning depends on §10 constraining only length, which is what `S-29` may change.
- [x] Flutter SDK installed on the development machine — verified 2026-09-22, `flutter doctor` reports `No issues found!` on Flutter 3.47.5 / Dart 3.13.4, with the Android SDK 37.0.0 and Visual Studio Community 2026 plus the Windows 10 SDK both present. iOS cannot be built on this machine, which Wave 0 does not require; `02` Section 10 defers that to Wave 5.

## 5. Approved Task Order

| Order | Task ID | Area | Track | Short outcome | Depends on | Status | Contract file |
|---:|---|---|---|---|---|---|---|
| 1 | `S01-BE-001` | Backend | `wave-owner` | Laravel `/api/v1` scaffold, error and quality foundation | Stage 0 closed | **Accepted** | `backend/stage-01/S01-BE-001-laravel-api-scaffold-quality-foundation.md` |
| 2 | `W0-INT-001` | Integration | `wave-owner` | Local PostgreSQL and PHP runtime in Docker | `S01-BE-001` | **Accepted** | `integration/wave-00/W0-INT-001-local-postgresql-runtime.md` |
| 3 | `W0-INT-002` | Integration | `wave-owner` | GitHub Actions running backend tests, Pint and PHPStan against PostgreSQL; required check on `main` | `W0-INT-001` | **Accepted** | `integration/wave-00/W0-INT-002-github-actions-backend-checks.md` |
| 4 | `W0-INT-004` | Integration | `wave-owner` | Explicit PHP configuration in the container runtime: PHPStan's peak straddles PHP's default 128M ceiling, so the one mode that names a crashing file was itself crashing | `W0-INT-002` | **Accepted** | `integration/wave-00/W0-INT-004-container-php-memory-limit.md` |
| 5 | `W0-BE-010` | Backend | `wave-owner` | Module route registry, the backend half of `D-8` | `W0-INT-002`, `W0-INT-004` | **Accepted** | `backend/wave-00/W0-BE-010-module-route-registry.md` |
| 6 | `W0-BE-011` | Backend | `wave-owner` | Identity schema: users, six roles, Sanctum tokens, initial Admin CLI bootstrap | `W0-BE-010` | Draft | Not created |
| 7 | `W0-BE-012` | Backend | `wave-owner` | Shared API fixture directory (`D-9`): the `docs/09` response and error examples both sides assert against | `W0-BE-010` | Draft | Not created |
| 8 | `S01-BE-003` | Backend | `auth-backend` | Staff login/logout/me, blocking, first-login password gate | `W0-BE-011` | Draft | Not created |
| 9 | `S01-BE-004` | Backend | `auth-backend` | Customer OTP domain/API with strict challenge and rate-limit contract, fake `SmsGateway` | `W0-BE-011` | Draft | Not created |
| 10 | `S01-BE-005` | Backend | `auth-backend` | Six-role authorization foundation, scope-safe protected probe endpoints and tests | `S01-BE-003`, `S01-BE-004` | Draft | Not created |
| — | `Wave 0 Backend Phase 2` | Review | — | Backend auth/security block checkpoint | all backend tasks Accepted | Not started | Review later |
| 11 | `S01-FE-001` | Frontend | `client-foundation` | Flutter scaffold plus Riverpod/GoRouter/Dio/secure storage foundation, **and the Flutter feature route-fragment registry, the other half of `D-8`** | Flutter SDK — satisfied | In Review | `frontend/wave-00/S01-FE-001-flutter-scaffold.md` |
| 12 | `S01-FE-002` | Frontend | `client-foundation` | Typed auth repository, session bootstrap, account-switch isolation | `S01-FE-001`, `W0-BE-012` | Draft | Not created |
| 13 | `S01-FE-003` | Frontend | `client-foundation` | Customer OTP request/verify UX | `S01-FE-002` | Draft | Not created |
| 14 | `S01-FE-004` | Frontend | `client-foundation` | Staff login plus mandatory first-password-change UX | `S01-FE-002` | Draft | Not created |
| 15 | `S01-FE-005` | Frontend | `client-foundation` | Six role/device shells, route guards, logout and session isolation | `S01-FE-003`, `S01-FE-004`, `S01-BE-005` | Draft | Not created |
| — | `Wave 0 Frontend Phase 2` | Review | — | Frontend auth/session/router/build block checkpoint | all frontend tasks Accepted | Not started | Review later |
| 16 | `W0-INT-003` | Integration | `wave-owner` | Real Laravel/PostgreSQL/Flutter auth E2E on the fake `SmsGateway` | Backend and Frontend PASS | Draft | Not created |

Detailed contracts are prepared/hardened in execution order. `Order` is dependency order, not a queue.

The wave's financial-invariant owner is: **none — Wave 0 contains no money, quantity, pricing or payment code.** The wave's schema and shared-caretaker owner is: `wave-owner`.

Concurrency in Wave 0 is narrow by nature: tasks 2 to 5 are a serial chain owned by one track, because CI needs the runtime, the runtime has to be configured for the checks CI runs, and the registries should land under a green CI. Real width begins once `W0-BE-011` is Accepted, after which `auth-backend` and `client-foundation` run alongside `wave-owner`.

`S01-FE-001` depends on the Flutter SDK, not on backend code. Once the SDK is installed it runs in parallel with the backend track; the Frontend Phase 2 checkpoint still waits for backend PASS.

## 6. Implementation Readiness

| Task ID | Scope/non-goals | Behavior/API/UI | Persistence/lifecycle | Auth/scope/security | Money/concurrency/edge | Tests/verification | Ready |
|---|---|---|---|---|---|---|---|
| `S01-BE-001` | Yes | Yes | Yes | Yes | N/A | Yes | Accepted |
| `W0-INT-001` | Yes | Yes | Yes | N/A | N/A | Yes | Accepted |
| `W0-INT-002` | Yes | Yes | N/A | N/A | N/A | Yes | Accepted |
| `W0-INT-004` | Yes | Yes | N/A | N/A | N/A | Yes | Accepted |
| `W0-BE-010` | Yes | Yes | N/A | N/A | N/A | Yes | Accepted |
| `W0-BE-011` | No | No | No | No | N/A | No | No |
| `W0-BE-012` | No | No | N/A | No | N/A | No | No |
| `S01-BE-003` | No | No | No | No | No | No | No |
| `S01-BE-004` | No | No | No | No | No | No | No |
| `S01-BE-005` | No | No | No | No | N/A | No | No |
| `S01-FE-001` | Yes | Yes | N/A | Yes | N/A | Yes | Yes |
| `S01-FE-002` | No | No | N/A | No | N/A | No | No |
| `S01-FE-003` | No | No | N/A | No | N/A | No | No |
| `S01-FE-004` | No | No | N/A | No | N/A | No | No |
| `S01-FE-005` | No | No | N/A | No | N/A | No | No |
| `W0-INT-003` | No | No | No | No | N/A | No | No |

## 7. Dependency / Checkpoint Map

| Dependency/checkpoint | Required before | Evidence |
|---|---|---|
| `W0-INT-001` Accepted | any task that touches the database | runtime task PR |
| `W0-INT-002` Accepted and required on `main` | the first concurrent wave tracks | CI run visible on a PR |
| `W0-INT-004` Accepted | diagnosing any PHPStan crash, because `--debug` is what names the file and it did not fit under the old ceiling | memory-limit task PR |
| `W0-BE-010` Accepted | per-track route ownership | registry task PR |
| `W0-BE-011` Accepted | `S01-BE-003`, `S01-BE-004` | identity schema PR |
| `W0-BE-012` Accepted | `S01-FE-002` and every later contract-first frontend task | fixture task PR |
| Backend task block complete | Backend Phase 2 | `S01-BE-001`, `W0-BE-010`, `W0-BE-011`, `S01-BE-003…005` Accepted |
| Backend PASS | Frontend Phase 2 | backend block review |
| Frontend task block complete | Frontend Phase 2 | `S01-FE-001…005` Accepted |
| Frontend PASS | Integration | frontend block review |
| Integration PASS | Wave closure | `W0-INT-003` evidence plus Project Owner manual smoke |

## 8. Verification Map

Filled in per task when its contract is written. `git diff --check` is required for every task without exception. No task-level full suite, full build or broad E2E unless its contract names a concrete risk (`AGENTS.md` Section 11).

## 9. External Gates / Risks

| Gate/risk | Affected task | Required input | Status |
|---|---|---|---|
| Flutter SDK absent from the development machine | `S01-FE-001` and every later frontend task | installation | **Closed 2026-09-22** — Flutter 3.47.5 installed, `flutter doctor` clean, Android and Windows toolchains both present |
| The development machine's `C:` drive is full | any task whose build writes to a cache under `C:` | free disk space | **Open.** `flutter build apk` failed on `S01-FE-001` with a `jlink` error that renders as mojibake and says only that the disk is full; the Windows build passed because it writes into the repository on `G:`. Verified with `Get-PSDrive`: `C:` had `0` GB free. The APK was then built by pointing `GRADLE_USER_HOME` and `TEMP` at `G:\tmp`, which is evidence the project is sound but is not the normal configuration. Docker, PostgreSQL and the backend suite all live on `C:` |
| `S-1` role immutability versus unique phone | `W0-BE-011` | decision | **Resolved 2026-09-21** — partial unique index over active accounts, `BR-ROLE-010` |
| `S-2` what Desktop means, platform set | `S01-FE-001` | decision | **Resolved 2026-09-21** — Desktop is an installed Windows application; targets Android, iOS, Windows; iOS release required from Wave 5 |
| `S-19` Customer OTP verify when the only Customer account is blocked | `W0-BE-011`, `S01-BE-004` | decision | **Resolved 2026-09-22** — partial index permits a blocked Customer row; verify resolves only the active one and returns `account_blocked` |
| `S-28` does the staff-login rate limit cover `/auth/change-password` | `S01-BE-003`, which builds the endpoint — recorded against `S01-BE-004` in error until 2026-09-22, so while the decision was open it blocked nothing | decision | **Resolved 2026-09-22** — yes, 5 failed checks per minute and `429 rate_limited`, counted **per token**. The first answer counted per account, which let a stolen token bar the owner from ever changing their password. `AUD-025` |
| Stale `S-16` comment and the surviving interim rule in `ApiExceptionRenderer` | `S01-BE-003` | `backend/app/Exceptions/ApiExceptionRenderer.php` still says the codes for 400, 502 and 503 are an open decision, which `AUD-024` closed, and `CODE_BY_STATUS` still lacks `409` so `405` and `409` keep folding to a scope-safe `404` although `business_conflict` exists in `09` §54. Housekeeping, tracked so it is not forgotten | Open |
| PHPStan fails in CI on `W0-BE-010` with `Child process error (exit code 255)` | `W0-BE-010` and every task behind it | `W0-INT-004` | **Closed 2026-09-22 — the binding constraint identified, the mechanism not.** The forward merge changes nothing under `backend/**`, verified byte-identical, so PHP’s `memory_limit` is the only variable between five failing heads at 128M and two passing ones at 512M, and `--debug` on this tree dies outright at 128M. **Why the ceiling binds in CI’s parallel run and not locally is still unknown**: thirteen local runs at 128M refused to fail — cold cache (5), workers forced to four (3), container limited to four CPUs (3), two more on review. Peak figures here vary by sample (128.5 MB ×5, 138.5 ×1, 190.5 ×1), and an earlier version of this row asserted a settled cause on the single highest one |
| `09` §10 `change-password` has no `Codes:` line | `S01-BE-003`, `W0-BE-012` | a code for a wrong `current_password`, and for the `new_password` validation failure | Open — §6, §7 and §8 each carry a `Codes:` line and §10 never has. `AUD-025` added a rule that names both outcomes and deliberately did not invent codes for them; `invalid_credentials` by analogy with §8 is the obvious reading, which is not the same as a decision. `S01-BE-003`’s contract settles it or raises it |
| CI cannot name the file when PHPStan dies | any task whose analysis crashes | `--debug`, or an equivalent, in `.github/workflows/backend.yml` | Open — the workflow runs bare `phpstan analyse`, and a fatal in a parallel worker is reported only as a dead child. This cost five CI runs and most of a day on `W0-BE-010`. Housekeeping, tracked so it is not rediscovered the same way |
| Inert Sanctum SPA-cookie configuration | none blocking | `backend/config/sanctum.php` still carries Laravel default stateful domains, unused since `S-2` ruled out a browser surface. Housekeeping, tracked so it is not forgotten | Open |
| `S-3` locale and message language | `W0-BE-012`, `S01-FE-002`, `S01-FE-003`, `S01-FE-004` | decision | **Resolved 2026-09-22** — Uzbek and Russian client; `message` is developer-facing English; no backend locale negotiation |
| `S-4` staff login hardening, token lifetime | `S01-BE-003` | decision | **Resolved 2026-09-22** — rate limit 5 per phone and 20 per IP per minute, no lockout, sliding 30-day token, double revocation on block |
| `S-5` OTP verify and Cart creation | `S01-BE-004` | decision | **Resolved 2026-09-22** — Cart created lazily on first Cart access |
| `S-16` machine codes for 400, 502, 503 | `S01-BE-003`, `W0-BE-012`, `S01-FE-002` | decision | **Resolved 2026-09-22** — `malformed_request` for 400, `provider_unavailable` for 502 and 503 |
| `S-17` `request_id` source | `W0-BE-012`, `S01-FE-002` | decision | **Resolved 2026-09-22** — server-generated, error responses only |
| Contract-first frontend may not start before its fixture surface is decided | `S01-FE-002` onward | `S-3`, `S-16`, `S-17` resolved and `W0-BE-012` Accepted | `S-3`, `S-16` and `S-17` resolved 2026-09-22; now waits only on `W0-BE-012` |
| Real SMS path | **Wave 5**, not Wave 0 | vendor contract, alpha-name, credentials, legal entity | Deferred by `D-4` |
| CI absent until `W0-INT-002` | `W0-INT-001` merges on locally-run checks | verification output recorded in the PR | **Closed 2026-09-22** — CI is a required check on `main` |
| `backend/phpunit.xml` has no `failOnEmptyTestSuite`, so a suite that stops discovering tests would still report green | every wave | one attribute; `backend/**` was out of scope for `W0-INT-002` | Open — follow-up task |
| `backend/phpunit.xml` `DB_URL` lacks `force="true"` and Laravel prefers it over the discrete `DB_*` values | every wave | guarded today by `TestDatabaseIsolationTest`, which asks the server for `current_database()`; worth closing anyway | Open — follow-up task |
| Host PHP cannot load `pdo_pgsql` | every task that touches the database | `W0-INT-001` runs PHP and the suite in a container | **Closed 2026-09-22** — `W0-INT-001` Accepted |

## 10. Roadmap Acceptance Matrix

| Criterion | Implementing task(s) | Verification gate | Evidence | Status |
|---|---|---|---|---|
| Customer authenticates through the approved phone OTP flow | `S01-BE-004`, `S01-FE-003` | Integration, on the fake gateway | `[reference]` | Not started |
| Staff roles authenticate with phone and password | `S01-BE-003`, `S01-FE-004` | Backend/Frontend + Integration | `[reference]` | Not started |
| First-login gate blocks normal product access until the password changes | `S01-BE-003`, `S01-FE-004` | Backend/Frontend + Integration | `[reference]` | Not started |
| Blocked Staff cannot log in or continue with an old token | `S01-BE-003` | Backend + Integration | `[reference]` | Not started |
| Client cannot choose or escalate a role | `W0-BE-011`, `S01-BE-003…005`, `S01-FE-002` | Security tests + Integration | `[reference]` | Not started |
| Each role enters only its approved mobile/desktop shell | `S01-FE-005` | Frontend + Integration | `[reference]` | Not started |
| A release build is produced for every required target of this wave — **Android and Windows** per `02` Section 10 and `07` Section 2; iOS is required only from Wave 5 | `S01-FE-001`, `S01-FE-005` | Frontend Phase 2 required target build | `[reference]` | Not started |
| Direct-route and wrong-role protected access are denied | `S01-BE-005`, `S01-FE-005` | Backend/Frontend + Integration | `[reference]` | Not started |
| Logout and account switching do not leak prior account state | `S01-FE-002`, `S01-FE-005` | Frontend + Integration | `[reference]` | Not started |
| Backend checks run automatically on every pull request | `W0-INT-002` | CI run on a PR | `[reference]` | Not started |
| Concurrent tracks cannot collide on shared files | `W0-BE-010`, `tasks/OWNERSHIP.md` | registry task plus wave closure | `W0-BE-010` PR #9, merged | **Closed for routes 2026-09-22** — module route files are collected by one loop and a duplicate route name stops the boot. Ownership beyond routes is still enforced by `tasks/OWNERSHIP.md` alone and is re-checked at wave closure |
| The fake `SmsGateway` never emits an OTP to a client, log or header | `S01-BE-004` | Backend security tests + Integration | `[reference]` | Not started |
| The external SMS path is actually verified | Wave 5 | Wave 5 closure | Wave 5 record | Deferred by `D-4` |

## 11. Stop Conditions

- Current `origin/main` not clean or not synchronized.
- A task is reached while its specification decision in `docs/SPEC_DECISIONS_BACKLOG.md` is still open.
- A locked auth, API or database contract conflict is discovered.
- Role, blocking or existence-privacy behavior is incomplete.
- A task would need to modify a path another track owns.
- Required task, checkpoint or integration verification fails.
- More than five pull requests are open at once.

## 12. Change Log

| Date | Change | Reason | Approved by |
|---|---|---|---|
| 2026-09-07 | Stage 1 decomposition approved | Stage 0 closure | Project Owner |
| 2026-09-21 | Moved to Workflow v4; `S01-BE-001` approved and later merged as PR #2 | Two-party working model | Project Owner |
| 2026-09-21 | Folded into Wave 0. `S01-BE-001` set `Accepted`. The former `S01-INT-001`, `S01-INT-002` and `S01-INT-003` renamed `W0-INT-001`, `W0-INT-002`, `W0-INT-003`; registry, fixture and identity-schema tasks added as `W0-BE-010`, `W0-BE-012`, `W0-BE-011`; the former `S01-BE-002` is superseded by `W0-BE-011`. The SMS provider adapter task and the SMS closure criterion moved to Wave 5 under `D-4`. Tracks and the ownership map set and approved. | Adoption of the wave execution model, `AUD-022` | Project Owner |
| 2026-09-22 | `W0-INT-001` and `W0-INT-002` marked `Accepted` on the Project Owner's instruction; both merged, as PR #6 and PR #7. CI is a required check on `main` — job `Tests, Pint, PHPStan on PostgreSQL`, strict — so the pre-CI risk and the host-PHP risk are closed. | Wave 0 entry cost paid | Project Owner |
| 2026-09-22 | `W0-BE-010` delivers only the backend half of `D-8`. The Flutter feature route-fragment registry moves to `S01-FE-001`, because no Flutter project exists yet: `frontend/` holds only `AGENTS.md`. | Keep both halves of `D-8` carried by a task | Project Owner |
| 2026-09-21 | `W0-INT-001` contract approved by the Project Owner and implemented on its task branch: PostgreSQL 17 plus a PHP 8.4 container, the suite moved off SQLite onto a separate PostgreSQL test database. The ownership map enumeration of backend paths replaced by "all of `backend/**` except what `auth-backend` owns". Status is `In Review` until the pull request is merged. | Wave 0 foundation | contract approved by Project Owner; implemented by the implementing agent |
| 2026-09-21 | `S-1` and `S-2` resolved, `AUD-023`. `W0-BE-011` no longer blocked by a decision and moves to `Draft`; `S01-FE-001` drops `S-2` and stays `Blocked` on the absent Flutter SDK. | Wave 0 planning gate | Project Owner |
| 2026-09-22 | `S-3`, `S-4`, `S-5`, `S-16`, `S-17` and `S-19` resolved, `AUD-024`. Wave 0 has no open specification decision left. `W0-BE-011`, `W0-BE-012`, `S01-BE-003`, `S01-BE-004`, `S01-FE-002`, `S01-FE-003` and `S01-FE-004` are no longer blocked by a decision; what remains is task order and the absent Flutter SDK. | Wave 0 decision package complete | Project Owner |
| 2026-09-22 | Independent review of `AUD-024`: ten `P2` and eighteen `P3` findings, no `P1`, all verified and accepted. Eight `P2` fixed by edit. **Wave 0 reopened by `S-28`**, which blocks `S01-BE-004`; `S-25` to `S-27` and `S-29` to `S-31` recorded for Waves 1 and 2, three of them decisions the amendment made without authority. | Review findings resolved before delivery | Project Owner |
| 2026-09-22 | `W0-INT-004` inserted into the approved task order as order 4; former 4–15 renumbered 5–16. `W0-BE-010` now also depends on it. | `phpstan --debug` was observed at 170.5 MB against PHP’s default 128M ceiling and crashed on `W0-BE-010`’s tree, so the one mode that names a crashing file was itself unusable. Contract approved 2026-09-22. | Project Owner |
| 2026-09-22 | `main` merged forward into `W0-BE-010`, and the CI failure that held it closed: `memory_limit` was the binding constraint, raised by `W0-INT-004`, with two green runs on the merged head. The mechanism inside the parallel worker remains unexplained and is tracked as a separate risk. | Re-verification after taking in merged shared infrastructure, root `AGENTS.md` §11 | Implementing agent; task acceptance remains the Project Owner’s |
| 2026-09-22 | `W0-INT-004` and `W0-BE-010` set `Accepted`. Both are on `origin/main` (PR #11 and PR #9), local `main` is synchronized and clean, and CI is green on each merged head. | Acceptance assigned by the Project Owner and recorded on their instruction, per root `AGENTS.md` §15 | Project Owner |
| 2026-09-22 | `S-28` resolved, `AUD-025`: 5 failed `current_password` checks per minute on `/auth/change-password`, counted **per token**. No task row changed — the decision had been recorded against `S01-BE-004` in error, and `S01-BE-003`, which builds the endpoint, was already `Draft`. Every Wave 0 specification decision is now resolved; two Wave 0 gaps remain in Section 9 as risks rather than decisions. | The last Wave 0 decision, opened by the independent review of `AUD-024`; its own review then changed the answer | Project Owner |
| 2026-09-22 | `S01-FE-001` contract approved and implemented. The Flutter SDK gate closes, so the entry gate in Section 4 is complete. The Wave 0 ownership exception widens to the whole `frontend/` tree for this one task, because `flutter create` writes seven paths the map never listed; `tasks/OWNERSHIP.md` records it. A new Section 9 risk records that the machine's `C:` drive is full, which is what failed the Android build until its caches were moved. | First frontend task of the wave | contract approved by the Project Owner; implemented by the implementing agent |
