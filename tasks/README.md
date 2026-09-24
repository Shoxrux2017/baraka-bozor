# BarakaBozor Implementation Workflow — v6, Single Implementer

Since 2026-09-24 one implementing agent builds the product under `AGENTS.md` (`DL-1` in `docs/DECISIONS.md`). This file says how work is organised. Workflow v5 (concurrent tracks, path ownership, per-task contracts of 150–350 lines, owner-merged pull requests) is retired; its records stay in `tasks/backend/`, `tasks/frontend/`, `tasks/integration/`, `tasks/OWNERSHIP.md`, the `STAGE_*` files and `WAVE_00_TASK_INDEX.md` as history and are not edited.

## 1. Waves

Work runs in waves, in the order `docs/06-roadmap.md` Section 2 gives. Each wave has one plan file:

```text
tasks/WAVE_<N>.md
```

The plan file holds: the wave's goal, the ordered task list with status, per-task notes (goal, scope, acceptance, verification), the risk list, the independent-review findings not acted on, and the closure record. It is updated in the same pull request as the work it describes.

A task note is short. It records what the documents do not already say: the decisions taken for that task, the traps, and what "done" means. It cites `docs/01–09` instead of copying them.

## 2. Task Lifecycle

```text
Planned → In Progress → Merged → Verified (wave closure)
```

A task is one branch and one pull request, small enough to review in one sitting. Large features are split by vertical slice, not by layer.

## 3. Per-Task Flow

1. Read the governing sections of `docs/01–09` and the relevant code.
2. Decide what the documents leave open; record engineering decisions in `docs/DECISIONS.md`, and update the affected document in the same branch. A product question goes to the Owner per `AGENTS.md` Section 3.
3. Branch from a current `main`.
4. Implement with tests, following `backend/AGENTS.md` and `frontend/AGENTS.md`.
5. Run the focused verification of `AGENTS.md` Section 10.
6. Self-review the complete diff.
7. Independent review by a clean subagent; fix P1 and P2.
8. Push, open the pull request with the scope, the verification output and the review findings, wait for CI.
9. Merge. Update the wave file if the task's status or risks changed.

## 4. Wave Closure

When every task of the wave is merged:

1. run the full backend suite, the full frontend suite, `flutter build` for the wave's required targets;
2. bring up the real stack and walk the wave's end-to-end scenario;
3. write the Owner's manual-check checklist and the wave report (`AGENTS.md` Section 14);
4. record the closure in the wave file, with what was verified and what remains.

The Owner's manual check may produce fixes; they are ordinary tasks of the next wave unless they block the pilot.

## 5. External Gates

Some steps need the Owner:

| Gate | Needed by |
|---|---|
| Yandex MapKit API key | Wave 1 address picker |
| Firebase project and Android app registration | Wave 4 push |
| Telegram Gateway account and funding | Wave 4 login codes |
| Hosting in Uzbekistan, domain, TLS | Wave 4 deployment |
| Google Play personal account, twelve closed testers | Wave 4 Android distribution |
| Legal entity | Wave 5 payment contracts, Eskiz SMS contract |
| Payme and Click merchant agreements, credentials | Wave 5 |
| Apple Developer Program, a Mac | iOS release, later |

The agent asks for each gate when the wave that needs it is planned, with the exact steps, and works around it with fakes until it is met. It never invents a provider protocol and never presents a fake provider result as real.

## 6. Severity

| Severity | Meaning |
|---|---|
| P1 | security, privacy, data loss, financial integrity, public-contract breach |
| P2 | material functional, architectural or lifecycle defect |
| P3 | non-blocking maintainability, clarity or test-quality improvement |
