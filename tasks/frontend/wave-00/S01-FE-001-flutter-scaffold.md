# S01-FE-001 — Flutter scaffold, client foundation and the Flutter route-fragment registry

## Metadata

| Field | Value |
|---|---|
| Task ID | `S01-FE-001` |
| Wave | `0 — Foundation` |
| Area | `Frontend` |
| Track | `client-foundation` |
| Status | `Approved` — Project Owner, 2026-09-22 |
| Depends on | Flutter SDK installed — **satisfied 2026-09-22**, `flutter doctor` reports no issues, Windows and Android toolchains present |
| Blocks | `S01-FE-002`, `S01-FE-003`, `S01-FE-004`, `S01-FE-005`, `W0-INT-003` |
| Branch | `task/s01-fe-001-flutter-scaffold` |

## Goal

A Flutter application exists under `frontend/`, compiles for Android and Windows, boots into a GoRouter table assembled from per-feature fragments, and provides the one configured Dio client and the one secure token store that every later frontend task builds on. After this task no frontend feature task needs to invent transport, storage or routing infrastructure.

## Scope

**In:**

- `flutter create` for **android, ios, windows only**. No web, no linux, no macos target is generated.
- The directory layout of `07` §27, used exactly as written: `lib/app/`, `lib/core/`, `lib/features/<feature>/{data,domain,application,presentation}`. No empty directories are created for features this wave does not build.
- Exactly four runtime dependencies — `flutter_riverpod`, `go_router`, `dio`, `flutter_secure_storage` — plus `flutter_lints` as a dev dependency. `pubspec.lock` is committed.
- `lib/app/providers.dart`: the root composition root. It holds the process-wide provider overrides and nothing feature-specific.
- `lib/app/router.dart`: the **Flutter half of `D-8`** — the registry that collects per-feature route fragments into one `GoRouter`.
- `lib/core/network/`: one configured `Dio` — base URL, timeouts, JSON content negotiation, and the interceptor seam a later task attaches the bearer token to. It knows no endpoint and parses no envelope.
- `lib/core/storage/`: a secure token store behind an interface, implemented over `flutter_secure_storage`, so tests and later tasks depend on the interface rather than on the plugin.
- `lib/core/theme/`: a minimal Material 3 theme. Seed colour and `useMaterial3`, nothing more.
- Focused tests for the registry, the Dio configuration and the token store; `flutter analyze` and `dart format` clean.

**Out:**

- **Error-envelope parsing, the `code`-to-text map, DTOs, repositories.** `S01-FE-002` owns them and depends on `W0-BE-012`, which is not Accepted. `07` §33 forbids a frontend track building against a fixture surface that does not exist yet.
- **Any authentication UX** — `S01-FE-003`, `S01-FE-004`.
- **Role shells, route guards, logout, session isolation** — `S01-FE-005`. This task ships one neutral bootstrap route so the app can launch, and no role area.
- **Localization infrastructure.** `S-27`, how a language is chosen, defaulted and persisted, is open and filed against Wave 1. The scaffold therefore ships **no user-facing string at all**, which is also what keeps it inside `07` §27's "no English UI".
- **A frontend CI job.** `.github/workflows/**` belongs to `wave-owner`.
- **Release builds and signing configuration** for any target. The required Android and Windows release builds are a Frontend Phase 2 gate item per the wave index §10.
- Any feature route fragment with real routes. Mirrors `W0-BE-010`, which added no production endpoint.

## Governing Specification

| Source | Section | What it governs here |
|---|---|---|
| `docs/07-architecture.md` | §27 | the directory layout, fixed and not renegotiable (`AUD-026`); client owns every user-facing string |
| `docs/07-architecture.md` | §2 | Riverpod / GoRouter / Dio / `flutter_secure_storage` / Material 3; targets Android, iOS, Windows; no web |
| `docs/07-architecture.md` | §3, `D-8` | Flutter feature route fragments collected by one registry |
| `docs/07-architecture.md` | §8 | bearer token in secure platform storage; Sanctum in bearer mode, no CSRF surface |
| `docs/07-architecture.md` | §29 | role-aware areas `/auth`, `/customer`, … — consumed later, the registry must not preclude them |
| `docs/07-architecture.md` | §30, §33 | `/api/v1` base path; frontend test responsibilities |
| `docs/02-user-roles.md` | §10 | Desktop is an installed Windows application; Android and Windows required from Wave 0 |
| `frontend/AGENTS.md` | §2, §7, §13 | layer boundaries, one configured client, no unapproved packages or platform churn |
| `AGENTS.md` | §8 | the registry is one of the two named exceptions to the no-speculative-infrastructure rule |
| `tasks/OWNERSHIP.md` | Wave 0 exception | `pubspec.yaml`, `pubspec.lock`, `lib/app/router.dart`, `lib/app/providers.dart` are this task's to create |

## Decisions

| # | Decision | Why |
|---|---|---|
| D-1 | **The Wave 0 ownership exception is extended to the whole `frontend/` tree for this task**, plus `tasks/frontend/wave-00/S01-FE-001-flutter-scaffold.md` and this task's rows in `tasks/WAVE_00_TASK_INDEX.md`. From Wave 1 the table in `tasks/OWNERSHIP.md` applies unchanged. | `flutter create` writes `frontend/android/`, `frontend/ios/`, `frontend/windows/`, `frontend/analysis_options.yaml`, `frontend/.metadata`, `frontend/.gitignore` and `frontend/README.md`, none of which appears in the map; Rule 1 makes an unlisted path unmodifiable without a Project Owner decision, and the existing exception names only four files. `tasks/**` belongs to `wave-owner`, so without this the track could neither file its own contract nor record its own status. Rule 5 makes this a wave-level event, raised before implementation rather than during it. |
| D-2 | Dart package name `baraka_bozor`; Android `applicationId` and iOS bundle id `uz.barakabozor.app`; Windows product name `BarakaBozor`. | Nothing in `docs/01-09` fixes these, and `flutter create` otherwise stamps `com.example` into three platform trees. An `applicationId` cannot be changed after a Play upload, so it is cheapest to decide before the trees exist. |
| D-3 | API base URL comes from `--dart-define=BB_API_BASE_URL`, defaulting to `http://localhost:8000/api/v1`. | No document fixes it. `docker/compose.yaml` publishes no HTTP port today — the `app` service runs `tail -f /dev/null` — so nothing listens until `W0-INT-003` needs it. The default is a placeholder and this contract says so rather than implying a running server. |
| D-4 | **The registry is an explicit ordered list in `lib/app/router.dart`, enforced by a test that scans `lib/features/*/presentation/*_routes.dart` on disk** and fails when a fragment exists but is not registered, or when two routes share a path or a name. | Dart has no runtime file scanning and tree-shakes unimported code, so there is no Flutter equivalent of the backend's `glob` plus `require`. This keeps three of the four properties `W0-BE-010` delivers — deterministic order, loud failure on a forgotten fragment, duplicate detection — and loses one: a new feature still needs one import and one list entry in `router.dart`. From Wave 1 that file is `wave-owner`'s, so it is a serialization point, never a two-track collision, which is what `AGENTS.md` §8 asks for. **Rejected alternative:** `build_runner` codegen — two dev dependencies and a generated file, in a wave whose rules forbid hand-editing generated files, for safety the enforcing test already provides. |
| D-5 | The scaffold ships **no user-facing string**. The bootstrap route renders a centred progress indicator and no text. **Clarified during implementation:** the product name `BarakaBozor` does ship, as the `MaterialApp` title, the Android launcher label, the iOS bundle display name and the Win32 window title. Every platform tree requires a label, and a brand name is identical in both client languages, so it is not the localized prose `07` §27 governs. Recorded because `D-5` as approved reads absolutely. | `07` §27 forbids English UI and `S-27` leaves the language mechanism undecided. A placeholder string would be a violation to delete in Wave 1. |
| D-6 | `flutter_lints` as generated, plus `strict-casts` and `strict-raw-types` in `analysis_options.yaml`. | Analyzer settings, not a package, so no dependency is added. They are the frontend counterpart to PHPStan on the backend, and far cheaper to adopt on an empty tree than on five features' worth of code. |
| D-7 | `flutter_riverpod`, not `hooks_riverpod`, and no `riverpod_generator`. | `flutter_hooks` is a second widget paradigm alongside `StatefulWidget`, which `frontend/AGENTS.md` §2 reads against. Codegen can be added later without rewriting call sites. |
| D-8 | Feature providers are **not** registered anywhere. Only routes get a registry. | Riverpod providers are top-level globals reached by reference, so a feature's provider needs no central list; a route table does. Stated so no later task builds a provider registry by symmetry. |

## Implementation Notes

- `frontend/` already contains `AGENTS.md`. `flutter create .` from inside it must preserve that file — verify by blob hash before and after.
- The generated `frontend/.gitignore` overlaps the root one, which already covers `frontend/.dart_tool/`, `frontend/build/` and friends. Keep the generated file, since Flutter tooling expects it; do not touch the root `.gitignore`.
- `.gitattributes` forces LF on everything except `*.bat`, `*.cmd`, `*.ps1`. `flutter create` writes `windows/` with a `.bat` and CRLF-sensitive CMake files; check the diff for normalization damage before the commit, not after.
- `flutter_secure_storage` on Windows is the Credential Manager. **Corrected during implementation, confirmed 2026-09-23:** this note originally said the Android default is plain `SharedPreferences` and that `EncryptedSharedPreferences` must be requested explicitly. That was true of version 9.x. The approved dependency resolves to 11, where the option does not exist — its `CHANGELOG` records the Jetpack Security backend being removed — and the default is already AES-GCM under a KeyStore-wrapped RSA-OAEP key. `07` §8 is satisfied by the default, and more strongly than the original note asked for.
- The Dio instance must be a single provider-owned instance, not a global. Two instances is the exact failure `frontend/AGENTS.md` §2 names.
- Do not add an automatic retry interceptor. `frontend/AGENTS.md` §7 forbids it absent a contract that defines idempotent retry.

## Acceptance Criteria

- [ ] `frontend/` holds a Flutter application with `android/`, `ios/`, `windows/` and no `web/`, `linux/` or `macos/`.
- [ ] `frontend/AGENTS.md` is unmodified, verified by blob hash.
- [ ] The layout matches `07` §27 exactly; no directory exists that no file needs.
- [ ] `pubspec.yaml` declares the four runtime dependencies and `flutter_lints`, and nothing else. `pubspec.lock` is committed.
- [ ] `lib/app/router.dart` builds one `GoRouter` from an ordered fragment list and one neutral bootstrap route.
- [ ] A fixture fragment placed in the registry is actually routable — proven by a test, not by inspection.
- [ ] A fragment file present on disk but absent from the registry **fails a test**, and the failure names the file.
- [ ] Two fragments declaring the same route path, or the same route name, fail a test.
- [ ] No feature route fragment with real routes is added to the production tree.
- [ ] One Dio instance exists, owned by a provider, with base URL and timeouts from configuration; it parses no envelope and knows no endpoint; no retry interceptor exists.
- [ ] The token store is reached through an interface; a test proves read, write and delete against a fake, with no plugin channel in the test.
- [ ] The Android token store is encrypted at rest. **Amended, confirmed 2026-09-23:** this criterion originally named `EncryptedSharedPreferences`, which `flutter_secure_storage` 11 removed, so as approved it could not be met by the approved dependency. What is delivered is the plugin's v11 default, AES-GCM under a KeyStore-wrapped key. See the Implementation Note and finding `R-02`.
- [ ] The app renders no user-facing text.
- [ ] `flutter analyze` reports no issues; `dart format --set-exit-if-changed` is clean.
- [ ] A debug build succeeds for Windows and for Android.
- [ ] `git diff --check` passes, and no platform file was mangled by line-ending normalization.
- [ ] Independent review completed; P1 and P2 findings resolved.

## Verification

**Focused tests**

```text
cd frontend && flutter test
```

Required cases: fragment registered, route reachable; fragment on disk but unregistered fails the test naming the file; duplicate route path fails; duplicate route name fails; Dio base URL, timeouts and headers as configured; token store read/write/delete over a fake; no feature route exists in the production table.

**Format / static**

```text
cd frontend && flutter analyze
cd frontend && dart format --output=none --set-exit-if-changed .
```

**Build check** — one debug build per required target, **not** the Phase 2 release build

```text
cd frontend && flutter build windows --debug
cd frontend && flutter build apk --debug
```

Justified against `AGENTS.md` §11: this is the task that creates the three platform trees, and nothing else in the frontend block would exercise them until the Phase 2 release build — by which point five tasks would be stacked on an unverified toolchain wiring. Debug only; release and signing stay at Phase 2.

**Directly affected regression**

`None required` — no frontend code exists to regress. `backend/` is untouched, and `W0-BE-011` runs concurrently in another worktree.

**Project Owner manual check**

`flutter run -d windows` launches the application and it shows the neutral bootstrap screen without crashing.

**Always**

```text
git diff --check
git status --short
```

## Allowed Areas

Track: `client-foundation`

| Path or area | Action | Reason |
|---|---|---|
| `frontend/lib/**` except the two files below | Create | granted by the track's row in `OWNERSHIP.md` |
| `frontend/test/**` | Create | granted by the track's row |
| `frontend/pubspec.yaml`, `frontend/pubspec.lock` | Create | Wave 0 exception, approved 2026-09-22 |
| `frontend/lib/app/router.dart`, `frontend/lib/app/providers.dart` | Create | Wave 0 exception; this task **is** the dedicated task for the Flutter registry |
| `frontend/android/**`, `frontend/ios/**`, `frontend/windows/**` | Create | `D-1` — written by `flutter create` |
| `frontend/analysis_options.yaml`, `frontend/.metadata`, `frontend/.gitignore`, `frontend/README.md` | Create | `D-1` — same |
| `tasks/frontend/wave-00/S01-FE-001-flutter-scaffold.md` | Create | `D-1` — the contract |
| `tasks/WAVE_00_TASK_INDEX.md` | Modify | `D-1` — the SDK gate and this task's status |
| `tasks/OWNERSHIP.md` | Modify | `D-1` — record the extended exception in the Change Log, so a later agent reading the map can account for this diff |

Do not modify: **all of `backend/`** (`W0-BE-011` is live in another worktree), `docker/`, `.github/workflows/`, `tests/fixtures/api/`, `docs/01`–`docs/09`, `AGENTS.md`, `frontend/AGENTS.md`, root `.gitignore`, `.gitattributes`, `.editorconfig`.

## Delivery

PR title: `S01-FE-001 — Flutter scaffold, client foundation and the Flutter route-fragment registry`, target `main`. The implementing agent commits, pushes and opens the PR. The Project Owner merges. The task becomes `Accepted` only after the merge, with local `main == origin/main`, `0/0`, and a clean worktree.

## Independent Review

Reviewed 2026-09-22 by an agent with no implementation context, against this contract, both `AGENTS.md` files, `tasks/OWNERSHIP.md` and `docs/07` §2, §3, §8, §27, §29, §30, §33. It re-ran `flutter test`, `flutter analyze`, `dart format` and `git diff --check` itself, and read the `go_router` and `flutter_secure_storage` sources rather than taking this contract's word for their behaviour. Result: **0 P1, 2 P2, 10 P3**. It did not re-run the two debug builds, because `C:` was full by then; those two criteria rest on the implementing agent's observed output alone.

| ID | Severity | Finding | Resolution |
|---|---|---|---|
| R-01 | **P2** | The main Android manifest declared no `INTERNET` permission. `flutter create` puts it only in the debug and profile source sets, where it exists for the Flutter tool's own hot-reload channel. A release APK would therefore have failed every API call with a `SocketException` — and this task owns both `frontend/android/**` and the HTTP client, while no later frontend contract lists manifest permissions, so nothing downstream would have caught it before the Frontend Phase 2 Android release gate. | **Fixed.** `uses-permission android.permission.INTERNET` added to `android/app/src/main/AndroidManifest.xml`, with a comment recording why the generated template does not have it. |
| R-02 | **P2** | This contract's Implementation Note and one acceptance criterion required `EncryptedSharedPreferences`, which `flutter_secure_storage` 11 removed; the reviewer confirmed it in the package `CHANGELOG`. The criterion as approved could not be met by the approved dependency, and the correction existed only in a source comment. | **Contract amended, and flagged to the Project Owner rather than settled by the implementing agent.** The note and the criterion now describe what is delivered — the v11 default, AES-GCM under a KeyStore-wrapped RSA-OAEP key — and both carry an explicit "awaiting Project Owner confirmation" marker. The implementation did not change; the reviewer agreed the security outcome was already correct and stronger than the criterion asked. |
| R-03 | P3 | The theme test named `derives both schemes from one seed colour` asserted only that the light and dark primaries differ, which two unrelated seeds would also satisfy. The name did not match the assertion. | **Fixed.** `_seedColor` is now the public `appSeedColor`, and the test asserts each scheme equals `ColorScheme.fromSeed` on that exact value. |
| R-04 | P3 | No test imported `providers.dart`. Replacing `createApiClient(ref.watch(apiConfigProvider))` with a bare `Dio()` would have broken the contract with the suite still green. | **Fixed.** `test/app/providers_test.dart` reads the providers through a `ProviderContainer`: the client carries the configured base URL and all three timeouts, two reads return the identical instance, and the token store is exposed as the port. |
| R-05 | P3 | The registry scanner stripped `import` lines before looking for the fragment symbol, so a fragment named in the router's own dartdoc would have counted as registered. | **Fixed.** Comment lines are stripped too, and a test now proves that a fragment mentioned only in a doc comment is still reported as unregistered. |
| R-06 | P3 | `// TODO: Specify your own unique Application ID` survived directly above the `applicationId` that `D-2` had specified, making it a false statement in a file this task edited. Root `AGENTS.md` §9 forbids stale TODOs. | **Fixed.** Replaced with a note recording the decision and why it cannot change later. The signing-config TODO on the same file is left: signing is explicitly out of scope. |
| R-07 | P3 | `D-5` says the scaffold ships no user-facing string, but `BarakaBozor` ships as the `MaterialApp` title, the Android label, the iOS display name and the Win32 window title. | **Recorded, implementation unchanged.** `D-5` now states the exception. A brand name is identical in both client languages and every platform tree requires a label, so it is not the localized prose `07` §27 governs — but `D-5` as approved read absolutely, so the deviation belongs in writing. |
| R-08 | P3 | No `android:allowBackup="false"`. The plugin README warns that Android auto-backup restores ciphertext without the KeyStore key. | **Not acted on.** With `resetOnError` defaulting to true the outcome is a silent sign-out after a device restore, not a crash or a leak, and the correct response is a session-bootstrap decision rather than a scaffold default. Raised for `S01-FE-002`. |
| R-09 | P3 | `lib/core/config/` and `lib/core/routing/` are two `core/` subdirectories that neither `07` §27's illustrative list nor this contract's Scope enumerates. | **Not acted on.** Both sit inside the granted area, both hold exactly one file, and §27's rule is that nothing cross-feature lives outside `core/` — which is honoured. Reported so the Project Owner sees the layout is slightly wider than this contract's prose. |
| R-10 | P3 | `apiClientProvider` never closed its `Dio`, while `routerProvider` did dispose its router. | **Fixed.** `ref.onDispose(client.close)`, which matters once `S01-FE-002` starts overriding the container per test. |
| R-11 | P3 | The wave index readiness row gave `N/A` for `Auth/scope/security`, although this task ships the bearer-token store that `07` §8 governs; and the new `C:`-full risk row plus change-log row go slightly beyond this contract's stated grant for that file. | **Partly fixed.** The column is now `Yes`. The extra rows are left in place and flagged here: they record a real environment problem honestly, and the Project Owner should bless the wider bookkeeping edit since `tasks/**` is otherwise `wave-owner`'s. |
| R-12 | P3 | `frontend/README.md` is stock `flutter create` boilerplate pointing at the Flutter codelab. | **Not acted on.** `D-1` permits generated output as generated. Replacing it is worth doing but is not this contract's scope. |

**Checked and confirmed by the reviewer**, recorded because they were the main risks in the design: `collectFeatureRoutes` resolves child paths against their parents exactly as `go_router` does, so `/customer` plus a relative `orders` really does collide with a separately declared `/customer/orders`, while `orders` under two different parents does not; `StatefulShellRoute` flattens its branches into `RouteBase.routes`, verified in the `go_router` source, so there is no shell-shaped bypass of the collision check; the bootstrap route passes through the same check, so no feature can quietly take `/`; the token-store tests exercise the real `SecureTokenStore` over the plugin's own in-memory platform, holding the caller's map by reference, so they assert real behaviour and not a mock's recorded calls; `frontend/AGENTS.md` is byte-identical to `main`; `backend/**` is entirely untouched, so the concurrent `W0-BE-011` worktree is safe; and `git grep` finds no `print`, `debugPrint`, `developer.log` or `LogInterceptor` anywhere, so there is no path on which a token could reach a log.
