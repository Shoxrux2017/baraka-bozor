# BarakaBozor — Parallel Execution Model

## Document Status

| Field | Value |
|---|---|
| Status | `PROPOSED — awaiting Project Owner approval` |
| Date | `2026-09-21` |
| Produced by | implementing agent, design session |
| Amends | `docs/06-roadmap.md` §1–§2, `AGENTS.md` §8/§11, `tasks/README.md` §5/§9–§11 |
| Leaves untouched | `docs/01`, `02`, `03`, `04`, `05`, `08`, `09`; `AGENTS.md` §6/§7; all product, security and financial rules |

Every decision in §3 was made by the Project Owner during the 2026-09-21 design session. This document records them and derives the execution model from them. It decides no product question.

## 1. Problem

The approved plan runs 12 stages strictly in series, and vertically inside each stage:
`backend → backend checkpoint → Flutter → frontend checkpoint → integration → closure`
(`docs/06-roadmap.md` §1). Later stages do not begin until the current stage closes.

Repository state measured on 2026-09-21:

- `S01-BE-001` merged (PR #2, `5ac4d9e`); it is 1 of ~14 Stage 1 tasks
- `frontend/` contains only `AGENTS.md`; `docker/` contains only `README.md`
- no `.github/workflows`
- no local PostgreSQL client and no Flutter SDK on the development machine
- 17 open entries in `docs/SPEC_DECISIONS_BACKLOG.md`. `S-1`–`S-5` and `S-16` block 6 of the 10 remaining Stage 1 backend and frontend tasks — `S01-BE-002`, `S01-BE-003`, `S01-BE-004`, `S01-FE-001`, `S01-FE-003`, `S01-FE-004`. `S-17` is open without a named blocker; `S01-BE-006` is blocked by the external SMS gate rather than by a decision.

Four serializers, ordered by cost:

1. **Undecided specification questions, not code dependencies.** The parallelism the current index already permits is blocked by decisions, not by coupling.
2. **The vertical principle.** Frontend waits for backend inside every stage, although `docs/09-api-contracts.md` fixes the API contract for the entire MVP and `docs/08-database.md` fixes the schema. The specification is not the bottleneck; the plan's refusal to use it is.
3. **CI arrives third.** Parallel branches cannot merge safely before required automated checks exist.
4. **The Project Owner is the only serialized human.** Contract approval, PR review, merge, real-stack execution, manual smoke and stage closure all pass through one person. Parallel tracks without owner-load reduction relocate the queue instead of removing it.

## 2. Goal and Non-Goals

**Goal.** Reduce the critical path from 12 serial stages to 6 serial waves, each internally 2–5 tracks wide, and remove external-provider procurement from the critical path — without weakening security, ownership and assignment isolation, financial integrity, test quality or acceptance rigour.

**Non-goals.**

- No change to product or business behavior.
- No change to public API semantics, database contracts, or lifecycle rules.
- No change to `AGENTS.md` §6 (server authority and security) or §7 (historical and financial integrity).
- No change to the post-MVP boundary (`docs/06-roadmap.md` §18).
- No change to the Definition of Done substance (`docs/06-roadmap.md` §16); only its unit changes from stage to wave.
- No microservices, no second state framework, no new database — the architecture baseline in `AGENTS.md` §5 stands.

## 3. Project Owner Decisions — 2026-09-21

| ID | Decision |
|---|---|
| `D-1` | Owner capacity is several hours per day. Parallel width is therefore capped at 3–5 tracks, with two merge windows per day. |
| `D-2` | The implementing agent may restructure process, task order and stage boundaries. Product behavior, security and financial integrity are out of scope. |
| `D-3` | Execution model is contract-first waves with parallel vertical feature tracks. Maximum front-loading of all schema and all route skeletons was considered and rejected. |
| `D-4` | `W0` closes with a fake `SmsGateway`. Real SMS verification moves to `W5` as an explicit recorded debt, not a forgotten tail. |
| `D-5` | Provider adapters are implemented from official published protocol documentation before credentials exist. Adapters stay thin; all money logic remains provider-agnostic. Inventing a protocol and faking provider success remain forbidden. |
| `D-6` | "Demonstrable MVP on fake providers" is an explicit milestone, defined in §10, reached at the end of `W4`. |
| `D-7` | Tracks run as separate Claude Code sessions, one per git worktree. Each session is an independent implementing agent under `AGENTS.md`. |

A consequence of `D-2` that the Project Owner should see stated once: **no legal entity exists yet.** Company registration blocks the SMS contract and all merchant agreements, therefore it blocks MVP production launch. It does not block development, and under `D-6` it does not block a demonstrable system.

## 4. Wave Graph

| Wave | Content | Width | Blocked by company |
|---|---|---:|---|
| `W0` Foundation | PostgreSQL/Docker runtime, CI as a required check, module registries, identity schema, six-role auth core, Customer OTP behind a fake `SmsGateway`, Flutter scaffold and auth UX, role shells | 3 | no |
| `W1` Catalog and Account | Catalog backend and both Catalog UIs, Customer profile and addresses, Staff management and settings, notification infrastructure with a fake sender | 4–5 | no |
| `W2` Cart to Order to Money | Cart and map picker, business fees and checkout, Order core with idempotency and historical snapshots, payment adapters from published protocols, assignment abstraction | 3 | no |
| `W3` Fulfilment and Exceptions | Shopper market purchase, availability/substitution/Approval, Courier delivery, operational Order board | 3–4 | no |
| `W4` Demonstrable MVP | Notification events, history, Reorder, Manager analytics, **real FCM**, full end-to-end scenarios on fake providers | 3 | no |
| `W5` Providers and Launch | Real SMS with contract and alpha-name, merchant integrations and sandbox verification, pilot readiness | 2 | **yes** |

"Width" is the maximum number of tracks running concurrently inside the wave, and therefore the number of concurrent sessions and worktrees. It is bounded by `D-1`, not by the number of separable tasks.

Source stages: `W0` ← 1. `W1` ← 2, part of 3, part of 9, part of 10. `W2` ← rest of 3, 4, part of 7. `W3` ← 5, 6, 8, part of 9. `W4` ← rest of 10, 11, the fake-provider part of 12. `W5` ← rest of 7, the provider-sandbox and pilot part of 12.

**Real FCM belongs to `W4`, not `W5`.** A Firebase project requires only a Google account, so push can reach a real integration without a company. Only the SMS contract and merchant agreements require a legal entity, which keeps the company-blocked tail small.

Six decisions make this graph possible:

1. **Schema is one task per wave with one owner.** Feature tasks add no migrations. Migrations are the only genuinely shared serial resource, and this removes the largest collision source. Per wave, not the whole MVP at once — that distinction is what keeps this inside the spirit of `AGENTS.md` §8.
2. **Module registries are written once in `W0`.** `routes/api/v1/<module>.php` collected by a single loop; Flutter route fragments collected by a single registry. Feature tracks then never edit `routes/api.php`, `bootstrap/app.php`, the root GoRouter or the root Riverpod providers. This removes the second largest collision source.
3. **Frontend runs against the locked contract, not against backend code** (§7).
4. **Dependency-free slices of stages 9 and 10 move into `W1`**: Staff management, settings, FCM device registration. They need only auth. The operational board and lifecycle event emission stay where their dependencies are real.
5. **Payment adapters are built in `W2` on fakes; real credentials are wired in `W5`.**
6. **Decisions and procurement are a non-code track.** A wave's decision package is resolved at its entry gate and then **frozen for the wave**. Changing a decision mid-wave makes parallel tracks redo each other's work, which is the fastest way to lose the entire benefit of parallelism.

## 5. What Stays Serial, Deliberately

**Cart → Order core → Shopper purchase → Approval is a genuine data and lifecycle chain.** No restructuring removes it. It is the real critical path of the product, and it is why the honest expectation is roughly 2–2.5x on code throughput rather than a multiple of the track count.

**Financial invariants stay in one track with one owner**: Approval, billable quantity, price snapshots, payment obligations, refunds. Splitting these across concurrent agents is how money defects are introduced. `AGENTS.md` §7 leaves no room to trade this for speed, and this design does not try.

## 6. Parallel Mechanics

### 6.1 One worktree per track

```text
git worktree add ../bb-<track> -b task/<task-id-lowercase>-<short> origin/main
```

The primary checkout `baraka-bozor` stays on `main` and clean. It is the Project Owner's review and merge surface, never a track workspace.

### 6.2 Ownership map

A new `tasks/OWNERSHIP.md` records, per wave, which paths each track owns. The `TASK_TEMPLATE.md` "allowed files/areas" field becomes mandatory and must agree with that map. Two tracks never own the same path.

Shared-caretaker paths — `routes/api.php`, `bootstrap/app.php`, `composer.json`, `pubspec.yaml`, `database/migrations/**`, root router and root providers — are edited only by the wave owner, in a dedicated task and PR. Feature tracks do not touch them.

### 6.3 Merge queue

- CI is a **required** check on `main` before the first parallel wave.
- At most 5 open pull requests at a time; exceeding it means the owner is the bottleneck and width must drop.
- One approved contract = one branch = one small pull request.
- Rebase onto current `main` before merge; on conflict the agent rebases, never the owner.
- Merge order is first-in, first-out within a merge window.
- No merge without a green CI run and an independent review report.

### 6.4 Independent review

`AGENTS.md` §14 already requires a reviewer with no implementation context before every pull request. Under this model that step is also the mechanism that keeps owner load low: the owner reads the CI result, the review report — including findings deliberately not acted on, with reasons — and the diff, rather than re-deriving the review. Findings at P1 or P2 are fixed before the pull request opens.

## 7. Contract-First Frontend

Frontend tracks build against `docs/09-api-contracts.md`, using a typed DTO layer and fake repositories, in parallel with the backend track that implements the same contract. Real wiring happens at the wave integration gate.

**The guard against silent divergence is a shared fixture directory.** The response and error examples from `docs/09` live in one place. Backend feature tests assert that the API emits them; frontend tests assert that the client parses them. A divergence turns into a red CI run, not a surprise at integration. Without this guard the contract-first approach is not safe and must not be used.

## 8. Quality Gates

Per-task verification is unchanged (`AGENTS.md` §11, `tasks/README.md` §8C): focused tests, required formatter/linter/static checks, named regression checks when justified, `git diff --check`, full scope and diff self-review.

What changes is the unit of the block checkpoint. Instead of one backend and one frontend Phase 2 per stage, each **wave** ends with:

1. a backend block review and a frontend block review, each by a fresh reviewer with no implementation context;
2. full required backend and frontend verification, run by CI or the Project Owner;
3. one wave integration gate on the real Laravel/PostgreSQL/Flutter stack;
4. Project Owner manual smoke and the wave verdict.

`PASS` still requires P1 = 0 and P2 = 0 and all required verification passing. Severity definitions and the evidence-validity rules in `tasks/README.md` §12–§13 are unchanged.

## 9. External Gates

| Gate | Owner | Needed by | Requires legal entity |
|---|---|---|---|
| Specification decisions per wave | Project Owner | wave entry | no |
| Flutter SDK installed | Project Owner | `W0` frontend track | no |
| Provider selection — which SMS aggregator, which payment providers | Project Owner | `W2` adapter tasks | no |
| Firebase project and app registration | Project Owner | `W4` | no |
| **Company registration** | Project Owner | `W5` | — |
| SMS contract and alpha-name | Project Owner | `W5` | yes |
| Merchant agreements, sandbox credentials, contractual protocols | Project Owner | `W5` | yes |

A provider-dependent task stays `Blocked` until its external contract is available (`tasks/README.md` §16). Under `D-5` the thin adapter may be written earlier from official published documentation; live verification still waits. Inventing a protocol and faking production success remain forbidden.

## 10. Milestone: Demonstrable MVP — end of `W4`

`W4` is reached when all of the following hold:

- all six roles authenticate and enter only their own approved surface;
- the full scenario from Catalog to delivery completes on seeded data;
- the fake payment provider can be driven to success, failure **and unknown outcome** — the last matters most, because `payment_outcome_unknown` is the state where financial defects hide;
- the fake SMS gateway exposes the OTP value **in development only**; in production the OTP is never returned, logged or otherwise emitted, per `AGENTS.md` §6;
- no code path presents a fake provider success as a real payment.

Reaching this milestone before company registration is the point of `D-6`: a system that runs end to end on fakes is what makes the contracts and the registration worth pursuing.

## 11. Required Document Changes

| File | Change |
|---|---|
| `docs/06-roadmap.md` | §1 vertical principle and §2 stage table become the six-wave graph. §16 Definition of Done and §18 post-MVP boundary keep their substance; §16's unit becomes the wave. |
| `AGENTS.md` §8 | The prohibition on speculative infrastructure narrows: the current wave's approved schema task and the `W0` module registries are permitted. Everything else stays forbidden. |
| `AGENTS.md` §11 | Checkpoints are per wave. |
| `tasks/README.md` §5 | Stage planning gate becomes the wave planning gate, with the decision package resolved and frozen at wave entry. |
| `tasks/README.md` §9–§11 | Phase 2 and the integration gate become per wave; merge-queue and ownership rules are added. |
| `tasks/WAVE_<N>_TASK_INDEX.md` | New. Replaces `STAGE_<NN>_TASK_INDEX.md` as the execution index. |
| `tasks/OWNERSHIP.md` | New. Per-wave path ownership map. |
| `docs/SPEC_DECISIONS_BACKLOG.md` | Entries regrouped by wave instead of stage. Content unchanged. |
| `docs/CONTRACT_ALIGNMENT_REPORT.md` | One `AUD-` entry for the execution-model change, and one per resolved specification decision. |
| `tasks/STAGE_01_TASK_INDEX.md` | Folds into `WAVE_00_TASK_INDEX.md`. Its §4 and §6 SMS closure criterion moves to `W5` under `D-4`. No Stage 1 task is in flight — `S01-BE-001` merged as PR #2 — so this fold has nothing to disturb. |

## 12. Risks

| Risk | Mitigation |
|---|---|
| The Project Owner becomes the bottleneck | Cap of 5 open pull requests, small single-contract diffs, two merge windows, independent review carried in the PR. If two windows stop clearing the queue, reduce width — do not accelerate. |
| Frontend silently diverges from the real API | Shared fixture directory asserted from both sides (§7). Mandatory, not optional. |
| Adapters written from published documentation diverge from the contractual protocol | Adapter is transport, signing and parsing only. Obligations, attempts, idempotency, reconciliation and refunds stay provider-agnostic, so divergence rewrites a thin layer, not the payment core. |
| Rework from slices pulled forward out of stages 9 and 10 | Only lifecycle-independent slices moved: Staff management, settings, device registration. |
| A decision changes mid-wave | Decision packages are frozen per wave; reopening one is a wave-level event with an explicit rework assessment. |
| Company registration slips | `W4` still ships the demonstrable milestone. Only `W5` stalls, and it stalls visibly as a named external gate rather than dissolving into "almost done". |
| Two concurrent agents corrupt each other's work | One worktree per track, disjoint ownership map, shared paths reserved to the wave owner. |

## 13. Startup Sequence

**Step 0 — unblock.** `S01-BE-001` is already merged (PR #2), so what remains is: install the Flutter SDK; hold one decision session covering `S-1`–`S-5`, `S-16`, `S-17`, the schema-affecting `S-6`, `S-9`, `S-10`, `S-11`, `S-14`, and provider selection. The Firebase project is 15 minutes and is needed only by `W4`.

**Step 1 — build the cost of entry.** Four sequential tasks: PostgreSQL/Docker runtime; CI in GitHub Actions made a required check on `main`; module registries; identity schema. Task 3 is the one that is easy to treat as optional and is in fact what determines whether the parallel model survives. Task 2 must precede the first parallel wave, not follow it.

**Step 2 — turn on parallelism.** Create worktrees, publish `tasks/OWNERSHIP.md` for `W0`, start three tracks as separate sessions per `D-7`.

**Daily loop.** Morning: the owner approves the day's contracts as a batch, then clears merge window 1. Day: tracks implement, verify, self-review, obtain independent review, open pull requests. Evening: merge window 2.

## 14. Open Items

- The wave decision packages beyond `W0` are listed in `docs/SPEC_DECISIONS_BACKLOG.md` but not yet grouped by wave; that regrouping happens with the document changes in §11.
- Provider selection for SMS and payments is undecided and is required before the `W2` adapter tasks.
- Whether iOS is in the platform set is part of `S-2`; if it is, macOS hardware is an additional external gate with its own lead time.
