# W0-BE-011 — Identity schema

## Metadata

| Field | Value |
|---|---|
| Task ID | `W0-BE-011` |
| Wave | `0 — Foundation` |
| Area | `Backend` |
| Status | `Approved` — Project Owner, 2026-09-22 |
| Depends on | `W0-BE-010` — Accepted, PR #9 |
| Blocks | `S01-BE-003`, `S01-BE-004`, and through them every later Wave 0 backend task |
| Track | `wave-owner` |
| Branch | `task/w0-be-011-identity-schema` |

Start only when Status is `Approved` and Git preflight from `tasks/README.md` is safe.

## Goal

The six-role identity exists in PostgreSQL with its locked invariants enforced by the
database rather than by application code alone; an Admin can be brought into being on an
empty system without any public endpoint; and the `auth-backend` track can build Staff login
and Customer OTP without editing a single path it does not own.

## Scope

**In:**

- A migration creating `users` exactly as `08` §3 specifies: UUID PK, the six roles, the two
  partial unique indexes, the account-family invariant, the listed indexes.
- A migration creating `customer_otp_challenges` exactly as `08` §4 specifies.
- `App\Models\User`: UUID key, `HasApiTokens`, backed enums for `role` and `status`,
  hashed-password cast, `password` hidden from serialization.
- Backed PHP enums `Role` and `UserStatus`, placed outside the Auth module so both backend
  tracks may use them without either owning the other's path.
- `UserFactory`, so `auth-backend` tests can create users of any role and state without
  touching `backend/database/factories/**`, which this track owns.
- A one-time Artisan command creating the first Admin (`BR-ROLE-009`).
- The **module service-provider registry** — the container-binding counterpart to `D-8`'s
  route registry, so no feature task ever edits `bootstrap/providers.php`.
- Focused tests for every constraint, the command and the registry.

**Out:**

- `/auth/staff/login`, `/auth/me`, `/auth/logout`, `/auth/change-password` — `S01-BE-003`.
- The OTP endpoints, the `SmsGateway` interface and its fake — `S01-BE-004`. This task
  delivers the challenge **table** and the registry that will register that binding, and
  nothing else of the OTP domain.
- **Request-time token behavior**: the sliding 30-day lifetime measured from `last_used_at`
  and the per-request `blocked` re-check (`07` §8). Both are authentication behavior that
  emits `401 account_blocked` / `401 authentication_required` (`09` §8), so they belong with
  the endpoints that return them. Decision 3.
- Staff management, activate/block, Admin password reset — Wave 1, and `S-20` is still open.
- Every other table in `08` §2. Later waves own their own schema tasks.
- Shared API fixtures — `W0-BE-012`.
- `backend/routes/api/v1/auth.php` — owned by `auth-backend`.

## Governing Specification

| Source | Section | What it governs here |
|---|---|---|
| `docs/08-database.md` | §1 | UUID PKs, `timestamptz` instants, `varchar` + `CHECK` for business enums |
| `docs/08-database.md` | §3 | the `users` table, its columns, its two partial unique indexes, its indexes |
| `docs/08-database.md` | §4 | the `customer_otp_challenges` table; no plaintext OTP |
| `docs/02-user-roles.md` | §1, §2, §3, §12 | six roles, one role per account, role immutability, account status |
| `docs/05-business-rules.md` | `BR-ROLE-001`–`BR-ROLE-010` | the role, credential, gate, status and account-family rules |
| `docs/07-architecture.md` | §8 | identity model, Sanctum bearer mode, blocking; **its request-time half is out of scope here** |
| `docs/09-api-contracts.md` | §6, §10 | phone format (`+998` plus 9 digits); temporary password at least 12 characters |
| `AGENTS.md` | §7, §8 | no hard-delete historical users; the wave schema task may create this wave's tables |
| `backend/AGENTS.md` | §6 | structural invariants belong in PostgreSQL when practical |
| `tasks/OWNERSHIP.md` | Wave 0 | `backend/database/migrations/**` and `backend/bootstrap/**` are this track's; **this is their dedicated task** |
| execution-model design record | `D-8` | the registry pattern this task extends from routes to providers |

## Decisions

| # | Decision | Why |
|---|---|---|
| 1 | `customer_otp_challenges` is created **here**, not by `S01-BE-004`. | `AGENTS.md` §8 lets the wave schema task create the tables that wave's features need, so feature tasks add no migrations. It is not merely tidy: `backend/database/migrations/**` belongs to `wave-owner`, so `S01-BE-004` on the `auth-backend` track cannot add its own migration without breaking `OWNERSHIP.md`. Leaving the table out would block that task outright. |
| 2 | The bootstrap command takes the password by **hidden interactive prompt**, and sets `must_change_password = false`. | The password then never enters `argv`, shell history, a process list, the command output or any log — the only mechanism fully compatible with `AGENTS.md` §6, which forbids exposing a password with no environment qualifier. The gate is `false` because `BR-ROLE-005` sets it for Staff who receive a *server-generated* temporary password they did not choose; the Project Owner chooses this one, so a forced change would remedy nothing. |
| 3 | Request-time token behavior stays with `S01-BE-003`. | The sliding lifetime and the blocked re-check are decided per request and surface as `09` §8 error codes. Putting them in a schema task would split one authentication decision across two contracts and two tracks. Both `auth-backend` tasks that need them sit on one serial track, so nothing is lost by deferring. |
| 4 | This task delivers a **module service-provider registry** and is the dedicated task for `bootstrap/providers.php`. | `S01-BE-004` must bind `SmsGateway` to its fake. Its provider class lives in `backend/app/Modules/Auth/**`, which `auth-backend` owns, but registering it means editing `bootstrap/providers.php` or `AppServiceProvider`, both `wave-owner`'s. Without a registry every future feature task collides on one file — exactly what `D-8` solved for routes. Solving it once here is cheaper than a Wave 0 exception that Wave 1 inherits with more tracks running. |
| 5 | The locked invariants of `08` §3 are expressed as PostgreSQL `CHECK` constraints, not application validation alone. | `backend/AGENTS.md` §6. `role` and `status` are the predicates both partial unique indexes depend on; if application code could write a seventh role, the account-family invariant would silently stop holding. |
| 6 | `status = 'blocked'` implies `blocked_at IS NOT NULL`, enforced in one direction only. | An unblocked account keeps `blocked_at` as history, so the converse must not be constrained. This direction is not stated in `08` §3; it is proposed here because a blocked row with no block instant is unreadable in any audit. **Strike this line if you would rather not add a constraint the locked document does not name.** |
| 7 | Phone is stored already normalized to E.164, with a `CHECK` on the `+998` plus 9-digit shape from `09` §6. | Both partial unique indexes compare phone as text. Two spellings of one number would each be accepted as active, and the invariant `BR-ROLE-010` protects would be lost at the storage layer, where no API validation can recover it. |
| 8 | Password hashing keeps Laravel's default (bcrypt); column stays `varchar(255)` per `08` §3. | No locked document specifies an algorithm. Laravel rehashes on verify when the configured algorithm changes, so this is reversible later without a data migration, and inventing a requirement here would be a reserved decision taken without authority. |

## Implementation Notes

- **`timestamps()` is not `timestamptz` on PostgreSQL.** Laravel's `timestamp()` and
  `timestamps()` emit `timestamp without time zone`. `08` §1 requires `timestamptz` for
  authoritative instants, so every instant column on both tables must be declared with the
  timezone-aware builder method, and the delivered column type verified against the running
  database rather than assumed from the migration source.
- `customer_otp_challenges` has `created_at` and **no** `updated_at` in `08` §4. Do not reach
  for `timestamps()` there.
- PostgreSQL expresses conditional uniqueness only as an index. The two indexes in `08` §3 are
  written as raw `CREATE UNIQUE INDEX ... WHERE ...`; no Blueprint method produces them.
- The registry must load providers in **sorted** order, for the reason `D-8` Decision 1
  records: directory order differs between this Windows host, the Linux container and the CI
  runner.
- The registry's `app/Modules/` directory needs a tracked placeholder and a **loud failure**
  when it is missing, matching `D-8` Decision 2. A silently empty provider list is the same
  class of failure as a silently empty API.
- `bootstrap/providers.php` is evaluated before the container boots but after
  `vendor/autoload.php`, so a static call and `class_exists` are both safe there.
- Two docblocks name the superseded `S01-BE-002` as the future owner of this work:
  `backend/app/Models/User.php` and `backend/database/seeders/DatabaseSeeder.php`. Both
  describe precisely what this task delivers, so both are corrected here.
- The command is one-time by refusing when any Admin already exists, not by a marker file.
  The database is the only authority that survives a redeploy.
- `BCRYPT_ROUNDS=4` is already set in `backend/phpunit.xml`, so the command tests do not become
  slow because of hashing.
- This worktree has no `backend/vendor/` and no `backend/.env` yet. Both are gitignored, so the
  per-worktree preparation in `docker/README.md` runs first.

## Delivered Schema

`users` — every column from `08` §3, with types from `08` §1:

| Column | Type | Null | Note |
|---|---|---:|---|
| `id` | `uuid` | no | PK, server-generated |
| `role` | `varchar(24)` | no | `CHECK` in the six values of `BR-ROLE-001` |
| `phone` | `varchar(20)` | no | `CHECK` E.164 `+998` plus 9 digits |
| `full_name` | `varchar(160)` | yes | |
| `password` | `varchar(255)` | yes | `CHECK`: null for `customer`, non-null otherwise |
| `status` | `varchar(16)` | no | `CHECK` in `active`, `blocked` |
| `must_change_password` | `boolean` | no | `CHECK`: false for `customer` |
| `password_changed_at` | `timestamptz` | yes | |
| `last_login_at` | `timestamptz` | yes | |
| `blocked_at` | `timestamptz` | yes | `CHECK`: non-null when `status = 'blocked'` (Decision 6) |
| `created_by_user_id` | `uuid` | yes | FK to `users.id`, `ON DELETE RESTRICT` |
| `created_at`, `updated_at` | `timestamptz` | no | |

Indexes: both partial unique indexes quoted verbatim in `08` §3; `(role, status)`;
`lower(full_name)`.

`customer_otp_challenges` — every column from `08` §4:

| Column | Type | Null | Note |
|---|---|---:|---|
| `id` | `uuid` | no | PK |
| `phone` | `varchar(20)` | no | same `CHECK` as `users.phone` |
| `purpose` | `varchar(24)` | no | `CHECK` in `customer_login` |
| `code_hash` | `varchar(255)` | no | hash only; the algorithm is `S01-BE-004`'s |
| `failed_attempts` | `smallint` | no | default `0`, `CHECK >= 0` |
| `expires_at` | `timestamptz` | no | |
| `consumed_at` | `timestamptz` | yes | |
| `invalidated_at` | `timestamptz` | yes | |
| `created_at` | `timestamptz` | no | no `updated_at` |

Indexes: `(phone, created_at)`; `expires_at`.

## Acceptance Criteria

- [ ] Both tables exist after `migrate`, with every column, type and nullability above,
      verified against the running PostgreSQL rather than read off the migration.
- [ ] Every instant column on both tables is `timestamp with time zone`.
- [ ] A seventh role value is rejected by the database.
- [ ] A status outside `active`/`blocked` is rejected by the database.
- [ ] A `customer` row with a password is rejected; a `customer` row with
      `must_change_password = true` is rejected; a Staff row without a password is rejected.
- [ ] A second **active Customer** account on one phone is rejected; a second **active Staff**
      account on one phone is rejected.
- [ ] An active Customer and an active Staff account **on the same phone** are both accepted —
      `02` §3 requires this, and it is the case a plain unique index would have broken.
- [ ] A blocked account and an active account of the same family on one phone are both
      accepted, which is what makes the role change in `BR-ROLE-002` possible.
- [ ] A phone that is not `+998` plus 9 digits is rejected.
- [ ] `User` exposes `role` and `status` as backed enums and never serializes `password`.
- [ ] `UserFactory` can produce every role, both statuses, and the first-login gate state.
- [ ] The bootstrap command creates an active Admin with `must_change_password = false`,
      reading the password through a hidden prompt.
- [ ] The command **refuses** when an Admin already exists, and creates nothing.
- [ ] The command never writes the password to output, to a log, or to `argv`, and a test
      asserts its output does not contain the password.
- [ ] A provider placed in a fixture module directory is actually registered — proven by a test
      resolving a binding it makes, not by inspection.
- [ ] Providers load in deterministic sorted order, proven by a test that can fail.
- [ ] A missing `app/Modules/` directory raises a clear error naming the expected path.
- [ ] An empty `app/Modules/` directory registers nothing and raises nothing.
- [ ] No API endpoint is added. `GET /api/v1/<anything>` still returns `404 resource_not_found`.
- [ ] `backend/routes/**`, `backend/composer.json`, `backend/composer.lock`,
      `backend/phpunit.xml`, `docker/**` and the delivered Sanctum migration are untouched.
- [ ] The four existing test files still pass unchanged.
- [ ] Pint and PHPStan pass.
- [ ] `git diff --check` passes.
- [ ] No unrelated public behavior changed.
- [ ] Independent review completed; P1 and P2 findings resolved.

## Verification

Every command runs inside this worktree's own Compose stack. Export both variables first, per
`docker/README.md`, "Several worktrees at once" — without them this worktree reuses another
track's container and database:

```text
export COMPOSE_PROJECT_NAME=bb-schema
export DB_HOST_PORT=5433
```

**Focused tests**

```text
docker compose -f docker/compose.yaml exec app php artisan test --filter=Identity
docker compose -f docker/compose.yaml exec app php artisan test --filter=BootstrapFirstAdmin
docker compose -f docker/compose.yaml exec app php artisan test --filter=ModuleProviderRegistry
```

Required cases: every `CHECK`; both partial unique indexes, in both the rejecting and the
accepting direction; the same-phone Customer-plus-Staff case; the blocked-plus-active case;
delivered column types; enum casts and password hiding; the factory; the command's success, its
refusal, and its silence about the password; registry registration, order, missing directory,
empty directory.

**Directly affected regression**

```text
docker compose -f docker/compose.yaml exec app php artisan test
```

The whole suite. Justified: this task changes how **every** service provider in the application
is registered, which is the same blast radius `W0-BE-010` had for routes, and it introduces the
first real migration, which every future test run executes.

**Format / static**

```text
docker compose -f docker/compose.yaml exec app vendor/bin/pint --test
docker compose -f docker/compose.yaml exec app vendor/bin/phpstan analyse
```

**Project Owner manual check**

Not required for merge. The command is exercised by automated tests; its real first use is part
of Wave 0 real-stack verification in `W0-INT-003`.

**Always**

```text
git diff --check
git status --short
```

CI runs the same commands on the pull request and is a required check on `main`.

## Allowed Areas

Track: `wave-owner`

| Path or area | Action | Reason |
|---|---|---|
| `backend/database/migrations/2026_09_22_*_create_users_table.php` | Create | the identity table |
| `backend/database/migrations/2026_09_22_*_create_customer_otp_challenges_table.php` | Create | Decision 1 |
| `backend/app/Models/User.php` | Modify | replace the framework placeholder with the real model |
| `backend/app/Models/Enums/Role.php` | Create | shared by both backend tracks |
| `backend/app/Models/Enums/UserStatus.php` | Create | shared by both backend tracks |
| `backend/database/factories/UserFactory.php` | Create | so `auth-backend` tests need no path of this track's |
| `backend/app/Console/Commands/BootstrapFirstAdminCommand.php` | Create | `BR-ROLE-009` |
| `backend/app/Support/Modules/ModuleProviderRegistry.php` | Create | Decision 4, the testable collection logic |
| `backend/bootstrap/providers.php` | Modify | becomes the registry's caller. **This is the dedicated task for this shared-caretaker path.** |
| `backend/app/Modules/.gitkeep` | Create | the module directory must exist in git |
| `backend/database/seeders/DatabaseSeeder.php` | Modify | docblock only: it names the superseded `S01-BE-002` |
| `backend/tests/Feature/Identity/**` | Create | constraint and model tests |
| `backend/tests/Feature/Console/BootstrapFirstAdminCommandTest.php` | Create | command tests |
| `backend/tests/Feature/Modules/ModuleProviderRegistryTest.php` | Create | registry tests |
| `backend/tests/Fixtures/modules/**` | Create | fixture providers, so registration is proven without a production module |
| `backend/config/auth.php` | Inspect | `providers.users.model` already resolves to the real model; no change expected |
| `tasks/backend/wave-00/W0-BE-011-identity-schema.md` | Create | this contract |
| `tasks/WAVE_00_TASK_INDEX.md` | Modify | task status bookkeeping |

Do not modify: `backend/app/Modules/Auth/**`, `backend/routes/**`,
`backend/database/migrations/2026_09_21_100839_create_personal_access_tokens_table.php`,
`backend/composer.json`, `backend/composer.lock`, `backend/phpunit.xml`,
`backend/app/Exceptions/**`, `backend/app/Support/Routing/**`, the four existing test files,
`docker/**`, `frontend/**`, `docs/01`–`docs/09`, `AGENTS.md`, `backend/AGENTS.md`,
`tasks/OWNERSHIP.md`, `tasks/README.md`.

## Reported Separately

Found while reading, outside this scope, not fixed here:

- `backend/database/migrations/2026_09_21_100839_create_personal_access_tokens_table.php`
  declares `last_used_at`, `expires_at` and `timestamps()` as `timestamp without time zone`.
  `08` §1 requires `timestamptz` for authoritative instants, and `last_used_at` becomes
  authoritative once the sliding lifetime in `07` §8 is measured from it. Nothing is wrong
  today — Laravel reads and writes UTC on both sides — but the convention is not held. A
  forward `ALTER` is one migration. Raised for a Project Owner decision rather than folded in,
  per `AGENTS.md` §8.

## Delivery

PR title: `W0-BE-011 — Identity schema`, target `main`. The agent commits, pushes and opens the
PR; the Project Owner merges.

## Independent Review

Filled in before the PR is opened.

| ID | Severity | Finding | Resolution |
|---|---|---|---|
