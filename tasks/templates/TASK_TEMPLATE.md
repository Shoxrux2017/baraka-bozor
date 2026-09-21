# [Task ID] — [Short Title]

## Metadata

| Field | Value |
|---|---|
| Task ID | `[W0-AREA-000]` |
| Wave | `[number and exact name]` |
| Area | `[Backend / Frontend / Integration]` |
| Status | `Draft` |
| Depends on | `[Task IDs or None]` |
| Blocks | `[Task IDs or None]` |
| Branch | `task/[task-id-lowercase]-[short-description]` |

Start only when Status is `Approved` and Git preflight from `tasks/README.md` is safe.

## Goal

[One observable outcome, one or two sentences. What is true when this is done that is not true now.]

## Scope

**In:**

- [required change]

**Out:**

- [adjacent behavior explicitly excluded, and which task owns it]

## Governing Specification

Cite, do not copy. The locked documents are authoritative; this table says which parts apply.

| Source | Section | What it governs here |
|---|---|---|
| `docs/09-api-contracts.md` | `[§N]` | `[endpoint/envelope/error codes]` |
| `docs/08-database.md` | `[§N]` | `[tables/constraints]` |
| `docs/05-business-rules.md` | `[BR-XXX-000]` | `[rule]` |

## Decisions

Only what the specification does not already answer, or what it answers ambiguously. Each line is a decision the Project Owner approved for this task.

| # | Decision | Why |
|---|---|---|
| 1 | `[decision]` | `[reason]` |

If a needed decision is missing, the task is not `Approved`.

## Implementation Notes

Only the non-obvious. Skip anything a competent implementer reading the cited sections would do anyway.

- [trap, ordering constraint, framework behavior that surprises, file that must be preserved]

Use `N/A` when there is nothing non-obvious.

## Acceptance Criteria

- [ ] [Primary behavior, stated so it can be checked.]
- [ ] [API/UI contract matches the cited sections.]
- [ ] [Persistence/lifecycle/history behavior matches.]
- [ ] [Validation and error codes match.]
- [ ] [Authorized positive case passes.]
- [ ] [Wrong-role/foreign-ID negative case passes, or justified N/A.]
- [ ] [Money/quantity/financial invariant holds, or justified N/A.]
- [ ] [Concurrency/idempotency/replay/stale-async case passes, or justified N/A.]
- [ ] Focused tests and required checks pass.
- [ ] `git diff --check` passes.
- [ ] No unrelated public behavior changed.
- [ ] Independent review completed; P1 and P2 findings resolved.

## Verification

**Focused tests**

```text
[exact command]
```

Required cases: positive; validation/error; authorization/scope if applicable; lifecycle/money/concurrency/async/provider edge if applicable.

**Format / static**

```text
[exact command]
```

**Directly affected regression**

```text
[exact command]
```

or `None required — [specific reason]`.

**Project Owner manual check**

`[exact steps / Not required — reason]`

**Always**

```text
git diff --check
git status --short
```

## Allowed Areas

**Mandatory.** This section may not be left blank or generic. With several tracks running concurrently it is what keeps two agents out of the same file, and it must agree with this track's row in `tasks/OWNERSHIP.md`.

Track: `[track name exactly as it appears in tasks/OWNERSHIP.md]`

| Path or area | Action | Reason |
|---|---|---|
| `[path]` | `[Inspect/Modify/Create/Test]` | `[reason]` |

Changes outside these areas need a concrete necessity within scope and must be reported. A path owned by another track is never one of them — if the task genuinely needs it, stop and raise it with the Project Owner.

Do not modify: `[paths]`.

Shared-caretaker paths — `routes/api.php`, `bootstrap/app.php`, `composer.json`, `pubspec.yaml`, `database/migrations/**`, the root router and the root providers — belong to the wave owner and change only through a dedicated task. Unless this **is** that task, list them under `Do not modify`.

## Delivery

PR title: `[Task ID] — [Short Title]`, target `main`.

The implementing agent commits, pushes, and opens the PR. The Project Owner merges. The task becomes `Accepted` only after the merge, with local `main == origin/main`, `0/0`, and a clean worktree.

## Independent Review

Filled in before the PR is opened.

| ID | Severity | Finding | Resolution |
|---|---|---|---|
| `[R-01]` | `[P1/P2/P3]` | `[finding]` | `[fixed / not acted on + reason]` |
