# W4-6 Android Release Preparation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Everything the first Google Play upload needs that does not need the server: a release build signed only with the upload key, a committed script that builds the bundle from a clean commit, the backup sentence on the public deletion page, the launcher icon, and the store documents the Owner submits. The upload itself waits for W4-5 (the privacy-policy address, real login codes) and the Owner's Play account (`DL-112` (8)).

**Architecture:** Gradle reads the gitignored `frontend/android/key.properties`; a release task without a complete file fails before it builds, and debug, profile, tests and the web build never need it. `tasks/scripts/build_release.ps1` refuses a modified tree, checks the three gitignored env files by name, builds the bundle with `--dart-define-from-file`, and proves the bundle's signer is the upload key before copying it out. The store answers live in `docs/store/`, Owner-facing files in Russian. The icon is drawn in Claude Design first; its code waits for the Owner's choice.

**Tech Stack:** Flutter 3.47 / Dart 3.13, Android Gradle (Kotlin DSL), JDK `keytool` from Android Studio's `jbr`, Android build-tools 36 (`apksigner`, `zipalign`), PowerShell 5.1, Laravel 13 for the deletion page.

**Spec:** `docs/DECISIONS.md` `DL-104` (6) and (13), `DL-105`, `DL-112` (8), `DL-115` (4); `tasks/WAVE_4.md` W4-6 notes, the Google Play and Maps gates, the risk rows naming W4-6; `docs/09-api-contracts.md` section on the store pages; interview 8.2 (Uzbek is the default language). This plan's decisions become `DL-116` (Task 6). One corrects `DL-104` (13): Play Console offers no Uzbek store-listing language (Play Console Help, "Translate and localize your app", read 2026-10-25: Kazakh `kk` and Kyrgyz `ky-KG` are listed, Uzbek is not), so the listing is one Russian-labelled listing whose texts carry Uzbek first, then Russian.

**Google Play facts this plan relies on** (read 2026-10-25): new apps target API 36 (Flutter 3.47's default `targetSdkVersion` is 36); a new personal account needs 12 testers opted in for 14 days in a row before applying for production; the 16 KB page-size rule blocks updates from 2027-02-01, checked here anyway with `zipalign -c -P 16`; the Maps SDK collects request metadata, crash data, the IP address and a pseudonymous identifier, which the developer must disclose; FCM uses the Firebase installation ID; the advertising-ID declaration must match the merged manifest; screenshots' long side at most twice the short side (an emulator shot of 1080×2400 is cropped to 1080×2160).

## Global Constraints

- Flutter commands run in `frontend/` from PowerShell with `G:\tools\flutter\bin` first on `PATH`. Every Android build sets `$env:GRADLE_USER_HOME='G:\tools\gradle-home'`, `$env:TEMP='G:\tools\tmp'`, `$env:TMP='G:\tools\tmp'`. One Gradle build at a time, never while the emulator boots; after the task's last build stop only the Gradle daemon `java.exe` processes (command line contains `GradleDaemon`). Delete any `hs_err_pid*.log` your build leaves in `frontend/android`.
- Backend commands run inside Compose from the repository root: `docker compose -f docker/compose.yaml exec -T app <command>`. Never run `migrate:fresh`, `migrate:refresh`, `migrate:reset`, `migrate:rollback`, `db:wipe`, `db:seed` or any `--env=testing` artisan command; `php artisan test` alone touches the test database.
- No new dependency of any kind (pub, Gradle, Composer).
- Never print, commit, move or edit `frontend/.env.maps`, `frontend/.env.firebase`, `frontend/.env.mapkit` or anything in `G:\tools\secrets`. A throwaway keystore lives in `G:\tools\tmp\w46\`; any `frontend/android/key.properties` or `frontend/.env.release` a task writes for a check is deleted when the task ends, as is that directory. Only the lead writes the real key (Task 4).
- Fixed names: `key.properties` keys `storeFile`, `storePassword`, `keyAlias`, `keyPassword`. Env files: `frontend/.env.release` (`BB_API_BASE_URL`), `frontend/.env.maps` (`GOOGLE_MAPS_API_KEY`), `frontend/.env.firebase` (`FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_ANDROID_APP_ID`, `FIREBASE_ANDROID_API_KEY`). Bundle `barakabozor-<versionName>-<versionCode>.aab`, default output directory `frontend/build/release`. All four paths are already gitignored (root `.env.*`, `frontend/android/.gitignore`, `frontend/.gitignore` `/build/`).
- The script is Windows PowerShell 5.1: no `&&`, `||`, `??`, `?.` or ternary; `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'`. Each refusal prints one line `build_release: <reason>` naming a file or a key, never a value, and exits `1`.
- Comments say why, as in `frontend/android/app/build.gradle.kts` today, with the decision in backticks (`DL-116` (n)). No TODO.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **A release signed with the debug key, or not at all.** No `key.properties`, a blank key, or a `storeFile` that does not exist must stop `flutter build apk --release` and `flutter build appbundle` by name, while `flutter build apk --debug`, `flutter test` and `flutter build web` need nothing (Task 1, checks V1 to V4).
2. **Testers' builds pointing at the wrong server.** `http://`, `localhost`, `10.0.2.2` or any IP, a missing `/api/v1`, a trailing slash, an empty value, quotes or spaces in `BB_API_BASE_URL` are refused before Gradle starts (Task 2, check S4).
3. **A secret on screen or in a file the repository holds.** The script prints names and fingerprints only; the store password reaches `keytool` through an environment variable, never the command line, and is removed from the environment afterwards (Task 2, check S6).
4. **A bundle no commit explains.** A modified tracked file refuses the build; the summary file records the commit, the version and the bundle's SHA-256; a `version:` without `+N` is refused (Task 2, checks S1 and S6).
5. **The backup sentence missing in one language or with no support phone set** (Task 3, its test runs both languages with the support phone unset).

---

### Task 1: Release signing from `key.properties`

**Files:**
- Modify: `frontend/android/app/build.gradle.kts`
- Create: `frontend/android/key.properties.example`

**Interfaces:**
- Produces: a release variant signed by `signingConfigs["release"]`, which exists only when `frontend/android/key.properties` holds all four keys non-blank and `storeFile` names an existing file. Otherwise `preReleaseBuild` fails with `GradleException("A release build is signed with the upload key from frontend/android/key.properties (DL-116 (1)): <problem>. See docs/store/README.md.")`, `<problem>` one of `the file is missing`, `it has no <key>`, `the keystore its storeFile names does not exist`.
- `storeFile` may be absolute (the real one is `G:/tools/secrets/barakabozor-upload.jks`).

- [ ] **Step 1: Implement.** Read the file with `java.util.Properties` at configuration time into one nullable problem string; create the `release` signing config only when it is null; `buildTypes.release.signingConfig = signingConfigs.findByName("release")`; `tasks.matching { it.name == "preReleaseBuild" }.configureEach { doFirst { … throw … } }` so only a release task fails. Remove the two template TODO lines and the "You can update the following values" block; one comment line says the version code and name come from `pubspec.yaml`'s `version` (`DL-116` (2)). `key.properties.example` lists the four keys with placeholder values and a first comment line: never commit the real file; the keystore stays outside the repository.
- [ ] **Step 2: V1.** No `key.properties`: `flutter build apk --release` fails and its output contains `the file is missing`.
- [ ] **Step 3: V2.** `flutter build apk --debug` succeeds.
- [ ] **Step 4: V3.** A throwaway PKCS12 keystore: `keytool -genkeypair -keystore G:\tools\tmp\w46\test-upload.jks -storetype PKCS12 -alias upload -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=W46 Test" -storepass:env W46_PASS -keypass:env W46_PASS` (keytool from `C:\Program Files\Android\Android Studio\jbr\bin`). A `key.properties` naming it without `keyAlias`: the release build fails with `it has no keyAlias`.
- [ ] **Step 5: V4.** The complete file: `flutter build apk --release` succeeds, and `apksigner verify --print-certs build\app\outputs\flutter-apk\app-release.apk` (build-tools `36.1.0`) prints `CN=W46 Test`, not `Android Debug`.
- [ ] **Step 6: Clean** (Global Constraints) and **commit** `build(android): sign releases with the upload key only` — keep `G:\tools\tmp\w46\test-upload.jks` if Task 2 runs next in the same session, otherwise delete it.

### Task 2: `tasks/scripts/build_release.ps1`

**Files:**
- Create: `tasks/scripts/build_release.ps1`

**Interfaces:**
- Consumes: Task 1's release signing.
- Produces: `powershell -File tasks/scripts/build_release.ps1 [-OutDir <path>]`. On success, `<OutDir>/barakabozor-<versionName>-<versionCode>.aab` and beside it `….txt` with the lines `version=<name>+<code>`, `commit=<40-char sha>`, `built_at=<UTC ISO 8601>`, `aab_sha256=<hex>`, `signer_sha1=<AA:BB:…>`, `signer_sha256=<AA:BB:…>`; the same lines printed; exit `0`.

Checks, in this order, each a refusal:

1. `git status --porcelain --untracked-files=no` is not empty → `tracked files have uncommitted changes`.
2. `frontend/pubspec.yaml` has no line matching `^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$` → `pubspec.yaml version must be x.y.z+N`.
3. `frontend/android/key.properties` missing, a key blank, or `storeFile` missing on disk (the same three problems as Task 1, worded the same).
4. The env files, parsed as Flutter parses them (skip blank lines and lines starting with `#`, split at the first `=`, trim): a file missing, a required key absent or empty → `<file> has no <KEY>`; `BB_API_BASE_URL` not matching `^https://[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}/api/v1$` → `BB_API_BASE_URL in .env.release must be https://<host>/api/v1`.
5. No `keytool.exe` in `$env:JAVA_HOME\bin`, on `PATH`, or at `C:\Program Files\Android\Android Studio\jbr\bin` → `keytool not found; set JAVA_HOME`.
6. `flutter build appbundle --release --dart-define-from-file=.env.release --dart-define-from-file=.env.maps --dart-define-from-file=.env.firebase` in `frontend/` exits non-zero → `flutter build failed`.
7. The signer: `keytool -printcert -jarfile <aab>` gives the bundle's SHA-256; `keytool -list -v -keystore <storeFile> -alias <keyAlias> -storepass:env BB_RELEASE_STOREPASS` gives the key's. An owner starting `CN=Android Debug`, or fingerprints that differ → `the bundle is not signed with the upload key`. `BB_RELEASE_STOREPASS` is set in the script's process just before and removed in a `finally`.

- [ ] **Step 1: Write the script** and **commit it** (check 1 needs a clean tree): `build: the release bundle script`.
- [ ] **Step 2: S1.** Append a blank line to `frontend/README.md`, run, see check 1's line; `git checkout -- frontend/README.md`.
- [ ] **Step 3: S2.** No `key.properties`: the line names `frontend/android/key.properties`.
- [ ] **Step 4: S4.** With Task 1's throwaway `key.properties`, `.env.release` holding in turn `http://api.example.uz/api/v1`, `https://api.example.uz/api/v1/`, `https://10.0.2.2/api/v1`, `https://localhost/api/v1`, `"https://api.example.uz/api/v1"`, and an empty value: each refused with check 4's line, and the output never contains `example`.
- [ ] **Step 5: S5.** `.env.release` = `BB_API_BASE_URL=https://api.example.invalid/api/v1`: the run succeeds; the `.aab` and `.txt` exist; `signer_sha256` equals `keytool -list -v` of the throwaway keystore.
- [ ] **Step 6: S6.** Pipe S5's output to a file under `G:\tools\tmp\w46\`, and with a short Python check (reading the env files itself, printing only `True`/`False`) confirm no env value and no password appears in it; confirm `BB_RELEASE_STOREPASS` is absent from the environment after the run.
- [ ] **Step 7: Clean** (Global Constraints, and `frontend/build/release`); fix commits if any check failed.

### Task 3: Backups on the deletion page and in the privacy drafts

**Files:**
- Modify: `backend/app/Modules/Legal/LegalPageTexts.php` (`deletion()` gains `backups`; its docblock array shape too)
- Modify: `backend/resources/views/legal/account-deletion.blade.php` (`<p>{{ $texts['backups'] }}</p>` after `kept`)
- Modify: `docs/legal/privacy.ru.txt`, `docs/legal/privacy.uz.txt`, `docs/05-business-rules.md` (`BR-ROLE-013`), `docs/09-api-contracts.md` (the store pages paragraph)
- Test: `backend/tests/Feature/Legal/LegalPagesTest.php`

Exact copy:

| Where | Russian | Uzbek |
|---|---|---|
| page `backups` | `Резервные копии: стёртые данные ещё до шести месяцев хранятся в зашифрованных резервных копиях и исчезают вместе с ними.` | `Zaxira nusxalar: o'chirilgan ma'lumotlar yana olti oygacha shifrlangan zaxira nusxalarda saqlanadi va ular bilan birga yo'qoladi.` |
| privacy, "Сколько храним" / its Uzbek heading, a new paragraph | `Резервные копии базы данных зашифрованы, хранятся в Узбекистане и удаляются через шесть месяцев; до этого в них остаются и данные удалённых аккаунтов.` | `Ma'lumotlar bazasining zaxira nusxalari shifrlangan, O'zbekistonda saqlanadi va olti oydan keyin o'chiriladi; shu vaqtgacha ularda o'chirilgan akkauntlar ma'lumotlari ham qoladi.` |
| privacy, "Кому мы передаём данные" / its Uzbek heading, a new list item | `- Google (Firebase) — идентификатор устройства для уведомлений и их текст: номер заказа и сумма.` | `- Google (Firebase) — bildirishnomalar uchun qurilma identifikatori va ularning matni: buyurtma raqami va summa.` |

`BR-ROLE-013` gains: "Encrypted backups keep erased data until they expire, at most six months, and the public deletion page says so (`DL-104` (6))." `docs/09`'s sentence on `/account-deletion` gains ", and that backups keep erased data for up to six months".

- [ ] **Step 1: Write the failing test** `test_the_deletion_page_says_backups_keep_erased_data_for_six_months`: support phone unset; `/account-deletion?lang=ru` sees the Russian line; `/account-deletion` sees `e(<the Uzbek line>)`.
- [ ] **Step 2: Run it, see it fail:** `php artisan test --filter=LegalPagesTest`.
- [ ] **Step 3: Implement** the texts and the view.
- [ ] **Step 4: Run the Legal tests, `pint --test`, `phpstan analyse`; all pass.** Update the four documents.
- [ ] **Step 5: Commit** `feat(legal): the deletion page says backups keep erased data for six months`.

### Task 4 (lead): The upload key and the release checks

- [ ] The real upload key: a 32-character random password made and held in a PowerShell variable, never shown; `keytool -genkeypair` PKCS12 at `G:\tools\secrets\barakabozor-upload.jks`, alias `upload`, RSA 4096, `-validity 10000` (to 2054, past Play's 2033 floor), dname `CN=BarakaBozor, C=UZ`; `frontend/android/key.properties` written with it (`storePassword` = `keyPassword`, as PKCS12 requires). Print only the SHA-1 and SHA-256.
- [ ] A release APK for the emulator, signed with it: `flutter build apk --release --dart-define=BB_API_BASE_URL=http://10.0.2.2:8001/api/v1 --dart-define-from-file=.env.maps --dart-define-from-file=.env.firebase`. Checks: `apksigner verify --print-certs` = `CN=BarakaBozor`; `zipalign -c -P 16 -v 4` ends `Verification successful`; `aapt2 dump badging` shows `targetSdkVersion:'36'`; the merged release manifest has no `com.google.android.gms.permission.AD_ID`.
- [ ] On the `barakabozor` emulator with the local stack: a Customer signs in, the address map draws its tiles, the push device is registered, and a probe push arrives. A blank map means the Maps key is restricted to other SHA-1s: the Owner adds the upload key's SHA-1 (exact clicks in `docs/store/play-console.ru.md`).
- [ ] The script with the real key and `.env.release` = `https://api.example.invalid/api/v1` succeeds; that bundle and `.env.release` are deleted, since no real address exists before W4-5.
- [ ] Rulings and the fingerprints go into the ledger and `DL-116`. The Owner is told where the keystore and `key.properties` are and to copy both to a password manager or a USB stick (with Play App Signing a lost upload key is replaced through Play support, never the app's key).

### Task 5: The launcher icon (held until the Owner picks a drawing)

The lead draws variants in Claude Design ("BarakaBozor — стиль покупателя", file `Иконка приложения`): the launcher mark on the adaptive safe zone (66 of 108 dp), its white notification silhouette, the 512×512 store icon and the 1024×500 feature graphic. The Owner chooses; the brief for this task then carries the approved SVG.

**Files:**
- Create: `docs/store/graphics/icon.svg`, `icon-foreground.svg`, `notify.svg`, `feature-graphic.svg` (the sources), and the rendered `docs/store/graphics/play-icon-512.png` (32-bit, alpha) and `feature-graphic-1024x500.png` (24-bit, no alpha)
- Create: `frontend/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` (adaptive: `@color/ic_launcher_background`, `@drawable/ic_launcher_foreground`, `<monochrome>` the same foreground), `drawable/ic_launcher_foreground.xml` (vector), `values/ic_launcher_background.xml`
- Modify: `drawable/ic_stat_notify.xml` (the approved silhouette, white; its comment loses "to be redrawn")
- Delete: `mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png` (with `minSdk` 26 every device takes the adaptive icon)
- Modify: `frontend/web/favicon.png`, `frontend/web/icons/*.png`, `frontend/web/manifest.json` (`theme_color` `#44BA53`)

- [ ] **Step 1:** Render the PNGs from the SVGs with headless Chrome (`G:\tools\bb-walk\cdp.js shot` at the exact sizes); check the sizes and alpha with Python's `struct` on the PNG header.
- [ ] **Step 2:** A debug APK on the emulator: the home-screen icon, the themed icon (Wallpaper & style → Themed icons), and a push's small icon look as drawn. Screenshots for the lead.
- [ ] **Step 3:** `flutter build web --release` succeeds. **Commit** `feat(brand): the launcher icon and the store graphics`.

### Task 6 (lead): Store documents and the decision

**Files:**
- Create: `docs/store/README.md` (English: what is here; the release routine — raise `+N` in a pull request, merge, run the script, upload the `.aab`, keep its `.txt`)
- Create: `docs/store/listing.md` — the default listing, Russian-labelled: title `BarakaBozor` plus a descriptor within 30 characters; the short description in Uzbek and Russian within 80; the full description Uzbek first, then Russian, within 4 000, promising only what `docs/01–05` promise; "what's new" for the first build; the eight screenshots to take (Uzbek interface, cropped to 1080×2160)
- Create: `docs/store/play-console.ru.md` — the Owner's steps in order, with the English menu names in brackets: create the app; App content (privacy policy `https://api.<domain>/legal/privacy`, App access with the reviewer phone of `DL-105` and a note that the code is in the server's env, Ads: none, Content rating, Target audience 18+, Data safety, Government apps, Financial features, Health, Advertising ID: no); the store listing; the closed track, testers (an email list), the upload, the opt-in link; adding the upload and Play app-signing SHA-1s to the Maps key and the Firebase Android API key in Google Cloud Console; after 14 days with 12 testers, "Apply for production" and what it asks
- Create: `docs/store/data-safety.ru.md` — each Data safety answer with its source in the code: collected, none shared (Telegram, Google Maps and Firebase act as service providers); name, phone, delivery address, precise location (the confirmed map point, optional), purchase history, other user-generated content (notes, ratings, answers to the Shopper), in-app search history (processed ephemerally), device or other IDs (the push token, the Maps SDK's identifier), crash logs and diagnostics (the Maps SDK); encrypted in transit; deletion in the app and at `https://api.<domain>/account-deletion`, backups up to six months
- Create: `docs/store/content-rating.ru.md` — the questionnaire's answers (category, then each question); the alcohol and tobacco answer follows the Owner's answer to the question below
- Modify: `docs/DECISIONS.md` (`DL-116`), `docs/07-architecture.md` section 27 (the release build; "no brand assets exist" replaced once Task 5 lands), `tasks/WAVE_4.md` (W4-6 row and notes; the placeholder-icon row closed by Task 5; the reviewer-phone row → checked at the account's creation in W4-5)

- [ ] Write the files; check the character limits with Python.
- [ ] `git diff --check`; **commit** `docs(store): the Play listing, the data safety and content rating answers, DL-116`.

**Owner question raised by this plan** (asked on its own, after the plan's "да"): may the catalog hold tobacco, nicotine or alcohol? Google Play allows tobacco in a grocery app only in some regions with an ID check at delivery, and alcohol only with age checks; the content-rating answers and the pilot checklist depend on it.

### After the tasks

The full backend suite and the frontend suite through `test-runner`; `branch-reviewer` on the whole branch; one fix wave; `/security-review` (the branch touches signing secrets); pull request; merge on green; `wave-progress` memory.
