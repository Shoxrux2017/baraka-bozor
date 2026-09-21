# BarakaBozor Engineering Rules

## 1. Purpose and Scope

This file applies to the entire BarakaBozor repository.

More specific engineering rules exist in:

- `backend/AGENTS.md`
- `frontend/AGENTS.md`

The locked `docs/01–09` define approved MVP product and technical behavior. The current approved task contract defines exactly what is being built now. This file defines how to build it safely and well.

## 2. Working Model

Two parties build this project:

```text
Implementing agent = requirements analysis, task contracts, implementation,
                     focused verification, branches and PRs;
                     obtains an independent review before every PR
Project Owner      = product decisions, approval, PR review and merge,
                     real-stack execution, manual smoke, Wave closure
CI                 = checkpoint/integration verification when configured
```

The implementing agent never merges its own work. The Project Owner owns `main`.

Several implementing agents may work at once, one per track, each in its own git worktree and on its own branch. Each of them holds one approved task at a time and edits only the paths its task contract and `tasks/OWNERSHIP.md` assign to its track. Concurrency changes nothing about authority, verification, security, financial integrity or the review obligations below — it only means more than one of these agents exists.

## 3. Authority

Use this priority:

1. the current approved task contract for task-specific scope, behavior, public contracts, acceptance criteria, verification, and allowed areas;
2. root/nested `AGENTS.md` for engineering, security, quality, verification, and repository safety;
3. existing code patterns only where they do not conflict with the approved task contract.

The implementing agent must not decide these alone. They belong to the Project Owner:

- product/business behavior;
- public API semantics;
- database/schema contracts;
- Order/Item/Approval/Payment/Refund/Delivery lifecycle;
- role, ownership, assignment, or existence-privacy rules;
- money/quantity/rounding rules;
- concurrency, idempotency, or replay policy;
- cross-feature architecture;
- external-provider protocol;
- package/dependency strategy;
- unresolved UX behavior;
- any change to the locked `docs/01–09`.

If a required decision is missing or conflicting, stop and ask the Project Owner with the exact gap stated. Do not guess and do not pick a default.

## 4. Context Discipline

Reading the locked `docs/01–09` is allowed and expected. Holding the whole specification is how contradictions get caught before they reach code.

What remains forbidden:

- re-deciding a question the approved task contract already settled;
- widening scope because an adjacent problem became visible while reading;
- treating a locked document as a suggestion;
- implementing a behavior the specification describes but the current task excludes.

If reading the specification reveals a genuine conflict with the current task, stop and report it. Do not resolve it silently.

## 5. MVP Architecture Boundary

The locked baseline is:

```text
Laravel modular monolith
+ PostgreSQL
+ Flutter feature-first client
+ REST/JSON /api/v1
```

Do not introduce microservices, GraphQL, Kafka/RabbitMQ, Elasticsearch, mandatory Redis, WebSockets, event sourcing, a second state-management framework, another router, another HTTP stack, or another database unless an approved architecture change explicitly requires it.

## 6. Server Authority and Security

The backend is authoritative for:

- authenticated identity and one primary role;
- active/blocked state and first-login password gate;
- record ownership and assignment scope;
- Customer-only resources;
- Shopper current assignment scope;
- Courier current assignment scope;
- Operator/Admin capability boundaries;
- Manager read-only scope;
- Order and Order Item lifecycle;
- quantities and billable quantities;
- prices, fees, totals, rounding;
- Customer approvals;
- payment/refund state and provider reconciliation;
- cancellation;
- delivery completion.

A valid UUID does not grant access. Scope protected records before returning or mutating them. Do not leak whether an inaccessible record exists when the API contract requires scope-safe not-found behavior.

Never expose or log passwords, OTP values, bearer tokens, merchant credentials, payment secrets, private keys, raw sensitive provider payloads, or unnecessary Customer PII.

## 7. Historical and Financial Integrity

Never weaken locked invariants such as:

- historical Orders remain stable when current Catalog/pricing/settings change;
- ordered quantity is not silently increased;
- excess Shopper purchase is not billed to the Customer;
- Customer financial consent is required where the locked Approval contract requires it;
- payment/refund success is provider-authoritative;
- retries/callbacks must not create duplicate financial effects;
- no generic arbitrary Order-status mutation exists;
- critical lifecycle/history records are preserved.

Multi-write financial/lifecycle actions must be atomic when required by the task contract.

## 8. Scope and Change Control

Implement exactly the approved task.

Do not:

- add unrelated functionality;
- perform unrelated refactors or formatting churn;
- create speculative infrastructure for later waves;
- add/change packages unless explicitly required;
- change unrelated API/schema/routes/serialization;
- edit locked docs or wave bookkeeping unless explicitly required;
- manually edit generated files;
- change lockfiles without a real approved dependency change;
- edit a path owned by another track in `tasks/OWNERSHIP.md`.

Two things are permitted that read like speculative infrastructure and are not, because the wave model requires them and each needs its own approved contract:

- the current wave's schema task may create the tables that wave's features need, so that feature tasks add no migrations of their own — the current wave only, never the whole MVP;
- the module registries approved as `D-8` — per-module backend route files collected by one loop, and Flutter feature route fragments collected by one registry — so that concurrent tracks never edit the same shared file.

If an unrelated defect is found, report it separately unless it blocks the task.

## 9. Production Code Quality

Use precise names and focused responsibilities. Keep controllers/widgets thin, place logic in the layer that owns it, reuse existing abstractions only when responsibility truly matches, and avoid God classes/services/files.

Do not leave debug output, commented-out alternatives, dead code, hidden TODO acceptance criteria, broad catch-and-ignore handlers, stack traces, SQL details, or secrets.

## 10. Tests

Tests are production code. Add/update focused tests for the changed behavior, including negative/security and edge cases required by the task contract.

Do not delete, skip, weaken, or relax existing tests just to pass implementation. Keep tests deterministic: no real external networks, arbitrary sleeps, uncontrolled clocks, or hidden dependence on local environment.

## 11. Verification Model

Per-task verification is proportional and defined by the task contract:

- focused tests for changed functionality;
- required formatter/linter/static checks;
- named directly affected regression checks when justified;
- `git diff --check`;
- complete focused scope/diff self-review.

Do not independently run full backend/frontend suites, full builds, broad E2E, Phase 2, or wave closure verification unless the current task contract explicitly requires a broader check for a concrete risk.

Backend/frontend Phase 2, real-stack integration, and manual smoke are Project Owner/CI owned by default, and their unit is the wave. See `tasks/README.md`.

When a task branch takes in a merged migration or a merged shared-infrastructure change, re-run that task's focused verification before delivery. Evidence gathered before that merge does not cover the head that will be merged.

Never claim a command passed if it was not run and observed passing. Quote the observed output.

## 12. Preserve Existing Work

Before editing, inspect repository status and preserve all pre-existing user changes and untracked files. Do not overwrite, revert, stage, format, move, or delete unrelated existing work.

If safe isolation is impossible, stop and report why.

## 13. Git Safety

The implementing agent may create branches, commit, push, and open pull requests. It may not merge them.

Never:

- commit or push directly to `main`;
- merge a pull request;
- force-push or rewrite history on any branch, shared or task-owned — a branch that has fallen behind is brought up to date by merging `main` forward into it, never by rebasing a branch that has been pushed;
- use destructive `git reset --hard`/`git clean` as routine workflow;
- bypass checks with `--no-verify`;
- modify global Git configuration;
- silently replace an unexpected remote;
- commit credentials, tokens, OTPs, keys, certificates, secrets, or local-only files.

## 14. Review Before Delivery

Two reviews happen before a pull request is opened.

**Self-review of the complete diff.** Verify:

- every changed file is necessary;
- implementation exactly matches the task contract;
- non-goals remain excluded;
- responsibilities/layers are correct;
- no public API/schema/route/serialization changed unintentionally;
- ownership/assignment/security boundaries remain intact;
- lifecycle/money/quantity invariants remain intact;
- focused tests cover the actual change;
- no secret/debug/generated/temp junk exists.

**Independent review.** Because one agent both plans and implements, a reviewer that did not produce the change and holds no implementation context reviews the diff against the task contract before delivery. The producing agent never performs this review itself. Its findings are reported to the Project Owner with the work, including findings that were not acted on and why.

## 15. Completion Report

Return one implementation status:

```text
IMPLEMENTATION COMPLETE
BLOCKED
```

Report only:

- concise implementation summary;
- changed files and purpose;
- exact focused verification commands/results;
- required regression checks;
- `git diff --check` result;
- scope/non-goal confirmation;
- security/ownership evidence or justified N/A;
- independent review findings and their resolution;
- deviations/blockers;
- current Git state and the pull request for handoff.

Do not report a task `Accepted`. The Project Owner assigns acceptance only after the work is merged to `origin/main` and the repository state is synchronized and clean.
