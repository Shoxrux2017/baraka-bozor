# W0-INT-002 — GitHub Actions backend checks, required on `main`

## Metadata

| Field | Value |
|---|---|
| Task ID | `W0-INT-002` |
| Wave | `0 — Foundation` |
| Area | `Integration` |
| Status | `Approved` — Project Owner, 2026-09-21 |
| Depends on | `W0-INT-001` — Accepted, PR #6 |
| Blocks | every concurrent track in every wave |
| Track | `wave-owner` |
| Branch | `task/w0-int-002-github-actions-backend-checks` |

## Goal

Every pull request against `main` runs the backend test suite, Pint and PHPStan against a real PostgreSQL database, automatically, and cannot be merged until they pass.

This is the task the parallel model rests on. Concurrent tracks merge on the strength of a green check; until that check exists and is required, width above one is unsafe.

## Scope

**In:**

- One GitHub Actions workflow running on pull requests targeting `main`, and on pushes to `main`.
- It runs **the same commands `docker/README.md` documents**, through the same `docker/compose.yaml` and `docker/app.Dockerfile`: bring the stack up, install dependencies, prepare the environment, then `php artisan test`, `vendor/bin/pint --test`, `vendor/bin/phpstan analyse`.
- A concurrency rule so a new push to a branch cancels that branch's superseded run.
- `docker/README.md` gains a short section stating that CI runs these same commands, so a change to one must be made in the other.

**Out:**

- Frontend checks. No Flutter exists yet; the frontend track's first task adds them.
- Deployment, release building, container publishing, environment promotion.
- Coverage thresholds, mutation testing, a PHP or PostgreSQL version matrix. One pinned version pair, matching `docker/compose.yaml`.
- Branch protection itself. Making the check **required** is a repository setting only the Project Owner can change; see Delivery.
- Any application code, migration, route or configuration change.

## Governing Specification

| Source | Section | What it governs here |
|---|---|---|
| `docs/06-roadmap.md` | §1, §16 | wave model; the Definition of Done's green-CI obligation |
| `docs/07-architecture.md` | §2, §33 | the pinned stack; real PostgreSQL for integration |
| `tasks/README.md` | §8F merge queue | CI is a required check; the green run must be on the merged head |
| `tasks/README.md` | §13 | evidence validity — what a green run is evidence for |
| `AGENTS.md` | §10, §11 | tests stay deterministic; no check may be relaxed to pass |
| `tasks/OWNERSHIP.md` | Wave 0 | `.github/workflows/**` and `docker/**` belong to `wave-owner` |
| `W0-INT-001` contract | Decision 1 | why the runtime is a container, which CI must not diverge from |

## Decisions

| # | Decision | Why |
|---|---|---|
| 1 | CI builds and runs **the project's own `docker/app.Dockerfile` through `docker/compose.yaml`**, rather than configuring a separate PHP with an action. | `W0-INT-001` exists precisely so local, CI and production share one runtime. A separately configured PHP would have a different extension set — the `intl` gap found during `W0-INT-001` is exactly that class of divergence — and a green CI run would stop meaning what a local run means. |
| 2 | CI runs the commands `docker/README.md` documents, verbatim. | It makes the documented procedure continuously tested. If the README drifts from reality, CI goes red instead of a new developer discovering it. |
| 3 | No caching of Docker layers or Composer packages in the first version. | Caching is the most common source of CI runs that pass or fail for reasons unrelated to the change. The suite is small; a few minutes per run is acceptable. Revisit when run time actually hurts. |
| 4 | One pinned PHP and PostgreSQL pair, no matrix. | `docs/07` §2 fixes one stack. A matrix would test combinations this project will never deploy. |
| 5 | The workflow fails on the **first** failing check rather than continuing. | A red run's first message should be the cause. Collecting every failure matters when a matrix exists; here it just buries the signal. |

## Implementation Notes

- **The workflow validates itself.** For a `pull_request` event from a branch in this repository, GitHub runs the workflow as it exists on the pull request branch, so the pull request that adds the workflow is also the evidence that it works. That run is this task's verification.
- **The stack needs the database healthy before anything else.** `docker/compose.yaml` already gates `app` on the `db` healthcheck, so `up -d --build` is sufficient; do not add sleeps. `AGENTS.md` §10 forbids arbitrary waits.
- **`.env` and `vendor/` do not exist on a fresh checkout**, exactly as in a fresh worktree. The workflow must run the same `composer install`, `cp .env.example .env`, `php artisan key:generate` steps the README documents. A missing `.env` does not fail the suite — it produces warnings and exercises nothing, which is the failure mode `W0-INT-001` documented.
- **`COMPOSE_PROJECT_NAME` and `DB_HOST_PORT` are unset in CI and should stay unset.** One runner, one stack; the defaults are correct there.
- **No secret is needed.** Every credential involved is a local development default already in the repository. Do not add repository secrets for this workflow.
- **Branch protection is tracked in the wave index Section 7 Dependency/Checkpoint Map**, not as an entry-gate checkbox; the Delivery section below says so.
- **Do not weaken a check to make the first run green.** If Pint or PHPStan fails in CI while passing locally, the cause is a real environment difference and belongs in the diff, not in a relaxed configuration.

## Acceptance Criteria

- [ ] A workflow file exists under `.github/workflows/` and triggers on `pull_request` targeting `main` and on `push` to `main`.
- [ ] The run builds the stack from `docker/compose.yaml` and `docker/app.Dockerfile`, not from a separately configured PHP.
- [ ] The run executes `php artisan test`, `vendor/bin/pint --test` and `vendor/bin/phpstan analyse`, all inside the container.
- [ ] The suite in CI connects to PostgreSQL and to a `_test` database — `TestDatabaseIsolationTest` proves it, and must be green in the CI run.
- [ ] A superseded run on the same branch is cancelled by the next push.
- [ ] The run is green on this task's own pull request, and its log is quoted in the pull request.
- [ ] A deliberately introduced failure makes the run red. Demonstrated once and reverted, with both logs quoted — a check never observed failing is not known to work.
- [ ] No repository secret was added, and no credential beyond the existing local development defaults appears in the workflow.
- [ ] `docker/README.md` states that CI runs the same commands.
- [ ] No application code, migration, route, test or dependency change.
- [ ] `git diff --check` passes.
- [ ] Independent review completed; P1 and P2 findings resolved.

## Verification

**The CI run itself** is the verification for this task. Quote in the pull request:

- the green run's job log, showing the test, Pint and PHPStan steps and their output;
- the red run from the deliberate-failure demonstration, and the commit that reverted it.

**Locally, before pushing**

```text
docker compose -f docker/compose.yaml up -d --build
docker compose -f docker/compose.yaml exec app php artisan test
docker compose -f docker/compose.yaml exec app vendor/bin/pint --test
docker compose -f docker/compose.yaml exec app vendor/bin/phpstan analyse
git diff --check
```

The same commands CI will run, so a local failure is caught before a runner minute is spent.

**Project Owner manual step, after merge**

In the repository settings, add a branch protection rule on `main` requiring this workflow's check to pass before merging. The agent cannot and must not change repository settings. Until this is done the check is advisory, and `tasks/README.md` §8F is not yet satisfied.

## Allowed Areas

Track: `wave-owner`

| Path or area | Action | Reason |
|---|---|---|
| `.github/workflows/backend.yml` | Create | the workflow |
| `docker/README.md` | Modify | one section stating CI runs these same commands |
| `tasks/integration/wave-00/W0-INT-002-github-actions-backend-checks.md` | Create | this contract |
| `tasks/WAVE_00_TASK_INDEX.md` | Modify | task status bookkeeping |

Do not modify: `backend/**`, `docker/compose.yaml`, `docker/app.Dockerfile`, `frontend/**`, `docs/01`–`docs/09`, `AGENTS.md`, `tasks/OWNERSHIP.md`.

The two Docker files are deliberately out of scope. If CI cannot run without changing them, that is a defect in `W0-INT-001` and belongs in its own task, not hidden here.

## Delivery

PR title: `W0-INT-002 — GitHub Actions backend checks`, target `main`.

After merge the Project Owner adds the branch protection rule. The task becomes `Accepted` when the result is on `origin/main` with local `main` synchronized and clean; the **branch protection rule is tracked separately** in the wave index Section 7 Dependency/Checkpoint Map until done.

## Independent Review

Filled in before the pull request is opened.

| ID | Severity | Finding | Resolution |
|---|---|---|---|
