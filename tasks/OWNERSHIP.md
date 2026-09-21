# BarakaBozor — Path Ownership Map

## Purpose

Several implementing agents work at once, one per track, each in its own git worktree. This file says which paths each track may modify. It is the mechanism that keeps two concurrent agents out of the same file, and it is binding: a task contract's **Allowed Areas** section must agree with its track's row here, and root `AGENTS.md` Section 8 forbids editing a path owned by another track.

Rules:

1. **One owner per path.** Two tracks never own the same path. A path absent from this file is owned by nobody and must not be modified without a Project Owner decision.
2. **Shared-caretaker paths belong to the wave owner**, listed once per wave below, and change only through a dedicated task and pull request. Feature tracks list them under `Do not modify`.
3. **Read is always allowed.** Ownership restricts modification, never inspection.
4. **The map is approved at the wave planning gate**, together with the decomposition and the declared track width (`tasks/README.md` Section 5). Approving the map does not close the rest of that gate: a wave may have an approved map while its specification decisions are still open, and the wave index records which entry-gate items remain unchecked.
5. **Reassignment is a wave-level event.** If work turns out to need a path another track owns, stop and raise it; do not negotiate it between agents.

The primary checkout stays on `main` and clean. It is the Project Owner's review and merge surface, never a track workspace.

## Wave 0 — Foundation

Declared width: 3 concurrent tracks. Approved by the Project Owner on 2026-09-21.

Every path below is repository-relative and carries the correct prefix — the Laravel application lives under `backend/`, the Flutter application under `frontend/`, and a path written without that prefix would own nothing. Many of these paths do not exist yet: the whole `frontend/` tree, `tests/fixtures/api/**`, `.github/workflows/**` and the Auth module are created by later Wave 0 tasks. Each resolves to its real location once its owning task creates it.

| Track | Owns (modify) | Notes |
|---|---|---|
| `wave-owner` | **all of `backend/**`** except the paths `auth-backend` owns below; `frontend/pubspec.yaml`, `frontend/pubspec.lock`, `frontend/lib/app/router.dart`, `frontend/lib/app/providers.dart`, `tests/fixtures/api/**`, `.github/workflows/**`, `docker/**`, `tasks/**`, `docs/**` | The schema task, the module registries (`D-8`), the shared fixture directory (`D-9`), the runtime, CI, and all bookkeeping. One task at a time, never concurrent with itself. |
| `auth-backend` | `backend/app/Modules/Auth/**`, `backend/routes/api/v1/auth.php`, `backend/tests/Feature/Api/V1/Auth/**`, `backend/tests/Unit/Auth/**` | Six-role identity, Staff login, first-login gate, blocking, Customer OTP behind the fake `SmsGateway`. |
| `client-foundation` | `frontend/lib/**` **except** `frontend/lib/app/router.dart` and `frontend/lib/app/providers.dart`, which `wave-owner` owns; `frontend/test/**` | Flutter scaffold, Dio/secure storage, auth UX, role shells. Once the `D-8` registry task lands, each feature owns its own route fragment and still never edits the root router or root providers. |

`tests/fixtures/api/**` is created by `wave-owner`. From Wave 1 onward a fixture file is owned by whichever track owns the endpoint it describes, and both the backend and the frontend side of that endpoint assert against it. In Wave 0 it stays with `wave-owner`.

Wave 0 exception: until the `D-8` registry task is Accepted, per-module route files do not exist yet, so `auth-backend` routes are added by `wave-owner` on request rather than by the track itself. This exception exists only in Wave 0 and must not be carried forward.

## Wave 1 and later

Filled in at each wave planning gate, before the first task of that wave is approved. An empty section means the wave has not been planned yet, not that ownership is unrestricted.

## Change Log

| Date | Change | Reason |
|---|---|---|
| 2026-09-21 | File created with the Wave 0 map | Adoption of the wave execution model, `AUD-022` |
| 2026-09-21 | Wave 0 map approved by the Project Owner | Wave 0 planning gate, `tasks/README.md` Section 5 step 7 |
| 2026-09-21 | `backend/app/**` and `backend/tests/**`, both excluding the Auth trees, assigned to `wave-owner` | Independent review found them unowned while `W0-BE-011` must modify the existing `backend/app/Models/User.php` and most tasks need tests outside `Auth/`. Project Owner approved the assignment with the map. |
| 2026-09-21 | Enumeration of backend paths replaced by "all of `backend/**` except what `auth-backend` owns" | `W0-INT-001` needed `backend/.env.example` and `backend/phpunit.xml`, which the enumeration had also missed. Project Owner chose the general rule over patching the list each task. |
