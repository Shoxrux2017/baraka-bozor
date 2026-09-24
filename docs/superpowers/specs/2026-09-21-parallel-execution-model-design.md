# BarakaBozor — Parallel Execution Model

## Document Status

| Field | Value |
|---|---|
| Status | `SUPERSEDED on 2026-09-24 by DL-1 in docs/DECISIONS.md — one implementing agent, no concurrent tracks. Kept as history.` (was `APPROVED — Project Owner, 2026-09-21, merged as PR #3`) |
| Date | `2026-09-21` |
| Produced by | implementing agent, design session |
| Independent review | 2026-09-21, reviewer with no implementation context; findings and resolutions in §15 |
| Implemented by | `AUD-022`. Two deviations found by the review of that implementation are recorded in §16 |
| Amends | `docs/06-roadmap.md` §1, §2, §4, §10, §16 (unit only), §17, §18; `AGENTS.md` §8, §11, §13 (clarification); `tasks/README.md` §3, §4, §5, §7, §9–§11, §14; `docs/07-architecture.md` §1, §3, §11, §23, §33, §36; `README.md`; the stage-named files in `tasks/templates/` |
| Leaves untouched | `docs/01`, `02`, `03`, `04`, `05`, `08`, `09`; `AGENTS.md` §6, §7; all product, security and financial rules |

Decisions `D-1`–`D-9` in §3 were all made by the Project Owner during the 2026-09-21 design session. `D-8` and `D-9` fall under the "cross-feature architecture" reservation in `AGENTS.md` §3; the independent review of this document found that the agent had decided them on its own, so they were separated out, put to the Project Owner explicitly, and approved the same day. This document decides no product question.

## 1. Problem

The approved plan runs 12 stages strictly in series, and vertically inside each stage:
`planning gate → backend → backend checkpoint → Flutter → frontend checkpoint → integration → closure`
(`docs/06-roadmap.md` §1). Later stages do not begin until the current stage closes. `README.md` states the same constraint as "One approved task at a time."

Repository state measured on 2026-09-21:

- `S01-BE-001` merged as PR #2 (implementation commit `5ac4d9e`, merge `9274b12`); it is 1 of the 14 ordered Stage 1 tasks
- `frontend/` contains only `AGENTS.md`; `docker/` contains only `README.md`
- no `.github/workflows`
- Docker is installed; `psql`, `flutter` and `dart` are absent from the development machine
- 17 open entries in `docs/SPEC_DECISIONS_BACKLOG.md`. `S-1`–`S-5` and `S-16` block 6 of the 10 remaining Stage 1 backend and frontend tasks — `S01-BE-002`, `S01-BE-003`, `S01-BE-004`, `S01-FE-001`, `S01-FE-003`, `S01-FE-004`. `S-17` is open without a named blocker; `S01-BE-006` is blocked by the external SMS gate rather than by a decision.

Four serializers, ordered by cost:

1. **Undecided specification questions, not code dependencies.** The parallelism the current index already permits is blocked by decisions, not by coupling.
2. **The vertical principle.** Frontend waits for backend inside every stage, although `docs/09-api-contracts.md` and `docs/08-database.md` fix the API contract and the schema for the whole MVP **except** the gaps registered as `S-1`, `S-3`, `S-9`, `S-10`, `S-14`, `S-16` and `S-17`. Those gaps are real and they sit exactly where a contract-first frontend needs them — `S-16` and `S-17` are holes in the `docs/09` §3 error envelope, and `S-3` leaves the message language undecided. The specification is therefore a solvable bottleneck, not an unsolvable one: closing seven registered questions converts it into an asset the current plan does not use.
3. **CI arrives third.** Parallel branches cannot merge safely before required automated checks exist.
4. **The Project Owner is the only serialized human.** Contract approval, PR review, merge, real-stack execution, manual smoke and stage closure all pass through one person. Parallel tracks without owner-load reduction relocate the queue instead of removing it.

## 2. Goal and Non-Goals

**Goal.** Reduce the critical path from 12 serial stages to 6 serial waves, each internally up to 5 tracks wide, and remove external-provider procurement from the critical path — without weakening security, ownership and assignment isolation, financial integrity, test quality or acceptance rigour.

**Non-goals.**

- No change to product or business behavior.
- No change to public API semantics, database contracts, or lifecycle rules.
- No change to `AGENTS.md` §6 (server authority and security) or §7 (historical and financial integrity).
- No change to the post-MVP boundary (`docs/06-roadmap.md` §18).
- No change to the Definition of Done substance (`docs/06-roadmap.md` §16); only its unit changes from stage to wave.
- No microservices, no second state framework, no new database — the architecture baseline in `AGENTS.md` §5 stands.

## 3. Decisions

### Decided by the Project Owner, 2026-09-21

| ID | Decision |
|---|---|
| `D-1` | Owner capacity is several hours per day. Parallel width is capped at 5 tracks, typically 3–5, with two merge windows per day. |
| `D-2` | The implementing agent may restructure process, task order and stage boundaries. Product behavior, security and financial integrity are out of scope. |
| `D-3` | Execution model is contract-first waves with parallel vertical feature tracks. Maximum front-loading of all schema and all route skeletons was considered and rejected. |
| `D-4` | `W0` closes with a fake `SmsGateway`. Real SMS verification moves to `W5` as an explicit recorded debt, not a forgotten tail. |
| `D-5` | Provider adapters are implemented from official published protocol documentation before credentials exist. Adapters stay thin; all money logic remains provider-agnostic. Inventing a protocol and faking provider success remain forbidden. |
| `D-6` | "Demonstrable MVP on fake providers" is an explicit milestone, defined in §10, reached at the end of `W4`. |
| `D-7` | Tracks run as separate Claude Code sessions, one per git worktree. Each session is an independent implementing agent under `AGENTS.md`. |

### Cross-feature architecture, decided by the Project Owner, 2026-09-21

These two are reserved to the Project Owner by `AGENTS.md` §3. They were raised as separate decisions for that reason and approved in the same session.

| ID | Decision | Depends on it |
|---|---|---|
| `D-8` | Module registries: backend routes live in `routes/api/v1/<module>.php` collected by one loop; Flutter feature route fragments are collected by one registry. Neither `docs/07` §3 nor §29 specifies a layout either way, so this is a new architectural pattern, not a derivation. | the `W0` registry task, and the no-collision property every later wave relies on |
| `D-9` | A shared fixture directory derived from `docs/09` response and error examples, asserted from both sides: backend feature tests assert the API emits them, frontend tests assert the client parses them. `docs/07` §33 defines the testing architecture and does not contain this cross-cutting obligation, so §11 amends it. | the contract-first frontend in §7 |

A consequence of `D-2` that the Project Owner should see stated once: **no legal entity exists yet.** Company registration blocks the SMS contract and all merchant agreements, therefore it blocks MVP production launch. It does not block development, and under `D-6` it does not block a demonstrable system.

## 4. Wave Graph

| Wave | Content | Width | Blocked by company |
|---|---|---:|---|
| `W0` Foundation | PostgreSQL/Docker runtime, CI as a required check, module registries, identity schema, six-role auth core, Customer OTP behind a fake `SmsGateway`, Flutter scaffold and auth UX, role shells | 3 | no |
| `W1` Catalog and Account | Catalog backend and both Catalog UIs, Customer profile and addresses, Staff create/activate/block/reset with self and last-admin protections, settings and provider enablement, notification infrastructure with a fake sender | 4–5 | no |
| `W2` Cart to Order to Money | Cart and map picker, business fees and checkout, Order core with idempotency and historical snapshots, payment adapters from published protocols, the Shopper/Courier assignment abstraction | 3 | no |
| `W3` Fulfilment and Exceptions | Shopper market purchase, availability/substitution/Approval, Courier delivery, operational Order board and attention filters, no-response and expired Approval handling, payment and refund problem handling, cancellation decisions, audited dynamic price correction | 4 | no |
| `W4` Demonstrable MVP | Notification events, history, Reorder, Manager analytics, **real FCM**, full end-to-end scenarios on fake providers | 3 | no |
| `W5` Providers and Launch | Real SMS with contract and alpha-name, merchant integrations and sandbox verification, required release build, PostgreSQL migration checks, performance checks, security and financial integrity review, implementation-versus-documentation review, pilot readiness | 2 | **yes** |

"Width" is the maximum number of tracks running concurrently inside the wave, and therefore the number of concurrent sessions and worktrees. It is bounded by `D-1`, not by the number of separable tasks.

Source stages, covering stages 1–12 exactly once:

| Wave | Takes from |
|---|---|
| `W0` | 1 |
| `W1` | 2; part of 3 (profile, addresses); part of 9 (Staff management, settings, provider enablement); part of 10 (device registration, notification infrastructure) |
| `W2` | rest of 3 (Cart, map picker); 4; part of 5 and 8 (assignment abstraction only); part of 7 (adapters on published protocols) |
| `W3` | rest of 5; 6; rest of 8; rest of 9 (operational board, attention filters, no-response and expired Approval, payment/refund problems, cancellation decisions, audited price correction) |
| `W4` | rest of 10 (events, history, Reorder); 11; the fake-provider scenario part of 12 |
| `W5` | rest of 7 (real merchant integration, reconciliation against live providers); the provider-sandbox, release-build, performance, security-review and pilot part of 12 |

**Real FCM belongs to `W4`, not `W5`.** A Firebase project requires only a Google account, so Android push can reach a real integration without a company. If iOS is in the platform set — undecided, see `S-2` — APNs additionally requires an Apple Developer Program membership and an APNs key, which is a separate external gate with its own lead time (§9). Only the SMS contract and the merchant agreements require a legal entity, which keeps the company-blocked tail small.

Six decisions make this graph possible:

1. **Schema is one task per wave with one owner.** Feature tasks add no migrations. Migrations are the only genuinely shared serial resource, and this removes the largest collision source. Per wave, not the whole MVP at once — that distinction is what keeps this inside the spirit of `AGENTS.md` §8.
2. **Module registries are written once in `W0`** (`D-8`). Feature tracks then never edit `routes/api.php`, `bootstrap/app.php`, the root GoRouter or the root Riverpod providers. This removes the second largest collision source.
3. **Frontend runs against the locked contract, not against backend code** (§7), guarded by the shared fixtures of `D-9`.
4. **Dependency-free slices of stages 9 and 10 move into `W1`**: Staff management, settings and provider enablement, FCM device registration. They need only auth. Everything in stage 9 that depends on the Order lifecycle — the operational board, exception handling, cancellation decisions and price correction — stays in `W3`.
5. **Payment adapters are built in `W2` on fakes; real credentials are wired in `W5`.**
6. **Decisions and procurement are a non-code track.** A wave's decision package is resolved at its entry gate and then **frozen for the wave**. Changing a decision mid-wave makes parallel tracks redo each other's work, which is the fastest way to lose the entire benefit of parallelism.

## 5. What Stays Serial, Deliberately

**Cart → Order core → Shopper purchase → Approval is a genuine data and lifecycle chain.** No restructuring removes it. It is the real critical path of the product, and it is why the expected gain is a roughly two-fold improvement in code throughput rather than a multiple of the track count. That figure is a planning judgement from the dependency structure, not a measurement, and it should not be used as a commitment.

**Financial-invariant work is assigned to one designated money track per wave.** In `W2` that track owns price snapshots, fees, checkout totals and payment obligations; in `W3` it owns Approval, billable quantity, cancellation and refunds; in `W5` it owns live reconciliation. Two rules make this more than a label:

- within a wave, no other track may modify money, quantity, rounding, obligation or refund code, per the ownership map in §6.2;
- at each wave boundary the outgoing money track hands over in writing — invariants held, known gaps, tests that encode them — and the wave entry gate records the incoming owner.

The Project Owner owns cross-wave continuity of these invariants, because no track spans waves. Splitting this work across concurrent agents within a wave is how money defects are introduced; `AGENTS.md` §7 leaves no room to trade this for speed, and this design does not try.

## 6. Parallel Mechanics

### 6.1 One worktree per track

```text
git worktree add ../bb-<track> -b task/<task-id-lowercase>-<short> origin/main
```

The primary checkout `baraka-bozor` stays on `main` and clean. It is the Project Owner's review and merge surface, never a track workspace. This preserves the `tasks/README.md` §8A preflight requirement that local `main` is clean and equal to `origin/main`, which a naive single-checkout parallel model would break.

### 6.2 Ownership map

A new `tasks/OWNERSHIP.md` records, per wave, which paths each track owns. The `TASK_TEMPLATE.md` "allowed files/areas" field becomes mandatory and must agree with that map. Two tracks never own the same path.

Shared-caretaker paths — `routes/api.php`, `bootstrap/app.php`, `composer.json`, `pubspec.yaml`, `database/migrations/**`, root router and root providers — are edited only by the wave owner, in a dedicated task and PR. Feature tracks do not touch them.

### 6.3 Merge queue

- CI is a **required** check on `main` before the first parallel wave.
- At most 5 open pull requests at a time; exceeding it means the owner is the bottleneck and width must drop.
- One approved contract = one branch = one small pull request.
- A branch behind `main` is updated by **merging current `main` into the branch**, never by rebasing a pushed branch. Rebasing a branch that already has an open pull request would require a force-push, and `AGENTS.md` §13 forbids force-pushing without scoping the prohibition to `main`. Merging forward needs no history rewrite and no rule amendment. On conflict the track agent resolves it, never the owner.
- **The green CI run must be on the branch head that will be merged**, after any forward merge. A run that predates the update is not evidence for the updated head.
- A track whose branch takes in a merged migration or a merged shared-infrastructure change re-runs its focused verification before merge, per the evidence-validity rules in `tasks/README.md` §13.
- Merge order is first-in, first-out within a merge window.
- No merge without a green CI run on the final head and an independent review report.

### 6.4 Independent review

`AGENTS.md` §14 already requires a reviewer with no implementation context before every pull request. Under this model that step is also the mechanism that keeps owner load low: the owner reads the CI result, the review report — including findings deliberately not acted on, with reasons — and the diff, rather than re-deriving the review. Findings at P1 or P2 are fixed before the pull request opens.

## 7. Contract-First Frontend

Frontend tracks build against `docs/09-api-contracts.md`, using the strict DTO and repository layering already fixed by `docs/07` §27, in parallel with the backend track that implements the same contract. Real wiring happens at the wave integration gate.

The guard against silent divergence is the shared fixture directory approved as `D-9`: the response and error examples from `docs/09` live in one place, backend feature tests assert that the API emits them, frontend tests assert that the client parses them. A divergence turns into a red CI run rather than a surprise at integration.

Two preconditions remain, both real:

- the fixture guard must exist before the first contract-first frontend task, not alongside it; without it this approach is not safe and must not be used;
- a wave's frontend track may start only after that wave's fixture surface is actually decided. For `W0` this means `S-3`, `S-16` and `S-17` must be resolved, because the error envelope in `docs/09` §3 is incomplete without them and error fixtures cannot be written from it as it stands.

## 8. Quality Gates

Per-task verification is unchanged (`AGENTS.md` §11, `tasks/README.md` §8C): focused tests, required formatter/linter/static checks, named regression checks when justified, `git diff --check`, full scope and diff self-review.

What changes is the unit of the block checkpoint. Instead of one backend and one frontend Phase 2 per stage, each **wave** ends with:

1. a backend block review and a frontend block review, each by a fresh reviewer with no implementation context;
2. full required backend and frontend verification, run by CI or the Project Owner;
3. one wave integration gate on the real Laravel/PostgreSQL/Flutter stack;
4. Project Owner manual smoke, the money-track handover of §5, and the wave verdict.

The wave verdict replaces the stage closure verdict of `tasks/README.md` §14 and keeps its three values, renamed to their unit: `WAVE CLOSED`, `FIXES REQUIRED BEFORE CLOSURE`, `CLOSURE BLOCKED`. The Project Owner assigns it. `PASS` still requires P1 = 0 and P2 = 0 and all required verification passing. Severity definitions and the evidence-validity rules in `tasks/README.md` §12–§13 are unchanged in substance; §6.3 above states how they apply to a merge queue.

## 9. External Gates

| Gate | Owner | Needed by | Requires legal entity |
|---|---|---|---|
| Specification decisions for the wave | Project Owner | wave entry | no |
| Flutter SDK installed | Project Owner | `W0` frontend track | no |
| Flutter map/tile provider and package | Project Owner | `W2` map-picker task | no |
| Provider selection — which SMS aggregator, which payment providers | Project Owner | `W2` adapter tasks | no |
| Firebase project and app registration | Project Owner | `W4` | no |
| Apple Developer Program and APNs key, **only if iOS is in the platform set** | Project Owner | `W4` iOS push | no |
| **Company registration** | Project Owner | `W5` | — |
| SMS contract and alpha-name | Project Owner | `W5` | yes |
| Merchant agreements, sandbox credentials, contractual protocols | Project Owner | `W5` | yes |

This table restates and extends the gates already fixed by `docs/06-roadmap.md` §4/§6/§10/§13, `docs/07` §36 and `tasks/README.md` §16. A provider-dependent task stays `Blocked` until its external contract is available. Under `D-5` the thin adapter may be written earlier from official published documentation; live verification still waits. Inventing a protocol and faking production success remain forbidden.

## 10. Milestone: Demonstrable MVP — end of `W4`

`W4` is reached when all of the following hold:

- all six roles authenticate and enter only their own approved surface;
- the full scenario from Catalog to delivery completes on seeded data;
- the fake payment provider can be driven to success, failure **and unknown outcome** — the last matters most, because `payment_outcome_unknown` is the state where financial defects hide;
- the fake `SmsGateway` records each issued OTP in a test-only in-process sink that backend feature tests assert against. **No API response, log line, response header or client-visible surface carries an OTP value in any environment.** `AGENTS.md` §6 forbids exposing or logging OTP values without an environment qualifier, and this design does not create one;
- no code path presents a fake provider success as a real payment.

How a human demonstrator obtains an OTP during a live demonstration is **not decided here** — see §14. Any mechanism that would return an OTP to a client is a change to `AGENTS.md` §6 and requires an explicit Project Owner amendment with its own `AUD-` entry.

Reaching this milestone before company registration is the point of `D-6`: a system that runs end to end on fakes is what makes the contracts and the registration worth pursuing.

## 11. Required Document Changes

| File | Change |
|---|---|
| `docs/06-roadmap.md` §1–§2 | The vertical principle and the stage table become the six-wave graph. |
| `docs/06-roadmap.md` §4 | The Stage 1 closure condition "cannot close without approved real/sandbox SMS integration path" moves to `W5` under `D-4`. |
| `docs/06-roadmap.md` §10 | The Stage 7 gate currently reads documentation **and** credentials conjunctively. `D-5` separates them: published protocol documentation permits adapter code; credentials remain required for verification and closure. "Missing access = `BLOCKED`, never fake success" is unchanged. |
| `docs/06-roadmap.md` §16 | Definition of Done substance unchanged; its unit becomes the wave. |
| `docs/06-roadmap.md` §17 | `STAGE_<NN>_TASK_INDEX.md` as the execution-order authority becomes `WAVE_<N>_TASK_INDEX.md`. |
| `AGENTS.md` §8 | The prohibition on speculative infrastructure narrows: the current wave's approved schema task and the `D-8` module registries are permitted. Everything else stays forbidden. |
| `AGENTS.md` §11 | Checkpoints are per wave. |
| `AGENTS.md` §13 | Clarification only: state that a task branch is brought up to date by merging `main` forward, and that the force-push prohibition is absolute for every branch. No permission is added. |
| `AGENTS.md` §3, `README.md` | "One approved task at a time" becomes "one approved task at a time per track, with concurrent tracks bounded by the wave's declared width and the ownership map". The reserved-decision list is unchanged. |
| `tasks/README.md` §3 | Directory tree: `WAVE_<N>_TASK_INDEX.md`, `WAVE_<N>_CLOSURE_REVIEW.md`, `backend/wave-<N>/`, `frontend/wave-<N>/`, `integration/wave-<N>/`. |
| `tasks/README.md` §4 | Task IDs become `W<wave>-<area>-<number>-<short-description>`. Existing `S01-*` IDs are not renamed; the `W0` index carries them with their original names and records the mapping. |
| `tasks/README.md` §5 | Stage planning gate becomes the wave planning gate, with the decision package resolved and frozen at wave entry. |
| `tasks/README.md` §7 | Task lifecycle states are unchanged; `Accepted` keeps requiring local `main == origin/main`, ahead/behind `0/0`, clean worktree. |
| `tasks/README.md` §9–§11 | Phase 2 and the integration gate become per wave; the merge-queue and ownership rules of §6 are added. |
| `tasks/README.md` §14 | Stage Closure becomes Wave Closure with the renamed verdicts of §8. |
| `tasks/templates/STAGE_TASK_INDEX_TEMPLATE.md`, `STAGE_CLOSURE_REVIEW_TEMPLATE.md` | Renamed to their wave equivalents. The Roadmap Acceptance Matrix in the index template keeps every criterion; only its unit changes. `BLOCK_REVIEW_TEMPLATE.md` and `TASK_TEMPLATE.md` need no structural change beyond making "allowed files/areas" mandatory. |
| `docs/07-architecture.md` §23 | "actual SMS vendor is Stage 1 external gate" becomes `W5` under `D-4`. The rule that production OTP is never logged is unchanged and §10 above strengthens it. |
| `docs/07-architecture.md` §33 | Testing Architecture gains the `D-9` shared-fixture obligation. |
| `docs/07-architecture.md` §36 | External Integration Gates restated per §9, including the map/tile provider and the conditional APNs gate. |
| `docs/07-architecture.md` §3 | Repository Baseline records the `docs/superpowers/specs/` tree, which this document introduces and which no baseline currently lists. |
| `tasks/STAGE_01_TASK_INDEX.md` | Folds into `WAVE_00_TASK_INDEX.md`; its §4 and §6 SMS closure criterion moves to `W5` under `D-4`. Precondition: the index still records Stage status `In Progress` and `S01-BE-001` as `In Review`, and local `main` is behind `origin/main`. Bring both current, and let `S01-BE-001` reach `Accepted` per `tasks/README.md` §7, before folding. |
| `tasks/OWNERSHIP.md` | New. Per-wave path ownership map. |
| `docs/SPEC_DECISIONS_BACKLOG.md` | Entries regrouped by wave instead of stage. Content unchanged. |
| `docs/CONTRACT_ALIGNMENT_REPORT.md` | One `AUD-` entry for the execution-model change, and one per resolved specification decision. |

## 12. Risks

| Risk | Mitigation |
|---|---|
| The Project Owner becomes the bottleneck | Cap of 5 open pull requests, small single-contract diffs, two merge windows, independent review carried in the PR. If two windows stop clearing the queue, reduce width — do not accelerate. |
| Frontend silently diverges from the real API | The `D-9` shared fixture directory asserted from both sides (§7). The fixture guard must land before the first contract-first frontend task, and the wave's fixture surface must be decided first — for `W0` that means `S-3`, `S-16` and `S-17`. |
| Adapters written from published documentation diverge from the contractual protocol | Adapter is transport, signing and parsing only. Obligations, attempts, idempotency, reconciliation and refunds stay provider-agnostic, so divergence rewrites a thin layer, not the payment core. |
| Rework from slices pulled forward out of stages 9 and 10 | Only lifecycle-independent slices moved: Staff management, settings and provider enablement, device registration. |
| Financial invariants fragment across waves | One designated money track per wave, exclusive ownership of money paths in the ownership map, written handover at each wave boundary, Project Owner owning cross-wave continuity (§5). |
| Stale CI evidence clears a merge | Green CI is required on the final merged head after any forward merge, and focused verification is re-run when a migration or shared-infrastructure change lands underneath a branch (§6.3). |
| A decision changes mid-wave | Decision packages are frozen per wave; reopening one is a wave-level event with an explicit rework assessment. |
| Company registration slips | `W4` still ships the demonstrable milestone. Only `W5` stalls, and it stalls visibly as a named external gate rather than dissolving into "almost done". |
| Two concurrent agents corrupt each other's work | One worktree per track, disjoint ownership map, shared paths reserved to the wave owner. |
| A `PROPOSED` document in `docs/` is mistaken for locked authority | The status header marks it, and §11 requires the tree to be recorded in the `docs/07` §3 Repository Baseline with its status convention. |

## 13. Startup Sequence

**Step 0 — unblock.** `S01-BE-001` is merged and `D-8`/`D-9` are decided, so what remains is: install the Flutter SDK; hold one decision session. That session resolves the `W0` package — `S-1`, `S-2`, `S-3`, `S-4`, `S-5`, `S-16`, `S-17` — plus provider selection for SMS and payments, which is needed early only because the `W2` adapter tasks depend on knowing whose protocol to implement. The Firebase project takes minutes and is needed only by `W4`.

Later waves' decisions are resolved at their own entry gates, per §4.6. The selection rule is explicit: **a decision must be resolved before the wave whose schema task or public contract depends on it.** By that rule `S-6`, `S-7` and `S-9` belong to the `W3` entry gate, `S-10`, `S-11` and `S-13` to `W2`, `S-14` and `S-15` to `W1`, `S-8` to `W4`, `S-12` to `W4`. The Project Owner may pull any of them forward; none may slip past its wave.

**Step 1 — build the cost of entry.** Four sequential tasks: PostgreSQL/Docker runtime; CI in GitHub Actions made a required check on `main`; module registries under `D-8`; identity schema. Task 3 is the one that is easy to treat as optional and is in fact what determines whether the parallel model survives. Task 2 must precede the first parallel wave, not follow it.

**Step 2 — turn on parallelism.** Create worktrees, publish `tasks/OWNERSHIP.md` for `W0`, start three tracks as separate sessions per `D-7`.

**Daily loop.** Morning: the owner approves the day's contracts as a batch, then clears merge window 1. Day: tracks implement, verify, self-review, obtain independent review, open pull requests. Evening: merge window 2.

## 14. Open Items

- How a human demonstrator obtains an OTP for a live demonstration of the `W4` milestone. Any client-visible mechanism amends `AGENTS.md` §6 and is the Project Owner's decision (§10).
- Provider selection for SMS and payments, required before the `W2` adapter tasks.
- Whether iOS is in the platform set (`S-2`); if it is, Apple Developer Program membership and macOS hardware are additional external gates with their own lead times.
- The wave regrouping of `docs/SPEC_DECISIONS_BACKLOG.md` proposed in §13 is a proposal; each assignment is confirmed at the wave planning gate that adopts it.

## 15. Independent Review — 2026-09-21

Reviewed by an agent with no implementation context, against `AGENTS.md`, `tasks/README.md`, `docs/06-roadmap.md` and the locked `docs/01–09`. Findings: 1 × P1, 9 × P2, 7 × P3, plus two overreach findings.

**All P1 and P2 findings were fixed in this revision**, per `AGENTS.md` §14:

| Finding | Resolution |
|---|---|
| P1 — the milestone authorised a dev-visible OTP and cited `AGENTS.md` §6 as its authority, while claiming §6 was untouched | §10 rewritten to a test-only in-process sink with no client-visible or logged OTP in any environment; the demonstration question moved to §14 as an Owner decision |
| P2 — stage 9 content silently dropped | §4 source table now assigns the operational board, exception handling, cancellation decisions and audited price correction to `W3` |
| P2 — `W2` content and source mapping contradicted each other on assignment abstraction | §4 source table now lists "part of 5 and 8 (assignment abstraction only)" for `W2` |
| P2 — the locked Flutter map/tile provider gate was dropped | added to §9 |
| P2 — the `Amends` field understated the affected documents | `Amends` and §11 now name roadmap §4/§10/§17, `docs/07` §3/§23/§33/§36 and `README.md` |
| P2 — `tasks/README.md` §3/§4/§14 and the stage-named templates left unamended; "wave verdict" undefined | §11 adds rows for each; §8 defines the verdict and its three values |
| P2 — the merge queue required rebasing a pushed branch, which needs a force-push that `AGENTS.md` §13 forbids without scoping | §6.3 now merges `main` forward instead of rebasing, so no rule is weakened. This differs from the reviewer's proposed fix, which was to amend §13 to permit `--force-with-lease`; merging forward achieves the same result without relaxing a safety rule |
| P2 — stale CI evidence could clear a merge | §6.3 requires green CI on the final head and re-verification under a merged migration or shared-infrastructure change |
| P2 — "financial invariants in one track with one owner" was unachievable across waves | §5 rewritten: one designated money track per wave, exclusive ownership, written handover at wave boundaries, Owner holding cross-wave continuity |
| P2 — "the specification is not the bottleneck" contradicted the open backlog | §1 now names the seven registered gaps and states the precondition in §7 |

P3 findings 1, 2, 3, 4, 5 and 7 were also fixed: width figures harmonised with `D-1`; the APNs conditional added; the throughput figure marked a judgement, not a measurement; "~14" corrected to 14; the `STAGE_01` fold given its status and synchronisation precondition; stage 12's release-build, migration, performance, security-review and documentation-review items named in `W5`.

P3-6 was fixed by a different route than proposed: rather than defending the front-loading of `S-6`/`S-9`/`S-10`/`S-11`/`S-14`, §13 now states the selection rule and assigns every open decision to the wave that needs it, which removes the tension with `D-3` and §4.6 and supplies the criterion the reviewer found missing.

Both overreach findings were accepted: the module registries and the shared fixture contract were taken out of the agent's hands, raised as `D-8` and `D-9` in §3, and put to the Project Owner, who approved both on 2026-09-21. `W0` is therefore no longer blocked on them.

The reviewer also recorded what it checked and found accurate, including every repository-state claim in §1, the backlog arithmetic, and all citations except the one corrected as P1. Those checks are why this revision could be narrow.

## 16. Deviations Found While Implementing This Record

`AUD-022` carried §11 into the repository. Its own independent review found no P1 and no silent weakening, and confirmed all 24 rows of §11 were executed. Two places where this record was wrong, rather than the implementation, are corrected here:

- **§2 Non-Goals and the §11 Definition-of-Done row were mutually inconsistent in practice.** Adding "merged on a green CI run" to `docs/06-roadmap.md` §16 would have been a substantive addition to a locked clause, and Wave 0 cannot satisfy it — the tasks that build the runtime and CI must merge before CI exists. The obligation now lives in `tasks/README.md` §8 and §14, and §16 keeps its original substance. The non-goal stands as written.
- **§13's decision-to-wave assignment was wrong for two entries.** `S-14` (Cart `abandoned`) was assigned to `W1` while §4 puts Cart in `W2`; `S-9` (enum vocabularies) was assigned to `W3` while the Order, assignment and refund tables whose columns it defines are created in `W2`. Both moved to `W2`. §14 already labelled that grouping a proposal to be confirmed at the adopting gate, so this is the confirmation, not a change of decision.

Two further edits went beyond §11's letter and are disclosed in `AUD-022`: `docs/06-roadmap.md` §18 and `docs/07-architecture.md` §1 and §11 needed unit renames to stay coherent. No item list, criterion or rule changed in any of them.
