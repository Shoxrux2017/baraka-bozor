# W0-INT-004 — Explicit PHP configuration in the container runtime

## Metadata

| Field | Value |
|---|---|
| Task ID | `W0-INT-004` |
| Wave | `0 — Foundation` |
| Area | `Integration` |
| Status | `Approved` — Project Owner, 2026-09-22 |
| Depends on | `W0-INT-002` — Accepted, PR #7 |
| Blocks | nothing hard. It removes a defect on the diagnostic path every later task needs |
| Track | `wave-owner` |
| Branch | `task/w0-int-004-container-php-memory-limit` |

## Goal

Raise the container's PHP memory ceiling, and give the runtime an explicit
configuration file to hold that and any later setting this project depends on
deliberately rather than inherits.

## Why

PHPStan's peak memory in this runtime **straddles PHP's default ceiling of
128 MB**. Every figure below is one sample of a quantity that moves by tens of
megabytes with container state, so they are given as a range with how often each
was seen, not as a single number:

| Mode | Observed peak | Samples |
|---|---|---|
| single-process (`--debug`), ceiling raised | `126.5 MB`, and `170.5 MB` once on a freshly built image | 3 + 1 |
| single-process, ceiling at `128M` | `126.5 MB`, passing | 3 |
| parallel main process | `78.5 MB`, then `94.5 MB` with workers forced to 4 | 15 + 1 |
| parallel worker | `60 MB`, `72 MB`, `74 MB`, `114 MB` | 5, 1, 11, 2 |

**`170.5 MB` observed against a `128M` ceiling is the finding.** Where the
ceiling binds, the same analysis reports `126.5 MB` instead — PHP's allocator
collects harder under a tight limit rather than the work getting smaller — so
`128M` was not headroom, it was the wall.

`--debug` is not an exotic mode. It is single-process, and it is the one thing
that makes PHPStan name the file it died on, so it is exactly what anyone reaches
for when the analyser crashes. On `W0-BE-010`'s tree, which adds two analysed
files (19 → 21), it does not survive the ceiling at all:

```text
PHPStan process crashed because it reached configured PHP memory limit: 128M
Allowed memory size of 134217728 bytes exhausted (tried to allocate 131072 bytes)
```

That crash is the one hard failure in the set, and it is why this task exists:
the tool you reach for when something crashes was itself crashing.

The test suite runs under the same ceiling. It passes today and nothing suggests
it is close, but it has no configured headroom either.

## What this does not claim

PHPStan fails in CI on `W0-BE-010` (PR #9) with:

```text
Child process error (exit code 255):  while running parallel worker
```

**This task does not claim to fix that. The evidence neither confirms nor
excludes it.** In parallel mode, which is what CI runs, the worker peak observed
here ranges from `60 MB` to `114 MB` against the old `128 MB` ceiling — so the
margin is somewhere between 68 MB and 14 MB depending on a run-to-run variation
nothing in this work explains.

An earlier draft asserted `114 MB` flatly and called the memory ceiling the
leading cause. The independent review measured `60 MB` and called the figure
irreproducible. **Both observations are real**; the mistake was each of us
treating one sample as the number. Nineteen further samples put the worker
between `60` and `114 MB`. Neither "leading cause" nor "weak explanation" is
supportable, so this contract claims neither.

Also still unexplained: the CI-identical invocation could not be made to fail at
`128M` on the development machine, with a cold result cache (5 runs), with
PHPStan's worker count forced to four (3 runs), or with the container restricted
to four CPUs (3 runs). All green. PR #9's cause remains unknown and needs its own
task, one that can put `--debug` into `.github/workflows/backend.yml` so a CI
failure names a file. This task is what makes that step possible: at `128M`,
`--debug` on that tree dies before it can report anything.

## Scope

### Included

- An explicit `php.ini` in the image, setting `memory_limit`.
- The value chosen against a measured peak, with the measurement recorded.
- `docker/README.md` stating that the image sets PHP configuration explicitly
  and why, so the next person does not re-derive it from a crash.
- A negative control, reported as observed.

### Excluded

- Any change to PHPStan's level, baseline, configuration or analysed paths.
  Nothing here makes the analyser more permissive; an analysis that could not
  complete will now complete.
- Any change to `backend/phpstan.neon`. The defect is not in PHPStan's
  configuration.
- Any change to `.github/workflows/backend.yml`. Nothing in CI needs a memory
  flag once the image carries the setting. A CI *assertion* that the setting is
  present would be a different and defensible change — `W0-INT-002` added a
  "Show the runtime" step for exactly that kind of guard, so this is not an
  argument against it — but it is not this task, which must not widen.
- Diagnosing PR #9. See **What this does not claim**.
- Raising `memory_limit` for production. No deployable image exists:
  `app.Dockerfile` copies no application code, `compose.yaml` bind-mounts
  `../backend`, and `W0-INT-001` Decision 1 scopes this stack to development and
  CI.
- Any other PHP setting whose default is not demonstrably wrong here. This task
  adds a configuration file, not a tuning exercise.

## Governing Specification

| Source | Section | What it governs here |
|---|---|---|
| `docs/07-architecture.md` | §2 | the pinned PHP version the image supplies |
| `docs/06-roadmap.md` | §1, §16 | the Definition of Done's green-CI obligation |
| `tasks/README.md` | §8F | CI is a required check; the green run must be on the merged head |
| `tasks/README.md` | §13 | evidence validity — what this change does and does not invalidate |
| `AGENTS.md` | §8 | implement exactly this; no unrelated tuning |
| `AGENTS.md` | §10 | no check may be relaxed to pass |
| `AGENTS.md` | §11 | the verification must be observed, and its output quoted |
| `tasks/OWNERSHIP.md` | Wave 0 | `docker/**` belongs to `wave-owner` |
| `W0-INT-001` contract | Decision 1 | one runtime shared by local and CI, which this must not split |
| `W0-INT-002` contract | Decision 1, 2, 3 | CI builds this image, runs these documented commands, caches no layers |

## Decisions

| # | Decision | Why |
|---|---|---|
| 1 | Fix it in **the image**, not on the PHPStan command line. | The ceiling applies to every tool in the container, not to one command. A flag on `phpstan` would leave the test suite unconfigured and put the number in two places that can drift. |
| 2 | A dedicated `docker/php.ini` copied to `/usr/local/etc/php/conf.d/`, not one of the image's shipped `php.ini-*` files. | The shipped files set dozens of unrelated values, and — verified in the container — **both set `memory_limit = 128M` themselves**, identical to the compiled-in fallback, so activating either would have changed nothing here. A small file holding only what this project sets deliberately is reviewable, and `conf.d/` is the mechanism the base image documents. The main `php.ini` therefore stays absent by design. |
| 3 | `memory_limit = 512M`. | Chosen against the highest peak observed, `170.5 MB`, with roughly three times that as headroom — enough for several waves rather than a number to revisit each wave, and wide enough that the run-to-run variation recorded under **Why** does not matter. It rests on that measurement alone; an earlier draft claimed PHPStan's documentation recommends `512M` for Laravel, which could not be verified from this repository and is withdrawn. |
| 4 | No other setting is changed. | `AGENTS.md` §8 forbids unrelated change. A setting added speculatively here would be indistinguishable from one added for a reason. |
| 5 | The value lives in exactly one place, and `docker/README.md` points at it rather than repeating it. | Two copies of a number drift, and the drift is silent. |

## Implementation Notes

- `conf.d/` files are read in alphabetical order after the main `php.ini`. The
  `zz-` prefix puts this one after the `docker-php-ext-*.ini` files that
  `docker-php-ext-install` writes there, so its precedence is deliberate.
- `docker compose up -d` will not pick up a Dockerfile change on its own. The
  verification must build.
- `php --ini` will still report `Loaded Configuration File: (none)`. That is
  correct under Decision 2 and must not be read as the change not taking effect;
  the file appears under `Additional .ini files parsed`. `docker/README.md` says
  so.

## Acceptance Criteria

1. `php --ini` in the container lists `zz-baraka-bozor.ini` under
   `Additional .ini files parsed`.
2. `php -r 'echo ini_get("memory_limit");'` in the container returns `512M`.
3. `vendor/bin/phpstan analyse --debug` completes in the container on `main`
   plus this change, and its reported peak exceeds the old `128M` ceiling —
   which is what shows the raised ceiling is doing the work.
4. A negative control is run and reported **as observed**: the same `--debug`
   analysis at `-d memory_limit=128M`. On this tree it is expected to pass at
   `126.5 MB`, one and a half megabytes under the ceiling, and that number is the
   finding. The contract does not require it to fail here, and a report claiming
   it failed would be false.
5. `php artisan test` and `vendor/bin/pint --test` still pass.
6. CI is green on this branch.
7. `docker/README.md` states that the image sets PHP configuration explicitly,
   where the value lives, that the main `php.ini` stays absent by design, and
   that a change needs `--build`.
8. No file outside Allowed Areas is touched.

## Verification

Observed and quoted, per `AGENTS.md` §11:

- `docker compose -f docker/compose.yaml up -d --build`
- `docker compose -f docker/compose.yaml exec -T app php --ini`
- `docker compose -f docker/compose.yaml exec -T app php -r 'echo ini_get("memory_limit"), PHP_EOL;'`
- `docker compose -f docker/compose.yaml exec -T app php artisan test`
- `docker compose -f docker/compose.yaml exec -T app vendor/bin/pint --test`
- `docker compose -f docker/compose.yaml exec -T app vendor/bin/phpstan analyse -v`
- `docker compose -f docker/compose.yaml exec -T app vendor/bin/phpstan analyse --debug -v`
- the negative control for criterion 4, with its output
- `git diff --check`
- the CI run on this branch

Deliberately **not** run: the full Wave 0 checkpoint, any frontend check, or any
broader suite. `AGENTS.md` §11 reserves those.

### Evidence validity

Per `tasks/README.md` §13 this is a build-system change, which invalidates static
and build evidence, and the Project Owner decides the minimum sufficient rerun on
the implementing agent's recommendation.

**Recommendation: the backend suite, Pint and PHPStan on the rebuilt image, and
nothing more.** No application code, schema, route or public contract changes,
and the change only raises a ceiling — nothing that passed under `128M` can fail
under `512M` for that reason. Those three checks were re-run on the rebuilt image
as part of this task's verification, and the CI run on the merged head repeats
them.

## Allowed Areas

Nothing outside this table may be created, modified or deleted.

| Path or area | Action | Reason |
|---|---|---|
| `docker/php.ini` | Create | the explicit configuration |
| `docker/app.Dockerfile` | Modify | copy it into the image |
| `docker/compose.yaml` | Modify | one comment, which the Dockerfile change made false — added to this table by the Project Owner on 2026-09-22 after the independent review raised it |
| `docker/README.md` | Modify | one section recording what is set and why |
| `tasks/integration/wave-00/W0-INT-004-container-php-memory-limit.md` | Create | this contract |
| `tasks/WAVE_00_TASK_INDEX.md` | Modify | task row, readiness row, risk row, dependency map, change log |

Explicitly outside: `backend/**`, `.github/workflows/**`, `frontend/**`,
`docs/**`.

**One path was added after sign-off.** `docker/app.Dockerfile` now copies from the
build context, which made a comment in `docker/compose.yaml` false — it said the
Dockerfile "copies nothing from the build context". The independent review raised
it; the file is `wave-owner`'s but was outside this table, so it was reported
rather than edited, and the Project Owner widened the table for it on 2026-09-22.
The comment now states both reasons the context is this directory, including that
`context: .` is load-bearing rather than merely convenient.

## Delivery

Branch, commit, push, open a pull request. The Project Owner merges.

Per root `AGENTS.md` §14 an independent review of the complete diff is obtained
before the pull request is opened, and its findings are reported with the work
including any not acted on.

## Independent Review

One reviewer, holding no implementation context, reviewed the diff against this
contract. One `P1`, six `P2`, seven `P3`. Every finding was re-verified in the
container before acting; none was wrong.

| ID | Severity | Finding | Resolution |
|---|---|---|---|
| P1-1 | `P1` | The `114 MB` parallel-worker peak, cited in five places and twice as proof, does not reproduce. Reviewer measured `60 MB`. | **Upheld, and it goes further than the reviewer found.** Re-measuring gave `60 MB` five times, then `72`, then `74` eleven times — so `114 MB` is irreproducible on demand, and citing it as the peak was wrong. But nineteen samples span `60`–`114 MB`, and the single-process figure moves too (`126.5 MB` three times, `170.5 MB` once). **Every specific number either of us quoted was one sample of a noisy quantity.** The contract now records ranges with sample counts, drops the claim to diagnose PR #9, and rests the decision on the highest peak observed rather than on a margin. |
| P2-1 | `P2` | "Single-process analysis exceeded `128M`" was attributed to `main`, where it completes at `126.5 MB`. The crash belongs to `W0-BE-010`'s tree. | Confirmed, 3 runs, `126.5 MB` every time. Corrected in all four places. The crash is now attributed to the tree it happens on, and what shows `128M` was insufficient is not a margin but that the same analysis reports `170.5 MB` once the ceiling is raised and `126.5 MB` whenever the ceiling binds. |
| P2-2 | `P2` | Three statements still asserted the CI causation the same contract called unproven, including a Scope bullet promising proof that criterion 3 said could not be produced. | Confirmed by reading. All three rewritten, and the contract now has a section stating what it does not claim. |
| P2-3 | `P2` | Criterion 4 required an observation that is false on this branch. | Confirmed. Rewritten to require the control's *observed* result, and to say that reporting a failure here would be false. |
| P2-4 | `P2` | The diff makes a comment in `docker/compose.yaml` false, and that file is not in Allowed Areas. | Confirmed by reading the file. Reported rather than edited, since `AGENTS.md` §8 forbids editing outside the approved table; the Project Owner then widened the table and the comment is fixed. It now gives both reasons for `context: .`, the second of which is new: the build fails without it. |
| P2-5 | `P2` | Contract said `Approved`; the index said `Draft` and "Awaiting sign-off". | The approval is real, given 2026-09-22 before implementation began. The index cells were written before it and were stale. Corrected there. |
| P2-6 | `P2` | The renumbering left `W0-BE-010` depending only on `W0-INT-002`, contradicting the new prose. | Confirmed. `W0-BE-010`'s dependency cell updated. |
| P3-1 | `P3` | "Choosing neither is not a neutral default" is misleading: both shipped `php.ini-*` files also set `memory_limit = 128M`. | **Confirmed in the container** — `php.ini-development:433` and `php.ini-production:435` are both `128M`, and `php -n` is also `128M`. This mattered: the missing `php.ini` is not why the ceiling was `128M`. Reframed in Decision 2, `docker/php.ini` and `docker/README.md`. |
| P3-2 | `P3` | The Goal overstated: only `memory_limit` stops being inherited. | Confirmed. Goal rewritten. |
| P3-3 | `P3` | `php --ini` still reports `(none)`; criterion 1's first branch was unsatisfiable by construction; the README never said the file lands as `conf.d/zz-baraka-bozor.ini`. | Confirmed. Criterion 1 reduced to the one satisfiable check; the README and Implementation Notes now say the main `php.ini` stays absent by design. |
| P3-4 | `P3` | "the value PHPStan's documentation recommends for Laravel" is unverifiable from this repository. | Could not verify it either. Claim dropped; `512M` rests on the measurement alone. |
| P3-5 | `P3` | Excluding a workflow change conflated a duplicated *flag* with a CI *assertion*, which `W0-INT-002` already establishes as a pattern. | Fair. The Excluded entry now distinguishes them and says the assertion is a defensible separate change rather than a bad idea. |
| P3-6 | `P3` | Inserting a task into a Project-Owner-approved order left no dependency-map row and no change-log entry naming an approver. | Confirmed. Both added. |
| P3-7 | `P3` | Evidence validity concluded where `tasks/README.md` §13 gives the Project Owner the decision, on the implementing agent's recommendation. | Confirmed. Rewritten as a recommendation. |

The reviewer noted it did not run PHPStan against `W0-BE-010`'s tree, since that
needs a worktree it would not create for a review, and that this was the one
measurement that would settle `P1-1`. That run was made during implementation and
is quoted under **Why**; the `126.5 MB` figure on `main` was re-measured
afterwards and is quoted there too.
