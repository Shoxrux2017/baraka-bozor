# Login Code: Three Attempts, Instant Resend, 60-Second Lock — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A login code may be entered wrong twice without any pause and may be re-sent at once. The third wrong entry locks the phone for 60 seconds, with a live countdown. After the lock, a new code gives three attempts again. The limit of five sends per phone per hour stays.

**Architecture:**
- **Server.** The 60-second wait between sends goes. A phone whose code was entered wrong three times is locked for 60 seconds in the cache `RateLimiter`, the same store the existing send limits use. While the lock lasts, both verify and request answer `429 code_locked` with `Retry-After` = the seconds left.
- **Client.** It reads `Retry-After` (`ApiRefusal.retryAfterSeconds`) and shows a live countdown on the code screen and the phone screen. While the countdown runs, confirm and resend are off; when it ends, the client asks for a new code.

**Tech Stack:** Laravel 13 + PostgreSQL (PHPUnit, Pint, PHPStan) in Docker. Flutter 3.47.5, Riverpod 3, `flutter gen-l10n`.

**Spec:** The Owner's decision of 2026-10-18 (this conversation), recorded as `DL-87` in Task 1:

| What the Customer does | What happens |
|---|---|
| Enters the code wrong the 1st or 2nd time | may enter it again at once, no pause |
| "Отправить ещё раз" | a new code is sent at once, no 60 s |
| Enters it wrong the 3rd time | a 60 s countdown; neither entering a code nor asking for a new one is possible |
| The countdown ends | may ask for a new code, and has 3 attempts again |
| More than 5 sends in an hour | "Попробуйте позже", as today |

## Global Constraints

- Branch `task/auth-code-attempts` from `main` `29c1bc6`. Never commit to `main`.
- **Backend.** Every command runs in the container from the repo root:
  - `docker compose -f docker/compose.yaml exec app php artisan test --filter=…`
  - `… exec app vendor/bin/pint --test`
  - `… exec app vendor/bin/phpstan analyse`
- **Flutter.** `G:/tools/flutter/bin/flutter` from `frontend/`, with TEMP/TMP = `G:\tools\tmp`. Run `flutter analyze` and `dart format --set-exit-if-changed lib test`. Run the full suite with `--concurrency=1`: higher concurrency ran out of memory on this machine.
- **Security.**
  - A login code is never logged, returned or put in a header (`AGENTS.md` §5).
  - The lock is per phone and is checked before the challenge is read, so a locked phone tells nothing about its code.
  - The per-IP limit of 10 requests a minute and the 5 sends per phone per hour stay unchanged.
  - The staff password step (`StaffLoginStep`, 5 wrong passwords) is unchanged.
- **Large text.** Every new screen state is tested at 320×640 with text ×2, in `uz` and `ru`.
- **Tests.** Never delete, skip or weaken a test. Tests written for the 60-second resend and the 5 attempts are rewritten to assert the new rules.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **The lock is bypassed by resending.** During the lock, request must refuse too, or a new code would end the lock early. Task 1 test: "a locked phone gets no new code".
2. **A lock outlives its code.** After 60 s the old code (3 failures) still answers `401 code_attempts_exhausted`. Only a new code works, and it gives 3 fresh attempts. Task 1 test: "after the lock only a new code opens".
3. **A test phone.** The fixed test code follows the same counters. A walkthrough that enters it right is unaffected. Task 1 test: "a test phone locks like any other".
4. **The countdown survives leaving the screen.** Going back to the phone screen during the lock and pressing "Получить код" shows the server's remaining seconds, not a fresh 60. Task 2 test: "the phone screen shows the seconds left".
5. **Text at the extremes.** "0:59" and the lock sentence fit at 320×640 with text ×2. Task 2 test.

---

### Task 1: The server — three attempts, instant resend, 60-second lock

**Files:**
- Modify:
  - `backend/app/Modules/Auth/LoginCodePolicy.php`
  - `backend/app/Modules/Auth/Actions/RequestCustomerLoginCode.php`
  - `backend/app/Modules/Auth/Actions/VerifyCustomerLoginCode.php`
  - `backend/tests/Feature/Auth/CustomerLoginCodeTest.php`
  - `tasks/scripts/wave1_api_walkthrough.py`, `wave2_…`, `wave3_…`: wait out `code_locked`/`rate_limited` with `Retry-After` instead of `code_resend_too_soon` + 61 s
  - `docs/09-api-contracts.md` §6 and §7, `docs/07-architecture.md` (the policy sentence at line 89), `docs/DECISIONS.md`

**Interfaces:**
- `LoginCodePolicy`:
  - `MAX_FAILED_ATTEMPTS = 3`;
  - `LOCK_SECONDS = 60`;
  - `RESEND_SECONDS` removed;
  - `SENDS_PER_HOUR = 5` unchanged;
  - `public static function lockKey(string $phone): string` → `"login-code:lock:{$phone}"`.
- **Request.**
  - Order: IP reserve (10/min) → if `RateLimiter::tooManyAttempts(lockKey, 1)` refuse `ApiException::tooManyRequests('code_locked', availableIn(lockKey))` → hour reserve (5/h) → send.
  - The answer's `resend_available_in_seconds` is `0`.
  - `code_resend_too_soon` is never produced.
- **Verify.**
  1. First: a locked phone → `429 code_locked` + `Retry-After`.
  2. Then as today: no challenge → `code_invalid`, expired → `code_expired`, `failed_attempts >= 3` → `401 code_attempts_exhausted`.
  3. A wrong code increments `failed_attempts`. When that makes it 3, after the transaction commits, `hit(lockKey, LOCK_SECONDS)` and answer `429 code_locked` with `Retry-After: 60`. Otherwise answer `401 code_invalid`.

- [ ] **Step 1: Failing tests** in `CustomerLoginCodeTest` (the existing tests for 60 s and 5 attempts are rewritten to these rules):
  - "a resend is sent at once": two requests back to back both answer 200 with `resend_available_in_seconds` 0, and only the newest code verifies.
  - "two wrong codes are only invalid": `401 code_invalid` twice; the right code still verifies after them.
  - "the third wrong code locks the phone": `429 code_locked`, `Retry-After: 60`.
  - "a locked phone gets no new code": request answers `429 code_locked`, `Retry-After` 1–60, and no challenge is created.
  - "a locked phone cannot verify even the right code": `429 code_locked`.
  - "after the lock only a new code opens": `travel(61)->seconds()`; the old code gives `401 code_attempts_exhausted`; request gives 200; the new code allows two wrong and then the right one verifies.
  - "the hour limit stays": 5 requests in the hour pass and the 6th is `429 rate_limited`.
  - "a test phone locks like any other".
  - "the code never appears in the answer or the log" (extend the existing `SecretsStayOutOfLogsTest` case if one covers verify).

  Run `--filter=CustomerLoginCode` and `--filter=SecretsStayOutOfLogs`. Expected: FAIL.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Run** the Auth filter, `pint --test` and `phpstan analyse`. Expected: PASS.
- [ ] **Step 4: Docs.**
  - **`docs/09` §6.** The policy becomes: "six digits, five-minute lifetime, three failed verifications lock the phone for sixty seconds, no wait between sends, five sends per phone per hour". The example answer becomes `resend_available_in_seconds: 0`. The codes list replaces `code_resend_too_soon` with `code_locked` (`429`, `Retry-After`).
  - **`docs/09` §7.** Add: "The third wrong code answers `429 code_locked` with `Retry-After: 60` and locks the phone; while locked, verify and request answer `code_locked` with the seconds left (`DL-87`)."
  - **`docs/07` line 89.** Update the same policy sentence.
  - **`docs/DECISIONS.md`.** Append:

```markdown
## DL-87 — Login code: three attempts, instant resend, a 60-second lock (2026-10-18, Owner)

A code may be entered wrong twice with no pause and may be re-sent at once. The third wrong entry locks the phone for 60 seconds with a countdown, during which neither a code nor a new code is accepted. Then a new code gives three attempts again. The limit of five sends per phone per hour stays, because every send costs money. This supersedes the sixty seconds between sends and the five attempts of `docs/09` §6.

## DL-88 — How the lock is kept and shown (2026-10-18, agent)

The lock lives in the cache rate limiter, where the send limits already live, under one key per phone. It is checked before the challenge is read, so a locked phone tells nothing about its code. Both verify and request answer `429 code_locked` with `Retry-After`, the seconds left. The client counts down from that header, so leaving and returning to the screen shows the real remainder. The old code stays exhausted after the lock; only a new code opens.
```

- [ ] **Step 5: Commit**: `feat(auth): three code attempts, instant resend and a 60-second lock`.

---

### Task 2: The app — the countdown

**Files:**
- Modify:
  - `frontend/lib/features/auth/application/code_login_controller.dart`
  - `frontend/lib/features/auth/presentation/code_screen.dart`, `code_entry.dart`, `phone_screen.dart` (whichever shows the confirm and resend controls and the phone screen's failure)
  - `frontend/lib/core/localization/failure_text.dart`
  - both `.arb` files
- Test:
  - `frontend/test/features/auth/application/code_login_controller_test.dart`
  - the code and phone screen tests under `frontend/test/features/auth/`
  - `frontend/test/core/localization/failure_text_test.dart`

**Interfaces:**
- `CodeLoginState` gains `int lockedSeconds` (default 0) and `bool get locked => lockedSeconds > 0`.
- `canResend` and confirming are false while `locked`.
- A refusal `code_locked` from verify or request:
  - starts the lock countdown from `ApiRefusal.retryAfterSeconds`, or from 60 when the header is missing;
  - clears the entered digits;
  - is shown as the lock sentence, not as a failure text.
- When the countdown reaches 0: `locked` is false, resend is on, and the code screen shows `codeLockOver`.
- `failure_text`: `code_resend_too_soon` → `code_locked` → `errorCodeLocked`. Delete the `errorCodeResendTooSoon` key if unused.
- Texts:

| Key | uz | ru |
|---|---|---|
| codeLocked | Kod 3 marta noto'g'ri kiritildi. Yangi kodni {time} dan keyin so'rash mumkin | Код введён неверно 3 раза. Новый код можно запросить через {time} |
| codeLockOver | Yangi kod so'rang | Запросите новый код |
| errorCodeLocked | Juda ko'p noto'g'ri urinish. Biroz kuting | Слишком много неверных попыток. Подождите немного |

  `{time}` is `m:ss`, as `resendIn` already formats it.

- [ ] **Step 1: Failing tests.**
  - Controller:
    - "a resend can be sent at once": `resend_available_in_seconds` 0 means `canResend` is true.
    - "code_locked from verify locks for the header's seconds and counts down": fake clock; 60 → 0; `canResend` false, then true.
    - "code_locked without a header locks for 60".
    - "code_locked from request on the phone screen locks too" (Review Focus 4).
  - Code screen:
    - the lock sentence shows "1:00" then "0:59";
    - confirm and resend are disabled;
    - the boxes are empty;
    - at 0, `codeLockOver` shows and resend is enabled.
  - Phone screen: `code_locked` shows the lock sentence with the seconds left, and "Получить код" is disabled until 0.
  - 320×640 with text ×2, `uz` and `ru`, for the locked code screen and the locked phone screen.

  Run the auth tests. Expected: FAIL.
- [ ] **Step 2: Implement.** Run `flutter gen-l10n`.
- [ ] **Step 3: Run** the full `flutter test --concurrency=1`, `flutter analyze` and `dart format`. Expected: PASS.
- [ ] **Step 4: Commit**: `feat(auth): the code screen counts the lock down`.

---

## After the tasks

1. `branch-reviewer` (opus) reviews the branch, then one fix wave.
2. `/security-review`: the branch touches sign-in.
3. Push, open the PR, merge on both checks.
4. Walk the emulator or the Owner's phone:
   - two wrong codes, then the right one;
   - three wrong codes, the countdown to 0, a new code;
   - an instant resend.
