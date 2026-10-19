# Kit Stage 7b — Customer Profile Screens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Customer's profile looks and works like the approved drawings 32–36в and 02а of `kit/07-profil.dc.html`: a kit profile tab, a language sheet, a name editor, the terms and the privacy policy read from the server, account deletion confirmed with a code, and the consent line with links on the sign-in screen; and, as the Owner decided on 2026-10-19, an Admin erases a blocked Customer too, keeping only a one-way fingerprint of the phone so the number never signs up again.

**Architecture:** One small server task (the phone fingerprint block list, and the support phone in the profile answer) and its panel change; the rest is client-only on the stage 7a API (`docs/09` §12, §61–62, §64–65). A new `legal` feature reads the public documents; the `profile` feature gains the deletion data, a controller with the login code's lock rules, and rebuilt kit screens. Two pages — the documents and "Аккаунт удалён" — are open on mobile whether signed in or not.

**Tech Stack:** Laravel 13 + PostgreSQL 17; Flutter 3.47.5, Riverpod 3, go_router, `flutter gen-l10n` (template `app_uz.arb`), Montserrat, `KitColors`, `url_launcher` through `phoneCallsProvider`.

**Spec:** `kit/07-profil.dc.html` in the Claude Design project "BarakaBozor — стиль покупателя", approved by the Owner on 2026-10-19 ("да"); the Owner's answers `DL-93` and the answer of 2026-10-19 on blocked accounts, recorded in Task 1 as `DL-95`. Screens: 32 профиль, 32а без имени и без поддержки, 32б язык, 33 редактирование, 33а имя пустое, 34 условия, 35 политика, 36 удалить?, 36а код, 36б незавершённый заказ, 36в удалён, 02а согласие на входе. Screen 37 (the web page) shipped in 7a. The agent's rules are `DL-96`, one item per task.

## Global Constraints

- Branch `task/kit-7b-customer-profile` from `main` `e2ce0da`. Never commit to `main`.
- Backend commands run in Docker from the repo root: `docker compose -f docker/compose.yaml exec -T app <cmd>` (`php artisan test --filter=…`, `vendor/bin/pint --test`, `vendor/bin/phpstan analyse`). **Never** run `migrate:fresh`, `db:wipe`, `migrate:reset` or `--env=testing` artisan commands against the dev database; tests use their own database through `php artisan test`.
- Flutter: `G:/tools/flutter/bin/flutter` with `TEMP`/`TMP` = `G:\tools\tmp`, run from `frontend/`. Focused tests per task; `flutter analyze`; `dart format --set-exit-if-changed lib test`. The full suite runs with `--concurrency=2`.
- No new Composer or pub package; lockfiles unchanged.
- **Kit look.** Colours only from `KitColors`; Montserrat; sizes on a 375-wide screen: side padding 20; rows 58 high with a `KitColors.line` divider; buttons 56 high radius 14 (sheet buttons 54); sheets white with top radius 24, a 40×4 grab handle, padding 20; app bars `kitAppBar`. Red is `KitColors.danger`, its wash `KitColors.dangerWash` (added in Task 5).
- **Large text.** Every new or rebuilt screen and sheet has a widget test at 320×640 with `textScaleFactorTestValue = 2`, in `uz` and `ru`, with `tester.takeException()` null.
- **Localization.** Edit `app_uz.arb` (template, with `@` metadata for placeholders) and `app_ru.arb` only, then `flutter gen-l10n`; generated files are never hand-edited. Texts exactly as each task lists them (ru / uz). Uzbek uses the ASCII apostrophe, as the files do. Existing keys reused where named.
- **Security** (AGENTS.md §5): the phone and the login code are never logged; the fingerprint table never holds the phone; erasure never changes an order's status, lines, money or history (AGENTS.md §6).
- **Tests.** Never delete, skip or weaken a test. A test whose flow changed is rewritten to assert the new flow; each task names the flows that change.
- **Decisions.** Each task writes its `DL-96` item in `docs/DECISIONS.md` with its code and updates the `docs/01–09` section it changes (AGENTS.md §3).
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Two taps, or a lost answer, on "Удалить" and "Удалить аккаунт".** One request each; the button is busy while it runs. Task 5 tests "two quick taps request one code", "two quick taps delete once".
2. **An order placed between the code and the deletion** (on another phone). The delete answers `409`; the app shows sheet 36б with the order's number, not a generic error. Task 5 test "a 409 on delete shows the unfinished order".
3. **Reading the documents before signing in.** The consent links open the documents; back returns to the phone screen with the number kept; an unpublished document drops its link, none drops the line. Task 3 tests "a consent link opens the document and back keeps the phone", "the line names only published documents".
4. **A blocked number after its erasure, also after the application key rotates.** Sign-in refuses with `401 account_blocked` and creates no account; a fingerprint made under a previous key still matches. Task 1 tests "a blocked customer is erased and the phone stays blocked", "previous keys still match".
5. **The profile at the extremes.** A 120-character name, no support phone, no published document, a staff session, text ×2 at 320×640 in both languages. Task 6 tests "the profile holds at the extremes", "a staff session has no delete row".

---

### Task 1: The blocked number stays blocked after erasure; the support phone in the profile

**Files:**
- Create: `backend/database/migrations/2026_10_19_000004_create_blocked_phone_fingerprints_table.php`, `backend/app/Support/ApplicationKeys.php`, `backend/app/Modules/Accounts/PhoneFingerprint.php`, `backend/app/Modules/Accounts/BlockedPhones.php`
- Modify: `backend/app/Modules/Orders/Checkout/CheckoutSecrets.php` (reads the key through `ApplicationKeys::current()`, behaviour unchanged), `backend/app/Modules/Accounts/Actions/EraseCustomer.php`, `backend/app/Modules/Auth/Actions/VerifyCustomerLoginCode.php` (`resolveCustomer`), `backend/app/Modules/Customer/Http/Resources/ProfileResource.php` (and `ProfileController` if the resource needs the setting passed in), `frontend/lib/features/admin/presentation/customers_screen.dart`, both ARB files (+ `flutter gen-l10n`)
- Modify docs: `docs/DECISIONS.md` (new `DL-95`, new `DL-96` item 1), `docs/05-business-rules.md` `BR-ROLE-013`, `docs/08-database.md` (new §35 `blocked_phone_fingerprints`), `docs/09-api-contracts.md` §7 (a blocked number), §12 (`support_phone`), §66–67 (blocked accounts are erased), `docs/02-user-roles.md` (the Admin erases a blocked Customer), `tasks/REDESIGN_CUSTOMER.md` (stage 7 "In Progress (7a merged PR #101, 7b screens)"; the risk row "Owner question pending: erasure of a blocked Customer" replaced by the ruling of `DL-95`; new risk row below)
- Test: Create `backend/tests/Unit/Accounts/PhoneFingerprintTest.php`; Modify `backend/tests/Feature/Accounts/AdminCustomersApiTest.php`, `backend/tests/Feature/Customer/ProfileApiTest.php`, `frontend/test/features/admin/presentation/customers_screen_test.dart`

**Interfaces:**
- Produces (schema): `blocked_phone_fingerprints(fingerprint char(64) primary key, check fingerprint ~ '^[0-9a-f]{64}$', erased_user_id uuid not null fk users restrict, created_by_user_id uuid not null fk users restrict, created_at timestamptz not null)`. No phone column, ever.
- Produces (PHP):
  - `ApplicationKeys::current(): string` — the raw bytes of `app.key`, `base64:` decoded; empty or undecodable throws `LogicException` (moved from `CheckoutSecrets::key`). `ApplicationKeys::previous(): list<string>` — the same for each of `app.previous_keys`.
  - `PhoneFingerprint::of(string $phone): string` — lowercase hex `hash_hmac('sha256', $phone, $k)` where `$k = hash_hmac('sha256', 'phone-fingerprint/v1', ApplicationKeys::current(), true)`. `PhoneFingerprint::candidates(string $phone): list<string>` — the same under the current key first, then under each previous key.
  - `BlockedPhones::block(string $phone, User $erased, User $actor): void` — inserts `of($phone)` unless present (`insertOrIgnore`). `BlockedPhones::isBlocked(string $phone): bool` — any of `candidates($phone)` present. Same style as `UnfinishedOrders`.
- Produces (behaviour):
  - `EraseCustomer::erase` no longer refuses a blocked account. Under the same locks, after the unfinished-order check (a blocked account with an unfinished order is still `409 account_has_unfinished_orders`), a blocked account's phone is passed to `BlockedPhones::block` before the phone is nulled, in the same transaction.
  - `VerifyCustomerLoginCode::resolveCustomer`: when the phone has no Customer account and `BlockedPhones::isBlocked($phone)`, it throws `ApiException::unauthenticated('account_blocked')` — the code is already consumed, as for a blocked account; no account is created. An existing account on the phone is unaffected.
  - `GET` and `PATCH /customer/profile` answer `support_phone` (`string|null`, the business setting, as the order answers it).
  - Panel: on the customers page the erase button is enabled for a blocked account (only an unfinished order or a running request disables it); a blocked card and its confirmation dialog show `customerEraseBlockedNote`. The key `customerEraseBlocked` is removed.
- Texts: `customerEraseBlockedNote` "Аккаунт заблокирован: номер останется в чёрном списке, зарегистрироваться с ним снова будет нельзя." / "Akkaunt bloklangan: raqam qora ro'yxatda qoladi, u bilan qayta ro'yxatdan o'tib bo'lmaydi."

- [ ] **Step 1: Record the Owner's decision.** Append to `docs/DECISIONS.md` after `DL-94`:

```markdown
## DL-95 — Erasing a blocked Customer (2026-10-19, Owner)

Answer to the question `DL-94` item 5 left open. An Admin erases a blocked Customer's account like any other: the name, the addresses and the rest are erased as `DL-94` item 4 lists. Of the phone only a one-way fingerprint stays, on a block list: the number cannot be recovered from it, and with it the system refuses a new sign-up from that number, so a block cannot be escaped by deleting the account. The privacy policy says so in one line. This supersedes the refusal of a blocked account in `DL-94` item 5.
```

- [ ] **Step 2: Write the failing tests.**
  1. `PhoneFingerprintTest::test_a_fingerprint_is_keyed_and_stable`: `of('+998901234567')` matches `/^[0-9a-f]{64}$/`, is equal on a second call, differs from `hash('sha256', '+998901234567')` and from `of('+998901234568')`, and differs after `config(['app.key' => <another base64 key>])`.
  2. `test_previous_keys_still_match`: `$old = of($phone)` under key A; set `app.key` to B and `app.previous_keys` to `[A]` → `candidates($phone)` is `[of under B, $old]`.
  3. `test_an_unset_key_fails_closed`: `app.key` `''` → `LogicException`.
  4. `AdminCustomersApiTest::test_a_blocked_customer_is_not_erased` is rewritten as `test_a_blocked_customer_is_erased_and_the_phone_stays_blocked` (the flow changed by `DL-95`): erase a blocked Customer → `204`; the account is `deleted` with phone null; `blocked_phone_fingerprints` holds one row with `erased_user_id` the Customer and `created_by_user_id` the Admin, and no value of that row equals the phone; then `POST /auth/customer/code/request` + `verify` with the test code for that phone → `401 account_blocked`, and the count of Customer accounts is unchanged.
  5. `test_a_blocked_customer_with_an_unfinished_order_is_refused`: an order `shopping` → `409 account_has_unfinished_orders`; the account stays blocked; no fingerprint row.
  6. `test_erasing_an_active_customer_blocks_nothing`: erase an active Customer → no fingerprint row.
  7. `ProfileApiTest::test_the_profile_answers_the_support_phone`: `support_phone` null by default; after the setting is `+998712000000`, `GET` and `PATCH` both answer it.
  8. `customers_screen_test`: a blocked account's erase button is enabled and shows the note; the dialog shows the note; erasing sends once. The test that asserted the disabled button for a blocked account is rewritten to this flow.

- [ ] **Step 3: Run** `php artisan test --filter='PhoneFingerprintTest|AdminCustomersApiTest|ProfileApiTest'` and `flutter test test/features/admin/presentation/customers_screen_test.dart` — the new tests fail.

- [ ] **Step 4: Implement** the files above.

- [ ] **Step 5: Run** the filter, `tests/Feature/Accounts`, `tests/Feature/Auth`, `tests/Feature/Orders` (checkout tokens use the moved key code) and the panel test — all pass.

- [ ] **Step 6: Docs, DL, checks, commit.** `BR-ROLE-013`'s last sentence becomes: "An Admin erases a blocked account like any other; a one-way fingerprint of its phone stays on a block list, and that number never signs up again (`DL-95`)." `docs/09` §7: `account_blocked` also answers a phone whose blocked account was erased. New risk row in `tasks/REDESIGN_CUSTOMER.md`: "Stage 7b, a blocked number that the operator later gives to someone else stays refused; lifting a fingerprint needs an Admin tool that does not exist yet." `DL-96` item 1:

```markdown
## DL-96 — The Customer's profile screens, kit stage 7b (2026-10-19, agent)

1. **The fingerprint.** HMAC-SHA256 of the E.164 phone under a key derived from the application key for this one purpose (`phone-fingerprint/v1`), as checkout derives its keys (`DL-41` (7)). Uzbek mobile numbers are few enough to try them all, so a plain hash would give the number back; without the application key a copy of the database does not. The block list outlives any key, so a rotated key moves to `APP_PREVIOUS_KEYS` and fingerprints made under it keep matching, while new ones use the current key. Only a new Customer account is refused — at verify, after the code is valid, with the same `401 account_blocked` a blocked account gets; an account that already holds the phone is untouched. The profile answers the support phone, so the profile tab shows it without an order (`DL-90` item 2).
```

`pint --test`, `phpstan analyse`, `flutter analyze`, `dart format --set-exit-if-changed lib test`; commit `feat(accounts): erase a blocked Customer and keep the number blocked; the support phone in the profile (DL-95, DL-96 item 1)`.

---

### Task 2: Client data — documents, account deletion, the profile's support phone

**Files:**
- Create: `frontend/lib/core/legal/legal_document_kind.dart` (`LegalDocumentKind` moved here from `features/admin/domain/legal_documents.dart`, which imports it), `frontend/lib/features/legal/domain/legal.dart`, `frontend/lib/features/legal/data/legal_api.dart`, `frontend/lib/features/legal/application/legal_providers.dart`, `frontend/lib/features/profile/domain/account_deletion.dart`, `frontend/lib/features/profile/data/account_deletion_api.dart`
- Modify: `frontend/lib/features/profile/domain/profile.dart`, `frontend/lib/features/profile/data/profile_api.dart`, `frontend/lib/core/formatting/tashkent_time.dart`, `frontend/test/support/fake_customer_repositories.dart` (`FakeProfileRepository` takes a support phone, default null), every importer of the moved enum
- Test: Create `frontend/test/features/legal/data/legal_api_test.dart`, `frontend/test/features/profile/data/account_deletion_api_test.dart`; Modify the profile API test and `frontend/test/core/formatting/tashkent_time_test.dart` (or create it)

**Interfaces:**
- Consumes: `docs/09` §61–62, §64–65 and Task 1's `support_phone`.
- Produces (domain, `features/legal/domain/legal.dart`):
  - `enum LegalBlockType { heading, paragraph, item }`; `final class LegalBlock { LegalBlockType type; String text; }`.
  - `final class LegalEdition { LegalDocumentKind kind; AppLanguage language; DateTime updatedAt; }`.
  - `final class LegalIndex { LegalEdition? terms; LegalEdition? privacy; LegalEdition? of(LegalDocumentKind kind); bool get hasAny; }`.
  - `final class LegalDocument { LegalDocumentKind kind; AppLanguage language; DateTime updatedAt; List<LegalBlock> blocks; }`.
  - `abstract interface class LegalRepository { Future<LegalIndex> index(AppLanguage language); Future<LegalDocument?> document(LegalDocumentKind kind, AppLanguage language); }` — `404` is `null`; a block of an unknown `type` is skipped, so a later block kind does not break the document.
- Produces (data): `LegalApi implements LegalRepository` — unauthenticated requests, as `AuthApi.requestCustomerCode` sends them; `GET /legal?language=…`, `GET /legal/{kind}?language=…`.
- Produces (providers): `legalRepositoryProvider`; `legalIndexProvider` — `FutureProvider.autoDispose<LegalIndex>` for the current interface language (watches `languageControllerProvider`); `legalDocumentProvider` — `FutureProvider.autoDispose.family<LegalDocument?, LegalDocumentKind>`, same language.
- Produces (deletion, `features/profile/domain/account_deletion.dart`): `final class UnfinishedOrder { String id; int number; }`; `UnfinishedOrder? unfinishedOrderOf(ApiFailure failure)` — the order of an `ApiRefusal` `409 account_has_unfinished_orders` (`details.order_id`, `details.order_number`), otherwise `null`; `abstract interface class AccountDeletionRepository { Future<RequestedCode> requestCode(); Future<void> delete(String code); }`.
- Produces (data): `AccountDeletionApi implements AccountDeletionRepository` on the Customer session — `POST /customer/account/deletion-code` with no body, parsed into the `RequestedCode` that `requestCustomerCode` returns, by the same parsing; `POST /customer/account/delete {"code"}` expecting `204`. `accountDeletionRepositoryProvider`.
- Produces: `CustomerProfile.supportPhone` (`String?`, from `support_phone`); `TashkentTime.date(DateTime instant) → String` `dd.MM.yyyy` in Tashkent.

- [ ] **Step 1: Write the failing tests.**
  1. `legal_api_test`: `index(ru)` sends `GET /legal?language=ru` with no `Authorization`, parses `terms` and a null `privacy`; `document(terms, uz)` parses `language` `ru` (the server's fallback), `updated_at`, blocks heading/paragraph/item in order and skips `{"type":"table"}`; a `404` is `null`; a `500` throws the usual `ApiFailure`.
  2. `account_deletion_api_test`: `requestCode()` posts `/customer/account/deletion-code` with an empty body on the Customer token and parses `channel`, `expires_in_seconds`, `resend_available_in_seconds`; `delete('123456')` posts `{"code":"123456"}` and completes on `204`; a `409` with `details {order_id: 'o1', order_number: 1021}` → `unfinishedOrderOf` gives `('o1', 1021)`; a `422 code_invalid` → `unfinishedOrderOf` is null.
  3. The profile API test: `support_phone` `+998712000000` parses; absent or null → null.
  4. `TashkentTime.date(DateTime.utc(2026, 10, 18, 20, 30))` → `19.10.2026`.

- [ ] **Step 2: Run** the four files — expect failures.

- [ ] **Step 3: Implement.**

- [ ] **Step 4: Run** the four files and `flutter test test/features/admin test/features/auth` (the moved enum, the shared code parsing) — pass; `flutter analyze`, `dart format`.

- [ ] **Step 5: DL and commit.** `DL-96` item 2:

```markdown
2. **Data.** The documents are read without a session, in the interface language, and follow it when it changes; the server's fallback language is shown as it answers. A block kind the app does not know is skipped, so a later kind does not break a document. The deletion code is parsed as the login code is, and an unfinished order is read from the refusal's details.
```

Commit `feat(profile): documents, account deletion and the support phone on the client (DL-96 item 2)`.

---

### Task 3: The documents and the consent line on the sign-in screen (34, 35, 02а)

**Files:**
- Create: `frontend/lib/features/legal/presentation/legal_screen.dart`, `frontend/lib/features/legal/presentation/consent_line.dart`, `frontend/lib/features/legal/presentation/legal_routes.dart`
- Modify: `frontend/lib/core/routing/app_paths.dart`, `frontend/lib/core/routing/session_redirect.dart`, `frontend/lib/app/router.dart` (register `legalRoutes`), `frontend/lib/features/auth/presentation/phone_screen.dart` (footer), both ARB files (`termsLine` removed)
- Modify docs: `DL-96` item 3, `docs/07-architecture.md` (the routing section that lists the public screens: the open pages)
- Test: Create `frontend/test/features/legal/presentation/legal_screen_test.dart`, `frontend/test/features/legal/presentation/consent_line_test.dart`; Modify `frontend/test/core/routing/session_redirect_test.dart`, and the phone screen test that reads `termsLine` (rewritten: the footer is the consent line)

**Interfaces:**
- Consumes: Task 2 `legalIndexProvider`, `legalDocumentProvider`, `TashkentTime.date`.
- Produces (paths): `AppPaths.legalTerms = '/legal/terms'`, `AppPaths.legalPrivacy = '/legal/privacy'`, `AppPaths.legal(LegalDocumentKind kind)`, `AppPaths.openPages` (a `Set<String>`, here the two legal paths; Task 5 adds one). `sessionRedirect`: on mobile an open page is let through when signed out, and when signed in once the surface, staff-step and name gates pass.
- Produces (widgets): `LegalScreen(kind)` (key `legal-screen`); `ConsentLine` (key `consent-line`).
- Screen 34/35: `kitAppBar` titled `legalTerms` / `legalPrivacy` (existing keys); body padding 20/20/20/40: `legalEdition(TashkentTime.date(updatedAt))` 13 `muted`, 12 below; a heading 15 w700 `primaryDark`, line height 22, 22 above (4 when it is the first block) and 6 below, `Semantics(header: true)`; a paragraph 14 `ink2` line height 22, 6 above when it follows another paragraph; an item "•" with the text indented 18, 14 `ink2`. Loading: a spinner. `null`: `legalNotPublishedYet` centred. Failure: `LoadFailure` whose retry invalidates the provider.
- 02а: the phone screen's footer is `ConsentLine`: nothing while the index loads, fails or has no document; otherwise one centred `Text.rich` 11 `muted` line height 1.55 with the links 11 w600 `primary` — `consentAll(terms, privacy)`, `consentTermsOnly(terms)` or `consentPrivacyOnly(privacy)`. Each link pushes `AppPaths.legal(kind)` (`context.push`, so back returns to the phone screen as it was). The message is built with two private-use sentinels (`\u{E000}`, `\u{E001}`) in place of the placeholders and split on them into spans; the recognizers live in the widget's `State` and are disposed.
- Texts (ru / uz): `legalEdition` "Редакция от {date}" / "Tahrir: {date}"; `legalNotPublishedYet` "Документ пока не опубликован." / "Hujjat hali e'lon qilinmagan."; `consentAll` "Продолжая, вы принимаете {terms} и {privacy}" / "Davom etib, siz {terms} va {privacy}ni qabul qilasiz"; `consentTermsOnly` "Продолжая, вы принимаете {terms}" / "Davom etib, siz {terms}ni qabul qilasiz"; `consentPrivacyOnly` "Продолжая, вы принимаете {privacy}" / "Davom etib, siz {privacy}ni qabul qilasiz"; `consentTermsLink` "Условия использования" / "Foydalanish shartlari"; `consentPrivacyLink` "Политику конфиденциальности" / "Maxfiylik siyosati".

- [ ] **Step 1: Write the failing tests.**
  1. `legal_screen_test`: a document with the date 18.10.2026 20:30 UTC shows "Редакция от 19.10.2026", a heading, two paragraphs and two items in order, the heading is a semantics header; `null` shows "Документ пока не опубликован."; a failure shows the retry and a retry loads again; switching the interface to Uzbek loads the `uz` document.
  2. `consent_line_test`: both published → "Продолжая, вы принимаете Условия использования и Политику конфиденциальности"; only terms → no privacy link; none, loading or a failure → nothing (`find.byKey('consent-line')` finds nothing).
  3. `test_a_consent_link_opens_the_document_and_back_keeps_the_phone` (through `appUnderTest`, signed out): type `90 123 45 67`, tap the terms link → the legal screen; back → the phone screen with the number still typed.
  4. `session_redirect_test`: `/legal/terms` and `/legal/privacy` pass signed out and signed in as a named Customer on mobile; signed out on the web they go to `/auth`; a Customer without a name still goes to the name screen.
  5. Large text: the legal screen with a 40-block document and the phone screen with the consent line, 320×640, text ×2, `uz` and `ru`.

- [ ] **Step 2: Run** the files — expect failures.

- [ ] **Step 3: Implement.**

- [ ] **Step 4: Run** the files and `flutter test test/features/auth test/core/routing` — pass; `flutter analyze`, `dart format`.

- [ ] **Step 5: DL and commit.** `DL-96` item 3:

```markdown
3. **Documents and consent.** The terms and the policy are open pages: the sign-in screen links to them before any session, and the profile opens the same screens. The consent line names only the published documents and is absent when none is, as the server records consent only then (`DL-94` item 3). A link pushes the document, so back returns to the phone screen with the number kept.
```

Commit `feat(legal): the documents and the consent line on sign-in (DL-96 item 3)`.

---

### Task 4: The name editor (33, 33а)

**Files:**
- Create: `frontend/lib/features/profile/presentation/edit_profile_screen.dart`
- Modify: `frontend/lib/features/profile/presentation/profile_routes.dart` (child route), `frontend/lib/core/routing/app_paths.dart` (`customerEditProfile = '$customerProfile/edit'`), both ARB files
- Modify docs: `DL-96` item 4
- Test: Create `frontend/test/features/profile/presentation/edit_profile_screen_test.dart`

**Interfaces:**
- Consumes: `profileControllerProvider`, `renameControllerProvider` (as `_NameForm` uses them today).
- Produces: `EditProfileScreen` (key `edit-profile`) at `AppPaths.customerEditProfile`.
- Layout: `kitAppBar(title: profileEditTitle)`; a 70 circle `primarySoft` with the initials 26 w700 `primaryDark` (or a `person` icon 36 when no name), 8 above and 32 below; the name field (key `profile-name-field`, label `profileNameLabel`, outlined 1 px `primary`, radius 14, 120 characters, counter hidden); the phone field read-only (key `profile-phone-field`, label `profilePhoneLabel`, `field` fill, `line` border, value `ink2`, a `lock` icon 20 `muted`), under it `profilePhoneLocked` 12 `muted`; at the bottom `saveButton` (key `profile-save`), 56 radius 14 `primary`.
- Rules: while the trimmed name is empty the field's border is `danger`, `profileNameRequired` shows under it in `danger` and the button is disabled; an unchanged name closes the screen without a request; otherwise one rename runs (the button busy), success closes the screen and shows `profileSaved`, a failure shows its failure text and stays.
- Initials (shared with Task 6, defined here as `String? initialsOf(String? fullName)` in `features/profile/presentation/initials.dart`): the first letter of the first two words, upper-cased; `null` for no name.
- Texts (ru / uz): `profileEditTitle` "Редактирование профиля" / "Profilni tahrirlash"; `profileNameLabel` "Имя" / "Ism"; `profilePhoneLabel` "Номер телефона" / "Telefon raqami"; `profilePhoneLocked` "Номер — ваш вход в приложение, его не меняют." / "Raqam — ilovaga kirishingiz, uni o'zgartirib bo'lmaydi."; `profileNameRequired` "Введите имя — без него заказ не оформить." / "Ismni kiriting — usiz buyurtma berib bo'lmaydi."

- [ ] **Step 1: Write the failing tests** in `edit_profile_screen_test`: the field shows the name and the phone reads "+998 90 123 45 67" read-only; clearing the field shows the message and disables the button; "  Aziza  " renames once to "Aziza", closes and shows "Имя сохранено"; an unchanged name closes with no rename; a failed rename keeps the screen and shows the failure; two quick taps rename once; `initialsOf('Дилноза Каримова')` → "ДК", `initialsOf('aziza')` → "A", `initialsOf(null)` → null; large text in `uz` and `ru`.

- [ ] **Step 2: Run** the file — expect failures.

- [ ] **Step 3: Implement.**

- [ ] **Step 4: Run** the file — pass; `flutter analyze`, `dart format`.

- [ ] **Step 5: DL and commit.** `DL-96` item 4:

```markdown
4. **The name editor.** Only the name changes; the phone is shown locked, as the phone is the sign-in (`DL-23`). An empty name is refused on the screen, since checkout needs one; an unchanged one sends nothing.
```

Commit `feat(profile): the kit name editor (DL-96 item 4)`.

---

### Task 5: Account deletion (36, 36а, 36б, 36в)

**Files:**
- Create: `frontend/lib/features/profile/application/account_deletion_controller.dart`, `frontend/lib/features/profile/presentation/delete_account_sheets.dart` (36 and 36б), `frontend/lib/features/profile/presentation/delete_account_screen.dart` (36а), `frontend/lib/features/profile/presentation/account_deleted_screen.dart` (36в)
- Modify: `frontend/lib/features/profile/presentation/profile_routes.dart`, `frontend/lib/core/routing/app_paths.dart` (`customerDeleteAccount = '$customerProfile/delete'`, `accountDeleted = '/account-deleted'` added to `openPages`), `frontend/lib/features/auth/presentation/code_boxes.dart` (optional `Color accent = KitColors.primary` for the active box and caret), `frontend/lib/core/theme/kit_colors.dart` (`dangerWash = Color(0xFFFDECEB)`), both ARB files
- Modify docs: `DL-96` item 5, `docs/04-user-flows.md` (the deletion flow's screens)
- Test: Create `frontend/test/features/profile/application/account_deletion_controller_test.dart`, `frontend/test/features/profile/presentation/delete_account_flow_test.dart`; Modify `frontend/test/core/routing/session_redirect_test.dart`

**Interfaces:**
- Consumes: Task 2 `AccountDeletionRepository`, `unfinishedOrderOf`, `UnfinishedOrder`; `sessionControllerProvider.notifier.dropSession(SessionSlot.customer)`; the recent searches notifier's `clear()`; `formatPhone`, `formatCountdown`, `failureText`.
- Produces: `enum DeletionOutcome { deleted, refused, unfinished }`; `final class AccountDeletionState { RequestedCode? requested; int resendInSeconds; int lockedSeconds; bool lockOver; bool busy; ApiFailure? failure; UnfinishedOrder? unfinished; bool get entryOpen; bool get canResend; }`; `AccountDeletionController extends Notifier<AccountDeletionState>` (not auto-disposed: the sheet requests, the screen uses the answer) with `void reset()`, `Future<bool> requestCode()` (true when a code was sent; a `409` sets `unfinished`), `Future<void> resend()`, `Future<DeletionOutcome> delete(String code)`; one call at a time — a call while `busy` returns at once (`refused` / `false`). Countdowns and the lock follow `CodeLoginController`: `resendInSeconds` from the answer; `429 code_locked` starts `lockedSeconds` from `retryAfterSeconds` (60 without one); when it ends `lockOver` closes the entry until a new code. `accountDeletionControllerProvider`.
- Produces: `Future<void> showDeleteAccountSheet(BuildContext context)`, `Future<void> showUnfinishedOrderSheet(BuildContext context, UnfinishedOrder order)`; `DeleteAccountScreen` (key `delete-account-screen`) at `AppPaths.customerDeleteAccount`; `AccountDeletedScreen` (key `account-deleted`) at `AppPaths.accountDeleted`.
- Sheet 36 (key `delete-account-sheet`): a 56 circle `dangerWash` with `delete` 28 `danger`; `deleteAccountTitle` 18 w700; `deleteErasedHeading` and `deleteKeptHeading` 13 w700 with 16 above; erased lines with `close` 18 `danger`: `deleteErasedName`, `deleteErasedAddresses`, `deleteErasedFavorites`; the kept line with `check` 18 `primaryDark`: `deleteKeptOrders`; `deleteNote` in a `field` box radius 10, 12 `ink2`; buttons `cancelButton` (outlined, key `delete-cancel`) and `deleteConfirm` (`danger`, key `delete-confirm`, busy while the code is requested). Confirm → `requestCode()`: sent → the sheet closes and `DeleteAccountScreen` is pushed; `unfinished` → the sheet closes and 36б opens; another failure → its text above the buttons.
- Sheet 36б (key `delete-unfinished-sheet`): a 56 circle `warningWash` with `hourglass_top` `warning`; `deleteBlockedTitle`; `deleteBlockedBody(number)` 14 `ink2`; `understoodButton` (outlined) closes; `toOrderButton` (`primary`) pushes `AppPaths.customerOrder(id)`.
- Screen 36а: `kitAppBar(title: deleteCodeTitle)`; a 56 circle `dangerWash` with `lock`; `deleteCodeHeading` 22 w700; the sent-to line exactly as the login code screen chooses it for the channel, with the profile's phone; `CodeBoxes(accent: KitColors.danger)`; the resend and lock lines as `CodeEntry` shows them (`resendIn`, `resendCode`, `codeLocked`); a refusal's `failureText` under the boxes, the boxes cleared; at the bottom `profileDeleteAccount` (key `delete-submit`), `danger`, 56 radius 14, enabled with six digits while the entry is open and nothing runs. `deleted` → clear the account's recent searches, keep the session notifier, `context.go(AppPaths.accountDeleted)`, then `dropSession(SessionSlot.customer)`; `unfinished` → 36б, whose "Понятно" also leaves this screen.
- Screen 36в: centred — a 130 circle `primaryWash` around a 90 circle `primary` with `check_circle` 44 white; `deletedTitle` 22 w700; `deletedBody` 13 `muted`; `doneButton` (key `account-deleted-done`, `primary`, 56 radius 16) → `context.go(AppPaths.auth)`; system back does the same.
- Texts (ru / uz): `deleteAccountTitle` "Удалить аккаунт?" / "Akkauntni o'chirasizmi?"; `deleteErasedHeading` "Сотрём" / "O'chiriladi"; `deleteErasedName` "Имя и номер телефона" / "Ism va telefon raqami"; `deleteErasedAddresses` "Адреса" / "Manzillar"; `deleteErasedFavorites` "Избранное и корзину" / "Sevimlilar va savat"; `deleteKeptHeading` "Останется" / "Qoladi"; `deleteKeptOrders` "История заказов — без имени и телефона, для учёта" / "Buyurtmalar tarixi — ism va telefonsiz, hisob uchun"; `deleteNote` "Вернуть аккаунт нельзя. С этим номером можно войти снова — как новый покупатель." / "Akkauntni qaytarib bo'lmaydi. Bu raqam bilan yana kirish mumkin — yangi xaridor sifatida."; `deleteConfirm` "Удалить" / "O'chirish"; `deleteBlockedTitle` "Сейчас удалить нельзя" / "Hozir o'chirib bo'lmaydi"; `deleteBlockedBody` "Заказ № {number} ещё не завершён. Удалить аккаунт можно после доставки или отмены заказа." / "№ {number} buyurtma hali tugallanmagan. Akkauntni buyurtma yetkazilgan yoki bekor qilingandan keyin o'chirish mumkin."; `understoodButton` "Понятно" / "Tushunarli"; `toOrderButton` "К заказу" / "Buyurtmaga"; `deleteCodeTitle` "Удаление аккаунта" / "Akkauntni o'chirish"; `deleteCodeHeading` "Подтвердите удаление" / "O'chirishni tasdiqlang"; `profileDeleteAccount` "Удалить аккаунт" / "Akkauntni o'chirish"; `deletedTitle` "Аккаунт удалён" / "Akkaunt o'chirildi"; `deletedBody` "Ваши данные стёрты.\nСпасибо, что были с нами." / "Ma'lumotlaringiz o'chirildi.\nBiz bilan bo'lganingiz uchun rahmat."; `doneButton` "Готово" / "Tayyor" (reuse an existing key with that text if one exists).

- [ ] **Step 1: Write the failing tests.**
  1. `account_deletion_controller_test` (fake repository, `fakeAsync`): a sent code sets `requested` and `resendInSeconds`; a `409` sets `unfinished` and returns false; `delete` with a `422 code_invalid` → `refused` with the failure; a `429 code_locked` with 30 s → `lockedSeconds` 30 counting down, then `lockOver`, `entryOpen` false until `resend()` succeeds; a call while busy returns at once and the repository is called once.
  2. `delete_account_flow_test` (a signed-in named Customer; the profile row arrives in Task 6, so the test opens the sheet with `showDeleteAccountSheet` from a host screen under a router holding the profile routes and the open pages): the sheet lists the four lines and the note; "Отмена" sends nothing; `test_two_quick_taps_request_one_code`; a sent code opens 36а with "+998 90 123 45 67"; a `409` at the request opens 36б with "Заказ № 1021…" and "К заказу" opens that order.
  3. On 36а: a wrong code shows the refusal and clears the boxes; three wrong → the lock line and a disabled button; `test_two_quick_taps_delete_once`; `test_a_409_on_delete_shows_the_unfinished_order`; a right code → 36в, the Customer token is gone from the token store, the session is signed out, the recent searches of the account are empty; "Готово" → the phone screen.
  4. `session_redirect_test`: `/account-deleted` passes signed out and signed in on mobile.
  5. Large text: sheet 36, 36а, 36б, 36в in `uz` and `ru`.

- [ ] **Step 2: Run** the files — expect failures.

- [ ] **Step 3: Implement.**

- [ ] **Step 4: Run** the files, `flutter test test/features/auth` (the `accent` parameter) — pass; `flutter analyze`, `dart format`.

- [ ] **Step 5: DL and commit.** `DL-96` item 5:

```markdown
5. **Deleting the account.** The sheet asks first, then the code is requested, so an unfinished order is reported before any code is sent (`DL-94` item 4); an order that appears before the code is entered is reported the same way. The code screen keeps the sign-in code's rules: resend, the 60-second lock after three wrong codes, the entry closed until a new code. On success the app opens "Аккаунт удалён" first and then forgets the session, since the server has already revoked the token; it also forgets the account's recent searches on this phone. "Аккаунт удалён" is an open page, so it stays on screen once the session is gone.
```

Commit `feat(profile): delete the account with a code (DL-96 item 5)`.

---

### Task 6: The profile tab and the language sheet (32, 32а, 32б)

**Files:**
- Create: `frontend/lib/features/profile/presentation/profile_header.dart`, `frontend/lib/features/profile/presentation/language_sheet.dart`
- Modify: `frontend/lib/features/profile/presentation/profile_screen.dart` (rebuilt; `_NameForm` and `_LanguageChoice` go), both ARB files
- Modify docs: `DL-96` item 6, `docs/03-features.md` §3 (the profile), `tasks/REDESIGN_CUSTOMER.md`
- Test: Create `frontend/test/features/profile/presentation/profile_screen_test.dart`; Modify `frontend/test/features/addresses/customer_account_screens_test.dart` — the profile flows that change are rewritten: the inline name form → the editor of Task 4; the `profile-language` segmented button → the row and its sheet; the app bar's logout icon → the "Выйти" button (key `logout-button` kept).

**Interfaces:**
- Consumes: Task 2 `CustomerProfile.supportPhone`, `legalIndexProvider`; Task 3 `AppPaths.legal`; Task 4 `AppPaths.customerEditProfile`, `initialsOf`; Task 5 `showDeleteAccountSheet`; `languageControllerProvider`, `phoneCallsProvider`, `sessionControllerProvider` (`SignedIn.staffUser`).
- Produces: `ProfileHeader(profile)`; `Future<void> showLanguageSheet(BuildContext context)` (key `language-sheet`).
- Layout 32: no app bar; the header — `primary`, its bottom corners `Radius.elliptical(30, 22)`, under the status bar: `profileTitle` 16 w700 white centred; a 70 circle `primarySoft` with the initials 26 w700 `primaryDark` (or `person` 36); right of it the name 18 w700 white on one line with an ellipsis (key `profile-name`) or `profileNoName` at 0.9 opacity, and the phone 14 white (key `profile-phone`). Then the rows, padding 20, each 58 high with a `line` divider (none under the last), an icon 24 `ink` 16 before the title 16 w500, a value 14 `muted`, a chevron 22:
  - `profile-edit` — `edit_square`, `profileEdit` ("Указать имя" `profileSetName` when no name) → push `AppPaths.customerEditProfile`;
  - `profile-addresses` — `location_on`, `addressesTitle` → `AppPaths.customerAddresses`;
  - `profile-language` — `translate`, `profileLanguage`, value `languageUzbek` / `languageRussian` → `showLanguageSheet`;
  - `profile-support` — `support_agent`, `profileSupport`, value `formatPhone(supportPhone)`, no chevron, only with a support phone → `phoneCallsProvider` call; `false` → `SnackBar` `callFailed(formatPhone(phone))`;
  - `profile-privacy` — `verified_user`, `profilePrivacy`, only while `legalIndexProvider` has privacy → push `AppPaths.legal(privacy)`;
  - `profile-terms` — `event_note`, `legalTerms`, only while the index has terms → push `AppPaths.legal(terms)`;
  - `profile-delete` — `delete`, `profileDeleteAccount`, icon and title `danger`, no chevron, hidden when the session holds a staff account (`SignedIn.staffUser != null`) → `showDeleteAccountSheet`.
  Then 24 below, `logoutButton` with a `logout` icon (key `logout-button`), `primary`, 56 radius 14, which logs the Customer session out as today. The body scrolls; `CustomerTabBar(current: CustomerTab.profile)` and `UnderActiveMode` stay. A profile that fails to load keeps today's failure message and retry, with the language row and the logout button under it.
- Sheet 32б: the grab handle, `profileLanguage` 18 w700, two 58-high options `languageUzbek` (key `language-uz`) and `languageRussian` (key `language-ru`) with `radio_button_checked` `primary` / `radio_button_unchecked` `muted`; a tap selects the language through `languageControllerProvider` and closes the sheet.
- Texts (ru / uz): `profileNoName` "Как вас зовут?" / "Ismingiz nima?"; `profileEdit` "Редактировать профиль" / "Profilni tahrirlash"; `profileSetName` "Указать имя" / "Ismni kiritish"; `profileLanguage` "Язык" / "Til"; `profileSupport` "Поддержка" / "Qo'llab-quvvatlash"; `profilePrivacy` "Конфиденциальность" / "Maxfiylik".

- [ ] **Step 1: Write the failing tests** in `profile_screen_test`:
  1. A named Customer with a support phone and both documents → the header "ДК", "Дилноза Каримова", "+998 90 123 45 67" and the seven rows in order; the language row's value follows the language.
  2. No name, no support phone (drawing 32а) → the person icon, "Как вас зовут?", "Указать имя", no support row.
  3. `test_the_legal_rows_follow_the_documents`: none → neither row; privacy only → only "Конфиденциальность"; a failed index → neither; tapping a row opens its document.
  4. Support: a tap calls the number once; a failed dial shows the number.
  5. `test_a_staff_session_has_no_delete_row`: a Customer session beside a staff session → no `profile-delete`; Customer only → the row opens sheet 36.
  6. The language sheet: choosing O'zbekcha closes the sheet and the profile reads "Til"; the edit row opens the editor; "Выйти" signs the Customer out.
  7. `test_the_profile_holds_at_the_extremes`: a 120-character name, all rows, 320×640, text ×2, `uz` and `ru`; the language sheet the same.
  8. The rewritten flows of `customer_account_screens_test.dart` pass against the new profile.

- [ ] **Step 2: Run** `flutter test test/features/profile test/features/addresses/customer_account_screens_test.dart test/core/widgets/customer_tab_bar_test.dart` — the new tests fail.

- [ ] **Step 3: Implement.**

- [ ] **Step 4: Run** the same — pass; `flutter analyze`, `dart format`.

- [ ] **Step 5: Docs, DL and commit.** `docs/03` §3 describes the profile as drawn; `tasks/REDESIGN_CUSTOMER.md` keeps stage 7 "In Progress" until the merge. `DL-96` item 6:

```markdown
6. **The profile tab.** One kit screen: the header with the initials, name and phone; rows for the name, addresses, language, support, the two documents and deletion; "Выйти" under them. Support shows only with a support phone and calls it; each document row shows only while that document is published; deletion is hidden while the phone also holds a staff session, whose sign-in shares the phone. The language is chosen in a sheet.
```

Commit `feat(profile): the kit profile tab and language sheet (DL-96 item 6)`.

---

### Task 7 (the lead, not a subagent): The legal drafts for the Owner's lawyer

**Files:**
- Create: `docs/legal/README.md`, `docs/legal/terms.ru.txt`, `docs/legal/terms.uz.txt`, `docs/legal/privacy.ru.txt`, `docs/legal/privacy.uz.txt`
- Modify docs: `DL-96` item 7

- [ ] **Step 1:** Write the four texts in the panel's format (`## ` heading, `- ` item, any other line a paragraph) from drawings 34 and 35 and `docs/01–09`; the privacy text gains the line of `DL-95`: "Если аккаунт был заблокирован и затем удалён, мы храним необратимый отпечаток номера телефона — по нему номер нельзя восстановить, но с ним нельзя зарегистрироваться снова." Placeholders in square brackets: the company's name, tax number and address; the retention period. The README says what each placeholder needs (`DL-93` item 4), that a lawyer checks the texts before the Admin publishes them on "Документы", and that nothing here is published by code.
- [ ] **Step 2:** Publish the drafts on the local stack through the panel for the walk (local only).
- [ ] **Step 3: DL and commit.** `DL-96` item 7: "**Drafts, not data.** The texts live in `docs/legal/` for the lawyer and are published by the Admin; no migration or seeder writes them, so nothing unchecked reaches Google Play." Commit `docs(legal): drafts of the terms and the privacy policy (DL-96 item 7)`.

---

## After the tasks

- Full backend suite and full frontend suite through `test-runner`; `git diff --check`.
- `branch-reviewer` (opus) on the whole branch against this plan and its Review Focus; one fix wave; scoped re-review.
- `/security-review` (the branch changes who can sign up and erases personal data).
- Walk on the emulator before the merge: rerun `G:/tools/bb-walk/orders_6b.py` (the 7a walk left recipients "????"); profile, language, name, both documents, consent links from the sign-in screen, deletion refused by an unfinished order, deletion completed and signing in again as a new Customer; in the panel, erasing a blocked Customer and that number's sign-in refused. Screenshots to `G:/tools/demo-photos/stage7b`.
- PR, both required checks green, merge; `tasks/REDESIGN_CUSTOMER.md` stage 7 "Merged (PR #101, #…)".
