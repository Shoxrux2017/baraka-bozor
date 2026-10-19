# Kit Stage 7a — Profile Server and Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The server and the web panel give the kit profile screens (stage 7b) everything they need, as the Owner decided on 2026-10-19: the terms of use and the privacy policy live on the server, the Admin edits them in the panel in Uzbek and Russian, the app and public web pages show them; the server records when a person accepted them at sign-in; a Customer deletes their own account with a login code, an Admin deletes one on request, personal data is erased and orders stay without it.

**Architecture:** A new `Legal` module holds the documents in an append-only `legal_documents` table (the newest row per kind and language is in force, so every edition stays provable), an Admin editor API, a public API that returns parsed blocks, and three server-rendered public pages (the first Blade views of the project). Login codes gain a second purpose, `account_deletion`; the code check is extracted from the login action so both purposes share one lock and attempt counter. A new `Accounts` action erases a Customer under the cart lock: the user row becomes `deleted` with no phone or name, the Customer's own rows are deleted, and the order snapshots and free texts are nulled. The panel gains a documents page, a customers page with deletion, and shows erased orders.

**Tech Stack:** Laravel 13 + PostgreSQL 17 (Sanctum, Blade), Flutter 3.47.5 + Riverpod 3 + go_router, `flutter gen-l10n` (template `app_uz.arb`).

**Spec:** Claude Design project "BarakaBozor — стиль покупателя", file `kit/07-profil.dc.html`, approved by the Owner 2026-10-19 (screens 32–37, 02а), and the Owner's answers of 2026-10-19 recorded in Task 1 as `DL-93`. Stage 7b (`2026-10-19-kit-stage-7b-customer-profile.md`, written after this plan merges) builds the Customer screens on this API.

## Global Constraints

- Branch `task/kit-7a-profile-server` from `main` 73691c5. Never commit to `main`.
- Backend commands run in Docker from the repo root: `docker compose -f docker/compose.yaml exec -T app <cmd>` (`php artisan test --filter=…`, `vendor/bin/pint --test`, `vendor/bin/phpstan analyse`). Flutter: `G:/tools/flutter/bin/flutter` with `TEMP`/`TMP` = `G:\tools\tmp`, run from `frontend/`.
- Migrations: `backend/database/migrations/2026_10_19_00000N_<snake>.php`, N = 1…3 in task order, anonymous class, checks by `DB::statement` through a private `check()` helper as `2026_09_26_000004_create_product_images_table.php` does; a replaced check is dropped and re-added by name; uuid primary keys; `timestampTz`.
- Security (AGENTS.md §5): Customer routes in the `AuthServiceProvider::PROTECTED` + `RequireRole::of(Role::Customer)` group of `routes/api/v1/customer.php`; Admin routes in the Admin group of `routes/api/v1/settings.php`; only the public legal routes are unauthenticated, and they carry `throttle:60,1`. Another or an unknown Customer is the scope-safe `404 resource_not_found`. A login code, a phone or a name is never logged; a deletion code is never emitted anywhere a login code may not be (`BR-ROLE-011`).
- Strict request shape (`docs/09` §4): unknown body fields are `422 validation_failed`; a route that takes no body refuses any field.
- Historical integrity (AGENTS.md §6): erasure never changes an order's status, lines, quantities, prices, totals, payments or history events — only the personal fields listed in Task 4. Legal documents are never updated or deleted, only appended.
- Phone pattern: `LoginCodePolicy::PHONE_PATTERN`, reused, not copied.
- No new Composer or pub package; lockfiles unchanged. Generated l10n files are regenerated with `flutter gen-l10n`, never hand-edited. Texts: Uzbek (template, ASCII apostrophe as the ARB files use) and Russian.
- Each agent decision is an item of `DL-94` in `docs/DECISIONS.md`, written in the task that implements it, and the affected `docs/01–09` section is updated in that task (AGENTS.md §3).
- New `docs/08` section 34 `legal_documents`, appended after 33. New `docs/09` sections appended after 60 under a new heading `# Profile and Documents`: 61 Legal Documents, 62 Legal Document, 63 Admin Legal Documents, 64 Account Deletion Code, 65 Account Deletion, 66 Admin Customers, 67 Admin Customer Erasure.
- Never delete, skip or weaken a test; a test whose flow changed is rewritten to assert the new flow.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

- Deletion code refusals on an authenticated route: a wrong, expired or exhausted code answers `422`, never `401` — the client logs out on any `401` — and the third wrong code answers `429 code_locked` and locks login codes for that phone too.
- Purposes never cross: a login code never deletes an account, a deletion code never signs in, and requesting one never invalidates the other's open challenge.
- Erasure racing checkout: an order placed while the deletion runs either exists before the erasure takes the cart lock (deletion refused `409`) or is refused after it (the token is gone); a Customer is never deleted with an unfinished order.
- A deleted phone signs in again as a brand-new Customer with no addresses, favourites, cart or orders, while the deleted account's orders stay in the panel marked erased; a blocked Customer's phone still cannot escape its block this way (only a deleted account frees the phone).
- Public pages and blocks escape the Admin's text: `<script>` typed into a document renders as text in the API blocks, the web page and the panel preview.

---

### Task 1: The Owner's decisions; legal documents with the Admin editor and the public API

**Files:**
- Create: `backend/database/migrations/2026_10_19_000001_create_legal_documents_table.php`, `backend/app/Models/LegalDocument.php`, `backend/app/Models/Enums/LegalDocumentKind.php` (`Terms = 'terms'`, `Privacy = 'privacy'`), `backend/app/Modules/Legal/LegalDocuments.php`, `backend/app/Modules/Legal/LegalText.php`, `backend/app/Modules/Legal/Actions/PublishLegalDocument.php`, `backend/app/Modules/Legal/Http/Controllers/LegalDocumentController.php` (public), `backend/app/Modules/Legal/Http/Controllers/AdminLegalDocumentController.php`, `backend/app/Modules/Legal/Http/Requests/PublishLegalDocumentRequest.php`, `backend/app/Modules/Legal/Http/Requests/ShowLegalDocumentRequest.php` (`language` query), `backend/app/Modules/Legal/Http/Resources/…` as the controllers need, `backend/routes/api/v1/legal.php` (public; register it where the other `routes/api/v1/*.php` files are loaded)
- Modify: `backend/routes/api/v1/settings.php` (Admin routes)
- Modify docs: `docs/DECISIONS.md` (new `DL-93`, new `DL-94` item 1), `docs/02-user-roles.md` (Admin edits the documents; anyone reads them), `docs/03-features.md` §3 (documents), `docs/08-database.md` §34 (new), `docs/09-api-contracts.md` §61–63 (new, heading `# Profile and Documents`), `tasks/REDESIGN_CUSTOMER.md` (stage 6 "Merged (PR #99, #100)"; stage 7 "In Progress (7a server and panel, 7b screens)")
- Test: Create `backend/tests/Feature/Legal/LegalDocumentsApiTest.php`, `backend/tests/Unit/Legal/LegalTextTest.php`

**Interfaces:**
- Produces (schema): `legal_documents(id uuid, kind varchar(16) check in ('terms','privacy'), language char(2) check in ('uz','ru'), body text null, created_by_user_id uuid not null fk users restrict, created_at timestamptz)`, index `(kind, language, created_at)`. The newest row of a kind and language is in force; `body` null = not published.
- Produces (API): `GET /api/v1/legal?language=uz|ru` (public) → `{data: {terms: {language, updated_at}|null, privacy: {language, updated_at}|null}}`; `GET /api/v1/legal/{kind}?language=uz|ru` (public) → `{data: {kind, language, updated_at, blocks: [{type: 'heading'|'paragraph'|'item', text}]}}`. When the asked language has no published text the other language answers (its `language` says which); neither → the list's `null`, the document's `404 resource_not_found`. `language` absent → `uz`; another value `422`. An unknown kind → `404`. `GET /api/v1/admin/legal-documents` (Admin) → `{data: [{kind, language, body, updated_at, updated_by: {id, full_name}|null}]}`, always four entries in the order terms-uz, terms-ru, privacy-uz, privacy-ru. `PUT /api/v1/admin/legal-documents/{kind}/{language}` (Admin) body `{body: string|null}` (max 50 000; blank or whitespace = `null`) → `200` with that entry; the same body as in force → `200`, no new row.
- Produces (PHP): `LegalText::blocks(string $body): list<array{type: string, text: string}>`; `LegalDocuments::current(LegalDocumentKind $kind, string $language): ?LegalDocument` (newest row, body may be null); `LegalDocuments::published(LegalDocumentKind $kind, string $language): ?LegalDocument` (with the language fallback, body not null); `PublishLegalDocument::publish(User $admin, LegalDocumentKind $kind, string $language, ?string $body): LegalDocument`.

- [ ] **Step 1: Record the Owner's decisions.** Append to `docs/DECISIONS.md` after `DL-92`:

```markdown
## DL-93 — Profile, documents and account deletion, kit stage 7 (2026-10-19, Owner)

Answers to the questions of kit stage 7 (`kit/07-profil.dc.html`, approved the same day).

1. **Documents.** The terms of use and the privacy policy live on the server, in Uzbek and Russian. The Admin writes and changes them in the panel; the app shows them in the profile and the same text is published at a public address for Google Play. While a document is empty its row is hidden. The agent drafts the texts from these documents; a lawyer in Uzbekistan checks them before the Admin publishes them.
2. **Consent.** The sign-in screen says that by continuing the person accepts the terms and the policy, with links to both, and the server records when the person accepted.
3. **Account deletion.** The profile has "Удалить аккаунт". A sheet says what is erased — name, phone, addresses, favourites, cart — and what stays — the order history without name and phone, for accounting. The Customer confirms with a login code and the account is erased at once. While an order is unfinished the deletion is refused. A public page explains how to delete the account with or without the app; without it the Customer calls support and the Admin deletes the account in the panel.
4. **Still to come from the Owner, before publication:** the company's name, tax number and address for the terms; how many years order and money records are kept (from the accountant); the lawyer's check of both texts.
```

- [ ] **Step 2: Write the failing tests.**
  1. `LegalTextTest::test_blocks`: `"## Цены\nЦены примерные.\n\n- Один\n- Два\r\nКонец"` → `[heading "Цены", paragraph "Цены примерные.", item "Один", item "Два", paragraph "Конец"]`; leading/trailing spaces of a line trimmed; blank lines dropped; `"##"` alone and `"- "` alone are dropped; `"<script>x</script>"` stays the literal text.
  2. `LegalDocumentsApiTest::test_an_admin_publishes_and_reads_documents`: `GET /admin/legal-documents` → four entries with `body` null; `PUT /admin/legal-documents/terms/ru {"body":"## A\nB"}` → `200`, `body` the text, `updated_by.id` the Admin, `updated_at` set; the list shows it.
  3. `test_publishing_appends_and_repeats_naturally`: two different bodies → two rows, the newest in force; the same body again → no third row; `{"body":"  "}` → a row with `body` null, the document unpublished.
  4. `test_the_public_api_answers_blocks_with_a_language_fallback`: terms published in `ru` only → `GET /legal/terms?language=ru` and `?language=uz` both `200` with `language` `ru` and the blocks; `GET /legal?language=uz` → `terms.language` `ru`, `privacy` null; `GET /legal/privacy` → `404`; `GET /legal/other` → `404`; `?language=en` → `422`. No token needed.
  5. `test_only_admins_edit`: Customer, Shopper, Courier, Operator, Manager tokens → `403` on both Admin routes; an unknown kind or language in the path → `404`; a body over 50 000 characters, a missing `body` key or an extra field → `422`.

- [ ] **Step 3: Run** `php artisan test --filter='LegalDocumentsApiTest|LegalTextTest'` — expect failures.

- [ ] **Step 4: Implement** the files above. `PublishLegalDocument` normalises `\r\n` to `\n`, trims, maps blank to null, compares with `LegalDocuments::current()` and inserts only on a change; `updated_at` in every answer is the row's `created_at`, `updated_by` its creator.

- [ ] **Step 5: Run** the filter and `tests/Feature/Settings` — all pass.

- [ ] **Step 6: Docs, DL, checks, commit.** `docs/08` §34, `docs/09` §61–63 as the Interfaces say, `docs/03` §3 and `docs/02`. `DL-94` item 1:

```markdown
## DL-94 — Profile, documents and account deletion, kit stage 7 (2026-10-19, agent)

1. **Documents are append-only.** Each save adds a row; the newest row of a kind and language is in force and a blank save unpublishes. Every edition a Customer may have accepted stays readable with its date, which the consent time of item 3 needs. The text format is plain: a line starting with `## ` is a heading, one starting with `- ` a list item, any other line a paragraph; the server parses it into blocks so the app, the panel and the web pages render the same thing and nothing the Admin types is ever HTML. A missing language falls back to the other one. The public API is unauthenticated and throttled at 60 requests a minute.
```

`pint --test`, `phpstan analyse`; commit `feat(legal): documents with the Admin editor and the public API (DL-93, DL-94 item 1)`.

---

### Task 2: Public web pages — terms, privacy, account deletion

**Files:**
- Create: `backend/resources/views/legal/layout.blade.php`, `backend/resources/views/legal/document.blade.php`, `backend/resources/views/legal/account-deletion.blade.php`, `backend/app/Modules/Legal/Http/Controllers/LegalPageController.php`, `backend/app/Modules/Legal/LegalPageTexts.php` (the fixed page texts per language)
- Modify: `backend/routes/web.php`
- Modify docs: `DL-94` item 2, `docs/07-architecture.md` (public pages), `docs/09-api-contracts.md` §61 (the page addresses)
- Test: Create `backend/tests/Feature/Legal/LegalPagesTest.php`

**Interfaces:**
- Consumes: Task 1 `LegalDocuments::published`, `LegalText::blocks`; `BusinessSettings` `support_phone`.
- Produces (web): `GET /legal/terms`, `GET /legal/privacy`, `GET /account-deletion`, each `?lang=uz|ru` (absent or another value → `uz`), `throttle:60,1`, `text/html; charset=utf-8`, `<html lang>` = the shown language, a language switch linking the other `?lang`. A document page shows "BarakaBozor", the title, "Редакция от d.m.Y" / "Tahrir: d.m.Y" (Tashkent time) and the blocks (`h2`, `p`, `ul > li`); unpublished in both languages → `404` with the page title and "Документ ещё не опубликован." / "Hujjat hali e'lon qilinmagan.". No external script, font or image; one inline `<style>` in the kit colours (`#5AC268`, ink `#151D16`).
- Copy of `/account-deletion` (ru / uz), from drawing 37:
  - title "Удаление аккаунта BarakaBozor" / "BarakaBozor akkauntini o'chirish"
  - "В приложении: Профиль → «Удалить аккаунт», подтвердите кодом." / "Ilovada: Profil → «Akkauntni o'chirish», kod bilan tasdiqlang."
  - with a support phone: "Без приложения: позвоните в поддержку {phone} с номера, на который открыт аккаунт. Удалим в течение 7 дней." / "Ilovasiz: akkaunt ochilgan raqamdan {phone} qo'llab-quvvatlash raqamiga qo'ng'iroq qiling. 7 kun ichida o'chiramiz."; without one this paragraph is absent.
  - "Что сотрём: имя, номер телефона, адреса, избранное и корзину." / "Nimalar o'chiriladi: ism, telefon raqami, manzillar, sevimlilar va savat."
  - "Что останется: история заказов — без имени и телефона, для учёта." / "Nima qoladi: buyurtmalar tarixi — ism va telefonsiz, hisob uchun."
  - "Если есть незавершённый заказ, удалить аккаунт можно после его доставки или отмены." / "Tugallanmagan buyurtma bo'lsa, akkauntni u yetkazilgan yoki bekor qilingandan keyin o'chirish mumkin."
  - a link "Политика конфиденциальности" / "Maxfiylik siyosati" to `/legal/privacy?lang=…`.

- [ ] **Step 1: Write the failing tests** in `LegalPagesTest`:
  1. `test_a_published_document_is_a_public_page`: privacy published in `uz` with `"## Sarlavha\n<script>x</script>"` → `GET /legal/privacy` `200`, HTML contains `<h2>Sarlavha</h2>` and `&lt;script&gt;x&lt;/script&gt;`, never `<script>x`; `lang="uz"`.
  2. `test_the_language_falls_back_and_switches`: terms only in `ru` → `/legal/terms?lang=uz` shows the Russian text with `lang="ru"`; `?lang=de` is treated as `uz`.
  3. `test_an_unpublished_document_is_a_404_page`: `/legal/terms` → `404`, the body contains "Hujjat hali e'lon qilinmagan.".
  4. `test_the_deletion_page_shows_the_support_phone_only_when_set`: support phone `+998712000000` → `/account-deletion?lang=ru` contains "+998712000000" and "Удалим в течение 7 дней."; cleared → neither, the in-app paragraph still there.
  5. `test_pages_need_no_session_and_set_no_cookie`: no `Set-Cookie` with a session in the answer (the pages are served without the web session middleware).

- [ ] **Step 2: Run** `--filter=LegalPagesTest` — expect failures.

- [ ] **Step 3: Implement.** Routes in `routes/web.php` without the session and CSRF middleware (`withoutMiddleware` of the `web` group's session/cookie middleware, or a route group with only `throttle:60,1`); Blade `{{ }}` only, never `{!! !!}`.

- [ ] **Step 4: Run** the filter — pass.

- [ ] **Step 5: Docs, DL, checks, commit.** `DL-94` item 2:

```markdown
2. **Public pages.** The documents and the deletion instructions are three server-rendered pages — `/legal/terms`, `/legal/privacy`, `/account-deletion` — the addresses given to Google Play. They are the project's first Blade views: plain HTML with one inline style, no script, no session, no cookie, `?lang=uz|ru`. The deletion page's text is fixed in the code (it describes the product, not a legal position) and shows the support phone only when the Admin set one. "Within 7 days" for a request by phone is the agent's proposal, shown to the Owner with the drawing.
```

Commit `feat(legal): public pages for the documents and account deletion (DL-94 item 2)`.

---

### Task 3: Login codes gain the account-deletion purpose; the consent time

**Files:**
- Create: `backend/database/migrations/2026_10_19_000002_add_account_deletion_purpose_and_terms_accepted_at.php`, `backend/app/Modules/Auth/LoginCodeCheck.php`, `backend/app/Modules/Auth/LoginCodeRefused.php` (exception carrying `apiCode` and `retryAfterSeconds`)
- Modify: `backend/app/Modules/Auth/Models/LoginChallenge.php` (`PURPOSE_ACCOUNT_DELETION = 'account_deletion'`; `scopeOpenFor(Builder $query, string $phone, string $purpose = self::PURPOSE_CUSTOMER_LOGIN)`), `backend/app/Modules/Auth/Actions/RequestCustomerLoginCode.php` (`__invoke(string $phone, string $ip, string $purpose = LoginChallenge::PURPOSE_CUSTOMER_LOGIN)`), `backend/app/Modules/Auth/Actions/VerifyCustomerLoginCode.php` (uses `LoginCodeCheck`, maps `LoginCodeRefused` to today's `401`/`429` answers, sets `terms_accepted_at`), `backend/app/Models/User.php` (`terms_accepted_at` cast)
- Modify docs: `DL-94` item 3, `docs/08-database.md` §3 (`users.terms_accepted_at`) and §4 (purposes), `docs/09-api-contracts.md` §7 (verify records the consent), `docs/05-business-rules.md` (new `BR-ROLE-012`)
- Test: Modify `backend/tests/Feature/Auth/` login-code tests only by adding cases; Create `backend/tests/Feature/Auth/LoginCodePurposeTest.php`

**Interfaces:**
- Produces (schema): `customer_otp_challenges_purpose_check` → `purpose in ('customer_login','account_deletion')`; `users.terms_accepted_at timestamptz null`.
- Produces (PHP): `LoginCodeCheck::consume(string $phone, #[\SensitiveParameter] string $code, string $purpose): void` — the lock check, the newest open challenge of that purpose under `lockForUpdate`, expiry, attempts, hash, consumption, committed before any refusal is thrown, the lock taken on the third wrong code — exactly today's behaviour of `VerifyCustomerLoginCode`, moved; throws `LoginCodeRefused` with `apiCode` one of `code_invalid`, `code_expired`, `code_attempts_exhausted`, `code_locked` (with `retryAfterSeconds`). The lock key and the hourly send window stay per phone, shared by both purposes.
- Produces (behaviour): every successful `POST /auth/customer/code/verify` sets the Customer account's `terms_accepted_at` to now.

- [ ] **Step 1: Write the failing tests** in `LoginCodePurposeTest`:
  1. `test_a_deletion_code_never_signs_in`: a challenge of purpose `account_deletion` for the phone with a known code (create it through `RequestCustomerLoginCode` with that purpose on a configured test phone) → `POST /auth/customer/code/verify` with that code → `401 code_invalid`.
  2. `test_a_login_code_request_leaves_a_deletion_code_open` and the reverse: requesting one purpose does not set `invalidated_at` on the other purpose's open challenge.
  3. `test_the_lock_is_shared`: three wrong codes through `LoginCodeCheck::consume(..., 'account_deletion')` → the third throws `code_locked`; then `POST /auth/customer/code/request` for that phone → `429 code_locked`.
  4. `test_verifying_records_the_consent_time`: freeze time; verify → the Customer's `terms_accepted_at` equals now; a later verify moves it.
  5. Add to the existing verify tests nothing but these; the existing login-code tests pass unchanged.

- [ ] **Step 2: Run** `--filter='LoginCodePurposeTest|CustomerLoginCode'` — new tests fail, old pass.

- [ ] **Step 3: Implement.** Extract, do not rewrite: `VerifyCustomerLoginCode` calls `LoginCodeCheck::consume($phone, $code, LoginChallenge::PURPOSE_CUSTOMER_LOGIN)`, then resolves the account, sets `last_login_at` and `terms_accepted_at`, issues the token and the staff step in its own transaction; the docblocks move with the code they describe.

- [ ] **Step 4: Run** `tests/Feature/Auth` whole — all pass.

- [ ] **Step 5: Docs, DL, checks, commit.** `BR-ROLE-012 — A login code has a purpose, sign-in or account deletion; a code of one purpose never serves the other. Both share the phone's send window, attempt limit and lock.` `DL-94` item 3:

```markdown
3. **Codes and consent.** Account deletion reuses the login code: same six digits, lifetime, three attempts, 60-second lock and hourly window, all per phone and shared with sign-in, so deletion opens no second way to pump or guess codes. A purpose column keeps the two apart. The check moved out of the sign-in action into `LoginCodeCheck`, unchanged. Consent is the moment of each verified sign-in, kept in `users.terms_accepted_at`; with the append-only documents of item 1 it names the edition the person saw.
```

Commit `feat(auth): the account-deletion code purpose and the consent time (DL-94 item 3)`.

---

### Task 4: A Customer deletes their own account

**Files:**
- Create: `backend/database/migrations/2026_10_19_000003_allow_customer_erasure.php`, `backend/app/Modules/Accounts/Actions/EraseCustomer.php`, `backend/app/Modules/Accounts/UnfinishedOrders.php`, `backend/app/Modules/Accounts/Http/Controllers/AccountDeletionController.php`, `backend/app/Modules/Accounts/Http/Requests/DeleteAccountRequest.php` (`code` required, six digits), `backend/app/Modules/Accounts/Http/Requests/RequestDeletionCodeRequest.php` (no body)
- Modify: `backend/app/Models/Enums/UserStatus.php` (`Deleted = 'deleted'`), `backend/app/Models/User.php` (`phone` and `full_name` nullable in the docblock; `deleted_at`, `deleted_by_user_id`), `backend/app/Models/Order.php` (snapshot docblock types nullable; `customer_erased_at`), `backend/app/Modules/Auth/Http/Middleware/EnsureAccountActive.php` (a `deleted` account is refused like a blocked one), `backend/routes/api/v1/customer.php`
- Modify docs: `DL-94` item 4, `docs/02-user-roles.md` (the Customer deletes their own account), `docs/04-user-flows.md` (deletion flow), `docs/05-business-rules.md` (new `BR-ROLE-013`), `docs/08-database.md` §3 (`users` status `deleted`, phone null only when deleted, `deleted_at`, `deleted_by_user_id`) and the `orders` and `order_cancellation_requests` sections, `docs/09-api-contracts.md` §64–65
- Test: Create `backend/tests/Feature/Accounts/AccountDeletionApiTest.php`

**Interfaces:**
- Consumes: Task 3 `RequestCustomerLoginCode` with a purpose, `LoginCodeCheck::consume`, `LoginCodeRefused`.
- Produces (schema): `users_status_check` adds `deleted`; `users.phone` nullable with check `phone is not null or status = 'deleted'`; `users.deleted_at timestamptz null`, `users.deleted_by_user_id uuid null fk users restrict`. `orders`: `recipient_name_snapshot`, `recipient_phone_snapshot`, `latitude`, `longitude`, `street`, `house` nullable, new `customer_erased_at timestamptz null`, check `customer_erased_at is not null or (recipient_name_snapshot, recipient_phone_snapshot, latitude, longitude, street, house all not null)`. `order_cancellation_requests.reason` nullable.
- Produces (API): `POST /customer/account/deletion-code`, no body → `200` with the same `data` as `POST /auth/customer/code/request`; an unfinished order → `409 account_has_unfinished_orders` with `details: {order_id, order_number}` (the oldest unfinished order) and no code sent. `POST /customer/account/delete {code}` → `204`, every token of the account revoked; unfinished order → the same `409`, checked before the code is consumed; `code_invalid`, `code_expired`, `code_attempts_exhausted` → `422` with that code; `code_locked` → `429` with `Retry-After`.
- Produces (PHP): `UnfinishedOrders::oldest(User $customer): ?Order` (status not `completed`/`cancelled`); `EraseCustomer::erase(User $customer, User $actor): void` — throws `ApiException::conflict('account_has_unfinished_orders', ['order_id' => …, 'order_number' => …])`; refuses a non-Customer or an already deleted account with `ApiException::notFound()`.
- Erasure, in one transaction after `CustomerCart::lock($customer)` and the user row `lockForUpdate`, re-checking `UnfinishedOrders::oldest` under the lock:
  - `users`: `status` `deleted`, `phone` null, `full_name` null, `last_login_at` null, `deleted_at` now, `deleted_by_user_id` the actor; `preferred_language` and `terms_accepted_at` kept.
  - deleted rows: `customer_addresses`, `customer_favorites`, `push_devices`, the active cart's `cart_items`, `personal_access_tokens` of the account, `customer_otp_challenges` of the phone (read before nulling it).
  - nulled: `cart_items.customer_note` of the account's other carts; on the account's orders `recipient_name_snapshot`, `recipient_phone_snapshot`, `latitude`, `longitude`, `street`, `house`, `apartment`, `landmark`, `delivery_note_snapshot`, `delivery_time_note`, and `customer_erased_at` = now; `order_items.customer_note_snapshot` of those orders; `order_ratings.comment` of those orders; `order_cancellation_requests.reason` of requests the account made; `order_history.note` where `actor_user_id` is the account; `idempotency_keys.response` where `actor_user_id` is the account.
  - untouched: order status, lines, quantities, prices, totals, payments, approvals, history events and their `details` (ids and codes only — confirm by reading every `'details' =>` writer under `app/Modules/Orders` and record the result in the DL item).

- [ ] **Step 1: Write the failing tests** in `AccountDeletionApiTest` (a Customer on a configured test phone, so the code is the fixed test code):
  1. `test_a_customer_deletes_the_account`: the Customer has two addresses, a favourite, a cart line with a note, a completed order with a rating comment, a cancelled order with a cancellation request reason, a push device → request the code `200`; delete `204`; the old token answers `401`; the user row is `deleted` with phone, name and `last_login_at` null, `deleted_by_user_id` itself; no addresses, favourites, push devices, cart items or challenges remain for it; both orders keep status, totals and lines, have every listed snapshot null and `customer_erased_at` set; the rating's stars stay and its comment is null; the request's reason is null.
  2. `test_another_customer_is_untouched`: a second Customer's addresses, orders and snapshots are byte-for-byte unchanged.
  3. `test_an_unfinished_order_blocks_deletion`: an order `shopping` → code request `409 account_has_unfinished_orders` with `details.order_id`/`order_number`, no challenge created; delete with a valid code → the same `409` and the challenge still open.
  4. `test_wrong_codes_answer_422_then_lock`: two wrong codes → `422 code_invalid`; the third → `429 code_locked`; a login code for this phone (purpose sign-in) → `422 code_invalid`.
  5. `test_the_phone_signs_in_again_as_a_new_customer`: after deletion, `code/request` + `code/verify` for the phone → `200`, a new user id, `GET /customer/addresses` empty, `GET /customer/orders` empty.
  6. `test_a_blocked_customer_still_cannot_escape_the_block`: unchanged from today — a blocked Customer's phone verifies to `401 account_blocked` (deletion is the only way a phone is freed).
  7. `test_only_customers_and_no_body_fields`: Shopper, Courier, Operator, Admin, Manager tokens → `403`; an extra field on either route → `422`; `code` of five digits → `422`.

- [ ] **Step 2: Run** `--filter=AccountDeletionApiTest` — expect failures.

- [ ] **Step 3: Implement** the migration, `EraseCustomer`, `UnfinishedOrders`, the controller (maps `LoginCodeRefused` to `422`/`429`) and the routes. Check the new nullable `User::$phone` and Order snapshot docblock types with `phpstan analyse`: resources pass nulls through unchanged; on a path that only ever sees an active account or an unfinished order (sign-in, checkout, Shopper and Courier resources — an erased order is always finished, so never theirs) narrow with an `assert`, never a cast that would turn null into `''`.

- [ ] **Step 4: Run** `tests/Feature/Accounts`, `tests/Feature/Auth`, `tests/Feature/Orders` — all pass.

- [ ] **Step 5: Docs, DL, checks, commit.** `BR-ROLE-013 — A Customer may delete their own account with a deletion code while no order of theirs is unfinished. Deletion erases the account's personal data and frees the phone; orders, payments and history stay without the name, phone, address and free texts.` `DL-94` item 4:

```markdown
4. **Erasure, not removal.** A deleted Customer keeps a row with status `deleted` and no phone or name: orders, payments, assignments and history reference it and stay intact for accounting. Erased: the account's addresses, favourites, cart lines, push devices, tokens and codes; on its orders the recipient's name and phone, the delivery address with its point, apartment, landmark and notes, the delivery wish, the line notes, the rating comment, the cancellation reasons it wrote, the notes of its own history entries and its stored idempotent answers. History `details` hold only ids and codes (checked: …). The erasure takes the cart lock that order placement takes, so a checkout cannot slip in; an unfinished order refuses it with the oldest such order's id and number, before the code is spent. Deletion-code refusals answer `422`, not `401`, because the request is authenticated and the app treats `401` as a lost session. A deleted phone signs in as a new Customer; a blocked one still cannot.
```

Commit `feat(accounts): a Customer deletes their own account (DL-93 item 3, DL-94 item 4)`.

---

### Task 5: The Admin finds a Customer and deletes the account; erased orders in the operations API

**Files:**
- Create: `backend/app/Modules/Accounts/Http/Controllers/AdminCustomerController.php`, `backend/app/Modules/Accounts/Http/Requests/FindCustomersRequest.php` (`phone` required, `PHONE_PATTERN`), `backend/app/Modules/Accounts/Http/Resources/AdminCustomerResource.php`
- Modify: `backend/routes/api/v1/settings.php` (Admin group), `backend/app/Modules/Orders/Http/Resources/BoardOrderResource.php` and `BoardOrderRowResource.php` (`customer_erased: bool`)
- Modify docs: `DL-94` item 5, `docs/02-user-roles.md` (the Admin deletes a Customer account), `docs/09-api-contracts.md` §66–67 and the board order sections (`customer_erased`)
- Test: Create `backend/tests/Feature/Accounts/AdminCustomersApiTest.php`; Modify `backend/tests/Feature/Orders/OperationsBoardApiTest.php`

**Interfaces:**
- Consumes: Task 4 `EraseCustomer::erase`, `UnfinishedOrders::oldest`.
- Produces (API): `GET /admin/customers?phone=+998…` (Admin) → `{data: [{id, phone, full_name, status, created_at, last_login_at, order_count, unfinished_order: {id, order_number}|null}]}`, the Customer-role accounts holding the phone, active first, then blocked; none → `[]`. `POST /admin/customers/{customer}/erase`, no body (Admin) → `204`; a Staff, deleted or unknown id → `404`; unfinished → `409 account_has_unfinished_orders` with `details`. Board order and board row gain `customer_erased` (`customer_erased_at` is not null); their recipient and address fields are then null.

- [ ] **Step 1: Write the failing tests.**
  1. `AdminCustomersApiTest::test_an_admin_finds_customers_by_phone`: an active and a blocked Customer and a Courier on one phone → two entries, active first, with `order_count` and `unfinished_order` (an order `new` → its id and number); another phone → `[]`; a malformed phone → `422`.
  2. `test_an_admin_erases_a_customer`: → `204`; the account is `deleted`, `deleted_by_user_id` the Admin; its token answers `401`.
  3. `test_erasure_is_refused_for_staff_deleted_unknown_and_unfinished`: a Courier id, an already deleted Customer, a random uuid → `404`; a Customer with an order `on_the_way` → `409` with `details.order_number`.
  4. `test_only_admins`: Operator, Manager, Customer tokens → `403` on both routes; a body field on erase → `422`.
  5. `OperationsBoardApiTest::test_an_erased_order_shows_no_customer`: erase a Customer with a completed order → `GET /operations/orders/{order}` `customer_erased` true, recipient `full_name` and `phone` null, address fields null; the board list row the same; searching the board by the old phone finds nothing.

- [ ] **Step 2: Run** `--filter='AdminCustomersApiTest|OperationsBoardApiTest'` — expect failures.

- [ ] **Step 3: Implement.**

- [ ] **Step 4: Run** the filter and `tests/Feature/Orders` — all pass.

- [ ] **Step 5: Docs, DL, checks, commit.** `DL-94` item 5:

```markdown
5. **The Admin's side.** A Customer who has no app any more calls support; the Admin finds the account by phone — active and blocked Customer accounts on that number, with their unfinished order if any — and erases it with the same action and the same refusal. Only an Admin erases; an Operator or Manager does not. Board orders say `customer_erased` and carry no recipient or address, so the panel can say why.
```

Commit `feat(accounts): the Admin finds and erases a Customer; erased orders on the board (DL-94 item 5)`.

---

### Task 6: The panel — documents

**Files:**
- Create: `frontend/lib/features/admin/domain/legal_documents.dart`, `frontend/lib/features/admin/data/legal_documents_api.dart`, `frontend/lib/features/admin/presentation/legal_documents_screen.dart`
- Modify: `frontend/lib/core/routing/app_paths.dart` (`adminLegalDocuments = '$admin/documents'`), `frontend/lib/features/admin/presentation/admin_paths.dart`, `admin_routes.dart`, the Admin navigation that lists `AppPaths.adminStaff`, the provider file where the other Admin APIs are provided, `frontend/lib/core/localization/l10n/app_uz.arb`, `app_ru.arb` (+ `flutter gen-l10n`)
- Modify docs: `DL-94` item 6
- Test: Create `frontend/test/features/admin/data/legal_documents_api_test.dart`, `frontend/test/features/admin/presentation/legal_documents_screen_test.dart`

**Interfaces:**
- Consumes: Task 1 Admin routes.
- Produces (Dart): `enum LegalDocumentKind { terms, privacy }`; `final class LegalDocumentEntry { LegalDocumentKind kind; AppLanguage language; String? body; DateTime? updatedAt; String? updatedByName; }`; `LegalDocumentsApi.list(): Future<List<LegalDocumentEntry>>`, `LegalDocumentsApi.publish(LegalDocumentKind kind, AppLanguage language, String? body): Future<LegalDocumentEntry>`.
- Screen: two sections, "Условия использования" and "Политика конфиденциальности", each with tabs O'zbekcha / Русский; a multiline field (key `legal-{kind}-{language}`), the format hint, "Опубликовано {date}, {name}" or "Не опубликовано", and "Опубликовать" (key `legal-save-{kind}-{language}`) enabled only when the text changed; saving an empty field asks "Снять документ с публикации?" first.
- Texts (ru / uz): `legalDocumentsTitle` "Документы" / "Hujjatlar"; `legalTerms` "Условия использования" / "Foydalanish shartlari"; `legalPrivacy` "Политика конфиденциальности" / "Maxfiylik siyosati"; `legalFormatHint` "## — заголовок, - — пункт списка, каждая строка — абзац" / "## — sarlavha, - — ro'yxat bandi, har bir qator — xatboshi"; `legalPublishedBy` "Опубликовано {date}, {name}" / "E'lon qilindi: {date}, {name}"; `legalNotPublished` "Не опубликовано — в приложении строки нет" / "E'lon qilinmagan — ilovada qator ko'rinmaydi"; `legalPublish` "Опубликовать" / "E'lon qilish"; `legalUnpublishConfirm` "Снять документ с публикации?" / "Hujjatni e'londan olib tashlaysizmi?"; `legalSaved` "Документ опубликован" / "Hujjat e'lon qilindi".

- [ ] **Step 1: Write the failing tests.**
  1. `legal_documents_api_test`: the list parses four entries (null body, `updated_by` null); `publish(terms, ru, 'x')` sends `PUT /admin/legal-documents/terms/ru` with `{"body":"x"}`; `publish(..., null)` sends `{"body":null}`.
  2. `legal_documents_screen_test`: loaded entries show "Не опубликовано …" and a published one "Опубликовано …"; editing the Russian terms enables its "Опубликовать" only; tapping publishes once and shows "Документ опубликован"; clearing a published text and tapping asks the unpublish question, "Отмена" sends nothing; the field shows `<script>` literally.

- [ ] **Step 2: Run** `flutter test test/features/admin` — expect failures.

- [ ] **Step 3: Implement**, following `staff_screen.dart` and `settings_screen.dart` for layout, loading and failure states.

- [ ] **Step 4: Run** the folder, `flutter analyze`, `dart format --set-exit-if-changed lib test` — clean.

- [ ] **Step 5: DL and commit.** `DL-94` item 6:

```markdown
6. **The panel's documents page.** Four texts — two documents in two languages — each with its own "Опубликовать", the publication date and author, and a confirmation before an empty save takes a document down. The format hint sits under each field.
```

Commit `feat(panel): the documents page (DL-94 item 6)`.

---

### Task 7: The panel — customers and erased orders

**Files:**
- Create: `frontend/lib/features/admin/domain/admin_customers.dart`, `frontend/lib/features/admin/data/admin_customers_api.dart`, `frontend/lib/features/admin/presentation/customers_screen.dart`
- Modify: `frontend/lib/core/routing/app_paths.dart` (`adminCustomers = '$admin/customers'`), `admin_paths.dart`, `admin_routes.dart`, the Admin navigation, the Admin API providers, `frontend/lib/features/operations/domain/board.dart` and `frontend/lib/features/operations/data/operations_api.dart` (recipient and address nullable; `customerErased`), the operations order screen and board row that show the recipient, `app_uz.arb`, `app_ru.arb` (+ `flutter gen-l10n`)
- Modify docs: `DL-94` item 7
- Test: Create `frontend/test/features/admin/data/admin_customers_api_test.dart`, `frontend/test/features/admin/presentation/customers_screen_test.dart`; Modify `frontend/test/features/operations/data/operations_api_test.dart`, `frontend/test/features/operations/presentation/order_actions_test.dart`, `board_screen_test.dart`

**Interfaces:**
- Consumes: Task 5 routes and `customer_erased`.
- Produces (Dart): `final class AdminCustomer { String id; String phone; String? fullName; String status; DateTime createdAt; DateTime? lastLoginAt; int orderCount; ({String id, int number})? unfinishedOrder; }`; `AdminCustomersApi.find(String phone): Future<List<AdminCustomer>>`, `AdminCustomersApi.erase(String id): Future<void>` (a `409 account_has_unfinished_orders` surfaces as a typed failure with the order number).
- Screen: a phone field (`+998` and nine digits, key `customers-phone`) and "Найти"; each result a card: name or "Без имени", phone, status, "Заказов: N", the unfinished order "Незавершённый заказ № N" when any; "Удалить аккаунт" (key `customer-erase-{id}`, disabled with an unfinished order) → a dialog with the drawing-36 lists and "Удалить" → on success the card is gone and "Аккаунт удалён" shows.
- Erased orders: where the operations screens show the recipient, an erased order shows "Данные покупателя удалены" and no call or address action.
- Texts (ru / uz): `customersTitle` "Покупатели" / "Xaridorlar"; `customersPhoneHint` "+998 и 9 цифр" / "+998 va 9 raqam"; `customersFind` "Найти" / "Topish"; `customersNone` "Покупателей с этим номером нет" / "Bu raqamli xaridor yo'q"; `customerNoName` "Без имени" / "Ismsiz"; `customerOrders` "Заказов: {count}" / "Buyurtmalar: {count}"; `customerUnfinished` "Незавершённый заказ № {number}" / "Tugallanmagan buyurtma № {number}"; `customerErase` "Удалить аккаунт" / "Akkauntni o'chirish"; `customerEraseTitle` "Удалить аккаунт покупателя?" / "Xaridor akkauntini o'chirasizmi?"; `customerEraseBody` "Сотрём имя, номер, адреса, избранное и корзину. История заказов останется без имени и телефона." / "Ism, raqam, manzillar, sevimlilar va savat o'chiriladi. Buyurtmalar tarixi ism va telefonsiz qoladi."; `customerEraseConfirm` "Удалить" / "O'chirish"; `customerErased` "Аккаунт удалён" / "Akkaunt o'chirildi"; `orderCustomerErased` "Данные покупателя удалены" / "Xaridor ma'lumotlari o'chirilgan".

- [ ] **Step 1: Write the failing tests.**
  1. `admin_customers_api_test`: `find('+998901234567')` sends `GET /admin/customers?phone=%2B998901234567` and parses both entries (an `unfinished_order` and a null one); `erase('id')` posts `/admin/customers/id/erase` with no body; a `409` becomes the typed failure carrying the number.
  2. `customers_screen_test`: a malformed phone shows the hint error and sends nothing; results show the cards; the erase button is disabled for a Customer with an unfinished order; erasing asks, sends once, removes the card and shows "Аккаунт удалён"; "Отмена" sends nothing.
  3. `operations_api_test`: a board order with `customer_erased: true` and null recipient and address parses with `customerErased` true.
  4. `order_actions_test` / `board_screen_test`: an erased order shows "Данные покупателя удалены", no phone and no address.

- [ ] **Step 2: Run** `flutter test test/features/admin test/features/operations` — expect failures.

- [ ] **Step 3: Implement.**

- [ ] **Step 4: Run** the two folders, `flutter analyze`, `dart format --set-exit-if-changed lib test` — clean.

- [ ] **Step 5: DL and commit.** `DL-94` item 7:

```markdown
7. **The panel's customers page.** The Admin types the number the caller rang from and sees the Customer accounts on it; "Удалить аккаунт" is disabled while an order is unfinished and asks with the same lists the Customer sees. An erased order on the board says "Данные покупателя удалены" instead of a name, phone and address.
```

Commit `feat(panel): find and erase a Customer; erased orders (DL-94 item 7)`.

---

## After the tasks

- Full backend suite through `test-runner`; full frontend suite; `git diff --check`.
- `branch-reviewer` (opus) on the whole branch against this plan and its Review Focus; one fix wave; scoped re-review.
- `/security-review` (the branch touches authentication codes, Customer data and public routes).
- PR, both required checks green, merge; then the 7b plan (Customer screens 32–36в and 02а), which also states the legal drafts of drawings 34–35 in Uzbek and Russian for the Owner's lawyer.
