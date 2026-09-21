# Stage 1 Task Index — Authentication & Role-Based Entry

## 1. Stage Metadata

| Field | Value |
|---|---|
| Roadmap stage | `Stage 1 — Authentication & Role-Based Entry` |
| Stage status | `In Progress` |
| Verification model | `Workflow v4 — Two-Party` |
| Decomposition approved on | `2026-09-07` |
| Decomposition revised on | `2026-09-21` |
| Implementation started | `Yes — S01-BE-001 in review` |
| Backend checkpoint | `Not started` |
| Frontend checkpoint | `Not started` |
| Integration gate | `Not started` |
| Stage closed | `No` |

Stage 0 is closed. Every task must start from the latest clean, synchronized `origin/main` and verify the actual SHA during Git preflight rather than relying on a hash recorded here. Task contracts are prepared one at a time before implementation.

## 2. Goal and Boundary

### Goal

Allow all six approved user roles to authenticate securely and enter only their correct role surface, with backend-authoritative identity/role/account state, Customer OTP, Staff password plus first-login gate, blocked-account enforcement, and session/account-switch isolation.

### Included

- Laravel API/PostgreSQL/Sanctum foundation.
- Six-role user persistence and one-time initial Admin CLI bootstrap.
- Staff login/logout/me, blocking, password-change gate.
- Customer OTP challenge/verify/rate-limit contract behind `SmsGateway`.
- Role authorization foundation and scope-safe denial.
- Flutter/Riverpod/GoRouter/Dio/secure-storage foundation.
- Customer OTP UX, Staff login/password-change UX.
- Role/device shells for Customer/Shopper/Courier/Operator/Admin/Manager.
- Previous-session isolation and direct-route blocking.
- Continuous integration for the backend checks.
- Real-stack Stage 1 authentication verification.

### Excluded

- Catalog, Products, Cart, Orders, Shopper market workflow, payments, delivery, operational dashboards, analytics.
- Staff-management product UI beyond controlled bootstrap/fixtures required for Stage 1.
- Custom roles, multi-role account switching, 2FA, device-management center.

## 3. Entry Gate

- [x] Stage 0 is explicitly closed.
- [x] Locked `docs/01–09` are present on the audited `origin/main`.
- [x] Repository/engineering workflow baseline is delivered.
- [x] Stage scope and task order were reviewed against the locked Roadmap/Auth/API contract.
- [x] The provider-independent first task has no unresolved product/architecture/API/database/security/lifecycle decision.
- [ ] Stage 1 specification decisions `S-1` to `S-5` are resolved — see `docs/SPEC_DECISIONS_BACKLOG.md`. Not required for `S01-BE-001`; required before the tasks named in that register.
- [ ] SMS provider documentation/credentials are available — not required for `S01-BE-001`; a later provider-task and Stage-closure gate.

## 4. Gates

**SMS provider.** Documentation and credentials are still required. Provider-independent Auth tasks may proceed, but Stage 1 cannot close until an approved real or sandbox SMS integration path exists.

**Continuous integration.** CI arrives in `S01-INT-002`, so `S01-BE-001` and `S01-INT-001` merge on locally-run checks only. Their evidence is the verification output recorded in each pull request. Once CI exists, make its check required on `main`.

**Specification decisions.** `S-1` (role immutability versus unique phone) blocks `S01-BE-002`. `S-2` (what Desktop means) blocks `S01-FE-001`. `S-3` (locale) blocks `S01-FE-003` and `S01-FE-004`. `S-4` (staff login hardening, token lifetime) blocks `S01-BE-003`. `S-5` (Cart on OTP verify) blocks `S01-BE-004`. `S-16` (machine codes for 400, 502 and 503) also blocks `S01-BE-003`, because that task adds the first real endpoint and `S01-BE-001` currently renders those statuses under an interim rule. Each must be decided with the Project Owner before its task is approved.

## 5. Task Order

| Order | Task ID | Area | Short outcome | Depends on | Status | Contract |
|---:|---|---|---|---|---|---|
| 1 | `S01-BE-001` | Backend | Laravel `/api/v1` scaffold, error and quality foundation | Stage 0 closed | In Review | `backend/stage-01/S01-BE-001-laravel-api-scaffold-quality-foundation.md` |
| 2 | `S01-INT-001` | Integration | Local Laravel + PostgreSQL dev/test runtime | `S01-BE-001` | Draft | Not created |
| 3 | `S01-INT-002` | Integration | GitHub Actions running backend tests, Pint, PHPStan against PostgreSQL | `S01-INT-001` | Draft | Not created |
| 4 | `S01-BE-002` | Backend | Users/roles/Sanctum persistence + initial Admin CLI bootstrap | `S01-INT-001`, `S-1` | Blocked | Not created |
| 5 | `S01-BE-003` | Backend | Staff login/logout/me, blocking, first-login password gate | `S01-BE-002`, `S-4`, `S-16` | Blocked | Not created |
| 6 | `S01-BE-004` | Backend | Customer OTP domain/API with strict challenge/rate-limit contract + fake gateway | `S01-BE-002`, `S-5` | Blocked | Not created |
| 7 | `S01-BE-005` | Backend | Six-role authorization foundation, scope-safe protected probe endpoints/tests | `S01-BE-003`, `S01-BE-004` | Draft | Not created |
| 8 | `S01-BE-006` | Backend | Approved production/sandbox SMS provider adapter | `S01-BE-004`, external SMS gate | Blocked | Not created |
| — | `Stage 1 Backend Phase 2` | Review | Full backend auth/security checkpoint | `S01-BE-001…006` Accepted | Not started | Review later |
| 9 | `S01-FE-001` | Frontend | Flutter scaffold + Riverpod/GoRouter/Dio/secure storage foundation | `S-2` | Blocked | Not created |
| 10 | `S01-FE-002` | Frontend | Typed auth repository/session bootstrap/account-switch isolation | `S01-FE-001`, backend auth API | Draft | Not created |
| 11 | `S01-FE-003` | Frontend | Customer OTP request/verify UX | `S01-FE-002`, `S-3` | Blocked | Not created |
| 12 | `S01-FE-004` | Frontend | Staff login + mandatory first-password-change UX | `S01-FE-002`, `S-3` | Blocked | Not created |
| 13 | `S01-FE-005` | Frontend | Six role/device shells, route guards, logout/session isolation | `S01-FE-003`, `S01-FE-004`, `S01-BE-005` | Draft | Not created |
| — | `Stage 1 Frontend Phase 2` | Review | Full frontend auth/session/router/build checkpoint | `S01-FE-001…005` Accepted | Not started | Review later |
| 14 | `S01-INT-003` | Integration | Real Laravel/PostgreSQL/Flutter auth E2E + SMS sandbox/manual evidence | Backend/Frontend PASS | Draft | Not created |

`S01-FE-001` depends only on the Desktop-target decision, not on backend code. Once `S-2` is resolved it may run in parallel with the backend block; the Frontend Phase 2 checkpoint still waits for backend PASS.

Contracts are prepared one task at a time, in execution order.

## 6. Stage Acceptance Map

| Criterion | Implemented by | Final evidence |
|---|---|---|
| Customer can authenticate through the approved phone OTP flow | `S01-BE-004`, `S01-BE-006`, `S01-FE-003` | Integration |
| Staff roles authenticate with phone/password | `S01-BE-003`, `S01-FE-004` | Backend/Frontend + Integration |
| Staff first-login gate blocks normal product access until the password is changed | `S01-BE-003`, `S01-FE-004` | Backend/Frontend + Integration |
| Blocked Staff cannot log in or continue protected use with an old token | `S01-BE-003` | Backend + Integration |
| Client cannot choose or escalate a role | `S01-BE-002…005`, `S01-FE-002` | Security tests + Integration |
| Each role enters only its approved mobile/desktop shell | `S01-FE-005` | Frontend + Integration |
| Direct-route and wrong-role protected access are denied | `S01-BE-005`, `S01-FE-005` | Backend/Frontend + Integration |
| Logout and account switching do not leak prior account state | `S01-FE-002`, `S01-FE-005` | Frontend + Integration |
| Backend checks run automatically on every pull request | `S01-INT-002` | CI run on a PR |
| The external SMS path is actually verified before closure | `S01-BE-006`, `S01-INT-003` | Sandbox/real integration evidence |

## 7. Stop Conditions

- Stage 0 not closed.
- Current `origin/main` not clean or not synchronized.
- A task is reached while its specification decision in `docs/SPEC_DECISIONS_BACKLOG.md` is still open.
- The SMS provider-dependent task is reached while the external gate is unresolved.
- A locked Auth/API/DB contract conflict is discovered.
- Role, blocking, or existence-privacy behavior is incomplete.
- Required task, checkpoint, or integration verification fails.

## 8. Change Log

| Date | Change | Reason |
|---|---|---|
| 2026-09-07 | Decomposition approved | Stage 0 closure |
| 2026-09-21 | Moved to Workflow v4; `S01-BE-001` set `Approved` with its contract path; added `S01-INT-002` continuous integration and renumbered the E2E task to `S01-INT-003`; marked tasks blocked by open specification decisions | Two-party working model; repository review findings |
