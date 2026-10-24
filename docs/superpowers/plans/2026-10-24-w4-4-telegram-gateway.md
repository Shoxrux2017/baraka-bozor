# W4-4 — Login Codes Through Telegram Gateway Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task (one `plan-implementer` per task, the lead checks each diff). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A login code reaches the phone through Telegram Gateway; a number Telegram cannot reach is refused with `409 code_delivery_unavailable`; paid checks to strangers are capped by a daily ceiling that never blocks an existing account; and the store reviewer's phone of `DL-105` signs in with its own fixed code in production.

**Architecture:** `TelegramGatewayCodeDelivery` implements the existing `CodeDeliveryGateway` with two back-to-back calls (`checkSendAbility`, then `sendVerificationMessage` under the returned `request_id` with our own code and `ttl` 300), selected by `LOGIN_CODE_DRIVER=telegram`. `RequestCustomerLoginCode` gains two refusals before any challenge is written: the unreachable number (a new `CodeUndeliverable` exception) and the daily ceiling (`LoginCodeCeiling`). Per-address limits key an IPv6 client by its /64 through one helper. `TestPhones` learns the reviewer phone, which `VerifyCustomerLoginCode` never gives a staff step and on which no staff account can be created.

**Tech Stack:** Laravel 13 HTTP client (`Http` facade, already used by `GoogleGeocoder`), `Illuminate\Cache\RateLimiter` on the database cache store, Flutter `gen-l10n`. No new Composer or pub dependency.

**Spec:** `tasks/WAVE_4.md` task note W4-4; `docs/DECISIONS.md` `DL-104` (9), `DL-105`, `DL-11`; `docs/09-api-contracts.md` sections 6, 7, 52, 64; `docs/07-architecture.md` sections 8, 23, 31. Finer decisions go into `DL-110` (Task 6).

**Found before the plan (2026-10-24):**
- Telegram Gateway API (`core.telegram.org/gateway/api`): base `https://gatewayapi.telegram.org/<method>`, token as `Authorization: Bearer`, JSON body accepted, answer `{"ok":true,"result":{RequestStatus}}` or `{"ok":false,"error":"<STRING>"}`. `checkSendAbility(phone_number)` charges only when it confirms the number (free on the account's own number); `sendVerificationMessage(phone_number, request_id, code, ttl)` is free under that `request_id`, a repeat under it is an error; `code` 4–8 digits, `ttl` 30–3600, refunded when not delivered within `ttl`.
- The reference names one error string, `ACCESS_TOKEN_INVALID`. A Go client (`apifonica/tg-gateway-go`) lists the rest: `PHONE_NUMBER_INVALID`, `PHONE_NUMBER_NOT_FOUND`, `PHONE_NUMBER_NOT_AVAILABLE`, `BALANCE_NOT_ENOUGH`, `FLOOD_WAIT`, `REQUEST_ID_INVALID`, `MESSAGE_ALREADY_SENT`, `TTL_INVALID`, `CODE_LENGTH_INVALID`, … Which one a number without Telegram gets is confirmed in Task 7 with the Owner's token (a check that does not confirm is free).
- All three code screens (sign-in, Customer mode, account deletion) render refusals through `FailureMessage` → `failureText` (`frontend/lib/core/localization/failure_text.dart`); the client already shows `codeSentToPhone` for the `telegram` channel.
- `GoogleGeocoder` is the pattern for a provider adapter: `Http::timeout(5)->connectTimeout(3)`, catch `ConnectionException|RequestException`, log a reason only, throw a bare exception. `AddressSearchApiTest` is the pattern for `Http::fake`.
- Staff accounts never change phone (`UpdateStaffRequest`); they are created by `CreateStaff` and `bootstrap:first-admin`, and re-activated by `ActivateStaff`.

## Global Constraints

- Branch `task/w4-4-telegram-gateway` from `main` `1a8da77`. Never commit to `main`.
- Backend commands only inside the dev stack: `docker compose -f docker/compose.yaml exec -T app …` from the repository root. Never run `migrate:fresh`, `migrate:refresh`, `migrate:reset`, `migrate:rollback`, `db:wipe` or `db:seed` against it, and never `--env=testing` with any of them.
- `README.md` at the root carries the Owner's uncommitted edit and `.superpowers/` is untracked: never staged.
- No Composer or pub dependency.
- No test reaches the network: every Telegram test calls `Http::preventStrayRequests()` and fakes `https://gatewayapi.telegram.org/*`.
- Secrets (`AGENTS.md` §5, `DL-11` (3)): the code, the token and the phone never appear in a log line, an exception message, a response or a header. The token travels only in the `Authorization` header, never in a URL. `CodeDeliveryFailed` and `CodeUndeliverable` are thrown without a previous exception. A logged Telegram reason is Telegram's error string only when it matches `/^[A-Z_]{1,64}\z/` (no digits, so a code can never ride in it); otherwise `connection`, `http_<status>` or `unreadable`. Parameters carrying the code or the token are `#[\SensitiveParameter]`.
- Names fixed across tasks: channel `telegram`; API codes `code_delivery_unavailable` (`409`), `provider_unavailable` (`503`), `phone_reserved` (`409`); settings `TELEGRAM_GATEWAY_TOKEN` (`config('services.telegram_gateway.token')`), `LOGIN_CODE_DAILY_LIMIT` (`config('login_codes.daily_limit')`, default `500`), `LOGIN_CODE_REVIEWER_PHONE` and `LOGIN_CODE_REVIEWER_CODE` (`config('login_codes.reviewer_phone')`, `config('login_codes.reviewer_code')`); cache keys `login-code:day:<Y-m-d in Asia/Tashkent>`; log messages `Telegram Gateway refused a login code.`, `Login code daily ceiling half used.`, `Login code daily ceiling reached.`.
- Comments and docblocks match `app/Modules/Auth`: a header saying what and why with `docs/` and `DL-` references; no comment narrating a line.
- Client texts: Uzbek Latin with the ASCII apostrophe (`DL-16`); `app_uz.arb` is the template. Generated localization files are regenerated with `flutter gen-l10n`, never hand-edited.
- Flutter runs from PowerShell with `$env:TEMP='G:\tools\tmp'; $env:TMP='G:\tools\tmp'`, `G:\tools\flutter\bin\flutter.bat`, tests with `--concurrency=2`.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Before the pull request: full backend suite, `vendor/bin/pint --test`, `vendor/bin/phpstan analyse`, `flutter analyze`, `dart format --set-exit-if-changed lib test`, full `flutter test`, `git diff --check`, and `/security-review` once (sign-in, a provider token, phone numbers leaving the server).

## Review Focus

1. **A number without Telegram gets a string we did not list.** The Customer would read "service unavailable" instead of the Telegram text. Task 2 Step 1 (each of the three listed strings → `409`); Task 7 Step 2 (the real answer for a number without Telegram is observed and, if new, added).
2. **The check is paid and the send fails.** A timeout on the second call must leave no challenge, answer `503`, cost the phone its hour slot, and never retry either call (a retried check is a second charge). Task 2 Step 1 (`test_a_send_that_times_out_after_a_paid_check…`, exactly two requests sent).
3. **A Telegram answer that echoes the request.** A `500` whose body repeats the code and the token must reach neither the log, nor the response, nor the exception message. Task 2 Step 1 (echo test in `SecretsStayOutOfLogsTest` and the direct adapter test).
4. **A flood blocks someone who already has an account.** Above the ceiling, an active Customer, an active Shopper with no Customer account, and an account-deletion code must still be served. Task 3 Step 1.
5. **IPv6 behind the proxy.** A client rotating addresses inside one /64, and an IPv4 client seen as `::ffff:a.b.c.d`, must share one bucket; two different /64s must not. Task 1 Step 1.

---

### Task 1: Per-address limits count an IPv6 client by its /64

**Files:**
- Create: `backend/app/Support/Http/ClientAddress.php`
- Modify: `backend/app/Modules/Auth/Actions/RequestCustomerLoginCode.php` (key `login-code:ip:…`), `AuthenticateStaff.php` (`staff-login:ip:…`), `AuthenticateStaffStep.php` (`staff-step:ip:…`)
- Test: create `backend/tests/Unit/Support/ClientAddressTest.php`; modify `backend/tests/Feature/Auth/CustomerLoginCodeTest.php`, `StaffLoginTest.php`

**Interfaces:**
- Produces: `App\Support\Http\ClientAddress::limiterKey(string $ip): string` — an IPv4 address as given; an IPv4-mapped IPv6 address (`::ffff:203.0.113.7`) as its IPv4; any other IPv6 address as `inet_ntop` of its first 8 bytes followed by 8 zero bytes, plus `/64` (`2001:db8:1:2::/64`); anything `inet_pton` cannot read, as given.

- [ ] **Step 1: Write the failing tests.**
  - `ClientAddressTest` (data provider): `203.0.113.7` → `203.0.113.7`; `2001:db8:1:2:3:4:5:6` and `2001:DB8:1:2:ffff::1` → `2001:db8:1:2::/64`; `2001:db8:1:3::1` → `2001:db8:1:3::/64`; `::ffff:203.0.113.7` → `203.0.113.7`; `` → ``; `not-an-ip` → `not-an-ip`.
  - `CustomerLoginCodeTest::test_ten_requests_per_ipv6_prefix_per_minute`: ten requests from `2001:db8:5:6::1` … `2001:db8:5:6::a` (`REMOTE_ADDR`) to ten phones pass; the eleventh from `2001:db8:5:6:ffff::1` is `429 rate_limited`; one from `2001:db8:5:7::1` passes.
  - `StaffLoginTest::test_the_address_limit_counts_an_ipv6_prefix`: the per-IP failed-login limit (`AuthenticateStaff::IP_ATTEMPTS`) reached from addresses of one /64 refuses the next attempt from another address of it with `429`.
- [ ] **Step 2: Run** `docker compose -f docker/compose.yaml exec -T app php artisan test --filter='ClientAddressTest|ipv6'` — FAIL (class missing; eleventh request passes).
- [ ] **Step 3: Implement** `ClientAddress::limiterKey` and use it for the three `…:ip:` keys. Docblock: one subscriber holds a whole /64, so counting single IPv6 addresses would let one phone rotate past every per-address limit (`DL-104` (9)).
- [ ] **Step 4: Run** the filter of Step 2, then `--filter='CustomerLoginCodeTest|StaffLoginTest|StaffStepTest'` — PASS.
- [ ] **Step 5: Commit** `feat: per-address login limits count an IPv6 client by its /64`.

### Task 2: The Telegram Gateway adapter and the unreachable number

**Files:**
- Create: `backend/app/Modules/Auth/CodeDelivery/TelegramGatewayCodeDelivery.php`, `backend/app/Modules/Auth/CodeDelivery/CodeUndeliverable.php`
- Modify: `CodeDeliveryGateway.php` (docblock: `@throws CodeUndeliverable when no channel the gateway has reaches the number`), `backend/app/Modules/Auth/AuthServiceProvider.php` (driver `telegram`), `backend/config/services.php` (`'telegram_gateway' => ['token' => env('TELEGRAM_GATEWAY_TOKEN')]`), `backend/config/login_codes.php` (header comment: `telegram` exists), `RequestCustomerLoginCode.php`, `backend/app/Support/Runtime/ProductionConfiguration.php`
- Test: create `backend/tests/Feature/Auth/TelegramGatewayCodeDeliveryTest.php`; modify `SecretsStayOutOfLogsTest.php`, `CustomerLoginCodeTest.php`, `backend/tests/Feature/Accounts/AccountDeletionApiTest.php`, `backend/tests/Feature/Runtime/ProductionConfigurationTest.php`

**Interfaces:**
- Produces: `final class CodeUndeliverable extends RuntimeException` — no channel reaches the number; carries no message beyond a fixed sentence.
- Produces: `TelegramGatewayCodeDelivery implements CodeDeliveryGateway` with `CHANNEL = 'telegram'`, `BASE_URL = 'https://gatewayapi.telegram.org'`, `UNREACHABLE = ['PHONE_NUMBER_INVALID', 'PHONE_NUMBER_NOT_FOUND', 'PHONE_NUMBER_NOT_AVAILABLE']`, constructor `(#[\SensitiveParameter] string $token)`, `deliver(string $phone, #[\SensitiveParameter] string $code): string` returning `telegram`, throwing `CodeUndeliverable` for an `UNREACHABLE` error of either call and `CodeDeliveryFailed('Telegram Gateway: <reason>')` for anything else that is not `ok: true` with a non-empty string `result.request_id`.
- Produces: `RequestCustomerLoginCode` answers `ApiException::conflict('code_delivery_unavailable')` on `CodeUndeliverable`, creates no challenge, logs nothing.

- [ ] **Step 1: Write the failing tests.** In `TelegramGatewayCodeDeliveryTest` (`setUp`: `config(['login_codes.driver' => 'telegram', 'services.telegram_gateway.token' => 'tg-test-token'])`, `Http::preventStrayRequests()`), through `POST /api/v1/auth/customer/code/request` unless said otherwise:
  - `test_a_code_goes_out_as_a_check_then_a_send_under_its_request_id`: check answers `{"ok":true,"result":{"request_id":"req-1","phone_number":"+998901234567","request_cost":0.01}}`, send answers `{"ok":true,"result":{"request_id":"req-1"}}`. `200`, `data.channel` = `telegram`. Exactly two requests, in order: POST `…/checkSendAbility` with JSON `{"phone_number":"+998901234567"}`; POST `…/sendVerificationMessage` with `phone_number`, `request_id` `req-1`, `ttl` `300`, and a six-digit `code` for which `Hash::check` passes against the stored challenge's `code_hash`. Both carry `Authorization: Bearer tg-test-token`; neither URL contains the token.
  - `test_a_number_telegram_cannot_reach_is_refused_without_a_challenge` (data provider: the three `UNREACHABLE` strings, answered by the check with HTTP `400` `{"ok":false,"error":…}`): `409`, `code` `code_delivery_unavailable`; zero challenges; one request sent.
  - `test_a_provider_refusal_is_provider_unavailable` (data provider → logged reason): `ACCESS_TOKEN_INVALID`, `BALANCE_NOT_ENOUGH`, `FLOOD_WAIT` → the same string; `{"ok":false,"error":"CODE_123456"}` → `unreadable`; HTTP `502` with an HTML body → `http_502`; `{"ok":true,"result":{}}` → `unreadable`; a non-JSON `200` → `unreadable`. Each: `503 provider_unavailable`, zero challenges, one `Telegram Gateway refused a login code.` warning whose context is exactly `['reason' => <expected>]`.
  - `test_a_check_that_times_out_is_provider_unavailable`: check → `Http::failedConnection()`; `503`, reason `connection`, one request.
  - `test_a_send_that_times_out_after_a_paid_check_is_not_retried`: check ok, send → `Http::failedConnection()`; `503`, zero challenges, exactly two requests; a second request for the phone sends again (a new check), and the sixth within the hour is `429 rate_limited`.
  - `test_the_adapter_message_carries_neither_the_code_nor_the_token`: `new TelegramGatewayCodeDelivery('tg-secret-token')` called directly with code `482913`; the send's fake echoes the request body and the `Authorization` header in a `500`; the caught `CodeDeliveryFailed` has `getPrevious() === null` and a message containing neither `482913` nor `tg-secret-token`.
  - `test_the_telegram_driver_needs_a_token`: token `''` → resolving `CodeDeliveryGateway` throws `RuntimeException` whose message names `TELEGRAM_GATEWAY_TOKEN`.
  - `SecretsStayOutOfLogsTest::test_a_login_code_and_the_telegram_token_stay_out_of_the_log_when_telegram_echoes_them`: driver `telegram`; the send's fake captures the code from the request body and answers `500` echoing body and header; assert logged without the captured code and without the token, and the response body without either.
  - `CustomerLoginCodeTest::test_an_unreachable_number_is_409_and_still_costs_the_send_slot`: a gateway bound in the test throws `CodeUndeliverable`; five requests are `409`, the sixth `429 rate_limited`; zero challenges.
  - `AccountDeletionApiTest::test_the_deletion_code_is_refused_when_the_number_cannot_be_reached`: same bound gateway; `POST /api/v1/customer/account/deletion-code` → `409 code_delivery_unavailable`; zero `account_deletion` challenges; an open sign-in challenge is left as it was.
  - `ProductionConfigurationTest`: driver `telegram` with a blank token lists `TELEGRAM_GATEWAY_TOKEN`; with a token, it does not; driver `fake` never lists it.
- [ ] **Step 2: Run** `… php artisan test --filter='TelegramGatewayCodeDeliveryTest|SecretsStayOutOfLogsTest|CustomerLoginCodeTest|AccountDeletionApiTest|ProductionConfigurationTest'` — FAIL.
- [ ] **Step 3: Implement.** Each call: `Http::timeout(5)->connectTimeout(3)->withToken($token)->acceptJson()->asJson()->post(BASE_URL.'/<method>', …)`; catch `ConnectionException|RequestException` → reason `connection`. Read the body whatever the HTTP status: `ok === false` with an error string → `UNREACHABLE` throws `CodeUndeliverable`, otherwise the string (if it matches the reason pattern) is the reason; no readable `ok` → `http_<status>` when the status is not 2xx, else `unreadable`. A failure logs the one warning with `['reason' => …]` and throws. No retry of either call. The binding: `'telegram' => new TelegramGatewayCodeDelivery(<token>)`, throwing `RuntimeException('LOGIN_CODE_DRIVER is "telegram" but TELEGRAM_GATEWAY_TOKEN is empty.')` for a blank token; the default arm's message names `fake` and `telegram`. `ProductionConfiguration::problems()` adds `TELEGRAM_GATEWAY_TOKEN` when the driver is `telegram` and the token is blank. The adapter's docblock carries the two-call cost rule of `DL-104` (9) and why the calls stay back to back.
- [ ] **Step 4: Run** the filter of Step 2 — PASS; then `--filter=Auth` — PASS.
- [ ] **Step 5: Commit** `feat: login codes through Telegram Gateway; 409 code_delivery_unavailable`.

### Task 3: The daily ceiling of paid checks for phones without an account

**Files:**
- Create: `backend/app/Modules/Auth/LoginCodeCeiling.php`
- Modify: `backend/config/login_codes.php` (`'daily_limit' => env('LOGIN_CODE_DAILY_LIMIT', 500)` with its comment), `RequestCustomerLoginCode.php`, `ProductionConfiguration.php`
- Test: create `backend/tests/Feature/Auth/LoginCodeCeilingTest.php`; modify `ProductionConfigurationTest.php`

**Interfaces:**
- Consumes: Task 2's refusals stay as they are; the ceiling runs before the gateway call.
- Produces: `App\Modules\Auth\LoginCodeCeiling` with constructor `(RateLimiter $limiter)` and `reserve(string $phone): void`. It returns at once when any `users` row with this phone has status `active` (any role). Otherwise it hits `login-code:day:<Y-m-d in Asia/Tashkent>` (decay 86400 s), logs `Login code daily ceiling half used.` when the new count equals `intdiv($limit, 2)` and is above zero, logs `Login code daily ceiling reached.` when it equals `$limit` (context exactly `['limit' => $limit]`), and throws `ApiException::unavailable('provider_unavailable')` when it exceeds `$limit`. `$limit` is `(int) config('login_codes.daily_limit')`.
- Produces: `RequestCustomerLoginCode` calls `reserve()` after the hour slot, only when a code will really be delivered (not for a test or reviewer phone), before `deliver()`.

- [ ] **Step 1: Write the failing tests** (`config(['login_codes.daily_limit' => 4])`, the fake gateway, each request from its own `REMOTE_ADDR`):
  - `test_new_phones_are_refused_above_the_ceiling`: four new phones `200`; the fifth `503 provider_unavailable` and no challenge for it.
  - `test_existing_accounts_still_get_codes_above_the_ceiling`: after the ceiling, an active Customer's phone `200`; an active Shopper's phone with no Customer account `200`; an active Customer's `POST /api/v1/customer/account/deletion-code` `200`; a phone whose only account is a blocked Customer `503`.
  - `test_test_phones_never_count`: with limit `1` and a configured test phone, three test-phone requests, then one new phone `200`.
  - `test_warnings_at_half_and_at_the_ceiling_once_each`: six new phones; exactly one half warning (after the second) and one reached warning (after the fourth), each with context `['limit' => 4]` and no phone in any logged line.
  - `test_the_ceiling_starts_again_with_the_tashkent_day`: `travelTo` 23:58 `Asia/Tashkent`, exhaust; `travelTo` 00:02 the next Tashkent day; a new phone `200`.
  - `ProductionConfigurationTest`: `LOGIN_CODE_DAILY_LIMIT` of `0`, `-1`, `abc` is listed; `500` and the default are not.
- [ ] **Step 2: Run** `… php artisan test --filter='LoginCodeCeilingTest|ProductionConfigurationTest'` — FAIL.
- [ ] **Step 3: Implement** `LoginCodeCeiling` and the call. `ProductionConfiguration::problems()` lists `LOGIN_CODE_DAILY_LIMIT` unless `filter_var(…, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]])` accepts it. The class docblock carries `DL-104` (9)'s cost reasoning and its price: while the ceiling holds, the refusal tells a phone with no account from one with an account (`docs/09` section 6). The counter is taken before the call, as every login-code counter is (`DL-11` (1)), so it also counts checks that Telegram did not charge; it errs toward spending less.
- [ ] **Step 4: Run** the filter of Step 2 — PASS; then `--filter=Auth` — PASS.
- [ ] **Step 5: Commit** `feat: daily ceiling of paid login-code checks for phones without an account`.

### Task 4: The store reviewer's phone (`DL-105`)

**Files:**
- Modify: `backend/config/login_codes.php` (`reviewer_phone`, `reviewer_code`, comment), `backend/app/Modules/Auth/TestPhones.php`, `backend/app/Modules/Auth/LoginCodePolicy.php`, `backend/app/Modules/Auth/Actions/VerifyCustomerLoginCode.php`, `backend/app/Modules/Staff/Actions/CreateStaff.php`, `backend/app/Modules/Staff/Actions/ActivateStaff.php`, `backend/app/Console/Commands/BootstrapFirstAdminCommand.php`
- Test: modify `backend/tests/Unit/Auth/TestPhonesTest.php`, `CustomerLoginCodeTest.php`, `backend/tests/Feature/Staff/AdminStaffApiTest.php`, `backend/tests/Feature/Console/BootstrapFirstAdminCommandTest.php`

**Interfaces:**
- Produces: `TestPhones::__construct(array $phones, ?string $code, bool $production = false, ?string $reviewerPhone = null, #[\SensitiveParameter] ?string $reviewerCode = null)`; `codeFor()` also returns the reviewer code for the reviewer phone; `isReviewer(string $phone): bool`. `fromConfig()` reads the two new keys (blank → null).
- Produces: `LoginCodePolicy::isGuessable(#[\SensitiveParameter] string $code): bool` — six identical digits, or every digit one more than the one before, or every digit one less.
- Produces: `409 phone_reserved` from `POST /admin/staff` and `POST /admin/staff/{user}/activate` for the reviewer phone (Task 5 gives it words, Task 6 documents it).

- [ ] **Step 1: Write the failing tests.**
  - `TestPhonesTest`: a reviewer phone with a sound code boots in production with no test phones, and `codeFor` gives its code and `isReviewer` is true; test phones in production still refuse to boot. Each refusal throws `RuntimeException` whose message names the setting and never its value: only one of the two reviewer settings set; a phone not `+998` and nine digits; a code not six digits; a guessable code (`000000`, `123456`, `654321`, `012345`); a code equal to `LOGIN_CODE_TEST_CODE`; the reviewer phone also in the test phones. `isGuessable`: true for `000000`, `999999`, `123456`, `012345`, `654321`, `987654`; false for `482913`, `102938`, `123465`.
  - `CustomerLoginCodeTest::test_the_reviewer_phone_signs_in_with_its_own_code_and_receives_nothing`: config `reviewer_phone` `+998900000077`, `reviewer_code` `482913`; request answers `channel` `test`, the gateway is never called (the sink holds nothing), verify with `482913` issues a Customer token, and `123456` is `code_invalid`.
  - `CustomerLoginCodeTest::test_the_reviewer_phone_never_receives_a_staff_step`: an active Shopper made directly on the reviewer phone (factory, as a configuration made after the account would leave it); verify answers `staff_step: null`.
  - `AdminStaffApiTest`: create on the reviewer phone → `409 phone_reserved`, no account written; activate a blocked staff account on that phone → `409 phone_reserved`, still blocked.
  - `BootstrapFirstAdminCommandTest`: the command refuses the reviewer phone with a non-zero exit and writes no account.
- [ ] **Step 2: Run** `… php artisan test --filter='TestPhonesTest|CustomerLoginCodeTest|AdminStaffApiTest|BootstrapFirstAdminCommandTest'` — FAIL.
- [ ] **Step 3: Implement.** `TestPhones` checks the reviewer settings in the constructor whatever the environment; its docblock replaces "empty in production" with the reviewer exception of `DL-105`. `VerifyCustomerLoginCode` takes `TestPhones` and returns no staff step for the reviewer phone. `CreateStaff` (constructor-injected `TestPhones`) refuses before `activeHolderExists`; `ActivateStaff` refuses after its natural-repeat return; the command prints `That phone is the store reviewer's (LOGIN_CODE_REVIEWER_PHONE); no staff account may sit on it.` and returns failure.
- [ ] **Step 4: Run** the filter of Step 2 — PASS; then `--filter='Auth|Staff|Console'` — PASS.
- [ ] **Step 5: Commit** `feat: the store reviewer's phone with its own code (DL-105)`.

### Task 5: The app's words for the two refusals

**Files:**
- Modify: `frontend/lib/core/localization/l10n/app_uz.arb`, `app_ru.arb`, `frontend/lib/core/localization/failure_text.dart`; regenerate `frontend/lib/core/localization/generated/`
- Test: `frontend/test/core/localization/failure_text_test.dart`, `frontend/test/features/auth/presentation/customer_login_flow_test.dart`

**Interfaces:**
- Consumes: API codes `code_delivery_unavailable` (Task 2), `phone_reserved` (Task 4).
- Produces: ARB keys `errorCodeDeliveryUnavailable`, `errorPhoneReserved`.

- [ ] **Step 1: Write the failing tests.** `failure_text_test`: `ApiRefusal` `code_delivery_unavailable` / `409` and `phone_reserved` / `409` map to the new texts in both languages. `customer_login_flow_test`: a code request refused with `code_delivery_unavailable` shows the Russian text on the phone screen and stays on it.
- [ ] **Step 2: Run** `flutter test --concurrency=2 test/core/localization test/features/auth/presentation/customer_login_flow_test.dart` — FAIL.
- [ ] **Step 3: Add the texts** (exact copy), map both codes in `_refusalText`, run `flutter gen-l10n`.
  - `errorCodeDeliveryUnavailable` uz: `Kod Telegramga yuboriladi, lekin bu raqam Telegramda topilmadi. Hozircha Telegramsiz kod olib bo'lmaydi`; ru: `Код отправляется в Telegram, но этот номер в Telegram не найден. Пока без Telegram код получить нельзя`.
  - `errorPhoneReserved` uz: `Bu raqam ilovani Google Play'da tekshirish uchun ajratilgan`; ru: `Этот номер отведён для проверки приложения в Google Play`.
- [ ] **Step 4: Run** Step 2's command, then `flutter analyze` and `dart format --set-exit-if-changed lib test` — PASS, clean.
- [ ] **Step 5: Commit** `feat(app): words for code_delivery_unavailable and phone_reserved`.

### Task 6: Documents, settings examples, `DL-110`

**Files:**
- Modify: `docs/DECISIONS.md` (append `DL-110`), `docs/05-business-rules.md` (`BR-ROLE-011`), `docs/07-architecture.md` (sections 8 and 23), `docs/09-api-contracts.md` (sections 6, 7, 43, 52, 56), `docs/02-user-roles.md` (line 25), `docs/04-user-flows.md` (line 29), `AGENTS.md` (§5), `backend/.env.example`, `docker/production.env.example`, `tasks/WAVE_4.md` (W4-4 row `In progress`)

- [ ] **Step 1: `DL-110 — Telegram Gateway from W4-4 (2026-10-24, agent)`**, numbered points, each with its reason:
  1. The unreachable strings and how Task 7 confirms them; every other answer is `503`, and a confirmed check followed by a failed send is paid for nothing, so neither call is retried.
  2. Timeouts 3 s to connect and 5 s in all, per call, as `GoogleGeocoder`.
  3. Refines `DL-11` (3): the log may carry Telegram's error string, digit-free by pattern, because `BALANCE_NOT_ENOUGH` or `ACCESS_TOKEN_INVALID` must be visible to whoever runs the server; nothing else of the answer is logged.
  4. The ceiling counter is taken before the call (`DL-11` (1)), so it also counts unconfirmed (free) checks; the day is Tashkent's; "an account" means any active account of any role.
  5. The /64 applies to all three per-address auth limits (code request, staff login, staff step), and an IPv4-mapped address counts as its IPv4.
  6. The reviewer phone: `LOGIN_CODE_REVIEWER_PHONE` and `LOGIN_CODE_REVIEWER_CODE`, reported as channel `test`; a guessable code or the development code fails the boot; `409 phone_reserved` at staff creation, activation and the first-Admin command, and no staff step.
  7. No delivery-report callback and no `sender_username` (Telegram's own verification account sends).
- [ ] **Step 2: Update the documents** so they describe the system as built: the reviewer phone beside "empty in production" in `BR-ROLE-011`, `docs/02`, `docs/04`, `docs/07` section 8 and `AGENTS.md` §5 (`DL-105`); `docs/09` section 6 (the reviewer phone answers `test`), section 7 (no staff step for it), sections 43 and 56 (`phone_reserved`), section 52 unchanged unless a code is missing; `docs/07` section 23 (timeouts, no retry).
- [ ] **Step 3: Settings examples.** `backend/.env.example`: `LOGIN_CODE_DAILY_LIMIT=500`, `LOGIN_CODE_REVIEWER_PHONE=`, `LOGIN_CODE_REVIEWER_CODE=`, `TELEGRAM_GATEWAY_TOKEN=` with one-line comments. `docker/production.env.example`: `LOGIN_CODE_DRIVER=telegram`, the same four with comments (the reviewer code: six digits, not guessable, kept by the Owner; the token: restricted to the server's address in the Gateway account at W4-5).
- [ ] **Step 4: Check** `git diff --check`; every `DL-`, section and code named exists (`grep`).
- [ ] **Step 5: Commit** `docs: W4-4 Telegram Gateway, the reviewer phone, DL-110`.

### Task 7 (lead): Review, pull request, and the verification with the Owner's token

- [ ] **Step 1: Branch close.** Full backend suite, Pint, PHPStan, full `flutter test`, analyze, format; `branch-reviewer` on `main..HEAD`; one fix dispatch; `/security-review`; push, PR, merge on the two required checks.
- [ ] **Step 2: The Owner's gate.** With the Owner's token in the gitignored `backend/.env` (`LOGIN_CODE_DRIVER=telegram`, `TELEGRAM_GATEWAY_TOKEN=…`, typed in by the Owner, never in chat) on the dev stack served on 8001:
  - a code request for the Owner's own number answers `channel: telegram`, the code arrives in the Owner's Telegram, and the Owner types it into the app on the `barakabozor` emulator and is signed in (the account's own number costs nothing);
  - one request for a number with no Telegram account answers `409 code_delivery_unavailable` and the app shows the Telegram text; if Telegram answers a string not in `UNREACHABLE`, it is added in a follow-up pull request with its test and `DL-110` (1) updated;
  - afterwards `backend/.env` goes back to `LOGIN_CODE_DRIVER=fake` and the token line is removed.
- [ ] **Step 3: Record** the verification in `tasks/WAVE_4.md` (row `Merged`, the task note's outcome) in a `docs/` pull request.
