# Phase 2 Read-Only Block Review — [Stage / Backend or Frontend]

## 1. Metadata

| Field | Value |
|---|---|
| Stage | `[Stage number/name]` |
| Block | `[Backend / Frontend]` |
| Review mode | `Read-only` |
| Review date | `[YYYY-MM-DD]` |
| Stage index | `[path]` |
| Audited `origin/main` | `[SHA]` |
| Local `main` | `[SHA]` |
| Ahead/behind | `[0/0 expected]` |
| Verification executor | `Project Owner` |
| Verdict | `[Pending]` |

During review: no implementation edits, fixes, staging, commit, push, merge, or bookkeeping change.

## 2. Entry Conditions

| Condition | Result | Evidence |
|---|---|---|
| All approved block tasks Accepted/Delivered | `[Pass/Fail]` | `[IDs/PRs]` |
| Local main == origin/main | `[Pass/Fail]` | `[SHAs]` |
| Ahead/behind 0/0 | `[Pass/Fail]` | `[output]` |
| Worktree clean | `[Pass/Fail]` | `[output]` |
| Required previous checkpoint PASS/N/A | `[Pass/N/A/Fail]` | `[reference]` |

## 3. Scope / Architecture Review

Confirm:

- approved Stage scope only;
- no hidden feature/refactor/dependency churn;
- locked API/DB/business contracts preserved;
- task contracts compose without contradiction;
- no debug/placeholder/temp path remains.

### Backend-specific

- thin controllers;
- request validation vs stateful domain separation;
- focused Actions/services;
- explicit role/ownership/assignment scope before exposure;
- coherent migrations/FK/CHECK/partial unique/indexes;
- no N+1/unbounded reads;
- atomic money/lifecycle writes;
- lock/idempotency/replay rules compose;
- provider adapters protect secrets/authenticity;
- no hidden workflow in Resource/Model.

### Frontend-specific

- feature-first boundaries;
- Widgets do not call Dio/parse JSON;
- DTO/repository/controller contracts agree;
- auth/session/router state coherent;
- stale async completions safe;
- loading/empty/data/error/mutation/reconciliation states correct;
- cache ownership/invalidation narrow;
- backend authority preserved;
- machine values separate from labels;
- accessibility/focus/responsiveness adequate;
- no competing router/client/state/cache architecture.

## 4. Security / Financial Integrity

Verify where applicable:

- unauthenticated/wrong-role denied;
- blocked/first-login gates enforced;
- Customer ownership safe;
- Shopper current-assignment safe;
- Courier current-assignment safe;
- foreign/direct IDs do not reveal private records;
- filters/pagination/aggregates preserve scope;
- Customer PII minimized;
- no secrets/tokens/OTP/provider credentials exposed;
- ordered/purchased/billable quantity invariant preserved;
- money/rounding/snapshots correct;
- payment/refund success provider-authoritative;
- callback/idempotency/replay cannot duplicate financial effects.

Any unresolved security/privacy/financial-integrity defect is blocking.

## 5. Required Verification

### Backend

| Check | Command | Result | Status |
|---|---|---|---|
| Full backend regression | `[command]` | `[observed]` | `[Pass/Fail/N/A]` |
| Format/static | `[command]` | `[observed]` | `[Pass/Fail/N/A]` |
| Migration/schema verification | `[command/method]` | `[observed]` | `[Pass/Fail/N/A]` |
| Stage security/financial checks | `[command/method]` | `[observed]` | `[Pass/Fail/N/A]` |

### Frontend

| Check | Command | Result | Status |
|---|---|---|---|
| Full Flutter tests | `[command]` | `[observed]` | `[Pass/Fail/N/A]` |
| Analyze/format | `[command]` | `[observed]` | `[Pass/Fail/N/A]` |
| Required target build | `[command]` | `[observed]` | `[Pass/Fail/N/A]` |
| Stage routing/session/accessibility checks | `[method]` | `[observed]` | `[Pass/Fail/N/A]` |

## 6. Cross-Task / Prior-Stage Regression

| Surface | Expected | Evidence | Result |
|---|---|---|---|
| `[workflow]` | `[expected]` | `[evidence]` | `[Pass/Fail]` |

## 7. Findings

| ID | Severity | Finding | Evidence | Required correction |
|---|---|---|---|---|
| `[BR-01]` | `[P1/P2/P3]` | `[problem]` | `[evidence]` | `[focused fix]` |

If none:

```text
No findings.
P1 = 0
P2 = 0
P3 = 0
```

## 8. Verdict

Choose exactly one:

```text
PASS
NOT ACCEPTED
```

PASS requires all required entry/verification checks passing, P1=0, P2=0, no unresolved cross-task contract conflict.

## 9. Follow-Up

If NOT ACCEPTED: preserve this review; ChatGPT creates focused fix contract(s); Codex implements focused fix + focused verification; Project Owner delivers; ChatGPT decides minimum invalidated checkpoint reruns before new verdict.
