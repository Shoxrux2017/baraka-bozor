# Wave [Number] Task Index — [Wave Name]

## 1. Wave Metadata

| Field | Value |
|---|---|
| Roadmap wave | `[Wave exact name]` |
| Wave status | `Draft` |
| Verification model | `Workflow v5 — Concurrent Tracks` |
| Declared track width | `[max concurrent tracks]` |
| Ownership map approved | `No` |
| Decomposition approved on | `[YYYY-MM-DD / Not approved]` |
| Implementation started | `No` |
| Backend checkpoint | `Not started` |
| Frontend checkpoint | `Not started` |
| Integration gate | `Not started` |
| Wave closed | `No` |

Valid Wave statuses: `Draft`, `Approved`, `In Progress`, `Blocked`, `Closed`.

## 2. Goal and Boundary

### Goal

[Approved roadmap outcome.]

### Included

- [Wave capability]

### Excluded

- [Adjacent future Wave/Post-MVP/non-goal]

## 3. Authoritative Planning Inputs

| Source | Section/reference | Why it governs |
|---|---|---|
| `docs/06-roadmap.md` | `[Wave]` | scope/DoD |
| relevant `docs/0X` | `[section]` | business/role/flow |
| `docs/07-architecture.md` | `[section]` | architecture |
| `docs/08-database.md` | `[section]` | persistence |
| `docs/09-api-contracts.md` | `[section]` | API |
| `AGENTS.md` + nested | `[rule]` | engineering/safety |
| current `origin/main` | `[SHA]` | implementation baseline |
| previous closure | `[reference]` | dependency |

## 4. Entry Gate

- [ ] Previous Wave explicitly closed.
- [ ] Current origin/main verified and local main synchronized/clean.
- [ ] Relevant locked contracts reviewed.
- [ ] Relevant implementation/tests inspected.
- [ ] External provider/dependency gates identified.
- [ ] Wave decomposition/order approved.
- [ ] Backend/frontend/integration boundaries explicit.
- [ ] Every roadmap criterion mapped.
- [ ] No unresolved product/API/DB/security/ownership/lifecycle/money/concurrency/idempotency/UX decision blocks first task.

## 5. Approved Task Order

| Order | Task ID | Area | Track | Short outcome | Depends on | Status | Contract file |
|---:|---|---|---|---|---|---|---|
| 1 | `[W0-BE-001]` | Backend | `[track]` | `[outcome]` | None | Draft | Not created |

Detailed contracts are prepared/hardened in execution order. `Order` is the dependency order, not a queue: tasks with no dependency between them and no shared owned path may run concurrently, up to the declared track width. The `Track` column must match `tasks/OWNERSHIP.md`.

The wave's financial-invariant owner is: `[track]`. The wave's schema and shared-caretaker owner is: `[track]`.

## 6. Implementation Readiness

| Task ID | Scope/non-goals | Behavior/API/UI | Persistence/lifecycle | Auth/scope/security | Money/concurrency/edge | Tests/verification | Ready |
|---|---|---|---|---|---|---|---|
| `[Task]` | No | No | No | No | No | No | No |

## 7. Dependency / Checkpoint Map

| Dependency/checkpoint | Required before | Evidence |
|---|---|---|
| Backend task block complete | Backend Phase 2 | `[accepted tasks]` |
| Backend PASS | Frontend block | `[review]` |
| Frontend task block complete | Frontend Phase 2 | `[accepted tasks]` |
| Frontend PASS | Integration | `[review]` |
| Integration PASS | Closure | `[evidence]` |

## 8. Verification Map

| Task ID | Focused tests | Static/format | Direct regression | Manual check | diff check |
|---|---|---|---|---|---|
| `[Task]` | `[command]` | `[command]` | `[command/None]` | `[steps/N/A]` | Required |

## 9. External Gates / Risks

| Gate/risk | Affected task | Required input | Status |
|---|---|---|---|
| `[SMS/payment/map/FCM/etc.]` | `[Task]` | `[docs/credentials/decision]` | Open |

## 10. Roadmap Acceptance Matrix

| Criterion | Implementing task(s) | Verification gate | Evidence | Status |
|---|---|---|---|---|
| `[criterion]` | `[IDs]` | `[task/checkpoint/integration]` | `[reference]` | Not started |

## 11. Change Log

| Date | Change | Reason | Approved by |
|---|---|---|---|
| `[date]` | `[change]` | `[reason]` | `[owner]` |
