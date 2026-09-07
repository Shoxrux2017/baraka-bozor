# BarakaBozor Codex Engineering Rules

## 1. Purpose and Scope

This file applies to the entire BarakaBozor repository.

More specific engineering rules exist in:

- `backend/AGENTS.md`
- `frontend/AGENTS.md`

The locked `docs/01–09` define approved MVP product and technical behavior. A current approved implementation contract defines exactly what Codex implements now. This file defines how to implement it safely and well.

## 2. Authority

Use this priority:

1. the current approved implementation contract for task-specific scope, behavior, public contracts, acceptance criteria, verification, and allowed areas;
2. root/nested `AGENTS.md` for engineering, security, quality, verification, and repository safety;
3. existing code patterns only where they do not conflict with the approved contract.

Codex must not independently change or decide:

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
- unresolved UX behavior.

If a required decision is missing or conflicting, return `BLOCKED` with the exact gap.

## 3. Context Discipline

For an implementation task Codex reads only:

1. the current approved implementation contract;
2. this file;
3. the applicable nested `backend/AGENTS.md` and/or `frontend/AGENTS.md`;
4. directly relevant source, migrations, tests, config, and infrastructure;
5. immediately related implementation patterns needed for consistency.

Do not open `docs/01–09`, roadmap history, previous task files, closure reviews, or unrelated modules to rediscover requirements. ChatGPT must encode the resolved requirements into the implementation contract first.

## 4. MVP Architecture Boundary

The locked baseline is:

```text
Laravel modular monolith
+ PostgreSQL
+ Flutter feature-first client
+ REST/JSON /api/v1
```

Do not introduce microservices, GraphQL, Kafka/RabbitMQ, Elasticsearch, mandatory Redis, WebSockets, event sourcing, a second state-management framework, another router, another HTTP stack, or another database unless an approved architecture change explicitly requires it.

## 5. Server Authority and Security

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

## 6. Historical and Financial Integrity

Never weaken locked invariants such as:

- historical Orders remain stable when current Catalog/pricing/settings change;
- ordered quantity is not silently increased;
- excess Shopper purchase is not billed to the Customer;
- Customer financial consent is required where the locked Approval contract requires it;
- payment/refund success is provider-authoritative;
- retries/callbacks must not create duplicate financial effects;
- no generic arbitrary Order-status mutation exists;
- critical lifecycle/history records are preserved.

Multi-write financial/lifecycle actions must be atomic when required by the contract.

## 7. Scope and Change Control

Implement exactly the approved task.

Do not:

- add unrelated functionality;
- perform unrelated refactors or formatting churn;
- create speculative infrastructure for later Stages;
- add/change packages unless explicitly required;
- change unrelated API/schema/routes/serialization;
- edit locked docs or Stage bookkeeping unless explicitly required;
- manually edit generated files;
- change lockfiles without a real approved dependency change.

If an unrelated defect is found, report it separately unless it blocks the task.

## 8. Production Code Quality

Use precise names and focused responsibilities. Keep controllers/widgets thin, place logic in the layer that owns it, reuse existing abstractions only when responsibility truly matches, and avoid God classes/services/files.

Do not leave debug output, commented-out alternatives, dead code, hidden TODO acceptance criteria, broad catch-and-ignore handlers, stack traces, SQL details, or secrets.

## 9. Tests

Tests are production code. Add/update focused tests for the changed behavior, including negative/security and edge cases required by the contract.

Do not delete, skip, weaken, or relax existing tests just to pass implementation. Keep tests deterministic: no real external networks, arbitrary sleeps, uncontrolled clocks, or hidden dependence on local environment.

## 10. Verification Model

Per-task Codex verification is proportional and contract-defined:

- focused tests for changed functionality;
- required formatter/linter/static checks;
- named directly affected regression checks when justified;
- `git diff --check`;
- complete focused scope/diff self-review.

Do not independently run full backend/frontend suites, full builds, broad E2E, Phase 2, or Stage closure verification unless the current contract explicitly requires a broader check for a concrete risk.

Backend/frontend Phase 2, real-stack integration, and manual smoke are Project Owner/CI owned by default. See `tasks/README.md`.

Never claim a command passed if it was not run and observed passing.

## 11. Preserve Existing Work

Before editing, inspect repository status and preserve all pre-existing user changes and untracked files. Do not overwrite, revert, stage, format, move, or delete unrelated existing work.

If safe isolation is impossible, return `BLOCKED`.

## 12. Git Safety

Never:

- force-push or rewrite shared history;
- use destructive `git reset --hard`/`git clean` as routine workflow;
- bypass checks with `--no-verify`;
- modify global Git configuration;
- silently replace an unexpected remote;
- commit credentials, tokens, OTPs, keys, certificates, secrets, or local-only files.

Routine task delivery is owned by the Project Owner unless the current implementation contract explicitly assigns delivery to Codex.

## 13. Final Diff Review

Before reporting implementation complete, verify:

- every changed file is necessary;
- implementation exactly matches the contract;
- non-goals remain excluded;
- responsibilities/layers are correct;
- no public API/schema/route/serialization changed unintentionally;
- ownership/assignment/security boundaries remain intact;
- lifecycle/money/quantity invariants remain intact;
- focused tests cover the actual change;
- no secret/debug/generated/temp junk exists.

## 14. Completion Report

Return one implementation status:

```text
IMPLEMENTATION COMPLETE
BLOCKED
```

Use `DELIVERY BLOCKED` only when the active contract explicitly assigns delivery to Codex and delivery cannot complete safely.

Report only:

- concise implementation summary;
- changed files and purpose;
- exact focused verification commands/results;
- required regression checks;
- `git diff --check` result;
- scope/non-goal confirmation;
- security/ownership evidence or justified N/A;
- deviations/blockers;
- current Git state for handoff.

Do not report task `Accepted`; ChatGPT assigns acceptance only after approved delivery is present on `origin/main` and repository state is synchronized and clean.
