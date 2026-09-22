# W0-BE-010 — Module route registry

## Metadata

| Field | Value |
|---|---|
| Task ID | `W0-BE-010` |
| Wave | `0 — Foundation` |
| Area | `Backend` |
| Status | `Approved` — Project Owner, 2026-09-22 |
| Depends on | `W0-INT-002` — Accepted, PR #7 |
| Blocks | every feature task in every wave |
| Track | `wave-owner` |
| Branch | `task/w0-be-010-module-route-registry` |

## Goal

A backend module declares its API routes in its own file, and they are registered automatically. After this task no feature task needs to edit `routes/api.php`, so two concurrent tracks cannot collide there.

## Scope

**In:**

- `backend/routes/api/v1/` exists in git and is where a module puts its routes.
- `backend/routes/api.php` becomes a loader: it collects every `*.php` file in that directory, in a deterministic order, and requires each one.
- The collection logic lives in a small testable class, not inline in the route file, so it can be exercised against a fixture directory without adding fake production endpoints.
- The loader **fails loudly** if its directory is missing. A silently empty API is the failure mode this wave has already met twice.
- Focused tests for the loader, including the negative cases.

**Out:**

- **The Flutter half of `D-8`.** No Flutter project exists yet; `frontend/` holds only `AGENTS.md`. The feature route-fragment registry belongs to `S01-FE-001`, the Flutter scaffold task, and that task's contract must carry it. This contract cannot deliver it and must not pretend to.
- Any actual endpoint. No module route file with real routes is created — that would be the fake production endpoint `S01-BE-001`'s contract forbids.
- Middleware groups, rate-limiter definitions, route caching, a second API version. Each arrives with the task that needs it.
- `bootstrap/app.php`. It already mounts `routes/api.php` at `api/v1`; nothing there needs to change, and leaving it untouched keeps one fewer shared file in the diff.

## Governing Specification

| Source | Section | What it governs here |
|---|---|---|
| execution-model design record | `D-8` | the decision this implements, approved 2026-09-21 |
| `docs/07-architecture.md` | §3 | `routes/api/v1/<module>.php` collected by one loop |
| `docs/09-api-contracts.md` | §1–§3 | the API is rooted at `/api/v1`; the error envelope must not change |
| `AGENTS.md` | §8 | the registry is one of the two named exceptions to the no-speculative-infrastructure rule |
| `AGENTS.md` | §9 | no dead code, no commented-out alternatives |
| `tasks/OWNERSHIP.md` | Wave 0 | `routes/api.php` is a shared-caretaker path and **this is its dedicated task** |

## Decisions

| # | Decision | Why |
|---|---|---|
| 1 | Module files are loaded in **sorted filename order**, not raw directory order. | `glob` and `scandir` return filesystem order, which differs between a developer's Windows machine, the Linux container and the CI runner. Route order decides which pattern wins when two overlap, so an unsorted loader is a defect that only appears on someone else's machine. |
| 2 | A **missing** directory is a hard failure; an **empty** one is fine. | Missing means the deployment is broken and every endpoint is silently gone — the class of failure that produced a green suite testing nothing earlier this wave. Empty is the legitimate state immediately after this task. |
| 3 | The loader is a class taking a directory path, not inline code in `routes/api.php`. | It can then be tested against a fixture directory, proving registration really happens, without adding an endpoint to the production surface. |
| 4 | Duplicate route **names** across modules must fail the test suite, not be silently resolved. | Laravel lets a later registration overwrite an earlier name. Two tracks each naming a route `orders.show` would produce a route that works in tests and resolves to the wrong controller in production. |

## Implementation Notes

- `routes/api.php` currently contains only a comment block. It is mounted by `bootstrap/app.php` with `apiPrefix: 'api/v1'`, so files the loader requires are already inside `/api/v1` and must not add the prefix again.
- The directory needs a tracked placeholder — git does not store empty directories, and `.gitkeep` must not be mistaken for a route file. Collect `*.php` only.
- Do not use `Route::group` around the whole set to add a prefix. The prefix is `bootstrap/app.php`'s job and duplicating it would produce `/api/v1/api/v1/...`.
- The existing `ApiFoundationTest` asserts that an unknown `/api/v1/...` path returns `404 resource_not_found`. The loader must not change that, and with an empty module directory it will not.

## Acceptance Criteria

- [ ] `backend/routes/api/v1/` exists in git with a tracked placeholder.
- [ ] `backend/routes/api.php` requires every `*.php` file in that directory and nothing else.
- [ ] Files are loaded in sorted filename order, and a test proves the order.
- [ ] A module file placed in a fixture directory has its routes actually registered and reachable — proven by a test, not by inspection.
- [ ] A missing directory raises a clear error naming the expected path.
- [ ] An empty directory registers no routes and raises nothing.
- [ ] A duplicate route name across two module files fails a test.
- [ ] `.gitkeep` and any non-`.php` file are ignored.
- [ ] No endpoint is added to the production API surface. `GET /api/v1/<anything>` still returns `404 resource_not_found`.
- [ ] The two existing test files still pass unchanged.
- [ ] `bootstrap/app.php`, `composer.json`, `composer.lock` and every migration are untouched.
- [ ] Pint and PHPStan pass.
- [ ] `git diff --check` passes.
- [ ] Independent review completed; P1 and P2 findings resolved.

## Verification

**Focused tests** — inside the container

```text
docker compose -f docker/compose.yaml exec app php artisan test --filter=ModuleRouteLoader
```

Required cases: loads every `*.php` file; deterministic sorted order; a fixture module's route is registered and reachable; missing directory fails with the path named; empty directory is a no-op; duplicate route name is detected; non-`.php` files ignored.

**Directly affected regression**

```text
docker compose -f docker/compose.yaml exec app php artisan test
```

The whole suite. Justified: this task changes how every route in the application is registered, so the existing `ApiFoundationTest` 404 and error-envelope assertions are exactly the surface at risk.

**Format / static**

```text
docker compose -f docker/compose.yaml exec app vendor/bin/pint --test
docker compose -f docker/compose.yaml exec app vendor/bin/phpstan analyse
```

**Always**

```text
git diff --check
git status --short
```

CI runs the same commands on the pull request and is now a required check.

## Allowed Areas

Track: `wave-owner`

| Path or area | Action | Reason |
|---|---|---|
| `backend/routes/api.php` | Modify | becomes the loader. **This is the dedicated task for this shared-caretaker path.** |
| `backend/routes/api/v1/.gitkeep` | Create | the module directory must exist in git |
| `backend/app/Support/Routing/ModuleRouteLoader.php` | Create | the testable collection logic |
| `backend/tests/Feature/Routing/ModuleRouteLoaderTest.php` | Create | focused tests |
| `backend/tests/Fixtures/routes/**` | Create | fixture module files, so registration is proven without a production endpoint |
| `docs/07-architecture.md` | Modify | §3 already describes the layout; correct it only if the delivered shape differs |
| `tasks/backend/wave-00/W0-BE-010-module-route-registry.md` | Create | the contract |
| `tasks/WAVE_00_TASK_INDEX.md` | Modify | task status bookkeeping |

Do not modify: `backend/bootstrap/app.php`, `backend/composer.json`, `backend/composer.lock`, `backend/database/migrations/**`, `backend/app/Exceptions/**`, the two existing test files, `backend/phpunit.xml`, `docker/**`, `frontend/**`, `docs/01`–`docs/06`, `docs/08`, `docs/09`, `AGENTS.md`, `tasks/OWNERSHIP.md`.

## Delivery

PR title: `W0-BE-010 — Module route registry`, target `main`. The agent commits, pushes and opens the PR; the Project Owner merges.

## Independent Review

Filled in before the pull request is opened.

| ID | Severity | Finding | Resolution |
|---|---|---|---|
