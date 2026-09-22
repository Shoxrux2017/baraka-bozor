# W0-INT-004 — Explicit PHP configuration in the container runtime

## Metadata

| Field | Value |
|---|---|
| Task ID | `W0-INT-004` |
| Wave | `0 — Foundation` |
| Area | `Integration` |
| Status | `Approved` — Project Owner, 2026-09-22 |
| Depends on | `W0-INT-002` — Accepted, PR #7 |
| Blocks | `W0-BE-010` (PR #9), and therefore every remaining Wave 0 task |
| Track | `wave-owner` |
| Branch | `task/w0-int-004-container-php-memory-limit` |

## Goal

Give the container runtime an explicit PHP configuration file, so that no tool
in it runs under PHP's built-in fallback defaults.

`docker/app.Dockerfile` builds on `php:8.4-cli`. That image deliberately ships
**no active `php.ini`** — it places `php.ini-development` and
`php.ini-production` in `/usr/local/etc/php/` and expects the build to choose
one. This project chose neither, so every process in the container runs under
PHP's compiled-in fallbacks, including `memory_limit = 128M`.

Verified in the container:

```text
memory_limit: 128M
ini file: NONE
```

## Why now

PHPStan fails deterministically in CI on `W0-BE-010` (PR #9) with:

```text
Child process error (exit code 255):  while running parallel worker
```

The message names no file, because `255` is PHP's exit code for a fatal error
and PHPStan's parallel mode does not surface a dead worker's output. Running
the same analysis single-process in the same image reproduces the cause
verbatim:

```text
PHPStan process crashed because it reached configured PHP memory limit: 128M
Allowed memory size of 134217728 bytes exhausted (tried to allocate 131072 bytes)
```

The last file printed before the crash is `tests/Feature/Api/V1/ApiFoundationTest.php`,
so it died on the next one — the test `W0-BE-010` adds. That is why `main`
passes at 19 analysed files and the branch fails at 21.

How thin the margin already was, measured on `main` with this runtime: **PHPStan's
parallel worker peaks at `114 MB` against the old `128 MB` ceiling.** Fourteen
megabytes of headroom on a branch that passes. `W0-BE-010` adds the loader and a
test that exercises it.

### What is proven, and what is not

Stating this precisely matters, because an earlier claim about this same failure
rested on a local run that could not have shown what it was said to show.

**Proven, by direct observation in this image:**

- the container loaded no `php.ini` and ran at `memory_limit = 128M`;
- single-process analysis (`--debug`) exceeds `128M` and dies with
  `Allowed memory size of 134217728 bytes exhausted`, naming the file it died
  on; the same run at `512M` completes;
- on `main`, the parallel worker peaks at `114 MB` against that `128 MB`
  ceiling.

**Not proven:** that CI's `Child process error (exit code 255)` *is* this. The
CI-identical invocation could not be made to fail at `128M` on the development
machine — not with the result cache cold, not with PHPStan's worker count forced
to four, and not with the container restricted to four CPUs, which was the
difference the first hypothesis rested on. Five runs, three runs and three runs
respectively, all green.

The link is therefore an inference: `255` is PHP's exit code for a fatal error,
the only fatal this runtime can produce here is memory exhaustion, the headroom
was `14 MB`, and the failure appeared exactly when two files were added. Strong,
and not a demonstration.

**The decisive test is CI on `W0-BE-010`'s merged head**, which is the only
environment where the failure occurs. This task removes a real defect whose
merit does not depend on that outcome: a runtime with no configuration file and
`14 MB` of headroom is worth fixing whether or not it is also this bug.

## Scope

### Included

- An explicit `php.ini` in the image, setting `memory_limit`.
- The value chosen against a measured peak, with the measurement recorded.
- `docker/README.md` stating that the image sets PHP configuration explicitly
  and why, so the next person does not re-derive it from a crash.
- Proof that the CI check which currently fails on `W0-BE-010` passes with this
  change and still fails when it should.

### Excluded

- Any change to PHPStan's level, baseline, configuration or analysed paths.
  Nothing about this task makes the analyser more permissive; the analysis that
  could not complete will now complete.
- Any change to `backend/phpstan.neon`. The defect is not in PHPStan's
  configuration.
- Any change to `.github/workflows/backend.yml`. With the image fixed the
  workflow needs no flag, and adding one would put the number in two places
  that can drift.
- Raising `memory_limit` for production. No deployable image exists; `W0-INT-001`
  Decision 1 scopes this image to development and CI.
- `W0-BE-010` itself. Merging it forward and re-running its verification belongs
  to that task, per root `AGENTS.md` §11.
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
| `W0-INT-002` contract | Decision 1, 2 | CI runs this image and these documented commands |

## Decisions

| # | Decision | Why |
|---|---|---|
| 1 | Fix it in **the image**, not in the PHPStan invocation. | The defect is that the runtime has no configuration, and it reaches every tool in the container. `php artisan test` runs under the same `128M` today. A flag on one command would leave the same landmine for the test suite to hit in a later wave, with the same unreadable symptom. |
| 2 | A dedicated `docker/php.ini` copied into `/usr/local/etc/php/conf.d/`, not one of the image's shipped `php.ini-*` files. | The shipped files set dozens of unrelated values. A small file holding only what this project deliberately sets is reviewable, and `conf.d/` is the mechanism the base image documents for exactly this. |
| 3 | `memory_limit = 512M`. | Measured on `main` with this runtime: `94.5 MB` in PHPStan's main process and `114 MB` in its parallel worker, against the `128M` fallback the image was running under. The margin was 14 MB on a passing branch, which is why the failure looked mysterious rather than gradual. `512M` is about four and a half times the observed peak — headroom for several waves rather than a number to revisit each wave — and it is the value PHPStan's own documentation recommends for a Laravel project. |
| 4 | No other setting is changed in this task. | `AGENTS.md` §8 forbids unrelated change. Every other default is either correct or has not been shown wrong. A setting added speculatively here would be indistinguishable from a setting added for a reason. |
| 5 | The value is recorded in exactly one place, and `docker/README.md` points at it rather than repeating it. | Two copies of a number drift, and the drift is silent. |

## Implementation Notes

- `conf.d/` files are read in alphabetical order after the main `php.ini`. Name
  the file so its precedence is not accidental.
- `docker compose up -d` will not pick up a Dockerfile change on its own. The
  verification must build, and must confirm it is running the rebuilt image
  rather than a cached container.
- The measurement in Decision 3 came from `vendor/bin/phpstan analyse -v`, which
  prints the main-process and worker peaks. Re-measure after the change so the
  recorded number describes the delivered runtime.

## Acceptance Criteria

1. `php -r 'echo php_ini_loaded_file();'` in the container names a real file, or
   `php --ini` shows the `conf.d` file as scanned.
2. `php -r 'echo ini_get("memory_limit");'` in the container returns `512M`.
3. `vendor/bin/phpstan analyse` completes in the container on the
   `W0-BE-010` branch merged with this change, reporting no error. Note what
   this does and does not show: it also completed at `128M` on the development
   machine, so it confirms no regression rather than a repair.
4. A negative control is run and its result reported **as observed**, not as
   expected. Single-process analysis must fail at `128M` and pass at `512M`, and
   that is reproducible. The parallel failure CI shows could not be reproduced
   here; the contract requires that to be stated plainly rather than presented
   as a demonstration, and requires the CI run on `W0-BE-010`'s merged head to
   be named as the real test.
5. `php artisan test` still passes, and its run is not slowed materially.
6. CI is green on this branch.
7. `docker/README.md` states that the image sets PHP configuration explicitly,
   why a missing `php.ini` is a defect rather than a default, and where the
   value lives.
8. No file outside Allowed Areas is touched.

## Verification

Observed and quoted, per `AGENTS.md` §11:

- `docker compose -f docker/compose.yaml up -d --build`
- `docker compose -f docker/compose.yaml exec -T app php --ini`
- `docker compose -f docker/compose.yaml exec -T app php -r 'echo ini_get("memory_limit"), PHP_EOL;'`
- `docker compose -f docker/compose.yaml exec -T app php artisan test`
- `docker compose -f docker/compose.yaml exec -T app vendor/bin/pint --test`
- `docker compose -f docker/compose.yaml exec -T app vendor/bin/phpstan clear-result-cache`
- `docker compose -f docker/compose.yaml exec -T app vendor/bin/phpstan analyse -v`
- the negative control for criterion 4, with its output
- `git diff --check`
- the CI run on this branch

Deliberately **not** run: the full Wave 0 checkpoint, any frontend check, or any
broader suite. `AGENTS.md` §11 reserves those.

### Evidence validity

Per `tasks/README.md` §13, this changes the runtime every previous PASS was
observed on. It does not change any application code, schema, route or public
contract, and it only raises a ceiling — nothing that passed under `128M` can
fail under `512M` for that reason. The accepted tasks' evidence therefore
stands, and the CI run on the merged head re-establishes it in any case.

## Allowed Areas

Nothing outside this table may be created, modified or deleted.

| Path or area | Action | Reason |
|---|---|---|
| `docker/php.ini` | Create | the explicit configuration |
| `docker/app.Dockerfile` | Modify | copy it into the image |
| `docker/README.md` | Modify | one section recording what is set and why |
| `tasks/integration/wave-00/W0-INT-004-container-php-memory-limit.md` | Create | this contract |
| `tasks/WAVE_00_TASK_INDEX.md` | Modify | add the task row, close the risk row |

Explicitly outside: `backend/**`, `.github/workflows/**`, `frontend/**`,
`docs/**`.

## Delivery

Branch, commit, push, open a pull request. The Project Owner merges.

Per root `AGENTS.md` §14 an independent review of the complete diff is obtained
before the pull request is opened, and its findings are reported with the work
including any not acted on.

## Independent Review

| ID | Severity | Finding | Resolution |
|---|---|---|---|
| | | *to be filled before delivery* | |
