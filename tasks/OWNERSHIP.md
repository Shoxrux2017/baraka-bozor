# BarakaBozor — Path Ownership Map

## Purpose

Several implementing agents work at once, one per track, each in its own git worktree. This file says which paths each track may modify. It is the mechanism that keeps two concurrent agents out of the same file, and it is binding: a task contract's **Allowed Areas** section must agree with its track's row here, and root `AGENTS.md` Section 8 forbids editing a path owned by another track.

Rules:

1. **One owner per path.** Two tracks never own the same path. A path absent from this file is owned by nobody and must not be modified without a Project Owner decision.
2. **Shared-caretaker paths belong to the wave owner**, listed once per wave below, and change only through a dedicated task and pull request. Feature tracks list them under `Do not modify`.
3. **Read is always allowed.** Ownership restricts modification, never inspection.
4. **The map is approved at the wave planning gate**, together with the decomposition and the declared track width (`tasks/README.md` Section 5).
5. **Reassignment is a wave-level event.** If work turns out to need a path another track owns, stop and raise it; do not negotiate it between agents.

The primary checkout stays on `main` and clean. It is the Project Owner's review and merge surface, never a track workspace.

## Wave 0 — Foundation

Declared width: 3 concurrent tracks.

| Track | Owns (modify) | Notes |
|---|---|---|
| `wave-owner` | `database/migrations/**`, `routes/api.php`, `bootstrap/app.php`, `backend/composer.json`, `backend/composer.lock`, `frontend/pubspec.yaml`, `frontend/pubspec.lock`, `backend/config/**`, `.github/workflows/**`, `docker/**`, `tasks/**`, `docs/**` | The schema task, the module registries (`D-8`), the runtime, CI, and all bookkeeping. One task at a time, never concurrent with itself. |
| `auth-backend` | `backend/app/Modules/Auth/**`, `backend/routes/api/v1/auth.php`, `backend/tests/Feature/Api/V1/Auth/**`, `backend/tests/Unit/Auth/**` | Six-role identity, Staff login, first-login gate, blocking, Customer OTP behind the fake `SmsGateway`. |
| `client-foundation` | `frontend/lib/**` except `frontend/lib/app/router.dart` and `frontend/lib/app/providers.dart`, `frontend/test/**` | Flutter scaffold, Dio/secure storage, auth UX, role shells. Root router and root providers belong to `wave-owner` until the `D-8` registry task lands; afterwards each feature owns its own route fragment. |
| shared, no single owner | `tests/fixtures/api/**` (`D-9` shared fixtures) | Created by `wave-owner`. Afterwards a fixture file is owned by whichever track owns the endpoint it describes; both the backend and the frontend side of that endpoint assert against it. |

Wave 0 exception: until the `D-8` registry task is Accepted, per-module route files do not exist yet, so `auth-backend` routes are added by `wave-owner` on request rather than by the track itself. This exception exists only in Wave 0 and must not be carried forward.

## Wave 1 and later

Filled in at each wave planning gate, before the first task of that wave is approved. An empty section means the wave has not been planned yet, not that ownership is unrestricted.

## Change Log

| Date | Change | Reason |
|---|---|---|
| 2026-09-21 | File created with the Wave 0 map | Adoption of the wave execution model, `AUD-022` |
