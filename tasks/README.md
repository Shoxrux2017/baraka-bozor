# BarakaBozor Implementation Workflow — v4 Two-Party

This directory stores Stage indexes, approved task contracts, backend/frontend Phase 2 reviews, integration evidence, and Stage closure records for the locked BarakaBozor MVP.

Workflow v4 applies to **Stage 1 and later**. Stage 0 is the repository/specification bootstrap and has its own closure evidence. Workflow v3 assumed a separate planner and a blind implementer; v4 replaces that with one implementing agent plus an independent reviewer.

## 1. Authority and Responsibility

```text
Implementing agent = requirements analysis, task contracts, implementation,
                     focused verification, branches, commits, pull requests;
                     obtains an independent review before every PR
Project Owner      = product decisions, contract approval, PR review and merge,
                     checkpoint verification, real-stack execution,
                     manual smoke, Stage closure
CI                 = checkpoint/integration verification executor when configured
```

The implementing agent never merges its own work. The Project Owner owns `main`.

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

Changing any locked document requires Project Owner approval, an update to every affected document, and an appended entry in `docs/CONTRACT_ALIGNMENT_REPORT.md`.

## 2. What Changed From v3

| Area | v3 | v4 |
|---|---|---|
| Planning and implementation | separate parties | one implementing agent |
| Reading `docs/01–09` while implementing | forbidden | allowed and expected |
| Contract size | self-contained briefing, often 400+ lines | decision record, normally under 120 lines |
| Independent check | came free from the party split | explicit reviewer step before every PR |
| Git delivery | Project Owner did everything | agent branches/commits/pushes/opens PR; Owner merges |

Everything v3 said about security, ownership and assignment scope, financial integrity, lifecycle invariants, test quality, and Stage gates is unchanged and still binding.

## 3. Directory Structure

```text
tasks/
  README.md
  STAGE_<NN>_TASK_INDEX.md
  STAGE_<NN>_CLOSURE_REVIEW.md

  templates/
    TASK_TEMPLATE.md
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

## 4. Naming

```text
S<stage>-<area>-<number>-<short-description>.md
```

Examples:

```text
S01-BE-001-laravel-api-foundation.md
S01-FE-001-flutter-client-foundation.md
S01-INT-003-stage-01-auth-real-stack-e2e.md
```

Area codes: `BE`, `FE`, `INT`.

## 5. Stage Planning

Before implementation begins:

1. previous Stage must be explicitly closed;
2. current `origin/main` must be verified;
3. the roadmap and the relevant locked contracts are reviewed;
4. relevant implementation/tests are inspected;
5. product, API, DB, security, lifecycle, concurrency, idempotency, provider, and UX decisions needed for the Stage are resolved with the Project Owner;
6. Stage task decomposition/order is proposed;
7. Project Owner approves the decomposition;
8. the Stage index records tasks, dependencies, checkpoints, integration, risks, and acceptance mapping.

Detailed task contracts are prepared in execution order, not speculatively for the whole Stage.

## 6. Implementation Readiness Gate

A task becomes `Approved` only when the Project Owner has signed off and the contract answers, where applicable:

- one clear observable goal;
- included scope and explicit non-goals;
- exact business/lifecycle behavior;
- exact API/UI contract;
- persistence/schema behavior;
- role/active-state/ownership/assignment authorization, and existence privacy;
- validation/normalization/errors and edge cases;
- transaction/locking/concurrency/idempotency/replay, and frontend stale-async ownership;
- acceptance criteria;
- focused positive/negative/security tests and the exact verification commands;
- directly affected regression checks or a justified `None`;
- allowed files/areas.

A contract does not restate the specification. It records the decisions, points at the governing sections, and states what "done" means. Where the locked docs already answer something, cite the section instead of copying it.

Open product/architecture/API/database/security/lifecycle/financial/UX questions keep the task `Draft` or `Blocked`.

## 7. Task Lifecycle

| Status | Meaning |
|---|---|
| Draft | proposed; readiness gate not passed |
| Approved | Project Owner signed off; ready to implement |
| In Progress | implementation and verification under way |
| In Review | PR open, awaiting Project Owner merge |
| Accepted | merged to `origin/main`; local main synchronized and clean |
| Blocked | planning/dependency/environment/contract prevents safe implementation |

`Accepted` is task-level. Backend/frontend block checkpoints may still find cross-task defects later.

## 8. Per-Task Workflow

```text
A. Git preflight
B. Implementation
C. Focused verification
D. Scope/diff self-check
E. Independent review
F. Pull request
G. Merge and acceptance
```

### A — Git preflight

- task is `Approved`;
- dependencies accepted;
- local `main` clean;
- fetch and verify local `main == origin/main`;
- verify the expected `origin`;
- create one focused task branch;
- preserve unrelated user work and untracked files;
- stop if safe isolation would require force-push, history rewrite, destructive cleanup, or check bypass.

Branch naming:

```text
task/<task-id-lowercase>-<short-description>
```

### B — Implementation

Implement only the approved contract, using the applicable `AGENTS.md`, the locked specification where it governs, directly relevant code and tests, and focused tests. No unrelated refactor, dependency, generated-file, or doc churn.

### C — Focused verification

Run only what the contract defines:

- focused tests;
- required formatter/linter/static checks;
- named directly affected regression checks when justified;
- `git diff --check`.

Narrow diagnostic reruns are allowed to understand a concrete failure. Full suites, builds, E2E, Phase 2, and closure verification are not normal task-level work.

Never report a command as passing unless it was run and observed passing. Quote the output.

### D — Scope/diff self-check

Verify every changed file is necessary, the contract and non-goals are preserved, no accidental API/schema/route/serialization/security/financial behavior changed, no test was weakened, and no secret/debug/temp artifact exists.

### E — Independent review

Before opening the PR, a reviewer with no implementation context reviews the complete diff against the task contract and the applicable `AGENTS.md`.

This step replaces the quality separation that the v3 party split provided. It is not optional, and its findings travel with the work: every finding is reported to the Project Owner, including those deliberately not acted on, with the reason.

Findings at P1 or P2 are fixed before the PR is opened.

### F — Pull request

The implementing agent stages only task-owned files, performs secret and safety checks, commits, pushes the task branch, and opens a PR against `main` describing scope, verification results, and review findings.

The agent does not merge.

### G — Merge and acceptance

The Project Owner reviews and merges. The task becomes `Accepted` only when the result is on `origin/main`, local `main == origin/main`, ahead/behind is `0/0`, and the worktree is clean.

## 9. Backend Phase 2

After all approved backend Stage tasks are Accepted, run a read-only block review.

An independent reviewer with no implementation context owns the review scope and findings. The Project Owner or CI runs full backend regression and the required format/static/database/security verification. The Project Owner assigns the verdict. Fixes go through new approved contracts.

PASS requires:

- full required backend verification passes;
- P1 = 0, P2 = 0;
- no unresolved API/DB/security/ownership/assignment/lifecycle/money/concurrency/provider conflict;
- cross-task composition is coherent.

## 10. Frontend Phase 2

After backend PASS (when a backend block exists) and all frontend tasks are Accepted, run a read-only frontend block review.

An independent reviewer with no implementation context covers DTO/API/state/router/cache/stale-async/backend-authority composition. The Project Owner or CI runs full Flutter tests, static/format checks, the required target build, and Stage-specific routing/session/accessibility checks. The Project Owner assigns the verdict.

PASS requires P1 = 0, P2 = 0 and all required verification passing.

## 11. Integration Gate

Runs only after the required block checkpoints PASS.

Integration defines the real Laravel–Flutter workflow, real PostgreSQL, fixtures, exact API/error behavior, auth/session, role/scope denial, lifecycle progression, provider/sandbox boundaries, E2E commands, and Project Owner manual smoke.

Reuse fresh checkpoint evidence; do not rerun full suites merely because integration begins.

Accepted integration state must be on `origin/main`.

## 12. Severity

| Severity | Meaning |
|---|---|
| P1 | security/privacy/secret/data loss or corruption/financial integrity/core public-contract breach |
| P2 | material functional/architecture/lifecycle/integration/regression defect blocking checkpoint/closure |
| P3 | non-blocking maintainability/clarity/test-quality improvement |

## 13. Evidence Validity / Minimum Rerun

Fresh PASS evidence remains valid until a later change materially affects the proven surface.

Typical guidance:

- docs/bookkeeping-only: no product-verification invalidation;
- isolated test-only strengthening: production evidence remains valid;
- narrow production fix: preserve unrelated evidence, rerun focused affected checks;
- shared auth/router/client/middleware/error infrastructure: may invalidate a broader checkpoint;
- public API/schema/migration/authorization/financial/security change: normally invalidates the corresponding checkpoint/integration surface;
- dependency/platform/build-system change: invalidates relevant static/build evidence;
- any previously failing required command must eventually pass.

The Project Owner decides the minimum sufficient rerun, on the implementing agent's recommendation.

Do not rerun by habit; do not preserve materially invalidated evidence.

## 14. Stage Closure

Closure begins only after all approved tasks are Accepted, required backend/frontend checkpoints PASS or are justified N/A, integration PASS or justified N/A, fixes are merged, and current `origin/main` contains the complete accepted Stage result.

Closure reviews roadmap criteria, Definition of Done, locked contracts, current implementation and tests, checkpoint/integration/manual-smoke evidence, delivery bookkeeping, and final Git state.

Closure verdicts:

```text
STAGE CLOSED
FIXES REQUIRED BEFORE CLOSURE
CLOSURE BLOCKED
```

The Project Owner assigns the verdict. Next-Stage implementation may begin only after the current Stage is explicitly closed.

## 15. Git/Repository Safety

Never commit or push to `main` directly, merge your own PR, force-push or rewrite `main`, bypass checks, silently replace the remote, modify global Git config, destructively reset or clean as routine workflow, commit secrets/credentials/keys/OTP/provider data, or overwrite unrelated user work.

## 16. External Integration Gates

External provider dependencies are explicit Stage gates, not implementation freedom.

- Stage 1: approved SMS provider documentation/credentials;
- Stage 3: approved Flutter map/tile provider/package;
- Stage 7: official Payme/Paynet/xazna/Click merchant protocols plus sandbox/merchant credentials;
- Stage 10: FCM project/configuration.

A provider-dependent task stays `Blocked` until its required external contract is available. Provider-independent tasks may proceed when their own dependencies are satisfied.

Never invent a provider protocol and never fake production success.

## 17. Open Specification Decisions

Questions the locked specification does not yet answer are tracked in `docs/SPEC_DECISIONS_BACKLOG.md`.

Each is resolved with the Project Owner at its Stage planning gate, before the first task that depends on it. Reaching such a question mid-implementation is a stop-and-ask condition, not a judgement call.

## 18. Core Principle

> The implementing agent designs the solution, implements it, verifies it, and submits it for review. An independent reviewer checks the work before it is offered. The Project Owner decides product questions, merges, and closes Stages. Fewer parties must never mean less architecture quality, weaker security, weaker ownership and assignment isolation, weaker financial integrity, softer acceptance criteria, or less final Stage assurance.
