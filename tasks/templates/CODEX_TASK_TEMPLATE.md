# Codex Implementation Contract: [Task ID — Short Title]

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `[S00-AREA-000]` |
| Stage | `[Stage number and exact name]` |
| Area | `[Backend / Frontend / Integration]` |
| Status | `Draft` |
| Depends on | `[Task IDs or None]` |
| Verification | `Codex — focused task verification only` |
| Delivery execution | `Project Owner` |

Start only when status is `Approved`, dependencies are `Accepted / Delivered`, and Git preflight from `tasks/README.md` is safe.

This is the complete task-specific contract. Do not create a duplicate `CODEX-PROMPT` file.

## 2. Goal

[One observable outcome.]

## 3. Scope

### Included

- [Required change]

### Non-Goals

- [Explicit adjacent behavior excluded]

## 4. Current Implementation Context

Only facts Codex needs to find the correct code quickly:

- [Existing route/action/repository/provider/widget/test]
- [Current behavior that must remain unchanged]

Inspect only directly relevant implementation/tests. Do not open locked product specs, roadmap, previous tasks, or Stage history to discover requirements.

## 5. Exact Implementation Contract

Use `N/A — [reason]` when a subsection is not applicable.

### 5.1 Behavior and Lifecycle

- [Success behavior]
- [State transition / no-op / history]
- [Forbidden behavior]
- [Edge case]

### 5.2 API or UI

**API**

- Method/path: `[METHOD /api/v1/...]`
- Input: `[query/body/headers]`
- Success: `[status + envelope/resource]`
- List/filter/sort/pagination: `[rules or N/A]`

**UI**

- Route/screen/dialog: `[location or N/A]`
- States: `[loading/empty/data/error/mutation/reconciliation]`
- Actions/feedback: `[exact behavior]`
- Navigation/focus/accessibility/responsiveness: `[rules or N/A]`
- Cache/invalidation/retained state: `[rules or N/A]`

### 5.3 Persistence and Application State

- Schema/migration: `[exact change or N/A]`
- Read/query: `[scope/order/eager loading/limits]`
- Write/transaction: `[atomic rows/fields]`
- No-op/history: `[rules or N/A]`
- Frontend state/cache: `[rules or N/A]`

### 5.4 Authorization and Record Scope

- Actor/active-state requirements: `[roles/checks]`
- Ownership/current-assignment rule: `[exact rule]`
- Wrong role/unauthenticated result: `[exact status/code]`
- Foreign/direct ID result: `[scope-safe status/code]`
- Client identifiers that must not expand scope: `[fields/IDs]`
- Sensitive fields/PII boundary: `[rule or N/A]`

### 5.5 Validation and Errors

| Case | Required result |
|---|---|
| `[Malformed/unknown/protected input]` | `[status/code/errors]` |
| `[Scope-safe not found]` | `[status/code]` |
| `[Lifecycle/business conflict]` | `[status/code]` |
| `[Provider/unknown outcome]` | `[status/code/state]` |
| `[Unexpected failure]` | `[safe behavior]` |

Normalization/strict-input rules:

- [phone/UUID/decimal-string/money/timestamp/enum/content-type/body/query rules]

### 5.6 Money, Quantity, History

- Money/rounding: `[rule or N/A]`
- Ordered/purchased/billable quantity: `[rule or N/A]`
- Historical snapshot stability: `[rule or N/A]`
- Financial authority/reconciliation: `[rule or N/A]`

### 5.7 Concurrency, Idempotency, Replay, Async Ownership

- Transaction/lock/constraint: `[rule or N/A]`
- `Idempotency-Key` / natural idempotency: `[rule or N/A]`
- Provider callback/event replay: `[rule or N/A]`
- Concurrent conflict response: `[rule or N/A]`
- Frontend stale-completion/session-target safety: `[rule or N/A]`

### 5.8 Architecture and Placement

- Owning feature/layer: `[exact boundary]`
- Existing abstraction to reuse: `[name/path or None]`
- New abstraction allowed: `[exact boundary or None]`
- Logic forbidden in controller/widget/resource/model: `[restriction]`
- Shared infrastructure that must remain unchanged: `[boundary]`

## 6. Expected Files and Areas

| Path or area | Action | Reason |
|---|---|---|
| `[path]` | `[Inspect/Modify/Create/Test]` | `[Reason]` |

Changes outside these areas require concrete necessity within scope and must be reported.

## 7. Acceptance Criteria

- [ ] Primary behavior matches contract.
- [ ] API/UI contract matches exactly.
- [ ] Persistence/lifecycle/history behavior matches.
- [ ] Validation/error behavior matches.
- [ ] Authorized positive case passes.
- [ ] Wrong-role/foreign-ID negative case passes or justified N/A.
- [ ] Money/quantity/financial invariant passes or justified N/A.
- [ ] Concurrency/idempotency/replay/stale-async case passes or justified N/A.
- [ ] Architecture/placement requirement satisfied.
- [ ] Focused tests/checks pass.
- [ ] `git diff --check` passes.
- [ ] No unrelated public behavior changed.

## 8. Focused Tests and Verification

### Focused Tests

```text
[Exact command]
```

Required cases:

- positive;
- validation/error;
- authorization/scope if applicable;
- lifecycle/money/concurrency/async/provider edge if applicable.

### Format / Static

```text
[Exact command]
```

### Directly Affected Regression

```text
[Exact command]
```

or `None required — [specific reason]`.

### Project Owner Manual Check

`[Exact steps / Not required — reason]`

### Always

```text
git diff --check
```

Then inspect complete diff for only necessary files, no unrelated churn, no weakened tests, no secret/debug/temp/generated junk, no accidental API/schema/route change, and preserved security/ownership/financial boundaries.

Do not independently expand into full suites/builds/E2E/Phase 2/closure. Report a contract/verification mismatch instead.

## 9. Delivery

Default owner: `Project Owner`.

- Branch: `[rule/name]`
- Commit: `[convention]`
- PR: `[requirement]`
- Allowed bookkeeping files: `[paths or None]`

When Project Owner owns delivery, Codex stops after implementation + focused verification + diff self-check and reports Git state for handoff.

Task becomes Accepted only after accepted result is on `origin/main`, local `main == origin/main`, `0/0`, clean worktree.

## 10. Planning Provenance

For ChatGPT/reviewer traceability only; Codex must not reopen these sources.

| Source/reference | Decision encoded above |
|---|---|
| `[spec/Stage index]` | `[resolved decision]` |

## 11. Codex Final Report

Return one status:

```text
IMPLEMENTATION COMPLETE
BLOCKED
```

Use `DELIVERY BLOCKED` only when contract explicitly assigned delivery to Codex.

Report concise implementation, changed files, acceptance evidence, exact focused commands/results, security/scope evidence, `git diff --check`, non-goal confirmation, delivery handoff, deviations/blockers. Do not mark task `Accepted`.
