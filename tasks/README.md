# BarakaBozor Implementation Workflow — v3 Lean Verification

This directory stores Stage indexes, approved implementation contracts, backend/frontend Phase 2 reviews, integration evidence, and Stage closure records for the locked BarakaBozor MVP.

Workflow v3 applies to **Stage 1 and later**. Stage 0 is the repository/specification bootstrap and has its own closure evidence.

## 1. Authority and Responsibility

```text
ChatGPT       = requirements, architecture, task design, minimum verification,
                review, evidence-validity decisions, and Stage closure
Codex         = implementation + focused task verification only
Project Owner = routine Git/GitHub delivery, checkpoint verification,
                real-stack execution, and manual smoke by default
CI            = checkpoint/integration verification executor when configured
```

Locked authority:

```text
docs/01-business-overview.md
docs/02-user-roles.md
docs/03-features.md
docs/04-user-flows.md
docs/05-business-rules.md
docs/06-roadmap.md
docs/07-architecture.md
docs/08-database.md
docs/09-api-contracts.md
```

ChatGPT re-checks current `origin/main`, relevant locked contracts, current implementation/tests, Stage status, and dependencies before approving work.

Codex receives one compact self-contained approved contract and may inspect only that contract, applicable `AGENTS.md`, and directly relevant implementation/tests/config. Codex must not reopen product specs or prior task history to choose behavior.

## 2. Directory Structure

```text
tasks/
  README.md
  STAGE_<NN>_TASK_INDEX.md
  STAGE_<NN>_CLOSURE_REVIEW.md

  templates/
    CODEX_TASK_TEMPLATE.md
    BLOCK_REVIEW_TEMPLATE.md
    STAGE_TASK_INDEX_TEMPLATE.md
    STAGE_CLOSURE_REVIEW_TEMPLATE.md

  backend/stage-<NN>/
  frontend/stage-<NN>/
  integration/stage-<NN>/
```

Areas:

| Area | Primary ownership |
|---|---|
| Backend | Laravel, PostgreSQL, server-side authorization/scope, business rules, persistence, providers, backend tests |
| Frontend | Flutter data/domain/application/presentation, routing/state/API integration/accessibility/tests |
| Integration | Laravel–Flutter real-stack workflows, provider/sandbox integration, cross-layer security/lifecycle |

## 3. Naming

```text
S<stage>-<area>-<number>-<short-description>.md
```

Examples:

```text
S01-BE-001-laravel-api-foundation.md
S01-FE-001-flutter-client-foundation.md
S01-INT-001-stage-01-auth-real-stack-e2e.md
```

Area codes: `BE`, `FE`, `INT`.

## 4. Stage Planning

Before implementation begins:

1. previous Stage must be explicitly closed;
2. current `origin/main` must be verified;
3. ChatGPT reviews roadmap + relevant locked product/technical contracts;
4. relevant implementation/tests are inspected;
5. product, API, DB, security, lifecycle, concurrency, idempotency, provider, and UX decisions needed for the Stage are resolved;
6. Stage task decomposition/order is proposed;
7. Project Owner approves decomposition;
8. Stage index records tasks, dependencies, checkpoints, integration, risks, and acceptance mapping.

Detailed task contracts are prepared/hardened in execution order; do not generate a large backlog of duplicate `CODEX-PROMPT` files.

## 5. Implementation Readiness Gate

A task becomes `Approved` only when its contract defines, where applicable:

- one clear observable goal;
- included scope + explicit non-goals;
- current implementation context;
- exact business/lifecycle behavior;
- exact API/UI contract;
- persistence/schema behavior;
- role/active-state/ownership/assignment authorization;
- existence privacy;
- validation/normalization/errors;
- edge cases;
- transaction/locking/concurrency/idempotency/replay;
- frontend stale-async ownership;
- acceptance criteria;
- focused positive/negative/security tests;
- exact proportional verification commands;
- directly affected regression checks or justified `None`;
- allowed files/areas;
- delivery owner and evidence requirements.

Codex must not need to choose among product/architecture/API/database/security/lifecycle/financial/UX alternatives. Missing decisions keep the task `Draft` or `Blocked`.

## 6. Task Lifecycle

| Status | Meaning |
|---|---|
| Draft | proposed; readiness gate not passed |
| Approved | complete implementation contract ready for Codex |
| In Progress | Codex implementing/verifying |
| Accepted | contract + focused verification + approved delivery complete; result on `origin/main`; local main synchronized/clean |
| Blocked | planning/dependency/environment/contract prevents safe implementation |
| Delivery Blocked | implementation+verification passed but explicitly assigned delivery could not complete |

Delivery status: `Not started`, `Delivered`, `Blocked`, `Not applicable`.

`Accepted` is task-level. Backend/frontend block checkpoints may still find cross-task defects later.

## 7. Per-Task Workflow

```text
A. Git Preflight
B. Implementation
C. Focused Verification
D. Scope/Diff Self-Check
E. GitHub Delivery
F. Task Acceptance
```

### A — Git Preflight

- task is `Approved`;
- dependencies accepted/delivered;
- local `main` clean;
- fetch and verify local `main == origin/main`;
- verify expected `origin`;
- create one focused task branch;
- preserve unrelated user work/untracked files;
- stop if safe isolation would require force-push/history rewrite/destructive cleanup/check bypass.

### B — Implementation

Implement only the approved contract, using applicable `AGENTS.md`, directly relevant code/tests, focused tests, and explicit non-goals. No unrelated refactor/dependency/generated/doc churn.

### C — Focused Verification

Codex runs only contract-defined:

- focused tests;
- required formatter/linter/static checks;
- named directly affected regression checks when justified;
- `git diff --check`.

Narrow diagnostic reruns are allowed to understand a concrete failure. Full suites/builds/E2E/Phase 2/closure are not normal task-level Codex work.

### D — Scope/Diff Self-Check

Verify every changed file is necessary, contract/non-goals are preserved, no accidental API/schema/route/serialization/security/financial behavior changed, no test was weakened, and no secret/debug/temp artifact exists.

### E — GitHub Delivery

Default owner: **Project Owner**.

Project Owner normally stages only task-owned files, performs safety/secret checks, commits once, pushes task branch, opens/updates PR, merges only with required checks, then synchronizes local `main`, verifies `0/0`, and clean worktree.

Codex performs delivery only when the active task contract explicitly assigns it.

### F — Task Acceptance

Task becomes `Accepted` only when contract/focused verification/diff check pass, approved delivery completes, accepted result is on `origin/main`, local `main == origin/main`, ahead/behind `0/0`, worktree clean.

## 8. Backend Phase 2

After all approved backend Stage tasks are Accepted/Delivered, run a **read-only block review**.

ChatGPT owns scope/findings/verdict; Project Owner/CI runs full backend regression and required format/static/database/security verification. Codex is used only for focused fixes with new approved contracts.

PASS requires:

- full required backend verification passes;
- P1=0, P2=0;
- no unresolved API/DB/security/ownership/assignment/lifecycle/money/concurrency/provider conflict;
- cross-task composition is coherent.

## 9. Frontend Phase 2

After backend PASS (when backend block exists) and all frontend tasks are Accepted/Delivered, run a read-only frontend block review.

Project Owner/CI runs full Flutter tests, static/format checks, required target build, and Stage-specific routing/session/accessibility checks. ChatGPT reviews DTO/API/state/router/cache/stale-async/backend-authority composition.

PASS requires P1=0, P2=0 and all required verification passing.

## 10. Integration Gate

Runs only after required block checkpoints PASS.

Integration defines real Laravel–Flutter workflow, real PostgreSQL, fixtures, exact API/error behavior, auth/session, role/scope denial, lifecycle progression, provider/sandbox boundaries, E2E commands, and Project Owner manual smoke.

Reuse fresh checkpoint evidence; do not rerun full suites merely because integration begins.

Accepted integration state must be delivered to `origin/main`.

## 11. Severity

| Severity | Meaning |
|---|---|
| P1 | security/privacy/secret/data loss or corruption/financial integrity/core public-contract breach |
| P2 | material functional/architecture/lifecycle/integration/regression defect blocking checkpoint/closure |
| P3 | non-blocking maintainability/clarity/test-quality improvement |

## 12. Evidence Validity / Minimum Rerun

Fresh PASS evidence remains valid until a later change materially affects the proven surface. ChatGPT decides minimum sufficient rerun.

Typical guidance:

- docs/bookkeeping-only: no product-verification invalidation;
- isolated test-only strengthening: production evidence remains valid;
- narrow production fix: preserve unrelated evidence, rerun focused affected checks/path;
- shared auth/router/client/middleware/error infrastructure: may invalidate broader checkpoint;
- public API/schema/migration/authorization/financial/security change: normally invalidates corresponding checkpoint/integration surface;
- dependency/platform/build-system change: invalidates relevant static/build evidence;
- any previously failing required command must eventually pass.

Do not rerun by habit; do not preserve materially invalidated evidence.

## 13. Stage Closure

Closure begins only after all approved tasks are Accepted/Delivered, required backend/frontend checkpoints PASS or justified N/A, integration PASS or justified N/A, fixes delivered, and current `origin/main` contains complete accepted Stage result.

ChatGPT reviews roadmap criteria, DoD, locked contracts, current implementation/tests, checkpoint/integration/manual-smoke evidence, delivery/bookkeeping, and final Git state.

Closure verdicts:

```text
STAGE CLOSED
FIXES REQUIRED BEFORE CLOSURE
CLOSURE BLOCKED
```

Next Stage implementation may begin only after current Stage is explicitly closed.

## 14. Git/Repository Safety

Never force-push/rewrite `main`, bypass checks, silently replace remote, modify global Git config, destructively reset/clean as routine workflow, commit secrets/credentials/keys/OTP/provider data, or overwrite unrelated user work.

## 15. External Integration Gates

External provider dependencies are explicit Stage gates, not Codex design freedom.

Examples:

- Stage 1: approved SMS provider documentation/credentials;
- Stage 3: approved Flutter map/tile provider/package;
- Stage 7: official Payme/Paynet/xazna/Click merchant protocols + sandbox/merchant credentials;
- Stage 10: FCM project/configuration.

Provider-dependent task remains `Blocked` until its required external contract is available. Provider-independent tasks may proceed when their own dependencies are satisfied.

## 16. Core Principle

> ChatGPT designs the exact solution and verification scope. Codex implements the approved contract and runs focused task verification. Project Owner/CI executes routine Git delivery, heavy checkpoints, real-stack integration, and manual smoke by default. Reduced duplication must never reduce architecture quality, security, ownership/assignment isolation, financial integrity, acceptance criteria, or final Stage assurance.
