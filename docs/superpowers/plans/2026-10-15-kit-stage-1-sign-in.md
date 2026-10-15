# Kit Stage 1 — Sign-in Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sign-in looks like the approved Claude Design file `kit/01-vhod.dc.html` (10 screens) and works as the Owner decided on 2026-10-15: one entry in the mobile app — phone → Telegram code — for everyone; a Shopper or Courier is then asked for the staff password (code + password); a new customer gives a name once and sees a welcome; the panel (Operator/Admin/Manager, web) keeps phone + password; a Shopper/Courier enters Customer mode without a second code; splash is white with the wordmark.

**Architecture:** Backend: `POST /auth/customer/code/verify` additionally returns a single-use `staff_step` token when the verified phone also holds a Shopper or Courier account; a new `POST /auth/staff/step` exchanges `{staff_step, password}` for the staff token; `POST /auth/staff/login` (phone + password) refuses Shopper/Courier with `staff_code_required`, so the code step cannot be skipped. Client: the session starts with the customer session, holds the pending step in `SignedIn`, adds the staff session after the password, and switches modes without codes; `/auth` renders the code flow on mobile and the staff (panel) login on web.

**Tech Stack:** Laravel 12/13 + PostgreSQL (Sanctum tokens), Flutter 3.47.5 + Riverpod 3 + go_router, `flutter gen-l10n` (ARB, template `app_uz.arb`).

**Spec:** Claude Design project "BarakaBozor — стиль покупателя", file `kit/01-vhod.dc.html` (approved by the Owner 2026-10-15): 01 Заставка, 02 Вход, 03 Подтверждение номера, 04 Код из Telegram, 05 Как вас зовут?, 06 Аккаунт создан, 07 Пароль сотрудника, 08 Смена временного пароля, 09 Нет связи с сервером, 10 Аккаунт работает в веб-панели. Owner decisions recorded in Task 6 (`DL-76`).

## Global Constraints

- Branch `task/kit-1-sign-in` from `main` b35c963. Never commit to `main`.
- Backend commands run in Docker: `docker compose -f docker/compose.yaml exec -T app <cmd>` from the repo root (tests: `php artisan test --filter=…`, `vendor/bin/pint --test`, `vendor/bin/phpstan analyse`). Flutter: `G:/tools/flutter/bin/flutter` with `TEMP`/`TMP` = `G:\tools\tmp`, from `frontend/`.
- Security is server-side (AGENTS.md §5): the client never decides whether a person is staff; codes, step tokens and passwords are never logged, never in URLs, never in exception context (`#[\SensitiveParameter]`).
- The staff step reveals nothing to someone without the code: `staff_step` exists only in a successful verify response; `staff_code_required` is answered only to a caller who presented the correct password.
- Kit colours exactly: `#5AC268` primary, `#44BA53`, `#D5EFD9`, `#EEF9F0`, ink `#151D16`, ink2 `#303731`, muted `#8E948F`, line `#EEF0EF`, field `#F9F9F9`, card `#FAFAFA`, danger `#F04438`. Font Montserrat (bundled, OFL).
- Texts in Uzbek (template) and Russian; Uzbek uses the ASCII apostrophe as the ARB files do.
- Generated l10n files are regenerated, never hand-edited; `pubspec.lock` unchanged (no new package).
- Every widget test that renders a sign-in screen also runs at 320×640 with `textScaleFactorTestValue = 2` in `uz` and `ru`, with no exception.
- Never delete, skip or weaken a test; a test whose flow changed is rewritten to assert the new flow.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

- Skipping the code: a Shopper/Courier calling `POST /auth/staff/login` with phone + right password gets no token (`staff_code_required`); with a wrong password the answer is `invalid_credentials` exactly like a non-staff phone (no role oracle).
- Step token abuse: a step works once, for 5 minutes, at most 5 wrong passwords, only for the staff account of the phone that verified the code; replay, expiry and exhaustion are refused; the token is stored hashed and never logged.
- Blocked accounts: a blocked Shopper with the right password in the step gets `account_blocked`; a blocked customer account still refuses verify (unchanged), and the code is consumed first.
- Mode switching: the customer session from verify is kept when the staff password is entered; Customer mode is offered only to a Shopper/Courier who passed the first-login password gate; an expired step leaves the person signed in as a customer, never half signed in.
- Large text on 320 px in both languages for every new screen, and the 6-box code field accepts paste and the SMS/one-time-code autofill.

---

### Task 1: Backend — the staff password step

**Files:**
- Create: `backend/database/migrations/2026_10_15_000001_create_staff_login_steps_table.php`
- Create: `backend/app/Modules/Auth/Models/StaffLoginStep.php`
- Create: `backend/app/Modules/Auth/Actions/AuthenticateStaffStep.php`, `backend/app/Modules/Auth/Actions/VerifiedLogin.php`
- Create: `backend/app/Modules/Auth/Http/Controllers/StaffStepController.php`, `backend/app/Modules/Auth/Http/Requests/StaffStepRequest.php`
- Modify: `backend/app/Modules/Auth/Actions/VerifyCustomerLoginCode.php`, `backend/app/Modules/Auth/Http/Controllers/CustomerLoginCodeController.php`, `backend/app/Modules/Auth/Actions/AuthenticateStaff.php`, `backend/routes/api/v1/auth.php`, `docs/09-api-contracts.md` (Sections 7, 8, 52)
- Test: Create `backend/tests/Feature/Auth/StaffStepTest.php`; modify `backend/tests/Feature/Auth/CustomerLoginCodeTest.php`, `backend/tests/Feature/Auth/StaffLoginTest.php`, `backend/tests/Feature/Auth/SecretsStayOutOfLogsTest.php`

**Interfaces:**
- Produces (API):
  - `POST /auth/customer/code/verify` → `200 {"data":{"token":"…","user":{…},"staff_step":null|{"token":"<64 chars>","expires_at":"<ISO-8601 UTC>"}}}`.
  - `POST /auth/staff/step` `{"staff_step":"<64 chars>","password":"…"}` → `200 {"data":{"token":"…","user":{…}}}` (staff token, same shape as staff login). Refusals: `401 staff_step_invalid` (unknown, used, or exhausted), `401 staff_step_expired`, `401 invalid_credentials` (wrong password, counts an attempt), `401 account_blocked` (right password, blocked staff), `429` rate limited (20/min per IP).
  - `POST /auth/staff/login` (phone + password): unchanged for Operator/Admin/Manager; for a Shopper or Courier with the RIGHT password → `403 staff_code_required` and no token; wrong password → `401 invalid_credentials` as today.

- [ ] **Step 1: Migration and model**

Migration (follow the style of the existing migrations: uuid primary keys, `timestampsTz`, checks in SQL):

```php
Schema::create('staff_login_steps', function (Blueprint $table): void {
    $table->uuid('id')->primary();
    $table->foreignUuid('staff_user_id')->constrained('users')->restrictOnDelete();
    $table->char('token_hash', 64)->unique();      // sha256 hex of the step token
    $table->timestampTz('expires_at');
    $table->timestampTz('consumed_at')->nullable();
    $table->smallInteger('failed_attempts')->default(0);
    $table->timestampsTz();
    $table->index(['staff_user_id', 'consumed_at']);
});
DB::statement('ALTER TABLE staff_login_steps ADD CONSTRAINT staff_login_steps_failed_attempts_check CHECK (failed_attempts >= 0)');
```

Model `StaffLoginStep` (`HasUuids`, `$table = 'staff_login_steps'`, casts `expires_at`/`consumed_at` immutable datetimes, `token_hash` hidden, `isExpired(): bool`, `staff(): BelongsTo`). Constants in a small `StaffStepPolicy`-style block on the model: `TTL_SECONDS = 300`, `MAX_FAILED_ATTEMPTS = 5`.

- [ ] **Step 2: Write the failing feature tests** (`StaffStepTest`, plus additions to `CustomerLoginCodeTest` and `StaffLoginTest`). Use the existing helpers of those files (test phones / code helpers, staff factories). Cases:

  1. verify for a phone holding only a customer → `staff_step` is `null`.
  2. verify for a phone holding an active Shopper (and the same for a Courier) → `staff_step.token` is 64 chars, `expires_at` ≈ now + 300 s; the response `token` is a CUSTOMER token (calling `GET /auth/me` with it returns role `customer`); one `staff_login_steps` row exists with `token_hash = hash('sha256', token)`.
  3. verify for a phone holding an active Operator, Admin or Manager → `staff_step` is `null`.
  4. verify for a phone holding a BLOCKED Shopper → `staff_step` is issued (the block is answered at the password, item 9).
  5. a second verify for the same staff phone consumes the earlier open step (the old token now answers `staff_step_invalid`).
  6. `POST /auth/staff/step` with the step and the right password → 200, staff token (`GET /auth/me` → role `shopper`), step `consumed_at` set, `last_login_at` updated.
  7. the same step again → `401 staff_step_invalid` (single use).
  8. wrong password → `401 invalid_credentials`, `failed_attempts` 1; after 5 wrong ones the right password → `401 staff_step_invalid`.
  9. blocked Shopper, right password → `401 account_blocked`; the step is consumed.
  10. step older than 300 s (travel the clock with `$this->travel(301)->seconds()`) → `401 staff_step_expired`.
  11. unknown token → `401 staff_step_invalid`; malformed body (missing / non-64-char token, missing password) → `422`.
  12. a Shopper whose `must_change_password` is true → step login succeeds (200) and the first-login gate then applies as today (`GET` of a protected endpoint → `403 password_change_required`).
  13. `POST /auth/staff/login` for a Shopper (and Courier) with the right password → `403 staff_code_required`, no token created (count `personal_access_tokens` unchanged); with a wrong password → `401 invalid_credentials`; for an Admin with the right password → 200 as before.
  14. 21 step attempts from one IP within a minute → the 21st is `429`.
  15. `SecretsStayOutOfLogsTest`: extend so the step token and the step password never appear in logs or exception reports (follow how the file checks codes and passwords).

- [ ] **Step 3: Run them — expect failures** (`php artisan test --filter=StaffStep` and the two modified files).

- [ ] **Step 4: Implement**

`VerifiedLogin` (result of verify):

```php
final class VerifiedLogin
{
    public function __construct(
        public readonly IssuedSession $customer,
        #[\SensitiveParameter] public readonly ?string $staffStepToken,
        public readonly ?\DateTimeImmutable $staffStepExpiresAt,
    ) {}
}
```

In `VerifyCustomerLoginCode::verify()` after the customer token is created (inside the same transaction): find the staff account of the phone with `role IN (shopper, courier)` and status active or blocked (newest first); if found, mark its open steps consumed, create a step:

```php
$token = Str::random(64);
StaffLoginStep::query()->create([
    'staff_user_id' => $staff->id,
    'token_hash' => hash('sha256', $token),
    'expires_at' => now()->addSeconds(StaffLoginStep::TTL_SECONDS),
]);
```

and return `new VerifiedLogin($session, $token, $expiresAt)`; otherwise `new VerifiedLogin($session, null, null)`. Update the class doc comment: verify still never issues a STAFF session; it may hand out a staff step for a Shopper/Courier (`DL-77`). `CustomerLoginCodeController::verify` adds `'staff_step' => $login->staffStepToken === null ? null : ['token' => …, 'expires_at' => $login->staffStepExpiresAt->format(DATE_ATOM in UTC, as other instants in the API)]`.

`AuthenticateStaffStep(string $stepToken, string $password, string $ip): IssuedSession` — mirror `VerifyCustomerLoginCode`'s pattern (refusal thrown after the transaction commits so attempt counts and consumption persist): IP limiter `staff-step:ip:{ip}` 20/min (hit on every refusal); in a transaction: `StaffLoginStep::where('token_hash', hash('sha256', $stepToken))->lockForUpdate()->first()`; null or consumed or `failed_attempts >= 5` → `staff_step_invalid`; expired → `staff_step_expired`; `Hash::check($password, $staff->password)` false → increment, `invalid_credentials`; true → consume; staff blocked → `account_blocked`; else `last_login_at`, `createToken('staff')`.

`AuthenticateStaff`: after the password check and the blocked check, before issuing the token:

```php
if (in_array($account->role, [Role::Shopper, Role::Courier], true)) {
    // Counted like a failure, as for a blocked account: the caller holds the
    // password, so learning that the code step is required discloses nothing new.
    $this->limiter->hit($phoneKey, self::DECAY_SECONDS);
    $this->limiter->hit($ipKey, self::DECAY_SECONDS);
    throw ApiException::forbidden('staff_code_required');
}
```

(use whatever factory `ApiException` has for 403; add one only if none exists). Route: `Route::post('staff/step', StaffStepController::class)->name('auth.staff.step');` next to `staff/login`. `StaffStepRequest`: `staff_step` required string size 64, `password` required string max as `StaffLoginRequest`.

docs/09: Section 7 — the verify response gains `staff_step` and the sentence "never issues a staff session" becomes "never issues a staff session; for a phone that also holds a Shopper or Courier account it returns a single-use `staff_step` (5 minutes, 5 wrong passwords) for `POST /auth/staff/step`". Section 8 — add the step endpoint paragraph and the `staff_code_required` refusal. Section 52 — add `staff_code_required`, `staff_step_invalid`, `staff_step_expired`.

- [ ] **Step 5: Run the tests** — the new and modified files, then the whole `tests/Feature/Auth` folder; then `pint --test` and `phpstan analyse`. All green.

- [ ] **Step 6: Commit** — `feat(auth): staff password step after the login code (Shopper, Courier)`.

---

### Task 2: Walkthrough scripts follow the new staff sign-in

**Files:** Modify `tasks/scripts/wave1_api_walkthrough.py`, `tasks/scripts/wave2_api_walkthrough.py`, `tasks/scripts/wave3_api_walkthrough.py`; `backend/.env.example` (comment only).

- [ ] Replace every Shopper/Courier `POST /auth/staff/login` in the scripts with one helper: request code → verify (test phone, fixed code from `backend/.env`) → `POST /auth/staff/step` with the walkthrough password. Admin/Operator/Manager keep phone + password. A step refusal or a missing `staff_step` fails the script with a clear message.
- [ ] Wave 3 creates fresh Couriers per run: give them phones from a fixed pool constant in the script; the pool phones must be test phones — add them to the LOCAL `backend/.env` `LOGIN_CODE_TEST_PHONES` (gitignored, not committed) and document the need in a comment in `backend/.env.example` and at the top of the script. If a pool phone already holds an active Courier from an earlier run, block it through the Admin API before creating the new one.
- [ ] Wave 2's Customer-mode code step for staff disappears: staff enter Customer mode with the customer token returned by their verify.
- [ ] Verify: start the stack (served on 8001 as in memory), run `python tasks/scripts/wave1_api_walkthrough.py` and `wave2_api_walkthrough.py` to the end — all checks pass; run `python -m py_compile` on wave3. Report the counts.
- [ ] Commit — `chore(scripts): walkthroughs sign Shoppers and Couriers in with code + password step`.

---

### Task 3: Frontend foundation — kit tokens, Montserrat, white splash

**Files:**
- Create: `frontend/lib/core/theme/kit_colors.dart`, `frontend/lib/core/widgets/brand_wordmark.dart`, `frontend/assets/fonts/Montserrat-Variable.ttf`, `frontend/assets/fonts/Montserrat-OFL.txt`, `frontend/android/app/src/main/res/values-v31/styles.xml`, `frontend/android/app/src/main/res/values-night-v31/styles.xml`, `frontend/android/app/src/main/res/drawable/splash_blank.xml`
- Modify: `frontend/lib/core/theme/app_theme.dart`, `frontend/lib/core/theme/font_licenses.dart`, `frontend/pubspec.yaml`, `frontend/lib/app/router.dart` (`_BootstrapScreen`)
- Delete: `frontend/assets/fonts/Manrope-Variable.ttf`, `frontend/assets/fonts/Manrope-OFL.txt` (no longer used)
- Test: `frontend/test/core/theme/app_theme_test.dart`, `frontend/test/core/theme/font_licenses_test.dart`, new `frontend/test/app/bootstrap_screen_test.dart`

- [ ] Download Montserrat from google/fonts (`ofl/montserrat/Montserrat%5Bwght%5D.ttf`, `ofl/montserrat/OFL.txt`), check the TrueType magic `00 01 00 00` and the copyright line; strip trailing spaces in the licence text so `git diff --check` passes.
- [ ] `KitColors` (`abstract final class`, the Global Constraints values, each with a one-line doc comment of its role). `appFontFamily = 'Montserrat'`; `appSeedColor = KitColors.primary`; `buildAppTheme` keeps `fromSeed` but pins the brand: `colorScheme: ColorScheme.fromSeed(seedColor: KitColors.primary, brightness: b).copyWith(primary: KitColors.primary, onPrimary: Colors.white)`; `FilledButton`/`ElevatedButton` theme: height 56, radius 16, Montserrat 600 16; `InputDecorationTheme`: filled `KitColors.field`, radius 14, border `KitColors.line`, focused border `KitColors.primary` 1.5. Update the theme tests (seed = kit primary, font Montserrat, primary pinned) — rewrite the "derives both schemes from the seed" test to assert the scheme equals `fromSeed(...).copyWith(primary:…, onPrimary:…)`.
- [ ] `registerFontLicenses()` registers Montserrat's OFL instead of Manrope's; the font test loads Montserrat. `pubspec.yaml` fonts/assets switch to Montserrat.
- [ ] `BrandWordmark({double size = 34})`: "BarakaBozor", Montserrat 700, `KitColors.primary`, `Semantics(header: true)`.
- [ ] `_BootstrapScreen` (shown while the session restores): white `Scaffold`, `Center(child: BrandWordmark())`. Test: pumping the app with a session that never resolves shows the wordmark and no spinner.
- [ ] Android 12+ system splash: `values-v31/styles.xml` and `values-night-v31/styles.xml` LaunchTheme with `android:windowSplashScreenBackground` `#FFFFFF` and `android:windowSplashScreenAnimatedIcon` `@drawable/splash_blank` (a transparent vector, 1×1 viewport), so the system splash is plain white, never the default Flutter icon; keep the pre-31 `launch_background.xml` white. (Platform file change: reason in the commit message.)
- [ ] Run `flutter test test/core test/app`, analyze, format. Commit — `feat(theme): kit palette, Montserrat and the white splash (kit stage 1)`.

---

### Task 4: Frontend — session, routing and data for the new sign-in

**Files:**
- Modify: `frontend/lib/features/auth/domain/auth_repository.dart`, `frontend/lib/features/auth/data/auth_api.dart`, `frontend/lib/features/auth/data/auth_repository_impl.dart`, `frontend/lib/features/auth/domain/app_user.dart` (or a new `staff_step.dart` in domain), `frontend/lib/core/session/session_state.dart`, `frontend/lib/core/session/session_controller.dart`, `frontend/lib/core/routing/app_paths.dart`, `frontend/lib/core/routing/session_redirect.dart`, `frontend/lib/features/auth/presentation/auth_routes.dart`, `frontend/lib/features/shells/presentation/staff_area_menu.dart`
- Delete: `frontend/lib/features/auth/presentation/customer_mode_screen.dart` (and its route, path, l10n keys if unused)
- Test: `frontend/test/support/fake_auth_repository.dart`, `frontend/test/features/auth/data/auth_api_test.dart`, `frontend/test/core/session/session_controller_test.dart`, `frontend/test/core/routing/session_redirect_test.dart`, `frontend/test/features/shells/presentation/staff_area_menu_test.dart`

**Interfaces:**
- `final class StaffStep { final String token; final DateTime expiresAt; }` (strict parse: 64-char token, ISO instant).
- `AuthRepository.verifyCustomerCode(...)` returns `VerifiedLogin { IssuedSession customer; StaffStep? staffStep; }`; new `Future<IssuedSession> staffStep({required String token, required String password})` → `POST /auth/staff/step`.
- `SignedIn` gains `final StaffStep? staffStep;` (the pending password step; `copyWith` cannot clear it — add `withoutStaffStep()`).
- `SessionController`: `verifyCustomerCode` stores the customer session and, when a step came back, `SignedIn(activeMode: customer, customerUser, staffStep: step)`; `Future<void> completeStaffStep(String password)` → stores the staff token, `activeMode: staff`, clears the step; `void dismissStaffStep()` → stays the customer; `Future<void> updateCustomerName(String fullName)` (through the existing profile repository) refreshes `customerUser`. Remove `requestCustomerModeCode`/`enterCustomerMode`. `canOfferCustomerMode` additionally requires `customerUser != null`.
- Paths: `AppPaths.staffPassword = '/auth/staff-password'`, `AppPaths.customerName = '/auth/name'`; `/auth/customer-mode` and the mobile use of `/auth/staff` go away.

- [ ] Write the failing tests first:
  - API: verify parses `staff_step` null / object; strict parse rejects a 63-char token or a bad instant; `staffStep()` posts the body and parses the staff session; `staff_code_required`, `staff_step_invalid`, `staff_step_expired` map to `ApiRefusal` codes.
  - Session controller: customer verify without step → SignedIn customer, no step; with step → customer session stored in the customer slot, `staffStep` set; `completeStaffStep` → staff token stored in the staff slot, active mode staff, both users kept, step cleared; a refusal (`invalid_credentials`) keeps the step; `staff_step_expired`/`staff_step_invalid` clears the step and stays the customer; `dismissStaffStep` clears it; `switchMode(customer)` works with no code when `customerUser` exists; logout of the staff slot keeps the customer.
  - Redirect (mobile): SignedIn with `staffStep` → only `/auth/staff-password`; customer with `fullName == null` and no step → only `/auth/name`; with a name → role home. Web surface: signed-out `/auth` stays `/auth` (rendered as the staff login by Task 5); the code routes are not reachable on web.
  - Staff menu: "Режим покупателя" switches at once when `customerUser != null`, and is absent when it is null (sessions from before this change) or while `mustChangePassword`.
- [ ] Implement to green, following the file's existing patterns (account-scoped state, no navigation from completions whose surface was left — `DL-28`). Fake repository: `FakeAuthRepository` gains `staffSteps` (phone → step) and `staffStep()` with refusal switches like its other methods.
- [ ] Run `flutter test test/core test/features/auth test/features/shells`, analyze, format. Commit — `feat(auth): the session starts as the customer and adds the staff step`.

---

### Task 5: Frontend — the sign-in screens of `kit/01-vhod`

**Files:**
- Modify: `frontend/lib/features/auth/presentation/auth_scaffold.dart`, `phone_screen.dart`, `code_screen.dart`, `code_entry.dart`, `phone_field.dart`, `staff_login_screen.dart`, `change_password_screen.dart`, `unreachable_screen.dart`, `wrong_surface_screen.dart`, `auth_routes.dart`; both ARB files + `flutter gen-l10n`
- Create: `frontend/lib/features/auth/presentation/staff_password_screen.dart`, `customer_name_screen.dart`, `confirm_phone_dialog.dart`, `welcome_dialog.dart`, `code_boxes.dart`, `auth_entry_screen.dart`
- Test: `frontend/test/features/auth/presentation/customer_login_flow_test.dart`, `staff_login_flow_test.dart`, `surface_and_unreachable_test.dart`, `phone_field_test.dart`, new `sign_in_screens_test.dart`

Match the approved design screen by screen (open `kit/01-vhod.dc.html` through `mcp__claude-design__render_preview` + `G:\tools\bb-walk\shot-url.ps1` if a value is unclear; the exported source PNGs are in `G:\tools\tmp\figma-kit\light`). Shared look: white background, 24 px side padding, `BrandWordmark` at the top, title Montserrat 700 24 `KitColors.ink`, subtitle 14 `KitColors.muted`, 56 px green buttons, the language globe (`LanguageMenuButton`) top-right in a 40 px outlined circle.

- [ ] `auth_entry_screen.dart`: `/auth` builds `PhoneScreen` on `Surface.mobile` and `StaffLoginScreen` on the web surface (the panel), from `surfaceProvider`.
- [ ] **02 Вход** (`PhoneScreen`): wordmark, title, subtitle, `PhoneField` with the fixed `+998` prefix, primary "Получить код", a row with a Telegram icon (`assets`-free: a 20 px blue circle `#2AABEE` with a white `Icons.send_rounded` rotated −30°) and "Код придёт в Telegram", and the small terms line at the bottom (plain text for now; the terms screen arrives with stage 7). No staff link.
- [ ] **03 Подтверждение номера**: `showConfirmPhoneDialog` before the request — the formatted number, "Изменить" (closes) and "Отправить" (requests the code). Not dismissible while the request runs.
- [ ] **04 Код из Telegram** (`CodeScreen`): six boxes (`CodeBoxes`: one hidden `TextField` with `autofillHints: [AutofillHints.oneTimeCode]`, digits only, max 6, paste fills all; the boxes draw the digits and the caret, the focused/filled box green), "Отправить ещё раз через 0:58" countdown (existing logic), "Изменить номер", "Подтвердить". Keep the existing keys (`code-field`, `verify-button`, …) where tests use them.
- [ ] **05 Как вас зовут?** (`CustomerNameScreen` at `/auth/name`): one name field (validation as the profile's name form), "Продолжить" → `updateCustomerName` → **06** `showWelcomeDialog` ("Добро пожаловать, {name}!", "К покупкам") → customer home.
- [ ] **07 Пароль сотрудника** (`StaffPasswordScreen` at `/auth/staff-password`): back arrow (= `dismissStaffStep`, continues as the customer), title, subtitle, password field with the eye toggle, "Войти" → `completeStaffStep`; `invalid_credentials` → field error "Неверный пароль"; expired/invalid step → a message and a "Получить новый код" button that logs the customer slot out and returns to `/auth`; note "Забыли пароль? Обратитесь к администратору".
- [ ] **08 Смена временного пароля**, **09 Нет связи с сервером**, **10 Аккаунт работает в веб-панели**: restyle the existing screens to the design (behaviour unchanged). The web `StaffLoginScreen` gets the same look; its `staff_code_required` refusal reads "Этот аккаунт работает в приложении BarakaBozor на телефоне".
- [ ] Strings (uz + ru) for every new text; Uzbek: "Kirish", "Telefon raqamingizni kiriting — kirish kodini yuboramiz", "Kod olish", "Kod Telegramga keladi", "Raqamni tekshiring", "Unga Telegramda kod yuboramiz", "O'zgartirish", "Yuborish", "Kodni kiriting", "Kodni Telegramga yubordik: {phone}", "Ismingiz nima?", "Ism yig'uvchi va kuryerga kerak", "Davom etish", "Xush kelibsiz, {name}!", "Bozordan yangi mahsulotlar sizni kutmoqda", "Xaridlarga", "Xodim sifatida kirish", "Raqam tasdiqlandi. Xodim parolini kiriting", "Parolni unutdingizmi? Administratorga murojaat qiling", "Yangi kod olish", "Bu hisob telefondagi BarakaBozor ilovasida ishlaydi" (Russian = the design's texts).
- [ ] Tests (rewrite the flows; never weaken): customer flow (phone → confirm dialog → code → name → welcome → home; a returning customer with a name skips the name step); staff flow (Shopper test phone → code → password → shopper home; then Customer mode with no code; back on the password screen → customer home; wrong password stays; expired step → new code); web surface `/auth` shows the staff login and a Shopper there gets the "works in the app" message; code boxes accept paste of "123456"; every screen at 320×640, text ×2, uz and ru, without exception.
- [ ] Run `flutter test test/features/auth test/app test/core test/features/shells`, analyze, format. Commit — `feat(auth): the sign-in screens of the kit (stage 1)`.

---

### Task 6: Record, documents, full verification

**Files:** `docs/DECISIONS.md` (append `DL-76` Owner, `DL-77` agent), `docs/02-user-roles.md` (§2, §10), `docs/04-user-flows.md` (§2, §3), `docs/07-architecture.md` (only if it describes the auth screens), `tasks/REDESIGN_CUSTOMER.md` (becomes the kit-stage tracker).

- [ ] `DL-76 — The screen kit and sign-in (2026-10-15, Owner)`: (1) the Figma "Grocery App UI Kit" is the design base; all its light screens live in Claude Design (`kit/` files) and are coded stage by stage (1 Вход … 7 Профиль); design 4a (`DL-74`) is superseded as the target, its header stays until stage 2; (2) onboarding is not wanted; (3) splash: white with the wordmark; (4) customer sign-in keeps phone + Telegram code, kit look, no password or Google; a name step after the first login; (5) in the mobile app everyone enters by code; a Shopper/Courier then gives the staff password; the "Войти как сотрудник" button goes; the panel keeps phone + password; (6) Customer mode needs no second code — supersedes `docs/02` §10 "verifies a Customer login code" and S-37 for this point, since the code was verified at sign-in.
- [ ] `DL-77 — Sign-in implementation (2026-10-15, agent)`: the step table, token and limits; `staff_code_required` and why it is answered only after the right password; the web `/auth` entry; Montserrat replaces Manrope (Poppins has no Cyrillic); kit tokens; Android 12 white system splash; white primary text on `#5AC268` is below WCAG contrast (2.4:1) — kept as the kit's look, listed as a risk.
- [ ] docs/02 §2 Staff and §10, docs/04 §2 and §3 rewritten to the new flows (concise, as the files are written).
- [ ] `tasks/REDESIGN_CUSTOMER.md`: title "Kit stages", table of the 7 stages (1 Вход — In Progress, 2–7 Planned), the risks (WCAG contrast; real Telegram delivery arrives in Wave 4 — until then only test phones can sign in, staff included), the part-1 rows kept as history.
- [ ] Full verification: backend whole suite in Docker (`php artisan test`, ~3 min), pint, phpstan; frontend `flutter test` (whole), analyze, format, `git diff --check main...HEAD`. Commit — `docs(kit): record stage 1 decisions (DL-76, DL-77)`.
