# BarakaBozor Engineering Rules

## 1. Purpose and Scope

This file applies to the entire BarakaBozor repository. Backend and frontend specifics are in `backend/AGENTS.md` and `frontend/AGENTS.md`.

`docs/01–09` describe the product and the technical design as they currently are. `docs/DECISIONS.md` records why they are that way. `docs/INTERVIEW_2026-09-24.md` records the Project Owner's product decisions. `tasks/` holds the wave plans.

## 2. Working Model

Two parties, since 2026-09-24 (`DL-1`):

```text
Implementing agent = plans, implements, tests, obtains an independent review,
                     merges on a green CI run, runs the real stack, keeps
                     docs/ and tasks/ current, reports once per wave
Project Owner      = product and business decisions; a manual check of the
                     product once per wave, from the agent's checklist
CI                 = tests, Pint, PHPStan on PostgreSQL on every pull request
```

One implementing agent at a time. It works on one task branch at a time from the primary checkout; no ownership map and no per-track worktrees are needed.

## 3. Authority

1. `docs/INTERVIEW_2026-09-24.md` and `docs/DECISIONS.md` for what was decided and why;
2. `docs/01–09` for the current product and technical design;
3. this file and the nested `AGENTS.md` for engineering, security and repository safety;
4. existing code patterns where they do not conflict with the above.

**What the Project Owner decides:** product and business behaviour that neither the documents nor the interview covers, money the company charges or forgoes, and anything that changes what a Customer, Shopper or Courier is promised. When such a question arises, stop that task, research how real products handle it, and put it to the Owner with a recommended answer in the format the Owner asked for; continue with work that does not depend on the answer.

**What the implementing agent decides:** everything else, including schema shapes, API details, error codes, concurrency and idempotency mechanics, libraries, structure, tests, deployment and process. Each such decision is recorded in `docs/DECISIONS.md` with its reason before or with the code that implements it, and the affected document in `docs/01–09` is updated in the same pull request. A decision that turns out wrong is superseded by a later entry, never edited away.

Read `docs/01–09` whole before planning a wave. Contradictions between documents are resolved by the agent and recorded; contradictions with the Owner's interview are resolved in the interview's favour.

## 4. Architecture Boundary

```text
Laravel modular monolith + PostgreSQL
Flutter feature-first client: Android, iOS, web panel
REST/JSON under /api/v1
```

Do not introduce microservices, GraphQL, message brokers, Elasticsearch, mandatory Redis, WebSockets, event sourcing, a second state-management framework, another router, another HTTP stack, or another database. If one of these ever seems necessary, record the reasoning in `docs/DECISIONS.md` first.

## 5. Server Authority and Security

The backend is authoritative for identity and role, active or blocked state and the first-login password gate, record ownership and assignment scope, Customer-only resources, Shopper and Courier current-assignment scope, Operator and Admin capability boundaries, Manager read-only scope, the Order and Item lifecycle, quantities and billable quantities, prices, markup, fees, totals and rounding, Customer approvals, payment and refund state and provider reconciliation, cancellation, and delivery completion.

A valid UUID never grants access. Scope every protected record to the actor before returning or mutating it. Where the API contract requires scope-safe not-found behaviour, do not reveal whether an inaccessible record exists.

Never expose or log passwords, login codes, bearer tokens, merchant credentials, payment secrets, private keys, raw provider payloads, or Customer PII beyond what a screen needs. A login code is never emitted to a client, a log or a header in any environment. The configured test phone numbers use a fixed code that is never generated or delivered (`DL-2`, topic 7); that is not an emission, and the list is empty in production.

## 6. Financial and Historical Integrity

Never weaken:

- historical orders stay stable when the catalog, markup, fees or settings change;
- the ordered quantity never silently increases; excess purchase is never billed;
- a price above the tolerance, a substitution, or a reduced quantity requires the Customer's decision as the documents define it, and an expired approval is never consent;
- payment success is provider-authoritative for online payments; a cash payment is recorded only by the Courier's explicit action at handover;
- a refund is recorded as completed only by an Admin with the provider's reference, and completed refunds never exceed the amount paid;
- retries and callbacks never create duplicate financial or lifecycle effects;
- no generic arbitrary order-status mutation exists;
- lifecycle, assignment, approval, payment and refund history is preserved.

Multi-write financial and lifecycle actions run in one database transaction with the row locks `backend/AGENTS.md` describes.

## 7. Scope and Change Control

Implement the task at hand. Adjacent improvements that the task makes obviously necessary are fine; unrelated refactors, formatting churn, speculative infrastructure and dependency changes are not. A dependency is added only when the task needs it, with the reason in the commit message.

Generated files are never hand-edited. Lockfiles change only with a real dependency change.

If work reveals a defect outside the task, fix it in the same pull request when it is small and clearly related; otherwise record it in the wave file's risk list.

## 8. Production Code Quality

Precise names, focused responsibilities, thin controllers and widgets, logic in the layer that owns it. No debug output, commented-out alternatives, dead code, TODO placeholders standing in for acceptance criteria, broad catch-and-ignore handlers, stack traces, SQL details or secrets in production code.

## 9. Tests

Tests are production code. Every behaviour change carries focused tests, including the negative and security cases the design implies. Tests are deterministic: no real external networks, no arbitrary sleeps, no uncontrolled clocks, no hidden dependence on the local environment. Backend tests run against the real PostgreSQL test database; provider adapters are tested against fakes.

Never delete, skip or weaken a test to make an implementation pass.

## 10. Verification

Per task, before the pull request:

- focused tests for the changed behaviour;
- `pint --test`, `phpstan analyse`, `flutter analyze`, `dart format --set-exit-if-changed` as applicable;
- `git diff --check`;
- a self-review of the complete diff against Sections 5 to 9.

CI runs the full backend suite on every pull request and is required for merge. Before a wave closes, the agent also runs the full frontend suite, builds the required targets, brings up the real stack, and walks the end-to-end scenario of that wave.

Never claim a command passed unless it was run and observed passing.

## 11. Preserve Existing Work

Inspect repository status before editing. Preserve pre-existing changes and untracked files. Do not overwrite, revert, stage, format, move or delete unrelated work. Containers, volumes and directories that belong to other projects on the development machine are never touched.

## 12. Git

The agent creates branches, commits, pushes, opens pull requests and merges them once CI is green and the independent review is resolved. It never commits or pushes directly to `main`, never force-pushes any branch or rewrites pushed history, never bypasses checks, never edits global Git configuration, never replaces a remote silently, and never commits credentials, tokens, login codes, keys, certificates or local-only files. A branch that has fallen behind is updated by merging `main` into it.

Branch names: `task/<wave>-<short-description>` for code, `docs/<short-description>` for documentation.

## 13. Review Before Merge

Two reviews per pull request:

1. **Self-review of the complete diff:** every changed file necessary; the design in `docs/01–09` honoured; Sections 5 and 6 intact; tests cover the change; no secret, debug or temporary artefact.
2. **Independent review** by a subagent that did not write the change and holds no implementation context, against the task's goal and this file. P1 and P2 findings are fixed before merge. Findings not acted on are recorded in the wave file with the reason.

Severity: **P1** security, privacy, data loss, financial integrity or public-contract breach; **P2** material functional or architectural defect; **P3** non-blocking improvement.

## 14. Reporting to the Project Owner

One short report at the end of each wave: what now works, what changed in behaviour, the checklist for the Owner's manual check in the app, known gaps, and what the next wave builds. Between reports the Owner is contacted only for a product question under Section 3 or for an external action only the Owner can take (accounts, keys, contracts, hosting).
