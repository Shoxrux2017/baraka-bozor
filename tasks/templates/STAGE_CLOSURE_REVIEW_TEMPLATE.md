# Stage [Number] Closure Review — [Stage Name]

## 1. Metadata

| Field | Value |
|---|---|
| Stage | `[number/name]` |
| Review mode | `Read-only` |
| Verification model | `Workflow v3 — Lean Verification` |
| Review date | `[YYYY-MM-DD]` |
| Stage index | `[path]` |
| Audited `origin/main` | `[SHA]` |
| Local `main` | `[SHA]` |
| Ahead/behind | `[0/0]` |
| Working tree | `[Clean/Not clean]` |
| Proposed verdict | `[Pending]` |

During review: no implementation edits/fixes/staging/commit/push/merge/bookkeeping changes until verdict.

## 2. Closure Entry Conditions

| Condition | Result | Evidence |
|---|---|---|
| Previous Stage closed | `[Pass/N/A/Fail]` | `[reference]` |
| Decomposition approved | `[Pass/Fail]` | `[index]` |
| Every approved task Accepted/Delivered | `[Pass/Fail]` | `[IDs/PRs]` |
| Backend checkpoint PASS/N/A | `[Pass/N/A/Fail]` | `[review]` |
| Frontend checkpoint PASS/N/A | `[Pass/N/A/Fail]` | `[review]` |
| Integration PASS/N/A | `[Pass/N/A/Fail]` | `[evidence]` |
| Complete accepted Stage on origin/main | `[Pass/Fail]` | `[SHA]` |
| Local main == origin/main, 0/0, clean | `[Pass/Fail]` | `[evidence]` |

## 3. Stage Scope / Delivery Audit

Verify complete approved scope, no missing task, no hidden feature/refactor, non-goals excluded, locked contracts unchanged without approval, delivery records coherent, no placeholder/workaround remains.

## 4. Roadmap Acceptance Matrix

| Criterion | Result | Implementation evidence | Verification evidence |
|---|---|---|---|
| `[exact roadmap criterion]` | `[Pass/Fail/Not verified]` | `[tasks/files]` | `[tests/checkpoint/integration/smoke]` |

## 5. Definition of Done

| Condition | Result | Evidence/N/A reason |
|---|---|---|
| Approved business behavior implemented | `[Pass/Fail]` | `[evidence]` |
| Required backend/API works | `[Pass/Fail/N/A]` | `[evidence]` |
| Required frontend uses real backend | `[Pass/Fail/N/A]` | `[evidence]` |
| No core placeholder | `[Pass/Fail/N/A]` | `[evidence]` |
| Backend authorization/scope enforced | `[Pass/Fail/N/A]` | `[evidence]` |
| Money/quantity/historical/financial invariants pass | `[Pass/Fail/N/A]` | `[evidence]` |
| Validation/error contract matches | `[Pass/Fail/N/A]` | `[evidence]` |
| Required checkpoints PASS | `[Pass/Fail/N/A]` | `[reviews]` |
| Real-stack/E2E + required manual smoke PASS | `[Pass/Fail/N/A]` | `[evidence]` |
| No blocking regression | `[Pass/Fail]` | `[evidence]` |
| Docs/tasks synchronized | `[Pass/Fail]` | `[evidence]` |
| P1=0 and P2=0 | `[Pass/Fail]` | `[findings]` |

## 6. Evidence Validity

Reuse fresh PASS checkpoint/integration evidence unless later changes materially affected it. Record invalidated surfaces and exact minimum reruns selected by ChatGPT.

## 7. Complete Working Scenario

| Workflow | Expected | Real-stack/E2E evidence | Result |
|---|---|---|---|
| `[primary]` | `[expected]` | `[evidence]` | `[Pass/Fail/N/A]` |
| `[negative/security/lifecycle]` | `[expected]` | `[evidence]` | `[Pass/Fail/N/A]` |

## 8. Security / Scope / Financial Integrity

Verify role/ownership/current assignment/existence privacy, sensitive fields/secrets, Customer PII minimization, quantity invariants, money/snapshots, payment/refund authority/idempotency/replay, frontend-not-authoritative boundary.

## 9. Project Owner Manual Smoke

| Scenario | Steps | Expected | Result |
|---|---|---|---|
| `[happy path]` | `[steps]` | `[expected]` | `[PASS/FAIL/Not run]` |

Do not claim PASS unless actually run.

## 10. Final Repository State

| Check | Expected | Actual | Result |
|---|---|---|---|
| origin/main | accepted Stage | `[SHA]` | `[Pass/Fail]` |
| local main | same SHA | `[SHA]` | `[Pass/Fail]` |
| ahead/behind | 0/0 | `[value]` | `[Pass/Fail]` |
| worktree | clean | `[value]` | `[Pass/Fail]` |

## 11. Findings

| ID | Severity | Finding | Evidence | Blocks closure? | Required action |
|---|---|---|---|---|---|

## 12. Verdict

Choose one:

```text
STAGE CLOSED
FIXES REQUIRED BEFORE CLOSURE
CLOSURE BLOCKED
```

State concise evidence-based reason and next permitted action.
