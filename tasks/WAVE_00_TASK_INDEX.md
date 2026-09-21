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
| `docs/07-architecture.md` | Sections 2, 3, 8, 9, 23, 27, 29, 33 | architecture, identity, OTP, Flutter, testing |
| `docs/08-database.md` | Section 3 | identity persistence |
| `docs/09-api-contracts.md` | Sections 3, 6, 7, 8, 11 | error envelope, OTP, staff login |
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
- [ ] Wave 0 specification decisions `S-3`, `S-4`, `S-5`, `S-16`, `S-17` resolved. `S-1` and `S-2` resolved 2026-09-21, `AUD-023` — see `docs/SPEC_DECISIONS_BACKLOG.md`. Not required for the runtime, CI or registry tasks; required before the tasks named against them below.
- [ ] Flutter SDK installed on the development machine — required before the first frontend task, absent as of 2026-09-21.

## 5. Approved Task Order

| Order | Task ID | Area | Track | Short outcome | Depends on | Status | Contract file |
|---:|---|---|---|---|---|---|---|
| 1 | `S01-BE-001` | Backend | `wave-owner` | Laravel `/api/v1` scaffold, error and quality foundation | Stage 0 closed | **Accepted** | `backend/stage-01/S01-BE-001-laravel-api-scaffold-quality-foundation.md` |
| 2 | `W0-INT-001` | Integration | `wave-owner` | Local Laravel + PostgreSQL dev/test runtime in Docker | `S01-BE-001` | Draft | Not created |
| 3 | `W0-INT-002` | Integration | `wave-owner` | GitHub Actions running backend tests, Pint and PHPStan against PostgreSQL; required check on `main` | `W0-INT-001` | Draft | `integration/wave-00/W0-INT-002-github-actions-backend-checks.md` |
| 4 | `W0-BE-010` | Backend | `wave-owner` | Module route registry and Flutter route-fragment registry (`D-8`) | `W0-INT-002` | Draft | Not created |
| 5 | `W0-BE-011` | Backend | `wave-owner` | Identity schema: users, six roles, Sanctum tokens, initial Admin CLI bootstrap | `W0-BE-010` | Draft | Not created |
| 6 | `W0-BE-012` | Backend | `wave-owner` | Shared API fixture directory (`D-9`): the `docs/09` response and error examples both sides assert against | `W0-BE-010`, `S-3`, `S-16`, `S-17` | Blocked | Not created |
| 7 | `S01-BE-003` | Backend | `auth-backend` | Staff login/logout/me, blocking, first-login password gate | `W0-BE-011`, `S-4`, `S-16` | Blocked | Not created |
| 8 | `S01-BE-004` | Backend | `auth-backend` | Customer OTP domain/API with strict challenge and rate-limit contract, fake `SmsGateway` | `W0-BE-011`, `S-5` | Blocked | Not created |
| 9 | `S01-BE-005` | Backend | `auth-backend` | Six-role authorization foundation, scope-safe protected probe endpoints and tests | `S01-BE-003`, `S01-BE-004` | Draft | Not created |
| — | `Wave 0 Backend Phase 2` | Review | — | Backend auth/security block checkpoint | all backend tasks Accepted | Not started | Review later |
| 10 | `S01-FE-001` | Frontend | `client-foundation` | Flutter scaffold plus Riverpod/GoRouter/Dio/secure storage foundation | Flutter SDK | Blocked | Not created |
| 11 | `S01-FE-002` | Frontend | `client-foundation` | Typed auth repository, session bootstrap, account-switch isolation | `S01-FE-001`, `W0-BE-012`, `S-3`, `S-16`, `S-17` | Blocked | Not created |
| 12 | `S01-FE-003` | Frontend | `client-foundation` | Customer OTP request/verify UX | `S01-FE-002`, `S-3` | Blocked | Not created |
| 13 | `S01-FE-004` | Frontend | `client-foundation` | Staff login plus mandatory first-password-change UX | `S01-FE-002`, `S-3` | Blocked | Not created |
| 14 | `S01-FE-005` | Frontend | `client-foundation` | Six role/device shells, route guards, logout and session isolation | `S01-FE-003`, `S01-FE-004`, `S01-BE-005` | Draft | Not created |
| — | `Wave 0 Frontend Phase 2` | Review | — | Frontend auth/session/router/build block checkpoint | all frontend tasks Accepted | Not started | Review later |
| 15 | `W0-INT-003` | Integration | `wave-owner` | Real Laravel/PostgreSQL/Flutter auth E2E on the fake `SmsGateway` | Backend and Frontend PASS | Draft | Not created |

Detailed contracts are prepared/hardened in execution order. `Order` is dependency order, not a queue.

The wave's financial-invariant owner is: **none — Wave 0 contains no money, quantity, pricing or payment code.** The wave's schema and shared-caretaker owner is: `wave-owner`.

Concurrency in Wave 0 is narrow by nature: tasks 2, 3 and 4 are a serial chain owned by one track, because CI needs the runtime and the registries should land under CI. Real width begins once `W0-BE-011` is Accepted, after which `auth-backend` and `client-foundation` run alongside `wave-owner`.

`S01-FE-001` depends on the Flutter SDK and on `S-2`, not on backend code. Once both are satisfied it runs in parallel with the backend track; the Frontend Phase 2 checkpoint still waits for backend PASS.

## 6. Implementation Readiness

| Task ID | Scope/non-goals | Behavior/API/UI | Persistence/lifecycle | Auth/scope/security | Money/concurrency/edge | Tests/verification | Ready |
|---|---|---|---|---|---|---|---|
| `S01-BE-001` | Yes | Yes | Yes | Yes | N/A | Yes | Accepted |
| `W0-INT-001` | No | No | No | No | N/A | No | No |
| `W0-INT-002` | No | No | No | No | N/A | No | No |
| `W0-BE-010` | No | No | No | No | N/A | No | No |
| `W0-BE-011` | No | No | No | No | N/A | No | No |
| `W0-BE-012` | No | No | N/A | No | N/A | No | No |
| `S01-BE-003` | No | No | No | No | No | No | No |
| `S01-BE-004` | No | No | No | No | No | No | No |
| `S01-BE-005` | No | No | No | No | N/A | No | No |
| `S01-FE-001` | No | No | N/A | No | N/A | No | No |
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
| Flutter SDK absent from the development machine | `S01-FE-001` and every later frontend task | installation | **Open — now the only thing blocking the frontend track** |
| `S-1` role immutability versus unique phone | `W0-BE-011` | decision | **Resolved 2026-09-21** — partial unique index over active accounts, `BR-ROLE-010` |
| `S-2` what Desktop means, platform set | `S01-FE-001` | decision | **Resolved 2026-09-21** — Desktop is an installed Windows application; targets Android, iOS, Windows; iOS release required from Wave 5 |
| `S-3` locale and message language | `W0-BE-012`, `S01-FE-002`, `S01-FE-003`, `S01-FE-004` | decision | Open |
| `S-4` staff login hardening, token lifetime | `S01-BE-003` | decision | Open |
| `S-5` OTP verify and Cart creation | `S01-BE-004` | decision | Open |
| `S-16` machine codes for 400, 502, 503 | `S01-BE-003`, `W0-BE-012`, `S01-FE-002` | decision | Open |
| `S-17` `request_id` source | `W0-BE-012`, `S01-FE-002` | decision | Open |
| Contract-first frontend may not start before its fixture surface is decided | `S01-FE-002` onward | `S-3`, `S-16`, `S-17` resolved and `W0-BE-012` Accepted | **Enforced by the task rows above** |
| Real SMS path | **Wave 5**, not Wave 0 | vendor contract, alpha-name, credentials, legal entity | Deferred by `D-4` |
| CI absent until `W0-INT-002` | `W0-INT-001` merges on locally-run checks | verification output recorded in the PR | Accepted risk |

## 10. Roadmap Acceptance Matrix

| Criterion | Implementing task(s) | Verification gate | Evidence | Status |
|---|---|---|---|---|
| Customer authenticates through the approved phone OTP flow | `S01-BE-004`, `S01-FE-003` | Integration, on the fake gateway | `[reference]` | Not started |
| Staff roles authenticate with phone and password | `S01-BE-003`, `S01-FE-004` | Backend/Frontend + Integration | `[reference]` | Not started |
| First-login gate blocks normal product access until the password changes | `S01-BE-003`, `S01-FE-004` | Backend/Frontend + Integration | `[reference]` | Not started |
| Blocked Staff cannot log in or continue with an old token | `S01-BE-003` | Backend + Integration | `[reference]` | Not started |
| Client cannot choose or escalate a role | `W0-BE-011`, `S01-BE-003…005`, `S01-FE-002` | Security tests + Integration | `[reference]` | Not started |
| Each role enters only its approved mobile/desktop shell | `S01-FE-005` | Frontend + Integration | `[reference]` | Not started |
| Direct-route and wrong-role protected access are denied | `S01-BE-005`, `S01-FE-005` | Backend/Frontend + Integration | `[reference]` | Not started |
| Logout and account switching do not leak prior account state | `S01-FE-002`, `S01-FE-005` | Frontend + Integration | `[reference]` | Not started |
| Backend checks run automatically on every pull request | `W0-INT-002` | CI run on a PR | `[reference]` | Not started |
| Concurrent tracks cannot collide on shared files | `W0-BE-010`, `tasks/OWNERSHIP.md` | registry task plus wave closure | `[reference]` | Not started |
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
