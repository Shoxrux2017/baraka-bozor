# W0-BE-010 — Module route registry

## Metadata

| Field | Value |
|---|---|
| Task ID | `W0-BE-010` |
| Wave | `0 — Foundation` |
| Area | `Backend` |
| Status | `Approved` — Project Owner, 2026-09-22 |
| Depends on | `W0-INT-002` — Accepted, PR #7; `W0-INT-004` — merged as PR #11 |
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
| 4 | Duplicate route **names** across modules must fail the test suite, not be silently resolved. | Laravel keeps the **first** registration of a name: `RouteCollection::addLookups` guards with `! $this->inNameLookup($name)`. Two tracks each naming a route `orders.show` would leave the second route unreachable by name while `route()` resolved to the first module, and which one won would depend on filename sort order. |

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
- [ ] The three existing test files still pass unchanged: `ApiFoundationTest`, `ApiExceptionRendererTest`, `TestDatabaseIsolationTest`.
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

### CI history on this branch

Every run from 2026-09-22 04:35 to 05:01 failed, and always at the same step:

```text
Child process error (exit code 255):  while running parallel worker
```

No file was named, because `255` is PHP's exit code for a fatal error and
PHPStan's parallel mode does not surface a dead worker's output. Five runs, five
failures, while the same commands passed locally.

`W0-INT-004`, merged as PR #11, raised the ceiling from PHP's default `128M` to
`512M`. The container was on the default because the `php:8.4-cli` image activates
no `php.ini`.

**What that establishes.** The forward merge changes nothing under `backend/**`
— independently verified byte-identical — so the memory ceiling is the only
variable between the five failing heads and the two passing ones (`35711716471`
on `8919161` and `35712055267` on `b50d896`, every step green, PHPStan included).
On this tree at `128M`, `phpstan analyse --debug` dies outright with
`Allowed memory size of 134217728 bytes exhausted`. The ceiling was binding.

**What it does not establish**, and this record previously deleted: the mechanism
inside the parallel worker was never reproduced outside CI. Thirteen local runs at
`128M` refused to fail — cold result cache (5), worker count forced to four (3),
container restricted to four CPUs (3), and two more by the second reviewer. All
green. `--debug` is single-process, as `docker/php.ini` says, so its crash cannot
show what a worker did. Why the ceiling binds in CI's parallel run and not in this
machine's is still unknown. `.github/workflows/backend.yml` runs bare
`phpstan analyse`, so the next dead worker will name no file either; that is
tracked as a Wave 0 risk.

**Peak figures, with sample counts, because that is the lesson here.** On this tree
at `512M`, `--debug` reports `128.5 MB` (5 samples), `138.5 MB` (1) and `190.5 MB`
(1). The modal figure is barely over the old `128 MiB` ceiling, which is consistent
with a crash at `128M` but is not the comfortable margin an earlier draft of this
section claimed.

**Three statements made during this diagnosis were unsound, and the third was in
the first draft of this very section.** A local run of `5/5 green` was offered as
evidence the analysis was fine; it proved nothing, because this machine has 12
cores (measured) against a standard hosted runner's 4 (documented, not measured
here) and PHPStan sizes its workers from the CPU count. A `114 MB` worker peak was
reported as measured fact; the independent review of `W0-INT-004` measured `60 MB`,
re-measurement gave a `60`-`114 MB` range, and the claim was withdrawn before that
PR opened. Then `190.5 MB` was written here as the confirming measurement, in a
section whose own point was not to do that; re-measurement gives it once in seven
samples. The conclusion held each time. The evidence offered for it did not, and
that is the part worth remembering.

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

Do not modify: `backend/bootstrap/app.php`, `backend/composer.json`, `backend/composer.lock`, `backend/database/migrations/**`, `backend/app/Exceptions/**`, the three existing test files, `backend/phpunit.xml`, `docker/**`, `frontend/**`, `docs/01`–`docs/06`, `docs/08`, `docs/09`, `AGENTS.md`, `tasks/OWNERSHIP.md`.

## Delivery

PR title: `W0-BE-010 — Module route registry`, target `main`. The agent commits, pushes and opens the PR; the Project Owner merges.

## Independent Review

Reviewed 2026-09-22 by an agent with no implementation context, which reproduced every number quoted **at that time** and tested the loader against a real bootstrapped application. Result: 0 P1, 1 P2, 7 P3.

A second reviewer checked the forward merge of `main` and the CI-history section below, both of which postdate the review above: 0 P1, 2 P2, 7 P3. It verified the merge resolution exhaustively and found nothing lost from either side. Its two `P2`s were the stale `Depends on` cell corrected above, and an overstatement in the CI-history section, corrected there.

| ID | Severity | Finding | Resolution |
|---|---|---|---|
| R-01 | **P2** | The duplicate-route-name test was theatre. `assertGreaterThan(1, ...)` passes *because* the collision happened, so it asserted the collision was **not** prevented, the inverse of Decision 4 and acceptance criterion 7. Nothing in the suite would have failed the day two tracks collided, and the wave index already cited this pull request as evidence that concurrent tracks cannot collide on shared files. | **Fixed.** `load()` now records which file registered each route name and throws, naming the name and both files. The test is `expectException` on all three strings. **Proven to bite**: with the guard disabled the test fails with `Failed asserting that exception of type "RuntimeException" is thrown`, and the guard was restored afterwards. |
| R-02 | P3 | The docblock and the commit message claimed `glob()` returns filesystem order. It does not: PHP sorts alphabetically unless `GLOB_NOSORT`. Verified in the container, where directory order was `z-last, m-mid, a-first` and `glob()` returned `a-first, m-mid, z-last`. | **Fixed.** The real justification is locale independence, since `glob()` sorts through the C library collation while `SORT_STRING` compares bytes. The docblock now says that. The commit message is history, so the pull request carries the correction. |
| R-03 | P3 | The sorted-order test could not fail. Because `glob()` already sorts, removing `sort()` left it green, and sorting a copy to compare against the original only asserts that an array is sorted. | **Fixed by deletion.** The remaining test asserts the exact expected filenames, which satisfies criterion 3 and can fail. A test that cannot fail is worse than no test. |
| R-04 | P3 | The no-production-endpoint test probed one unknown path, so a real added endpoint would have left it green, and it duplicated an assertion already in `ApiFoundationTest`. | **Fixed.** It now asserts that the whole route table contains no `api/v1` route. |
| R-05 | P3 | The reachability test called `load()` outside any group, so fixture routes landed at `fixture/first` rather than `/api/v1/fixture/first`. The property every feature task depends on, prefix and `api` middleware inherited and applied once, was untested. | **Fixed.** Fixtures now load inside `Route::middleware('api')->prefix('api/v1')->group(...)`, and the test asserts the URI, the middleware and a real request to `/api/v1/fixture/first`. |
| R-06 | P3 | A comment about empty directories sat above the `sort()` call, which has nothing to do with emptiness. | **Fixed.** Moved to the return. |
| R-07 | P3 | Both new files omitted `declare(strict_types=1)` and the test class was not `final`, unlike the hand-written classes already in the repository. | **Fixed** on both new files. |
| R-08 | P3 | The wave index still described this task as including the Flutter route-fragment registry, so accepting it would leave the Flutter half of `D-8` with no carrier anywhere. | **Fixed.** `W0-BE-010` now covers the backend registry only, `S01-FE-001` carries the Flutter half, and the change log records the move. (Named by task ID rather than order number, because `W0-INT-004` later renumbered them to 5 and 11.) |

**Reported, not acted on.**

- `TestDatabaseIsolationTest` also omits `declare(strict_types=1)` and `final`. It is outside this contract Allowed Areas, so changing it here would be unrelated churn. A Project Owner call.
- `tasks/OWNERSHIP.md` Rule 2 refers to shared-caretaker paths, but the Wave 0 section never enumerates them: it grants `wave-owner` all of `backend/**` wholesale. This contract claim that `routes/api.php` is such a path is therefore not literally supported by any list, although the modification is fully authorised either way. Worth the Project Owner deciding whether Wave 0 should enumerate them.
- A module file that returns early silently skips its remaining routes, and the loader still reports the file as loaded. A module-author foot-gun outside this contract scope.
- `route:cache` in production would bypass the missing-directory guard at request time, but `route:cache` itself would throw at deploy, and route caching is explicitly out of scope.

**Checked and confirmed by the reviewer**, recorded because it was the main risk in the design: `require` inside a static method does inherit the group, so the prefix is applied once and the `api` middleware is inherited; a missing directory produces a `500 server_error` on every request rather than a silent 404, with the path reaching only the log and never the response body; test fixtures cannot leak into the production route table, because `phpunit.xml` scans only `tests/Unit` and `tests/Feature`; and every protected path is byte-identical to `main`, verified by blob hash rather than by diff stat.
