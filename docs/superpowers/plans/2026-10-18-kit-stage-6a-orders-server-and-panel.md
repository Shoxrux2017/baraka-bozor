# Kit Stage 6a — Orders Server and Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The server and the web panel give the kit order screens (stage 6b) everything they need, as the Owner decided on 2026-10-18: the order list splits into current and past with an address and a picture per order; a past order can be repeated into the cart; the Customer rates a delivered order, a low rating reaches the Operator; the Customer calls the Courier while the order is on the way and calls support from any current order.

**Architecture:** Orders module. The Customer list gains a `state` filter and per-order address, picture, Courier phone and rating fields, computed in SQL like `item_count`; the detail gains line pictures, the Courier while on the way, the support phone and the rating. Reorder is a new action that copies an order's lines into the cart under the cart lock, idempotent through a stored answer on `idempotency_keys` (the Wave 2 risk row). Ratings live in a new `order_ratings` table; the Operator's attention list gains `low_rating`, cleared by a review action. Settings gain `support_phone`. Panel: the settings form, the attention label, and a rating section on the order screen.

**Tech Stack:** Laravel 13 + PostgreSQL 17 (Sanctum), Flutter 3.47.5 + Riverpod 3 + go_router, `flutter gen-l10n` (template `app_uz.arb`).

**Spec:** Claude Design project "BarakaBozor — стиль покупателя", file `kit/06-zakazy.dc.html`, approved by the Owner 2026-10-18 (screens 27–27б, 28–28а, 29–29к, 30–30б), and the Owner's answers of 2026-10-18 recorded in Task 1 as `DL-90`. Stage 6b (`2026-10-18-kit-stage-6b-customer-orders.md`, written after this plan merges) builds the Customer screens on this API.

## Global Constraints

- Branch `task/kit-6a-orders-server` from `main` c7135df. Never commit to `main`.
- Backend commands run in Docker from the repo root: `docker compose -f docker/compose.yaml exec -T app <cmd>` (`php artisan test --filter=…`, `vendor/bin/pint --test`, `vendor/bin/phpstan analyse`). Flutter: `G:/tools/flutter/bin/flutter` with `TEMP`/`TMP` = `G:\tools\tmp`, run from `frontend/`.
- Migrations: `backend/database/migrations/2026_10_18_00000N_<snake>.php`, N = 1…4 in task order, anonymous class, checks by `DB::statement` through a private `check()` helper as `2026_09_26_000004_create_product_images_table.php` does; uuid primary keys; `timestampTz`.
- Security (AGENTS.md §5): Customer routes in the `AuthServiceProvider::PROTECTED` + `RequireRole::of(Role::Customer)` group of `routes/api/v1/orders.php`; Operator/Admin routes in the `RequireRole::of(Role::Operator, Role::Admin)` group of `routes/api/v1/operations.php`; Admin settings stay Admin-only. Another Customer's order is the scope-safe `404 resource_not_found` (`CustomerOrders::own` + `ScopedLookup::firstOrNotFound`). The Courier's phone reaches a Customer only for that Customer's own order while its status is `on_the_way`. Nothing new is logged.
- Strict request shape (`docs/09` §4): unknown body fields are `422 validation_failed`; a route that takes no body refuses any field.
- Historical integrity (AGENTS.md §6): reorder reads an order and writes only the cart; a rating and its review never change an order's status, lines, totals or history.
- Phone pattern: `LoginCodePolicy::PHONE_PATTERN` (`/^\+998[0-9]{9}\z/`), reused, not copied.
- No new Composer or pub package; lockfiles unchanged. Generated l10n files are regenerated with `flutter gen-l10n`, never hand-edited. Texts: Uzbek (template, ASCII apostrophe as the ARB files use) and Russian.
- Each decision the agent takes is an item of `DL-91` in `docs/DECISIONS.md`, written in the same task as its code, and the affected `docs/01–09` section is updated in that task (AGENTS.md §3).
- New `docs/08` section: 33 `order_ratings`, appended after 32. New `docs/09` sections appended after 58 under a new heading `# Ratings`: 59 Order Rating, 60 Rating Review.
- Never delete, skip or weaken a test; a test whose flow changed is rewritten to assert the new flow.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

- Courier phone leak: the phone appears only while the order is `on_the_way`; `delivery_assigned`, `ready_for_delivery`, `completed`, `cancelled` and another Customer's order never carry it, in the list or the detail.
- Reorder retries: a replay of the same key answers the stored answer even after the cart changed or the product went off sale; two concurrent reorders of one order with different keys never put a product in the cart twice (the cart lock plus `BR-CART-002`).
- Rating window edges: exactly 7 days after `completed_at` is still open, a second later is `rating_window_closed`; a rating sent at 4 stars with reasons is `422`, never stored with reasons.
- Low-rating attention on a finished order: the item appears although the order is `completed` (other attention types only look at open orders) and disappears after a review; a 4–5 star rating never appears.
- Panel settings: clearing the support phone sends `null` (the Customer button hides), a malformed number is refused before sending, and an untouched form sends no `support_phone`.

---

### Task 1: The Owner's decisions; the list splits into current and past, with an address and pictures

**Files:**
- Modify: `backend/app/Modules/Orders/Http/Requests/ListCustomerOrdersRequest.php` (filter `state`), `backend/app/Modules/Orders/Http/Controllers/CustomerOrderController.php` (`index` applies the state and the picture; `show` and `resource()` load `items.product.image`), `backend/app/Modules/Orders/CustomerOrders.php` (`inState`, `withPictureKey`), `backend/app/Modules/Orders/Http/Resources/CustomerOrderSummaryResource.php` (`address`, `image_url`), `backend/app/Modules/Orders/Http/Resources/CustomerOrderResource.php` (`items[].image_url`; update the "Expects … loaded" docblock), `backend/app/Modules/Catalog/ProductImages.php` (`urlOfKey`)
- Modify docs: `docs/DECISIONS.md` (new `DL-90`, new `DL-91` item 1), `docs/09-api-contracts.md` §20, `tasks/REDESIGN_CUSTOMER.md` (stage 6 "In Progress (6a server and panel, 6b screens)")
- Test: Create `backend/tests/Feature/Orders/CustomerOrdersListApiTest.php`

**Interfaces:**
- Produces (API): `GET /customer/orders?state=current|past` — `current` = every status except `completed` and `cancelled`, `past` = those two, absent = all (as before); another value `422` on `state`. Each row adds `address: {street, house}` (the order's snapshot) and `image_url: string|null`. Each detail line adds `image_url: string|null`.
- Produces (PHP): `CustomerOrders::inState(Builder $orders, ?string $state): Builder`; `CustomerOrders::withPictureKey(Builder $orders): Builder` adds `picture_storage_key`; `ProductImages::urlOfKey(?string $storageKey): ?string`.

- [ ] **Step 1: Record the Owner's decisions.** Append to `docs/DECISIONS.md` after `DL-89`:

```markdown
## DL-90 — Orders, kit stage 6 (2026-10-18, Owner)

Answers to the questions of kit stage 6 (`kit/06-zakazy.dc.html`, approved the same day).

1. **Rating.** After delivery the Customer rates the whole order — freshness, weight and delivery together, not the Courier alone — with 1 to 5 stars and an optional comment. At 1 to 3 stars the Customer may also pick reasons: "Несвежее", "Не тот вес", "Опоздал", "Невежливо". Operators and Admins see the rating on the order in the panel. A rating of 1 to 3 enters the Operator's attention list, and the Operator calls the Customer. Tips wait for card payments (Wave 5).
2. **Calls.** While a Courier takes the order to the Customer, the order shows "Позвонить курьеру" with the Courier's number; once the order is delivered the number is gone. Every current order shows "Позвонить в поддержку" with the company's number, which the Admin sets in the settings; without a number the button is hidden. Masked numbers through a telephony provider are for later.
3. **No notifications list.** The kit's notifications screen is not built: the order page shows the status, and Wave 4's pushes notify. While a Shopper's question waits for the Customer, the home shows "Сборщик ждёт вашего ответа" with "Ответить".
4. **No chat.** Interview 7.3 stands; the kit's chat screen is dropped.
```

and start `DL-91` (agent) with item 1:

```markdown
## DL-91 — Orders server and panel, kit stage 6a (2026-10-18, agent)

1. **The list splits and shows where and what.** `GET /customer/orders` takes `state=current|past`: past is `completed` and `cancelled`, current every other status, so each tab pages on its own. A row carries the address snapshot's street and house and a picture: the current picture of the earliest line (by creation, then id) whose product has one, `null` when none has. Detail lines carry their product's current picture too. A picture is decoration, not history: it is the product's picture now, never a snapshot, and changes when the Admin replaces it.
```

- [ ] **Step 2: Write the failing tests** in `CustomerOrdersListApiTest`:
  1. `test_state_current_and_past_split_the_list`: orders in `new`, `on_the_way`, `completed`, `cancelled` for one Customer; `?state=current` → the first two (newest first), `?state=past` → the last two, no `state` → all four; `?state=old` → `422`, `errors.state` present.
  2. `test_a_row_carries_the_address_street_and_house`: row `address` equals `['street' => <street_snapshot>, 'house' => <house_snapshot>]` and has exactly those two keys.
  3. `test_a_row_pictures_the_earliest_line_with_a_picture`: lines A (no picture, oldest), B (picture `b.webp`), C (picture `c.webp`, newest) → `image_url` ends with `b.webp`; an order whose lines have no picture → `null`.
  4. `test_detail_lines_carry_their_product_picture`: a line whose product has a picture → `items.0.image_url` ends with its key; one without → `null`.
  5. `test_another_customers_orders_are_not_listed`: Customer B's order is absent from A's `current` and `past` pages.

- [ ] **Step 3: Run** `docker compose -f docker/compose.yaml exec -T app php artisan test --filter=CustomerOrdersListApiTest` — expect failures on `state`, `address`, `image_url`.

- [ ] **Step 4: Implement.** `state` rule `['sometimes', 'string', Rule::in(['current', 'past'])]` in `filters()` with an accessor `state(): ?string`. `withPictureKey` adds a correlated subquery: `product_images.storage_key` joined on `order_items.product_id`, `where order_items.order_id = orders.id`, `order by order_items.created_at, order_items.id limit 1`. `urlOfKey` returns `Storage::disk('public')->url($key)` or `null`; `url(?ProductImage)` delegates to it.

- [ ] **Step 5: Run** the filter again and the whole `tests/Feature/Orders` folder — all pass.

- [ ] **Step 6: Update `docs/09` §20** (the `state` filter, the two row fields, `items[].image_url`) and `tasks/REDESIGN_CUSTOMER.md`; `pint --test`, `phpstan analyse`; commit `feat(orders): current and past lists with an address and a picture (DL-90, DL-91)`.

---

### Task 2: The support phone and the Courier on the way

**Files:**
- Create: `backend/database/migrations/2026_10_18_000001_add_support_phone_to_business_settings.php`
- Modify: `backend/app/Models/BusinessSettings.php`, `backend/app/Modules/Settings/Http/Requests/UpdateBusinessSettingsRequest.php`, `backend/app/Modules/Settings/Http/Resources/BusinessSettingsResource.php`, `backend/app/Modules/Orders/Http/Controllers/CustomerOrderController.php` (load `currentCourierAssignment.courier`; the list eager-loads it too), `backend/app/Modules/Orders/Http/Resources/CustomerOrderResource.php` (`courier`, `support_phone`), `backend/app/Modules/Orders/Http/Resources/CustomerOrderSummaryResource.php` (`courier_phone`)
- Create: `backend/app/Modules/Orders/CourierContact.php`
- Modify docs: `docs/DECISIONS.md` `DL-91` item 2, `docs/08-database.md` §11, `docs/09-api-contracts.md` §20 and §44, `docs/03-features.md` (Customer order page: calls)
- Test: Create `backend/tests/Feature/Orders/CustomerOrderContactsApiTest.php`; Modify `backend/tests/Feature/Settings/BusinessSettingsApiTest.php`

**Interfaces:**
- Produces (API): Admin `GET|PATCH /admin/settings/business` gains `support_phone: string|null` (`+998` and nine digits). Customer detail gains `courier: {first_name: string|null, phone: string}|null` and `support_phone: string|null`; list rows gain `courier_phone: string|null`.
- Produces (PHP): `CourierContact::of(Order $order): ?array{first_name: string|null, phone: string}` — non-null only when `$order->status === OrderStatus::OnTheWay` and the current Courier assignment is loaded with its courier; `first_name` is the first whitespace-separated word of `full_name`, `null` when the name is empty.

- [ ] **Step 1: Write the failing tests.**
  1. `BusinessSettingsApiTest`: `PATCH {"support_phone":"+998712000000"}` → `200`, `data.support_phone` equal; `"998712000000"`, `"+99871200000"`, `"+9987120000000"` → `422` on `support_phone`; `{"support_phone":null}` → `200`, `null`; a migration check refuses a raw insert of `'12345'` (`business_settings_support_phone_check`).
  2. `CustomerOrderContactsApiTest::test_the_courier_is_shown_only_while_on_the_way`: one order per status `delivery_assigned`, `on_the_way`, `completed` with a live or ended Courier assignment (Courier `full_name` "Азиз Каримов", phone `+998901112233`); detail `courier` is `{"first_name":"Азиз","phone":"+998901112233"}` only for `on_the_way`, `null` for the others; list `courier_phone` likewise.
  3. `test_a_courier_without_a_name_is_shown_by_phone`: `full_name` null → `first_name` null, phone present.
  4. `test_support_phone_follows_the_setting`: setting unset → `support_phone` null; set → equal, for an order in any status.
  5. `test_another_customers_order_reveals_no_courier`: Customer B reading A's `on_the_way` order → `404 resource_not_found`.

- [ ] **Step 2: Run** `--filter='BusinessSettingsApiTest|CustomerOrderContactsApiTest'` — expect failures.

- [ ] **Step 3: Implement.** Migration adds `support_phone varchar(13) null` with check `support_phone is null or support_phone ~ '^\+998[0-9]{9}$'`. Request rule `['sometimes', 'nullable', 'string', 'regex:'.LoginCodePolicy::PHONE_PATTERN]`. `CustomerOrderResource` reads the setting once per request through `BusinessSettings::current()`.

- [ ] **Step 4: Run** the filter and `tests/Feature/Orders`, `tests/Feature/Settings` — all pass.

- [ ] **Step 5: Docs, DL, checks, commit.** `DL-91` item 2:

```markdown
2. **Calls.** The Customer sees the Courier — the first word of the name and the phone — on the list row and the order only while the order is `on_the_way`, the status the Courier's start sets and delivery or failure ends; the Courier's own call already shows the number, so no wider exposure follows. The support phone is a business setting, `+998` and nine digits like every phone here, unset by default; the Customer's order answers it whatever the status, and the client shows it on current orders.
```

`pint --test`, `phpstan analyse`; commit `feat(orders): support phone and the courier on the way (DL-90 item 2)`.

---

### Task 3: Reorder with a stored answer

**Files:**
- Create: `backend/database/migrations/2026_10_18_000002_add_response_to_idempotency_keys.php`, `backend/app/Modules/Orders/Actions/ReorderOrder.php`, `backend/app/Modules/Orders/Http/Controllers/ReorderController.php`
- Modify: `backend/app/Support/Idempotency/IdempotencyStore.php` (`runAnswer`, `Replay` carries the answer), `backend/routes/api/v1/orders.php`
- Modify docs: `DL-91` item 3, `docs/08-database.md` §27, `docs/09-api-contracts.md` §26 and §48, `docs/04-user-flows.md` §33, `docs/05-business-rules.md` §19 (`BR-HIST-005`), `docs/06-roadmap.md` (Wave 4 row and its paragraph: reorder delivered in kit stage 6), `tasks/WAVE_2.md:87` and `tasks/WAVE_3.md:412` (the reorder row "Closed by `DL-91` item 3")
- Test: Create `backend/tests/Feature/Orders/ReorderApiTest.php`; Modify `backend/tests/Feature/Support/IdempotencyStoreTest.php`

**Interfaces:**
- Produces (API): `POST /customer/orders/{order}/reorder` with `Idempotency-Key`, no body → `200` `{"data":{"added_items":[{product_id,name_uz,name_ru,quantity}],"skipped_existing_items":[{product_id,name_uz,name_ru}],"unavailable_items":[{product_id,name_uz,name_ru}],"cart_full_items":[{product_id,name_uz,name_ru}]}}`. Names are the order line's snapshots. Never creates an order.
- Produces (PHP): `IdempotencyStore::runAnswer(string $actorId, string $operation, string $key, string $requestHash, Closure $perform): array` — `$perform(): array` runs in the same transaction that completes the key with `response` = the answer; a replay returns the stored `response`. `ReorderOrder::reorder(User $customer, string $orderId, string $key): array`.

- [ ] **Step 1: Write the failing tests.**
  1. `IdempotencyStoreTest::test_an_answer_is_stored_and_replayed`: `runAnswer` with `$perform` returning `['n' => 1]` and counting calls; a second call with the same key and hash returns `['n' => 1]` without calling `$perform`; the row is `completed` with `response` and null `resource_id`; another hash → `409 idempotency_key_reused`; a throwing `$perform` leaves no row.
  2. `ReorderApiTest::test_reorder_adds_missing_lines_and_reports_the_rest`: completed order with lines tomato 2 kg (note "твёрдые", `contact_before_substitution`), bread 3 pcs (already in the cart at 1), apple (product now archived), cucumber (removed with `customer_removed`) → `added_items` = tomato with `"quantity":"2.000"`, `skipped_existing_items` = bread, `unavailable_items` = apple, cucumber in no list; the cart holds tomato 2 kg with the note and the rule, bread still 1.
  3. `test_a_product_whose_unit_changed_is_unavailable`: line `kg`, product now `piece` → in `unavailable_items`, not added.
  4. `test_a_full_cart_reports_the_rest`: cart at 99 lines, order with 3 addable lines → first in line order added, the other two in `cart_full_items`.
  5. `test_a_replay_answers_the_first_answer`: reorder, then archive tomato and empty the cart, replay the same key → the same body; the cart stays empty.
  6. `test_lines_removed_for_other_reasons_are_reordered`: a line removed as `unavailable` at the market is added.
  7. `test_reorder_needs_a_key_and_an_own_order`: no header → `400 idempotency_key_required`; Customer B → `404`; a body field → `422`; a Shopper token → `403`.

- [ ] **Step 2: Run** `--filter='ReorderApiTest|IdempotencyStoreTest'` — expect failures.

- [ ] **Step 3: Implement.** Migration adds `response jsonb null` and replaces `idempotency_keys_completed_check` so a completed row names a resource or holds a response (keep every other condition of the old check). `ReorderOrder` loads the own order (`404` otherwise), then under `CustomerCart::lock` walks the lines in line order, skipping `removed_reason_code = customer_removed`; for each: not visible through `CustomerCatalogListing::visibleProducts()` or `unit_code` ≠ `unit_code_snapshot` → unavailable; in the cart → skipped; cart at `ChangeCart::MAX_LINES` → cart full; else a `CartItem` with `ordered_quantity` parsed by `QuantityPolicy::parse`, `customer_note_snapshot`, `substitution_policy_snapshot`. Operation name `orders.reorder`; hash over the route parameter only.

- [ ] **Step 4: Run** the filter and `tests/Feature/Orders`, `tests/Feature/Support` — all pass.

- [ ] **Step 5: Docs, DL, checks, commit.** `DL-91` item 3:

```markdown
3. **Reorder.** It copies every line of the order except those the Customer removed in an edit, in line order, with the ordered quantity, note and rule, at today's prices; a product the Customer may no longer see, or whose unit changed since, is unavailable; a product already in the cart is skipped and keeps its line; lines past the cart's 100 are reported as not added. Any own order may be repeated, whatever its status. The answer is stored on the idempotency key (`response`), so a replay answers what the first call did; this closes the Wave 2 risk row on reorder's answer.
```

`BR-HIST-005` in `docs/05`: "A product already in the cart keeps its line; one that would exceed the cart's 100 lines is reported, not added." `pint --test`, `phpstan analyse`; commit `feat(orders): reorder into the cart with a stored answer (DL-91 item 3)`.

---

### Task 4: The Customer rates a delivered order

**Files:**
- Create: `backend/database/migrations/2026_10_18_000003_create_order_ratings_table.php`, `backend/app/Models/OrderRating.php`, `backend/app/Models/Enums/RatingReason.php`, `backend/database/factories/OrderRatingFactory.php`, `backend/app/Modules/Orders/Actions/RateOrder.php`, `backend/app/Modules/Orders/OrderRatings.php`, `backend/app/Modules/Orders/Http/Requests/RateOrderRequest.php`
- Modify: `backend/app/Models/Order.php` (`rating(): HasOne`), `backend/app/Modules/Orders/Http/Controllers/CustomerOrderController.php` (`rate`; load `rating` in `show`/`resource`, the list), `CustomerOrderResource` (`rating`, `can_rate`), `CustomerOrderSummaryResource` (`rating_stars`, `can_rate`), `backend/routes/api/v1/orders.php`
- Modify docs: `DL-91` item 4, `docs/08-database.md` §33 (new), §2 table list, `docs/09-api-contracts.md` §20, §49, §59 (new, under `# Ratings`), the error-code section for orders (§54), `docs/03-features.md` §24, `docs/04-user-flows.md` (new §36 Rating, appended after §35), `docs/05-business-rules.md` (new `# 23. Ratings`, appended after §22, with `BR-RATE-001`…`003`)
- Test: Create `backend/tests/Feature/Orders/OrderRatingApiTest.php`, `backend/tests/Feature/Schema/OrderRatingsTableTest.php`

**Interfaces:**
- Produces (DB): `order_ratings(id uuid, order_id uuid unique → orders restrict, customer_id uuid → users restrict, stars smallint check 1..5, reasons jsonb not null default '[]' (array), comment varchar(500) null, reviewed_by_user_id uuid null → users restrict, reviewed_at timestamptz null, timestamps)`; check `(reviewed_by_user_id is null) = (reviewed_at is null)`; check `stars <= 3 or reasons = '[]'::jsonb`.
- Produces (PHP): `enum RatingReason: string { NotFresh = 'not_fresh'; WrongWeight = 'wrong_weight'; Late = 'late'; Rude = 'rude'; }`; `OrderRatings::WINDOW_DAYS = 7`; `OrderRatings::canRate(Order $order, CarbonInterface $now): bool` (completed, no rating, `$now <= completed_at + 7 days`); `OrderRatings::LOW_MAX_STARS = 3`; `RateOrder::rate(User $customer, string $orderId, int $stars, list<string> $reasons, ?string $comment): array{order: Order, created: bool}`.
- Produces (API): `POST /customer/orders/{order}/rating` `{"stars":2,"reasons":["not_fresh"],"comment":"…"}` (`reasons` and `comment` optional) → `201` with the order (`CustomerOrderResource`); the identical body again → `200` with the order (natural repeat); a different body on a rated order → `409 order_already_rated`; not `completed` → `409 order_not_rateable`; past the window → `409 rating_window_closed`. Detail gains `rating: {stars, reasons, comment, created_at}|null` and `can_rate`; list rows gain `rating_stars: int|null` and `can_rate`.

- [ ] **Step 1: Write the failing tests.**
  1. `OrderRatingsTableTest`: stars 0 and 6 refused (`order_ratings_stars_check`); stars 4 with `["late"]` refused; a second rating for one order refused (unique); `reviewed_at` without `reviewed_by_user_id` refused.
  2. `OrderRatingApiTest::test_the_customer_rates_a_delivered_order`: completed order, `{"stars":2,"reasons":["not_fresh","late"],"comment":"  Помидоры мятые  "}` → `201`, `data.rating` = `{stars:2, reasons:["not_fresh","late"], comment:"Помидоры мятые", created_at:<iso>}`, `data.can_rate` false; the list row `rating_stars` 2, `can_rate` false.
  3. `test_an_identical_repeat_is_answered_and_a_different_one_refused`: same body → `200`, one row; `{"stars":5}` → `409 order_already_rated`.
  4. `test_only_a_completed_order_within_seven_days_is_rateable`: `on_the_way` → `409 order_not_rateable`, `cancelled` → same; completed with `completed_at` = now − 7 days exactly → `201`; another at now − 7 days − 1 second → `409 rating_window_closed`; its `can_rate` false.
  5. `test_the_body_is_validated`: stars `0`, `6`, `"3"` → `422` on `stars`; stars 4 with any reason → `422` on `reasons`; reason `"bad"` or a repeated reason → `422`; comment of 501 characters → `422`; a whitespace-only comment stores `null`; an unknown field → `422`.
  6. `test_another_customer_cannot_rate`: Customer B → `404 resource_not_found`, no row.

- [ ] **Step 2: Run** `--filter='OrderRatingApiTest|OrderRatingsTableTest'` — expect failures.

- [ ] **Step 3: Implement.** `RateOrder` locks the order row (`lockForUpdate`) in a transaction, decides in this order: not completed → `order_not_rateable`; rated → identical (stars, reasons as a set, trimmed comment) → `created: false`, else `order_already_rated`; past the window → `rating_window_closed`; then inserts. Route `POST orders/{order}/rating`, `throttle:30,1`, no `Idempotency-Key` (the identical repeat is the retry, `docs/09` §49).

- [ ] **Step 4: Run** the filter and `tests/Feature/Orders`, `tests/Feature/Schema` — all pass.

- [ ] **Step 5: Docs, DL, checks, commit.** `DL-91` item 4:

```markdown
4. **The rating.** One per order, for a `completed` order, within seven days of its completion; the window keeps a rating about this delivery, not a later complaint. Reasons are allowed only at 1 to 3 stars, each at most once; the comment is trimmed, at most 500 characters, and an empty one is none. A retry is the identical body, answered `200` with the order like any natural repeat (`docs/09` section 49), so the call needs no idempotency key; a different body on a rated order is `409 order_already_rated`. A rating never changes the order: its status, lines, totals and history stay.
```

`BR-RATE-001` one rating per completed order within seven days; `BR-RATE-002` reasons only at 1–3 stars; `BR-RATE-003` a rating of 1–3 waits for an Operator's review. `pint --test`, `phpstan analyse`; commit `feat(orders): the customer rates a delivered order (DL-90 item 1, DL-91 item 4)`.

---

### Task 5: A low rating reaches the Operator

**Files:**
- Create: `backend/app/Modules/Orders/Actions/ReviewOrderRating.php`
- Modify: `backend/app/Modules/Orders/Operations/Attention.php` (`LOW_RATING`, `narrow`, `items`, `TYPES`, the docblock list), `backend/app/Modules/Orders/Http/Controllers/OperationsOrderController.php` (`reviewRating`; `show` loads `rating.reviewedBy`), `backend/app/Modules/Orders/Http/Resources/BoardOrderResource.php` (`rating`), `backend/app/Models/OrderRating.php` (`reviewedBy(): BelongsTo`), `backend/routes/api/v1/operations.php`
- Modify docs: `DL-91` item 5, `docs/09-api-contracts.md` §38 (attention types), §39, §60 (new), `docs/03-features.md` §22 (attention list), `docs/04-user-flows.md` §36 (the Operator's call)
- Test: Modify `backend/tests/Feature/Orders/OperationsBoardApiTest.php`; Create `backend/tests/Feature/Orders/RatingReviewApiTest.php`

**Interfaces:**
- Produces (API): attention item type `low_rating` — `since` = the rating's `created_at`, `shopper` and `courier` the order's last assignments' people or `null` as the item shape allows; `GET /operations/orders?attention=low_rating`. `POST /operations/orders/{order}/rating/review`, no body → `200` with the board order (`BoardOrderResource`); already reviewed → `200`, unchanged reviewer (natural repeat); no rating → `409 order_not_rated`; unknown order → `404`. `BoardOrderResource` gains `rating: {stars, reasons, comment, created_at, reviewed_by: {id, full_name}|null, reviewed_at}|null`.
- Produces (PHP): `Attention::LOW_RATING = 'low_rating'`; `ReviewOrderRating::review(User $staff, string $orderId): Order`.

- [ ] **Step 1: Write the failing tests.**
  1. `OperationsBoardApiTest::test_a_low_rating_enters_the_attention_list_until_reviewed`: completed orders rated 2 (unreviewed), 3 (reviewed), 5 → `/operations/attention` holds one `low_rating` item for the first, `since` its rating's `created_at`; the summary's attention count includes it; `?attention=low_rating` lists only that order.
  2. `RatingReviewApiTest::test_an_operator_reviews_a_rating`: Operator → `200`, `data.rating.reviewed_by.id` = the Operator, `reviewed_at` set; the attention item is gone; a second call by an Admin → `200`, reviewer still the Operator.
  3. `test_reviewing_an_unrated_order_is_refused`: → `409 order_not_rated`; an unknown id → `404`.
  4. `test_only_operators_and_admins_review`: a Customer, Shopper, Courier or Manager token → `403`; a body field → `422`.
  5. `test_the_board_order_shows_the_rating`: `GET /operations/orders/{order}` → `data.rating` with stars, reasons, comment, `reviewed_by` null.

- [ ] **Step 2: Run** `--filter='OperationsBoardApiTest|RatingReviewApiTest'` — expect failures.

- [ ] **Step 3: Implement.** `narrow(LOW_RATING)` does not use `open()`: `whereHas('rating', stars <= OrderRatings::LOW_MAX_STARS and reviewed_at is null)`. `ReviewOrderRating` locks the rating row, sets `reviewed_by_user_id` and `reviewed_at` once.

- [ ] **Step 4: Run** the filter and `tests/Feature/Orders` — all pass.

- [ ] **Step 5: Docs, DL, checks, commit.** `DL-91` item 5:

```markdown
5. **The Operator's side of a low rating.** A rating of 1 to 3 is an attention item, `low_rating`, since the rating was given, whatever the order's status — the only type that looks at finished orders. It stays until an Operator or Admin marks the rating reviewed after calling the Customer; the review records who and when, once, and a repeat answers the same. A Manager does not review (read-only scope). The board order shows the rating with its review.
```

`pint --test`, `phpstan analyse`; commit `feat(operations): low ratings in the attention list and their review (DL-90 item 1, DL-91 item 5)`.

---

### Task 6: The panel — support phone, low-rating attention, the rating on the order

**Files:**
- Modify: `frontend/lib/features/admin/domain/business_settings.dart` (`supportPhone` on `BusinessSettings` and `BusinessSettingsDraft`), `frontend/lib/features/admin/data/settings_dto.dart`, `frontend/lib/features/admin/presentation/settings_form_rules.dart` (`supportPhone` validator), `frontend/lib/features/admin/presentation/settings_screen.dart` (field `field-support_phone`), `frontend/lib/features/operations/domain/board.dart` (`AttentionType.lowRating`; `BoardOrder.rating`; `OrderRating` value class), `frontend/lib/features/operations/data/operations_api.dart` (parse `low_rating` and `rating`; `reviewRating(String orderId)`), `frontend/lib/features/operations/presentation/board_screen.dart` (`_describe`), `frontend/lib/features/operations/presentation/order_detail_screen.dart` (rating section), the operations controller that already runs order actions (add `reviewRating`), `frontend/lib/core/localization/l10n/app_uz.arb`, `app_ru.arb` (+ `flutter gen-l10n`)
- Modify docs: `DL-91` item 6
- Test: Modify `frontend/test/features/admin/data/settings_dto_test.dart`, `settings_api_test.dart`, `frontend/test/features/admin/presentation/settings_form_rules_test.dart`, `settings_screen_test.dart`, `frontend/test/features/operations/data/operations_api_test.dart`, `frontend/test/features/operations/presentation/board_screen_test.dart`, `order_actions_test.dart`

**Interfaces:**
- Consumes: Task 2 `support_phone`; Task 5 `low_rating`, `rating`, `POST /operations/orders/{order}/rating/review`.
- Produces (Dart): `final class OrderRating { int stars; List<RatingReason> reasons; String? comment; DateTime createdAt; String? reviewedByName; DateTime? reviewedAt; }`, `enum RatingReason { notFresh, wrongWeight, late, rude }` (unknown codes skipped), `AttentionType.lowRating`.
- Texts (ru / uz): `settingsSupportPhone` "Телефон поддержки" / "Qo'llab-quvvatlash telefoni"; `settingsSupportPhoneHint` "+998 и 9 цифр; пусто — кнопку не показываем" / "+998 va 9 raqam; bo'sh bo'lsa tugma ko'rinmaydi"; `attentionLowRating` "Низкая оценка" / "Past baho"; `ratingTitle` "Оценка клиента" / "Mijoz bahosi"; `ratingReasonNotFresh` "Несвежее" / "Yangi emas"; `ratingReasonWrongWeight` "Не тот вес" / "Og'irligi noto'g'ri"; `ratingReasonLate` "Опоздал" / "Kechikdi"; `ratingReasonRude` "Невежливо" / "Qo'pol"; `ratingReview` "Связались с клиентом" / "Mijoz bilan bog'lanildi"; `ratingReviewed` "Разобрано: {name}, {time}" / "Ko'rib chiqildi: {name}, {time}".

- [ ] **Step 1: Write the failing tests.**
  1. `settings_dto_test`: `support_phone` parses to `supportPhone`, `null` stays null; a draft that changed only the phone serialises `{"support_phone":"+998712000000"}`, a cleared one `{"support_phone":null}`, an untouched one has no `support_phone` key.
  2. `settings_form_rules_test`: `supportPhone('')` null (allowed), `'+998712000000'` null, `'998712000000'` and `'+99871200000'` an error text.
  3. `settings_screen_test`: the field `field-support_phone` shows the loaded phone; saving with a malformed one shows the error and sends nothing.
  4. `operations_api_test`: `low_rating` parses to `AttentionType.lowRating`; a board order with `rating` parses stars, reasons (an unknown reason skipped), comment, reviewer; `reviewRating('id')` posts to `/operations/orders/id/rating/review` with no body.
  5. `board_screen_test`: a `low_rating` item reads "Низкая оценка".
  6. `order_actions_test`: an order with an unreviewed rating 2 shows "Оценка клиента", two filled stars, "Несвежее", the comment and "Связались с клиентом"; tapping it calls `reviewRating` once and the screen then shows "Разобрано: …"; a reviewed rating shows no button; an order without a rating shows no section.

- [ ] **Step 2: Run** `flutter test test/features/admin test/features/operations` — expect failures.

- [ ] **Step 3: Implement** in the files above, matching the existing section and attention patterns; the stars are `Icons.star` / `Icons.star_border` in `KitColors`' amber if the panel already uses `KitColors`, else the theme's primary.

- [ ] **Step 4: Run** the two folders, then `flutter analyze` and `dart format --set-exit-if-changed lib test` — clean.

- [ ] **Step 5: DL and commit.** `DL-91` item 6:

```markdown
6. **The panel.** The settings form gains the support phone, `+998` and nine digits or empty; the attention list names `low_rating` "Низкая оценка"; the order screen shows the Customer's rating — stars, reasons, comment — with "Связались с клиентом" until it is reviewed, then who reviewed it and when.
```

Commit `feat(panel): support phone, low-rating attention and the rating on the order (DL-91 item 6)`.

---

## After the tasks

- Full backend suite through `test-runner`; full frontend suite; `git diff --check`.
- `branch-reviewer` (opus) on the whole branch against this plan and its Review Focus; one fix wave; scoped re-review.
- `/security-review` (the branch touches Customer data and a staff phone).
- PR, both required checks green, merge; then the 6b plan.
