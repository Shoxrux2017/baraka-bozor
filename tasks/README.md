# BarakaBozor Implementation Workflow — v5 Concurrent Tracks

This directory stores wave indexes, the path ownership map, approved task contracts, backend/frontend Phase 2 reviews, integration evidence, and wave closure records for the locked BarakaBozor MVP.

This workflow applies to everything after Stage 0, which is the repository/specification bootstrap and has its own closure evidence. Workflow v3 assumed a separate planner and a blind implementer. v4 replaced that with one implementing agent plus an independent reviewer. v5 keeps v4 whole and lets several such agents run concurrently, one per track, under the wave model in `docs/06-roadmap.md` Sections 1–2.

## 1. Authority and Responsibility

```text
Implementing agent = requirements analysis, task contracts, implementation,
                     focused verification, branches, commits, pull requests;
                     obtains an independent review before every PR
Project Owner      = product decisions, contract approval, PR review and merge,
                     checkpoint verification, real-stack execution,
                     manual smoke, Wave closure
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

Everything v3 said about security, ownership and assignment scope, financial integrity, lifecycle invariants, test quality, and stage gates is unchanged and still binding.

**Waves, added 2026-09-21.** Execution moved from twelve serial stages to six waves, each running several tracks concurrently. One implementing agent per track, one approved task at a time per agent, one worktree per track, disjoint file ownership. This changed the unit of planning, checkpoints and closure from the stage to the wave, and added the merge-queue and ownership rules below. It changed nothing about authority, security, ownership and assignment scope, financial integrity, test quality, severity, or what `PASS` requires. See `docs/superpowers/specs/2026-09-21-parallel-execution-model-design.md`.

## 3. Directory Structure

```text
tasks/
  README.md
  OWNERSHIP.md
  WAVE_<N>_TASK_INDEX.md
  WAVE_<N>_CLOSURE_REVIEW.md

  templates/
    TASK_TEMPLATE.md
    BLOCK_REVIEW_TEMPLATE.md
    WAVE_TASK_INDEX_TEMPLATE.md
    WAVE_CLOSURE_REVIEW_TEMPLATE.md

  backend/wave-<N>/
  frontend/wave-<N>/
  integration/wave-<N>/
```

`STAGE_01_TASK_INDEX.md` and `backend/stage-01/` remain in place as the historical record of the work that was decomposed before waves existed. `WAVE_00_TASK_INDEX.md` carries that work forward and is the authority from now on.

Areas:

| Area | Primary ownership |
|---|---|
| Backend | Laravel, PostgreSQL, server-side authorization/scope, business rules, persistence, providers, backend tests |
| Frontend | Flutter data/domain/application/presentation, routing/state/API integration/accessibility/tests |
| Integration | Laravel–Flutter real-stack workflows, provider/sandbox integration, cross-layer security/lifecycle |

## 4. Naming

```text
W<wave>-<area>-<number>-<short-description>.md
```

Examples:

```text
W0-INT-001-local-postgresql-runtime.md
W0-BE-010-module-route-registry.md
W1-FE-004-customer-catalog-browse.md
```

Area codes: `BE`, `FE`, `INT`.

A task that already has a written contract or delivered work keeps its earlier `S<stage>-...` ID. `S01-BE-001` keeps its ID, its contract path and its history; `WAVE_00_TASK_INDEX.md` records it under that name. Renaming delivered work would break the audit trail for no benefit. A task that was only a planned row with no contract may be renamed into the wave scheme — `S01-INT-001`, `S01-INT-002` and `S01-INT-003` became `W0-INT-001`, `W0-INT-002` and `W0-INT-003` that way, and the wave index records the mapping.

## 5. Wave Planning

Before implementation begins:

1. the previous wave must be explicitly closed;
2. current `origin/main` must be verified;
3. the roadmap and the relevant locked contracts are reviewed;
4. relevant implementation/tests are inspected;
5. product, API, DB, security, lifecycle, concurrency, idempotency, provider, and UX decisions needed for the wave are resolved with the Project Owner, and then **frozen for the wave** — reopening one mid-wave is a wave-level event with an explicit rework assessment, because concurrent tracks would otherwise redo each other's work;
6. wave task decomposition, track split and order are proposed, including which track owns the wave's schema task and which track owns its financial invariants;
7. Project Owner approves the decomposition, the declared track width, and the ownership map;
8. the wave index records tasks, dependencies, tracks, checkpoints, integration, risks, and acceptance mapping; `OWNERSHIP.md` records the path assignment.

**Path ownership.** `OWNERSHIP.md` gives every modifiable path exactly one owning track, and a task contract's **Allowed Areas** section must agree with it. A path absent from the map is owned by nobody and must not be modified without a Project Owner decision. Paths are repository-relative and must resolve to real locations — the Laravel application lives under `backend/` and the Flutter application under `frontend/`.

Shared-caretaker paths belong to the wave owner and change only through a dedicated task and pull request: `backend/routes/api.php`, `backend/bootstrap/app.php`, `backend/composer.json`, `backend/database/migrations/**`, `frontend/pubspec.yaml`, `frontend/lib/app/router.dart`, `frontend/lib/app/providers.dart`. Feature tracks list them under `Do not modify`. Reassignment is a wave-level event: if work turns out to need a path another track owns, stop and raise it, do not negotiate it between agents.

Detailed task contracts are prepared in execution order, not speculatively for the whole wave.

A decision must be resolved before the wave whose schema task or public contract depends on it. `docs/SPEC_DECISIONS_BACKLOG.md` records which wave owns each open question.

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
- the paths the task will touch are the ones this track owns in `OWNERSHIP.md`;
- local `main` clean;
- fetch and verify local `main == origin/main`;
- verify the expected `origin`;
- create one focused task branch, in this track's own git worktree;
- preserve unrelated user work and untracked files;
- stop if safe isolation would require force-push, history rewrite, destructive cleanup, or check bypass.

Branch naming:

```text
task/<task-id-lowercase>-<short-description>
```

Worktree layout. The primary checkout stays on `main` and clean — it is the Project Owner's review and merge surface, never a track workspace. Each track works in a sibling worktree:

```text
git worktree add ../bb-<track> -b task/<task-id-lowercase>-<short> origin/main
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

**Merge queue.** With several tracks in flight, these rules keep `main` sound and keep the Project Owner from becoming the bottleneck:

- CI is a **required** check on `main`. No merge without it.
- At most five open pull requests at once. More than that means the queue is not clearing and the wave's track width must drop, not that merging should be rushed.
- One approved contract = one branch = one small pull request.
- A branch that has fallen behind is updated by merging `main` forward into it. Never rebase a pushed branch; that needs a force-push, which root `AGENTS.md` Section 13 forbids on every branch. The track agent resolves conflicts, never the Project Owner.
- The green CI run must be on the head that will actually be merged, after any forward merge. A run from before the update is not evidence for the updated head.
- A branch that takes in a merged migration or a merged shared-infrastructure change re-runs its focused verification before merge, per Section 13.
- Merge order is first-in, first-out inside a merge window.

**What the Project Owner reads in a merge window:** the CI result, the independent review report including findings deliberately not acted on with their reasons, and the diff. The review is not re-derived from scratch.

### G — Merge and acceptance

The Project Owner reviews and merges. The task becomes `Accepted` only when the result is on `origin/main`, local `main == origin/main`, ahead/behind is `0/0`, and the worktree is clean.

## 9. Backend Phase 2

After all approved backend tasks **of the wave** are Accepted, run a read-only block review.

An independent reviewer with no implementation context owns the review scope and findings. The Project Owner or CI runs full backend regression and the required format/static/database/security verification. The Project Owner assigns the verdict. Fixes go through new approved contracts.

PASS requires:

- full required backend verification passes;
- P1 = 0, P2 = 0;
- no unresolved API/DB/security/ownership/assignment/lifecycle/money/concurrency/provider conflict;
- cross-task composition is coherent.

## 10. Frontend Phase 2

After backend PASS (when a backend block exists) and all frontend tasks **of the wave** are Accepted, run a read-only frontend block review.

An independent reviewer with no implementation context covers DTO/API/state/router/cache/stale-async/backend-authority composition, and confirms that the shared fixtures the frontend was built against are the ones the backend actually emits. The Project Owner or CI runs full Flutter tests, static/format checks, the required target build, and wave-specific routing/session/accessibility checks. The Project Owner assigns the verdict.

PASS requires P1 = 0, P2 = 0 and all required verification passing.

## 11. Integration Gate

Runs only after the required block checkpoints PASS.

Integration defines the real Laravel–Flutter workflow, real PostgreSQL, fixtures, exact API/error behavior, auth/session, role/scope denial, lifecycle progression, provider/sandbox boundaries, E2E commands, and Project Owner manual smoke.

Reuse fresh checkpoint evidence; do not rerun full suites merely because integration begins.

Accepted integration state must be on `origin/main`.

One integration gate per wave. Where a wave's providers are still fakes, the gate proves the fake boundary honestly: it must exercise provider failure and unknown-outcome paths, and it must show that no code path presents a fake provider success as a real payment.

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

## 14. Wave Closure

Closure begins only after all approved tasks of the wave are Accepted, required backend/frontend checkpoints PASS or are justified N/A, integration PASS or justified N/A, fixes are merged, and current `origin/main` contains the complete accepted wave result.

Closure reviews roadmap criteria, the Definition of Done in `docs/06-roadmap.md` Section 16, locked contracts, current implementation and tests, checkpoint/integration/manual-smoke evidence, the wave's financial-invariant handover, delivery bookkeeping, and final Git state.

Closure verdicts:

```text
WAVE CLOSED
FIXES REQUIRED BEFORE CLOSURE
CLOSURE BLOCKED
```

The Project Owner assigns the verdict. The next wave may begin only after the current wave is explicitly closed.

## 15. Git/Repository Safety

Never commit or push to `main` directly, merge your own PR, force-push or rewrite history on any branch, bypass checks, silently replace the remote, modify global Git config, destructively reset or clean as routine workflow, commit secrets/credentials/keys/OTP/provider data, or overwrite unrelated user work — including the work of another track.

## 16. External Integration Gates

External provider dependencies are explicit wave gates, not implementation freedom.

| Gate | Needed by | Requires a registered legal entity |
|---|---|---|
| Flutter SDK installed | Wave 0 frontend track | no |
| Approved Flutter map/tile provider/package | Wave 2 map-picker task | no |
| Provider selection — which SMS aggregator, which payment providers | Wave 2 adapter tasks | no |
| Firebase project/configuration | Wave 4 | no |
| Apple Developer Program and APNs key, **only if iOS is in the platform set** | Wave 4 iOS push | no |
| **Company registration** | Wave 5 | — |
| Approved SMS provider contract, alpha-name and credentials | Wave 5 | yes |
| Official Payme/Paynet/xazna/Click merchant protocols plus sandbox/merchant credentials | Wave 5 | yes |

A provider-dependent task stays `Blocked` until its required external contract is available. Provider-independent tasks may proceed when their own dependencies are satisfied.

Official **published** protocol documentation is enough to implement a thin adapter — transport, signing and response parsing only — ahead of credentials. Credentials remain mandatory for verification and for Wave 5 closure. Obligations, attempts, idempotency, reconciliation and refunds stay provider-agnostic, so a divergence between published and contractual protocol rewrites the thin layer and not the payment core.

Never invent a provider protocol and never fake production success. A fake gateway used before its real provider exists must be unmistakably a fake: it may not emit an OTP or any other secret to a client, a log or a response header in any environment, and no code path may present its success as a real payment.

## 17. Open Specification Decisions

Questions the locked specification does not yet answer are tracked in `docs/SPEC_DECISIONS_BACKLOG.md`.

Each is resolved with the Project Owner at its wave planning gate, before the first task that depends on it, and then frozen for the wave. Reaching such a question mid-implementation is a stop-and-ask condition, not a judgement call.

## 18. Core Principle

> The implementing agent designs the solution, implements it, verifies it, and submits it for review. An independent reviewer checks the work before it is offered. The Project Owner decides product questions, merges, and closes waves. Neither fewer parties nor more concurrent tracks may ever mean less architecture quality, weaker security, weaker ownership and assignment isolation, weaker financial integrity, softer acceptance criteria, or less final assurance.
