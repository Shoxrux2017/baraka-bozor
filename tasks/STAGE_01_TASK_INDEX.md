# Stage 1 Task Index — Authentication & Role-Based Entry

## 1. Stage Metadata

| Field | Value |
|---|---|
| Roadmap stage | `Stage 1 — Authentication & Role-Based Entry` |
| Stage status | `Draft` |
| Verification model | `Workflow v3 — Lean Verification` |
| Decomposition approved on | `Not approved` |
| Implementation started | `No` |
| Backend checkpoint | `Not started` |
| Frontend checkpoint | `Not started` |
| Integration gate | `Not started` |
| Stage closed | `No` |

Implementation must not start until Stage 0 is explicitly closed on real `origin/main`.

## 2. Goal and Boundary

### Goal

Allow all six approved user roles to authenticate securely and enter only their correct role surface, with backend-authoritative identity/role/account state, Customer OTP, Staff password + first-login gate, blocked-account enforcement, and session/account-switch isolation.

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
- Real-stack Stage 1 authentication verification.

### Excluded

- Catalog, Products, Cart, Orders, Shopper market workflow, payments, delivery, operational dashboards, analytics.
- Staff-management product UI beyond controlled bootstrap/fixtures required for Stage 1.
- Custom roles, multi-role account switching, 2FA, device-management center.

## 3. External Gate

**SMS provider documentation/credentials are still required.** Provider-independent Auth tasks may proceed after Stage 0 closes, but Stage 1 cannot close until an approved real/sandbox SMS integration path exists.

## 4. Proposed Task Order

| Order | Task ID | Area | Short outcome | Depends on | Status | Delivery | Contract |
|---:|---|---|---|---|---|---|---|
| 1 | `S01-BE-001` | Backend | Laravel `/api/v1` scaffold, error/quality foundation | Stage 0 closed | Draft | Not started | Not created |
| 2 | `S01-INT-001` | Integration | Local Laravel + PostgreSQL dev/test runtime | `S01-BE-001` | Draft | Not started | Not created |
| 3 | `S01-BE-002` | Backend | Users/roles/Sanctum persistence + initial Admin CLI bootstrap | `S01-INT-001` | Draft | Not started | Not created |
| 4 | `S01-BE-003` | Backend | Staff login/logout/me, blocking, first-login password gate | `S01-BE-002` | Draft | Not started | Not created |
| 5 | `S01-BE-004` | Backend | Customer OTP domain/API with strict challenge/rate-limit contract + fake gateway | `S01-BE-002` | Draft | Not started | Not created |
| 6 | `S01-BE-005` | Backend | Six-role authorization foundation, scope-safe protected probe endpoints/tests | `S01-BE-003`, `S01-BE-004` | Draft | Not started | Not created |
| 7 | `S01-BE-006` | Backend | Approved production/sandbox SMS provider adapter | `S01-BE-004`, external SMS gate | Blocked | Not started | Not created |
| — | `Stage 1 Backend Phase 2` | Review | Full backend auth/security checkpoint | `S01-BE-001…006` Accepted | Not started | N/A | Review later |
| 8 | `S01-FE-001` | Frontend | Flutter scaffold + Riverpod/GoRouter/Dio/secure storage foundation | Backend PASS | Draft | Not started | Not created |
| 9 | `S01-FE-002` | Frontend | Typed auth repository/session bootstrap/account-switch isolation | `S01-FE-001`, backend auth API | Draft | Not started | Not created |
| 10 | `S01-FE-003` | Frontend | Customer OTP request/verify UX | `S01-FE-002` | Draft | Not started | Not created |
| 11 | `S01-FE-004` | Frontend | Staff login + mandatory first-password-change UX | `S01-FE-002` | Draft | Not started | Not created |
| 12 | `S01-FE-005` | Frontend | Six role/device shells, route guards, logout/session isolation | `S01-FE-003`, `S01-FE-004`, `S01-BE-005` | Draft | Not started | Not created |
| — | `Stage 1 Frontend Phase 2` | Review | Full frontend auth/session/router/build checkpoint | `S01-FE-001…005` Accepted | Not started | N/A | Review later |
| 13 | `S01-INT-002` | Integration | Real Laravel/PostgreSQL/Flutter auth E2E + SMS sandbox/manual evidence | Backend/Frontend PASS | Draft | Not started | Not created |

Detailed implementation contracts will be created/hardened one task at a time after Stage 0 closes and decomposition is approved.

## 5. Stage Acceptance Map

| Criterion | Implemented by | Final evidence |
|---|---|---|
| Customer can authenticate through approved phone OTP flow | `S01-BE-004`, `S01-BE-006`, `S01-FE-003` | Integration |
| Staff roles authenticate with phone/password | `S01-BE-003`, `S01-FE-004` | Backend/Frontend + Integration |
| Staff first-login gate blocks normal product access until password changed | `S01-BE-003`, `S01-FE-004` | Backend/Frontend + Integration |
| Blocked Staff cannot log in or continue protected use with old token | `S01-BE-003` | Backend + Integration |
| Client cannot choose/escalate role | `S01-BE-002…005`, `S01-FE-002` | Security tests + Integration |
| Each role enters only its approved mobile/desktop shell | `S01-FE-005` | Frontend + Integration |
| Direct-route and wrong-role protected access are denied | `S01-BE-005`, `S01-FE-005` | Backend/Frontend + Integration |
| Logout/account switching does not leak prior account state | `S01-FE-002`, `S01-FE-005` | Frontend + Integration |
| External SMS path is actually verified before closure | `S01-BE-006`, `S01-INT-002` | Sandbox/real integration evidence |

## 6. Stop Conditions

- Stage 0 not closed.
- Current `origin/main` not clean/synchronized.
- SMS provider-dependent task reached while external gate remains unresolved.
- Locked Auth/API/DB contract conflict discovered.
- Role/blocking/existence-privacy/security behavior is incomplete.
- Required task/checkpoint/integration verification fails.
