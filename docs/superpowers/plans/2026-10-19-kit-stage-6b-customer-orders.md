# Kit Stage 6b — Customer Order Screens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Customer's orders look and work like the approved drawings 27–30б of `kit/06-zakazy.dc.html`: current and past tabs with kit cards, a home banner while a Shopper's question waits, an order page per status with calls, kit question cards, cancel sheets, repeat into the cart, a rating screen, and the kit editor.

**Architecture:** Client only, on the stage 6a API (`docs/09` §20, §23, §26, §59). The data layer gains the 6a fields, a tab filter, reorder, rating and the pending questions. The orders feature's presentation is rebuilt from focused kit widgets: list cards, the order page sections, question cards, sheets. The editor keeps its draft logic (`_LineDraft`, `_changesNothing`, `_save`) and changes only its look. Shared cart widgets are reused (`CartLineStepper`, `SummaryAmountRow`, `EstimateNote`, `showQuantitySheet`, `CardQuantity`, `LineOptionsFields`).

**Tech Stack:** Flutter 3.47.5, Riverpod 3, go_router, `flutter gen-l10n` (template `app_uz.arb`), Montserrat, `KitColors`, `url_launcher` through `phoneCallsProvider`.

**Spec:** `kit/06-zakazy.dc.html` in the Claude Design project "BarakaBozor — стиль покупателя", approved by the Owner on 2026-10-18 ("ДА"), and the Owner's answers recorded as `DL-90`. Screens: 27 текущие, 27а пусто, 27б баннер на главной, 28 прошлые, 28а повторить, 29 принят, 29а вопрос о цене, 29б другие вопросы, 29в отменить, 29г попросить отменить, 29д запрос отправлен, 29е в пути, 29ж доставлен, 29з отменён, 29и изменить, 29к добавить товар, 30 оценка 5★, 30а оценка 1–3, 30б оценка отправлена. The agent's rules are `DL-92`, one item per task.

## Global Constraints

- Branch `task/kit-6b-customer-orders` from `main` `e37a985`. Never commit to `main`.
- **Client only.** Nothing under `backend/` changes. No new package; `pubspec.lock` unchanged.
- **Flutter.** `G:/tools/flutter/bin/flutter` with `TEMP`/`TMP` = `G:\tools\tmp`, run from `frontend/`. Focused tests per task; `flutter analyze`; `dart format --set-exit-if-changed lib test`. The full suite runs with `--concurrency=2`.
- **Kit look.** Colours only from `KitColors`; Montserrat; sizes on a 375-wide screen: side padding 20; cards white, radius 16, shadow `0x14000000` blur 12 offset 0/2; product pictures `ProductImage` on `card` with radius 14 (56 in lists, 48 in the order's lines); buttons 54 high radius 14 (`primary` filled, or outlined); section headings 16 / w700; status chips 11 / w600 on a wash with radius 8. App bars are `kitAppBar`.
- **Money.** Every amount shown is the server's. The client adds nothing up. The only preview is `EstimatePreview.lineUzs` on an editor line (Task 7), as the product screen does. Estimate amounts read `cartLineEstimate(...)` ("≈ …"); a `final` total has no "≈".
- **Dates.** Instants are Tashkent wall-clock (`TashkentTime`); "today" comes from `clockProvider` (Task 1), never `DateTime.now()` in a widget.
- **Calls.** Every call goes through `phoneCallsProvider`; when it answers `false`, a `SnackBar` shows `callFailed(formatPhone(phone))`.
- **Keys kept.** These keys stay on their new widgets so behaviour tests carry over: `orders-empty`, `orders-list`, `order-<id>`, `order-waiting-<id>`, `order`, `order-status`, `order-edit`, `order-cancel`, `order-request-cancel`, `order-cancel-needs-reason`, `order-cancellation-request`, `order-cancellation-requested`, `order-cancellation-request-<status>`, `order-payment`, `order-line-<id>`, `order-line-replacement-<id>`, `question-<id>`, `question-expired-<lineId>`, `question-drops-replacement-<id>`, `approve-<id>`, `reject-<id>`, `decide-again-<id>`, `decision-unanswered-<id>`, `cancel-reason`, `cancel-keep`, `cancel-confirm`, `order-editor`, `edit-line-<key>`, `edit-adds-<key>`, `edit-unavailable-<key>`, `edit-remove-<key>`, `edit-add-product`, `edit-full`, `edit-delivery-wish`, `edit-none-left`, `edit-save`, `edit-closed`, `edit-back-to-order`, `pick-search`, `pick-search-clear`, `pick-category`, `pick-categories`, `pick-category-<id>`.
- **Large text.** Every new or rebuilt screen and sheet has a widget test at 320×640 with `textScaleFactorTestValue = 2`, in `uz` and `ru`, with `tester.takeException()` null.
- **Localization.** Edit `app_uz.arb` (template, with `@` metadata for placeholders) and `app_ru.arb` only, then `flutter gen-l10n`; generated files are never hand-edited. Texts exactly as each task lists them. Uzbek uses the ASCII apostrophe, as the files do.
- **Tests.** Never delete, skip or weaken a test. A test whose flow changed is rewritten to assert the new flow; each task names the flows that change.
- **Decisions.** Each task writes its `DL-92` item in `docs/DECISIONS.md` with its code (AGENTS.md §3).
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **A reorder whose answer is lost, or two quick taps on "Повторить".** One call goes; the retry sends the same `Idempotency-Key`; nothing is added twice. Task 2 tests: "two quick taps repeat once", "a lost answer is retried under the same key".
2. **The last question answered.** The home banner and the card's question strip go at once, not after the next 30-second refresh. Task 2 test: "an answer hides the banner without waiting".
3. **Stars lowered, then raised.** Reasons picked at 2★ are not sent at 5★; two quick taps on "Отправить" send once. Task 6 tests: "raising to 4 drops the reasons", "two quick taps rate once".
4. **The Courier's phone.** "Позвонить курьеру" shows only when the server sends the phone; a phone without a dialer shows the number. Task 3 test: "the courier button follows courier_phone"; Task 4 test: "a failed dial shows the number".
5. **An order at the extremes.** Twelve lines, three open questions, a 60-character address, a 160-character wish, 99 999 999 сум, at 320×640 with text ×2: nothing overflows. Task 4 test "the order page holds at the extremes", Task 5 test "the question cards hold at the extremes".

---

### Task 1: The 6a fields, the tabs, reorder, rating, pending questions, dates

**Files:**
- Create: `frontend/lib/core/platform/clock.dart`, `frontend/lib/core/formatting/order_dates.dart`
- Modify: `frontend/lib/core/formatting/tashkent_time.dart` (`time`), `frontend/lib/core/orders/order_values.dart` (receive `RatingReason`), `frontend/lib/core/localization/order_labels.dart` (`ratingReason`), `frontend/lib/features/operations/domain/board.dart` and `frontend/lib/features/operations/presentation/order_actions.dart` (use the moved enum and label), `frontend/lib/features/orders/domain/customer_orders.dart`, `frontend/lib/features/orders/data/customer_orders_api.dart`, `frontend/lib/features/orders/application/customer_orders_controllers.dart`, every caller of `customerOrdersProvider` / `ordersPageProvider`, `frontend/test/support/fake_customer_orders_repository.dart`, `frontend/test/support/app_harness.dart` (optional `DateTime Function()? clock`)
- Texts: both ARB files
- Test: `frontend/test/core/formatting/order_dates_test.dart` (create), `frontend/test/features/orders/data/customer_orders_api_test.dart`, `frontend/test/features/orders/application/customer_orders_controllers_test.dart`

**Interfaces:**
- Produces (core):
  - `final Provider<DateTime Function()> clockProvider` — `DateTime.now` by default.
  - `TashkentTime.time(DateTime instant) → String` — `HH:mm` in Tashkent.
  - `String orderDay(AppLocalizations l10n, DateTime instant, DateTime now)` — the Tashkent calendar day of `instant` against that of `now`: same day `dayToday`, the day before `dayYesterday`, same year `dayDate('$d', monthShort('m$m'))`, another year `dd.MM.yyyy`.
  - `String orderWhen(AppLocalizations l10n, DateTime instant, DateTime now)` → `l10n.orderWhen(orderDay(...), TashkentTime.time(instant))` ("Сегодня, 12:40").
  - `String orderAt(AppLocalizations l10n, DateTime instant, DateTime now)` → `l10n.orderAt(...)` ("Сегодня в 13:05").
  - `String orderAtLower(AppLocalizations l10n, DateTime instant, DateTime now)` — `orderAt` with its first letter lower-cased, for mid-sentence use ("Вы отменили сегодня в 18:24").
  - `enum RatingReason` moves to `core/orders/order_values.dart` unchanged; `OrderLabels.ratingReason(AppLocalizations, RatingReason)`.
- Produces (domain):
  - `enum OrdersTab { current('current'), past('past') }` with `code`.
  - `OrderSummary` gains `street`, `house`, `courierPhone` (`String?`), `imageUrl` (`String?`), `ratingStars` (`int?`), `canRate` (`bool`).
  - `CustomerOrderLine` gains `imageUrl` (`String?`).
  - `CustomerOrder` gains `courier` (`OrderCourier?`), `supportPhone` (`String?`), `rating` (`CustomerRating?`), `canRate`, and the instants `shoppingStartedAt`, `onTheWayAt`, `completedAt`, `cancelledAt` (all `DateTime?`).
  - `final class OrderCourier { String? firstName; String phone; }`.
  - `final class CustomerRating { int stars; List<RatingReason> reasons; String? comment; DateTime createdAt; }`.
  - `final class ReorderItem { String productId; String nameUz; String nameRu; String? quantity; String name(AppLanguage) }` and `final class ReorderResult { List<ReorderItem> added, skipped, unavailable, cartFull; }`.
  - `final class PendingQuestion { String approvalId; String orderId; int orderNumber; DateTime expiresAt; }`.
  - Repository: `orders(OrdersTab tab, int page)`, `reorder(String orderId, String idempotencyKey) → Future<ReorderResult>`, `rate(String orderId, int stars, List<RatingReason> reasons, String? comment) → Future<CustomerOrder>`, `pendingQuestions() → Future<List<PendingQuestion>>`.
- Produces (application):
  - `ordersPageProvider` becomes a family on `OrdersTab`; `customerOrdersProvider` a family on `OrdersTab`. `ref.invalidate(customerOrdersProvider)` still reloads both tabs.
  - `pendingQuestionProvider: FutureProvider.autoDispose<PendingQuestion?>` — the first page's question with the earliest `expiresAt`, `null` when none; a pending future without a Customer account.
  - `OrderMutation.reload` also invalidates `pendingQuestionProvider`.
  - `class ReorderController extends OrderMutation` with `Future<ReorderResult?> reorder()`: a tap while one runs is ignored; the key stays until an answer says for sure what happened (the `OrderCancelController` rule: kept after a non-refusal, a `5xx` or `idempotency_in_progress`); after a sure answer it invalidates `cartProvider`. Provider `reorderProvider` (`autoDispose.family` on the order id).
  - `class RateController extends OrderMutation` with `Future<CustomerOrder?> rate(int stars, List<RatingReason> reasons, String? comment)`: a tap while one runs is ignored; no key (the identical repeat is the retry, `docs/09` §49). Provider `rateProvider`.

- [ ] **Step 1: Write the failing tests.**
  - `order_dates_test`, with `now` = 2026-10-18 09:00 UTC (14:00 Tashkent):
    - `'today and yesterday by the Tashkent day'`: 2026-10-18 07:40 UTC → `'Сегодня, 12:40'`; 2026-10-17 14:45 UTC → `'Вчера, 19:45'`; 2026-10-17 19:30 UTC (00:30 on the 18th in Tashkent) → `'Сегодня, 00:30'`.
    - `'a day this year names the month, another year the full date'`: 2026-10-07 13:20 UTC → `'7 окт, 18:20'` in `ru`, `'7-okt, 18:20'` in `uz`; 2025-12-30 10:00 UTC → `'30.12.2025, 15:00'`.
    - `'orderAt reads "в"'`: `'Сегодня в 13:05'`; `orderAtLower` → `'сегодня в 13:05'`.
  - `customer_orders_api_test`:
    - `'a tab asks for its state'`: `orders(OrdersTab.past, 2)` sends `state=past&page=2`.
    - `'a summary carries the 6a fields'`: `address{street, house}`, `courier_phone`, `image_url`, `rating_stars`, `can_rate` parse; a summary without `address` is a `FormatException`.
    - `'an order carries the courier, support, rating and instants'`: `courier {first_name: null, phone}` parses; `rating.reasons` with an unknown code skips it; `timestamps.on_the_way_at` parses; `items[].image_url` parses.
    - `'reorder posts with its key and parses the four lists'`: `POST /customer/orders/<id>/reorder`, header `Idempotency-Key`, no body; `added_items[0].quantity == '2.000'`; skipped, unavailable and cart-full items have `quantity == null`.
    - `'rate posts stars, reasons and a comment'`: body `{"stars":2,"reasons":["not_fresh"],"comment":"мятые"}`; reasons empty and comment null are left out of the body; the answer is an order with `rating.stars == 2`, else `FormatException`.
    - `'pending questions read the approvals list'`: `GET /customer/approvals?status=pending&page=1`; each row's `id`, `order_id`, `order_number`, `expires_at`.
  - `customer_orders_controllers_test`:
    - `'the tabs page on their own'`: page 2 of `past` leaves `current` at page 1.
    - `'the banner question is the one expiring first'`: two questions → the earlier `expiresAt`; none → `null`.
    - `'a reorder keeps its key until a sure answer'`: a `NetworkFailure` then success → both calls carry the same key; a `409` refusal → the next call has a new key.
    - `'a reorder reloads the cart'`: after success `cartProvider` is loaded again.
    - `'a decision reloads the banner question'`.

  The fake gains `List<Map<String, Object?>> pendingRows`, `Map<String, Object?>? reorderAnswer`, `ApiFailure? reorderFailure`, `List<(String, String)> reorders`, `List<(String, int, List<String>, String?)> ratings`, `ApiFailure? rateFailure`; `orderSummaryJson` and `customerOrderJson` gain the 6a fields with defaults that keep today's JSON otherwise unchanged (`courier: null`, `support_phone: null`, `rating: null`, `can_rate: false`, `image_url: null`).

  Run `flutter test test/core/formatting test/features/orders/data test/features/orders/application`. Expected: FAIL.

- [ ] **Step 2: Implement** the files above. Parsing keeps the class's strictness: `courier_phone`, `courier.phone` and `support_phone` must match `^\+998\d{9}$` when present; `rating_stars` and `rating.stars` are 1–5 or `null`; `quantity` in `added_items` matches the line quantity form. `can_rate` is taken as the server says it, with no cross-check. Run the command again. Expected: PASS. Then `flutter test test/features/operations` (the moved enum) — PASS.

- [ ] **Step 3: Texts.**

  | Key | uz | ru |
  |---|---|---|
  | `dayToday` | Bugun | Сегодня |
  | `dayYesterday` | Kecha | Вчера |
  | `dayDate` `{day}` `{month}` | {day}-{month} | {day} {month} |
  | `monthShort` `{month}` select | `{month, select, m1{yan} m2{fev} m3{mar} m4{apr} m5{may} m6{iyn} m7{iyl} m8{avg} m9{sen} m10{okt} m11{noy} m12{dek} other{}}` | `{month, select, m1{янв} m2{фев} m3{мар} m4{апр} m5{мая} m6{июн} m7{июл} m8{авг} m9{сен} m10{окт} m11{ноя} m12{дек} other{}}` |
  | `orderWhen` `{day}` `{time}` | {day}, {time} | {day}, {time} |
  | `orderAt` `{day}` `{time}` | {day}, soat {time} | {day} в {time} |

  `flutter gen-l10n`, `flutter analyze`. Expected: clean.

- [ ] **Step 4: `DL-92` item 1.** Start the entry after `DL-91`:

```markdown
## DL-92 — The Customer's order screens, kit stage 6b (2026-10-19, agent)

1. **Data.** Each tab of the orders pages on its own (`state=current|past`). Dates read as the business does, in Tashkent: "Сегодня", "Вчера", a day and month this year, the full date otherwise; "today" comes from one clock the tests set. The rating reasons are one enum shared by the panel and the Customer.
```

- [ ] **Step 5: Commit** `feat(orders): the 6a fields, tabs, reorder, rating and pending questions in the client (DL-92 item 1)`.

---

### Task 2: "Повторить" and the home question banner

**Files:**
- Create: `frontend/lib/features/orders/presentation/reorder_sheet.dart`, `frontend/lib/features/orders/presentation/question_banner.dart`
- Modify: `frontend/lib/features/catalog/presentation/home_screen.dart` (the banner between the search row and the categories)
- Texts: both ARB files
- Test: `frontend/test/features/orders/presentation/reorder_sheet_test.dart`, `frontend/test/features/orders/presentation/question_banner_test.dart` (create)

**Interfaces:**
- Consumes: Task 1 `reorderProvider`, `ReorderResult`, `pendingQuestionProvider`, `currentCartProvider`, `TashkentTime.time`.
- Produces:
  - `Future<void> repeatOrder(BuildContext context, WidgetRef ref, {required String orderId, required int orderNumber})` — runs `reorderProvider(orderId).notifier.reorder()`; on an answer opens `showReorderSheet`; on a failure shows a `SnackBar` with `failureText(l10n, failure)`.
  - `Future<void> showReorderSheet(BuildContext context, {required ReorderResult result, required int orderNumber})` — drawing 28а.
  - `class RepeatOrderButton extends ConsumerWidget({required String orderId, required int orderNumber, required bool wide})` — `wide: false` is the card's small filled "↻ Повторить" (key `order-repeat-<id>`); `wide: true` the page's outlined "↻ Повторить заказ" (key `order-repeat`). While the reorder runs it shows an 18 px spinner with `reorderSending`.
  - `class QuestionBanner extends ConsumerWidget` — drawing 27б, key `question-banner`; nothing when the provider has no question, is loading, or failed. Inside a `PeriodicRefresh(interval: 30 s)` that invalidates `pendingQuestionProvider`.

**Behaviour:**
- Sheet (kit modal: white, top radius 28, drag handle, close button `reorder-close`):
  - Title `reorderTitle` when anything was added, else `reorderNothingTitle`.
  - `reorderAdded(count, number)` under the title when `added` is not empty.
  - Sections, each only when its list is not empty, rows with a 44 `ProductImage` (the current cart line's picture for a skipped product, else `null`), the name and a subtitle:
    - `reorderSkippedTitle`; subtitle `reorderInCart(QuantityRules.display(q) + unit)` from the current cart's line for that product, none when the cart does not hold it.
    - `reorderUnavailableTitle`; subtitle `catalogUnavailable` in `danger`, the picture greyed.
    - `reorderCartFullTitle`; no subtitle.
  - Buttons: `reorderStay` (outlined, key `reorder-stay`, closes) and `reorderToCart` (primary, key `reorder-to-cart`, closes and pushes `CartPaths.cart`).
- Banner: a `warningWash` card with radius 16; a 36 `warning` circle with a white `help` icon; `questionBannerTitle` (14 / w700); `questionBannerOrder('$number', TashkentTime.time(expiresAt))` (12 / w500 `ink2`); a small primary button `questionAnswer` (key `question-banner-answer`) that pushes `AppPaths.customerOrder(orderId)`. The whole card is one tap target with the same action.

- [ ] **Step 1: Write the failing tests.**
  - `reorder_sheet_test`:
    - `'the sheet lists what was added, kept and not on sale'`: added 8, skipped bread (cart holds 2 pcs), unavailable apple → `'Добавили в корзину'`, `'8 товаров из заказа № 1038 — по сегодняшним ценам.'`, `'Лепёшка'`, `'В корзине 2 шт.'`, `'Яблоки Семиренко'`, `'Нет в продаже'`.
    - `'nothing added says so'`: `'Ничего не добавили'`, no `reorderAdded` line.
    - `'"В корзину" opens the cart'`: `top(tester) == CartPaths.cart`.
    - `'two quick taps repeat once'`: two taps on `order-repeat-<id>` with the fake held → `reorders.length == 1`.
    - `'a lost answer is retried under the same key'`: `reorderFailure = NetworkFailure` → a SnackBar; the second tap succeeds → `reorders[0].$2 == reorders[1].$2`.
    - large text: the sheet with all three sections.
  - `question_banner_test`:
    - `'the banner names the order and the time to answer'`: `'Сборщик ждёт вашего ответа'`, `'Заказ № 1044 · ответьте до 12:55'`; `question-banner-answer` opens `AppPaths.customerOrder(orderTwo)`.
    - `'no question, no banner'`; `'a failed load shows nothing'`.
    - `'an answer hides the banner without waiting'`: decide the question on the order page, the fake's `pendingRows` emptied → back home, `question-banner` is gone before 30 s pass.
    - `'the banner loads again every 30 seconds'`.
    - large text: home with the banner.

  Run `flutter test test/features/orders/presentation/reorder_sheet_test.dart test/features/orders/presentation/question_banner_test.dart`. Expected: FAIL.

- [ ] **Step 2: Implement.** Run the two tests and `flutter test test/features/catalog`. Expected: PASS.

- [ ] **Step 3: Texts.**

  | Key | uz | ru |
  |---|---|---|
  | `reorderTitle` | Savatga qo'shildi | Добавили в корзину |
  | `reorderNothingTitle` | Hech narsa qo'shilmadi | Ничего не добавили |
  | `reorderAdded` `{count}` `{number}` plural | `{count, plural, other{Buyurtma № {number} dan {count} ta mahsulot — bugungi narxlarda.}}` | `{count, plural, one{{count} товар из заказа № {number} — по сегодняшним ценам.} few{{count} товара из заказа № {number} — по сегодняшним ценам.} many{{count} товаров из заказа № {number} — по сегодняшним ценам.} other{{count} товара из заказа № {number} — по сегодняшним ценам.}}` |
  | `reorderSkippedTitle` | Savatda bor edi — o'zgartirmadik | Уже были в корзине — оставили как есть |
  | `reorderInCart` `{quantity}` | Savatda {quantity} | В корзине {quantity} |
  | `reorderUnavailableTitle` | Sotuvda yo'q — qo'shilmadi | Нет в продаже — не добавили |
  | `reorderCartFullTitle` | Sig'madi — savatda 100 ta mahsulot bor | Не поместились — в корзине уже 100 товаров |
  | `reorderStay` | Qolish | Остаться |
  | `reorderToCart` | Savatga | В корзину |
  | `reorderRepeat` | Takrorlash | Повторить |
  | `reorderRepeatOrder` | Buyurtmani takrorlash | Повторить заказ |
  | `reorderSending` | Savatga qo'shilmoqda | Добавляем в корзину |
  | `questionBannerTitle` | Yig'uvchi javobingizni kutmoqda | Сборщик ждёт вашего ответа |
  | `questionBannerOrder` `{number}` `{time}` | Buyurtma № {number} · {time} gacha javob bering | Заказ № {number} · ответьте до {time} |
  | `questionAnswer` | Javob berish | Ответить |

- [ ] **Step 4: `DL-92` item 2:**

```markdown
2. **Repeat and the banner.** "Повторить" keeps its idempotency key until an answer says for sure what happened, so a retry after a lost answer is the same request; the sheet is built from the answer, and a product kept from the cart shows the cart's quantity. The cart loads again after a sure answer. The home banner shows the pending question that expires first, from the first page of `GET /customer/approvals?status=pending`; it loads again every 30 seconds while the home is shown and after every decision, and a failed load hides it — it is a pointer, the order page is the place to answer.
```

- [ ] **Step 5: Commit** `feat(orders): repeat into the cart and the home question banner (DL-92 item 2)`.

---

### Task 3: The orders list — tabs and kit cards

**Files:**
- Create: `frontend/lib/features/orders/presentation/order_cards.dart` (`OrderStatusChip`, `OrderProgressBar`, `CurrentOrderCard`, `PastOrderCard`)
- Modify: `frontend/lib/features/orders/presentation/orders_screens.dart` (`OrdersScreen` rebuilt; `orderTotalText` stays for its other callers)
- Texts: both ARB files
- Test: `frontend/test/features/orders/presentation/orders_screens_test.dart`, `order_progress_test.dart` (list tests), `frontend/test/features/orders/presentation/order_cards_test.dart` (create)

**Interfaces:**
- Consumes: Task 1 tabs, providers, `orderWhen`, `clockProvider`; Task 2 `RepeatOrderButton`.
- Produces:
  - `OrderStatusChip({required OrderStatus status})`: `customerStatus` text; colours — `shopping`, `finalPaymentPending`: `warning` on `warningWash`; `cancelled`: `danger` on `KitColors.danger.withValues(alpha: 0.08)`; `completed`: `muted` on `field`; every other status `primaryDark` on `primaryWash`.
  - `int orderStage(OrderStatus status)`: `newOrder`, `shoppingAssigned` → 1; `shopping`, `finalPaymentPending`, `readyForDelivery`, `deliveryAssigned` → 2; `onTheWay` → 3; `completed` → 4; `cancelled` → 0.
  - `OrderProgressBar({required int stage})`: four 4-high rounded segments with 6 gaps; the first `stage` in `primary`, the rest `line`.
  - `CurrentOrderCard({required OrderSummary order})`, `PastOrderCard({required OrderSummary order})`, both keyed `order-<id>`, each a tap target opening `AppPaths.customerOrder(id)`.

**Behaviour** (drawings 27, 27а, 28):
- `OrdersScreen`: `CustomerTabScope`, white `Scaffold`, `kitAppBar(title: myOrders, automaticallyImplyLeading: false)`, `CustomerTabBar(current: orders)`. Under the bar a 48-high segmented control on `field` with radius 14: `ordersTabCurrent` and `ordersTabPast` (keys `orders-tab-current`, `orders-tab-past`; the chosen one `primary` with white text). It opens on "Текущие".
- Each tab lists its provider's page in a `ListView` (key `orders-list`) of cards with 12 gaps, then `PaginationBar`. The current tab sits in `PeriodicRefresh(interval: 30 s)`.
- Current card: a 56 picture (`imageUrl`), `customerOrderTitle(number)` (15 / w700), the address `'$street, $house'` (12 `muted`, one line, ellipsis), `orderItemCount(n)` (12 `muted`), the chip at the top right; `OrderProgressBar(stage)`; when `pendingApprovalCount > 0` a `warningWash` strip (key `order-waiting-<id>`) with a `help` icon, `orderCardQuestion(count)` and a small primary `questionAnswer` button, both opening the order; a bottom row with `orderWhen(createdAt)` (12 `muted`) and the total (15 / w700) — `cartLineEstimate(amount)` for an estimate, the amount for a final, `totalNothingDue` for none; when `courierPhone != null` an outlined full-width `callCourier` button with a `call` icon (key `order-call-courier-<id>`).
- Past card: the same top and bottom rows, no progress bar. Then a row: when `canRate`, five 34×30 boxes on `field` reading "N★" (keys `order-rate-<id>-<N>`, each opening `AppPaths.customerOrderRate(id, stars: N)` from Task 6 — until Task 6 exists the boxes open the order); when `ratingStars != null`, that many filled `warning` stars and the rest `line`; otherwise nothing. At the right end `RepeatOrderButton(wide: false)`.
- Empty current tab (key `orders-empty`): a 96 `primaryWash` circle with `receipt_long`, `myOrdersEmpty` (18 / w700), `ordersEmptyHint`, a primary `ordersEmptyAction` (key `orders-empty-shop`) going to `AppPaths.customer`. Empty past tab: the same circle and `ordersPastEmpty`, no button.

**Flows that change in existing tests:** the list's row text "Заказ №1001 · Принят" becomes the card (`customerOrderTitle` and the chip); "Нужен ваш ответ" becomes the strip `order-waiting-<id>` reading `orderCardQuestion`. The empty list asserts `orders-empty` and `myOrdersEmpty` as before.

- [ ] **Step 1: Write the failing tests** (`order_cards_test` and the list tests):
  - `'the current card shows number, address, count, status, date and total'`: `'Заказ № 1044'`, `'Чиланзар, 9-й квартал, 14'`, `'4 товара'`, `'Собирается'`, `'Сегодня, 12:40'`, `'≈ 96 000 сум'`.
  - `'a waiting question shows the strip'`: `'Сборщик спрашивает про 1 товар'`; tapping `questionAnswer` opens the order.
  - `'the courier button follows courier_phone'`: with a phone, tapping `order-call-courier-<id>` calls `+998901112233` on the fake `PhoneCalls`; without one, no button.
  - `'the progress fills by stage'`: `orderStage` for all nine statuses.
  - `'the past card offers stars only while it can be rated'`: `canRate` → five `order-rate-<id>-N`; `ratingStars: 4` → four filled stars, no boxes; neither → none.
  - `'the tabs ask for their state'`: tapping `orders-tab-past` → the fake saw `OrdersTab.past`; back to current shows page 1.
  - `'an empty current tab leads to shopping'`; `'an empty past tab says what will be there'`.
  - `'the current tab loads again every 30 seconds'`.
  - large text: both tabs with a card each, the extremes (`street` of 60 characters, 99 999 999 сум, "Позвонить курьеру", the question strip).

  Run `flutter test test/features/orders`. Expected: FAIL.

- [ ] **Step 2: Implement.** Run `flutter test test/features/orders test/features/checkout`. Expected: PASS.

- [ ] **Step 3: Texts.**

  | Key | uz | ru |
  |---|---|---|
  | `ordersTabCurrent` | Joriy | Текущие |
  | `ordersTabPast` | O'tgan | Прошлые |
  | `customerOrderTitle` `{number}` | Buyurtma № {number} | Заказ № {number} |
  | `orderItemCount` `{count}` plural | `{count, plural, other{{count} ta mahsulot}}` | `{count, plural, one{{count} товар} few{{count} товара} many{{count} товаров} other{{count} товара}}` |
  | `orderCardQuestion` `{count}` plural | `{count, plural, other{Yig'uvchi {count} ta mahsulot haqida so'ramoqda}}` | `{count, plural, one{Сборщик спрашивает про {count} товар} few{Сборщик спрашивает про {count} товара} many{Сборщик спрашивает про {count} товаров} other{Сборщик спрашивает про {count} товара}}` |
  | `callCourier` | Kuryerga qo'ng'iroq qilish | Позвонить курьеру |
  | `ordersEmptyHint` | Savatni to'ldiring — yig'uvchi hammasini bozordan oladi, kuryer esa olib keladi. | Соберите корзину — сборщик купит всё на базаре, а курьер привезёт. |
  | `ordersEmptyAction` | Xaridga | За покупками |
  | `ordersPastEmpty` | Bu yerda yetkazilgan va bekor qilingan buyurtmalar bo'ladi | Здесь будут доставленные и отменённые заказы |
  | `rateStarsLabel` `{stars}` | 5 dan {stars} ga baholash | Оценить на {stars} из 5 |

- [ ] **Step 4: `DL-92` item 3:**

```markdown
3. **The list.** "Мои заказы" opens on "Текущие"; the current tab loads again every 30 seconds while shown. A card shows the server's total — "≈" for an estimate, "К оплате нет" when nothing is due — so a cancelled card reads "К оплате нет": the list carries neither the payment nor who cancelled, and the order page says both. Star boxes appear only while the server says the order can be rated; a rated order shows its stars.
```

- [ ] **Step 5: Commit** `feat(orders): current and past tabs with kit cards (DL-92 item 3)`.

---

### Task 4: The order page — status, lines, amounts, calls, actions, cancel sheets

**Files:**
- Create: `frontend/lib/features/orders/presentation/order_sections.dart` (`OrderStatusCard`, `OrderLineRow`, `OrderAmounts`, `OrderInfoRow`, `CourierCard`, `CancellationRequestCard`, `OrderFooter`), `frontend/lib/features/orders/presentation/order_questions.dart` (receives `_Question` and the expired line unchanged, as `OrderQuestionCard` and `OrderQuestionExpired`), `frontend/lib/features/orders/presentation/cancel_sheet.dart` (`showCancelSheet`, replacing `_CancelDialog`)
- Modify: `frontend/lib/features/orders/presentation/orders_screens.dart` (`OrderScreen`, `_Order` rebuilt; `_Line`, `_Question`, `_CancelDialog` leave)
- Texts: both ARB files
- Test: `frontend/test/features/orders/presentation/orders_screens_test.dart`, `order_progress_test.dart`, `frontend/test/features/orders/presentation/order_sections_test.dart` (create)

**Interfaces:**
- Consumes: Task 1 fields, `orderAt`, `orderAtLower`, `clockProvider`; Task 2 `RepeatOrderButton`; Task 3 `OrderStatusChip`, `orderStage`, `OrderProgressBar`; `SummaryAmountRow`, `EstimateNote`, `ProductImage`, `addressFullLine`, `formatPhone`, `phoneCallsProvider`.
- Produces:
  - `OrderStatusCard({required CustomerOrder order, required DateTime now})`, key `order-status`.
  - `OrderLineRow({required CustomerOrderLine line, required OrderStatus orderStatus})`, key `order-line-<id>`.
  - `Future<String?> showCancelSheet(BuildContext context, {required int orderNumber, required bool request, required bool unconfirmed, required String? reason})` — answers the reason typed (possibly empty), or `null` when kept.
  - `OrderQuestionCard({required String orderId, required CustomerOrderLine line, required CustomerQuestion question, required MutationState deciding, required AppLanguage language})`, `OrderQuestionExpired({required CustomerOrderLine line})` — today's widgets, moved.

**Behaviour** (drawings 29, 29в, 29г, 29д, 29е, 29ж without the rating, 29з):
1. **Page.** White `Scaffold`, `kitAppBar(title: customerOrderTitle(number))`, `ActiveModeBar`, `PeriodicRefresh` as today (15 s, open orders only). The `ListView` (key `order`) holds, in order: the status card; the request card; the courier card; the questions section; the lines; the amounts; the info rows. While `onTheWay`, the info rows come right after the courier card, before the questions and lines. `OrderFooter` is the `bottomNavigationBar` in `SafeArea(top: false)`, white with the cart footer's shadow; it is absent when it has no button.
2. **Status card** (`primaryWash`, radius 16, padding 16): a 44 `primary` circle with a white icon, a title (16 / w700) and a hint (12 `ink2`); then the four-stage bar with labels and times; then, when `canEdit`, `orderCanStillChange` (12 `ink2`). By status:
   - `newOrder`, `shoppingAssigned`: `receipt_long`, `orderStateAccepted`, `orderStateAcceptedHint`.
   - `shopping`: `shopping_basket`, `orderStateShopping`, `orderStateShoppingHint`.
   - `readyForDelivery`, `deliveryAssigned`: `inventory_2`, `orderStateCollected`, `orderStateCollectedHint`.
   - `finalPaymentPending`: `payments`, `customerStatusFinalPaymentPending`, no hint.
   - `onTheWay`: `two_wheeler`, `orderStateOnTheWay`, `orderStateLeftAt(TashkentTime.time(onTheWayAt))`.
   - `completed`: `check`, `orderStateDelivered`, `orderAt(completedAt)`.
   - `cancelled`: the card on `KitColors.danger.withValues(alpha: 0.08)` with a `danger` circle and `close`; `orderStateCancelled`; the hint `orderCancelledByYou(orderAtLower(cancelledAt))` for `customerCancelled`, else `orderCancelledAt(orderAtLower(cancelledAt))`; a second line `orderCancelReasonQuoted(request.reason)` when the reason is `cancellationRequestApproved` and the request is there, else `requestReason(OrderLabels.cancellationReason(...))` for a reason other than `customerCancelled`. No bar.
   - The bar: four labelled segments (`progressAccepted`, `progressShopping`, `progressDelivering`, `progressDelivered`, 10 / w600), filled up to `orderStage`; under each reached label its time (`TashkentTime.time`) from `createdAt`, `shoppingStartedAt`, `onTheWayAt`, `completedAt` when known.
3. **Lines.** A heading `checkoutItems(n)`, `n` = lines other than `customerRemoved`; then each such line as `OrderLineRow`: a 48 picture (greyscale at opacity 0.4 when removed), the name (14 / w600; struck through and `muted` when removed), a subtitle (12 `muted`), an optional tag, and the amount at the right (14 / w700):
   - open line: `'${QuantityRules.display(q)} $unit · ${perUnit}'` where `perUnit` is `cartLineEstimate(catalogPricePerUnit(...))` for an estimate line, plain for a fixed one; amount `cartLineEstimate(lineTotal)` or plain.
   - bought line while the order is `shopping`: `'$billed $unit × ${MoneyFormat.uzs(billedPrice)}'` with the tag `lineTagBought` (`primaryDark`, `check` icon); in any later status: `orderLineBoughtKit(...)` without a tag. Amount plain.
   - waiting line with a question: the open subtitle and the tag `lineTagWaiting` (`warning`, `help` icon).
   - removed line: `'${QuantityRules.display(q)} $unit'`; the tag by reason — `unavailable` `lineTagUnavailable`, `customerRejected` `lineTagRejected`, `approvalExpired` `lineTagExpired`, `operatorRemoved` `lineTagOperator`, `orderCancelled` none; amount `MoneyFormat.uzs(0)`.
   - under the subtitle: the replacement (`itemReplacedWith`, key `order-line-replacement-<id>`), the rule when it is not `allowSimilar` (`OrderLabels.substitution`), the note in quotes, each 12 `muted`.
4. **Amounts.** Not `none`: `SummaryAmountRow`s `cartGoods(n)`, `cartDelivery`, `cartServiceFee`, a divider, `cartTotal` strong; estimates through `cartLineEstimate`; then `EstimateNote` for an estimate. `none`: one strong row `orderToPayLabel` / `orderNothingDue`.
5. **Info rows** (`OrderInfoRow`: a 44 `primaryWash` icon well with radius 12, a title 14 / w600, a subtitle 12 `muted`, an optional trailing text button):
   - payment (key `order-payment`): a paid payment → `orderPaidCash`, `orderPaidWhen(amount, orderAtLower(paidAt))`; a final total unpaid → `orderToPayAmount(amount)`, `orderCashOnDelivery`; else `paymentCashTitle`, `paymentCashHint`.
   - address: `home` icon, `orderAddressTitle`, `addressFullLine(street, house, apartment)`; the landmark under it when given.
   - wish, only when set: `schedule`, `checkoutWishLabel`, the wish.
   - support (key `order-support`), only when `supportPhone != null` and the order is neither `completed` nor `cancelled`: `support_agent`, `supportTitle`, `supportHint`, trailing `callAction` (key `order-call-support`).
6. **Courier card** (key `order-courier`), only when `courier != null`: a 44 `primaryWash` circle with the name's first letter (or a `person` icon), the name (or `formatPhone(phone)` without one) in 15 / w700, `courierYours` under it, and a 44 round `primary` call button (key `order-call-courier`, tooltip `callCourier`).
7. **Request card** (key `order-cancellation-request`), when a request exists: `requestYouAsked` and a chip — pending `requestStatusPending` (key `order-cancellation-requested`) on `warningWash`, else the status text as today (key `order-cancellation-request-<status>`); the reason in quotes; for pending `requestPendingHint`.
8. **Footer.** `canEdit` → `orderCancelShort` (outlined, `danger` text, key `order-cancel`) and `orderEdit` (primary with `edit` icon, key `order-edit`) side by side; `canRequestCancellation` → `orderRequestCancel` outlined `danger`, full width (key `order-request-cancel`); `completed` or `cancelled` → `RepeatOrderButton(wide: true)`; nothing otherwise. While a cancel runs, its button shows the spinner with `orderCancelling` as today. `order-cancel-needs-reason` and the `FailureMessage` sit above the buttons, with today's rules.
9. **Cancel sheets** (kit modal; drawings 29в, 29г). Title `cancelSheetTitle(number)` or `requestSheetTitle`, a close button (`cancel-keep` closes too); hint `cancelSheetHint` or `requestSheetHint`; the label `orderCancelReason` or `orderRequestCancelReason`; the field `cancel-reason` (hint `cancelReasonHint`, 1–4 lines, on `field`, radius 14), a counter `'$n / 300'` with `n` counted as `trimLikeServer` keeps it; `orderCancelRepeating` under it while unconfirmed (read-only field). Buttons `orderCancelKeepKit` (outlined, key `cancel-keep`) and `orderCancelShort` / `requestSend` (filled `danger`, key `cancel-confirm`). Validation exactly as `_CancelDialog` does today.
10. **Questions section.** Above the lines: one `OrderQuestionCard` per line with a question and one `OrderQuestionExpired` per `questionExpired` line, each followed by its `FailureMessage` with today's rule; the widgets themselves unchanged until Task 5.

**Flows that change in existing tests:** the cancel dialog is a bottom sheet with the same keys; `find.text('Отменить заказ?')` becomes `'Отменить заказ № 1001?'`. Status text assertions on `order-status` read the card's title. `orderLineBought` assertions become the kit subtitle. `order-payment` asserts `orderPaidCash` and `orderPaidWhen`.

- [ ] **Step 1: Write the failing tests** (`order_sections_test` plus rewrites):
  - `'the status card by status'`: one case per status with title and hint; cancelled by the Customer → `'Вы отменили 7 окт в 18:24'`; cancelled after an approved request → `'Причина: «Срочно уезжаю»'`.
  - `'the bar shows the times reached'`: `createdAt` 12:10, `shoppingStartedAt` 12:25, `onTheWayAt` 12:52 → three times, none under "Доставлен".
  - `'lines read as they stand'`: an open estimate line `'2 кг · ≈ 14 000 сум / кг'` and `'≈ 28 000 сум'`; a bought line while shopping `'3 шт. × 3 000 сум'` with `'Куплено'`; the same after shopping `'Куплено 3 шт. × 3 000 сум'`; a removed unavailable line with `'Не было на базаре — убрали'` and `'0 сум'`; a `customerRemoved` line is absent and not counted (`'Товары · 3'`).
  - `'nothing due reads "К оплате нет"'`.
  - `'support shows on a current order with a phone, never on a finished one'`.
  - `'the courier card calls the courier'`; `'a courier without a name is shown by phone'`.
  - `'a failed dial shows the number'`: `PhoneCalls.call` answers `false` → a SnackBar with `'+998 90 111 22 33'`.
  - `'on the way, payment and address come before the lines'`: `order-payment` is above `order-line-<first>` (`tester.getTopLeft`).
  - `'a finished order offers "Повторить заказ"'`; `'a pending request shows its reason and no button'`.
  - `'the cancel sheet counts what is kept'`: `'  не то  '` → `'5 / 300'`.
  - `'the order page holds at the extremes'`: twelve lines, three open questions, a 60-character street, a 160-character wish, `total 99 999 999`, the courier, support, at 320×640 with text ×2, `uz` and `ru`.

  Run `flutter test test/features/orders`. Expected: FAIL.

- [ ] **Step 2: Implement.** Run `flutter test test/features/orders test/features/checkout`. Expected: PASS.

- [ ] **Step 3: Texts.**

  | Key | uz | ru |
  |---|---|---|
  | `orderStateAccepted` | Buyurtma qabul qilindi | Заказ принят |
  | `orderStateAcceptedHint` | Tez orada yig'uvchi bozordan xarid qilishni boshlaydi | Скоро сборщик начнёт покупать на базаре |
  | `orderStateShopping` | Bozordan xarid qilyapmiz | Покупаем на базаре |
  | `orderStateShoppingHint` | Yig'uvchi mahsulotlaringizni tanlayapti | Сборщик выбирает ваши продукты |
  | `orderStateCollected` | Buyurtma yig'ildi | Заказ собран |
  | `orderStateCollectedHint` | Tez orada kuryer olib ketadi | Скоро курьер заберёт его |
  | `orderStateOnTheWay` | Kuryer buyurtmani olib kelmoqda | Курьер везёт заказ |
  | `orderStateLeftAt` `{time}` | Soat {time} da yo'lga chiqdi | Выехал в {time} |
  | `orderStateDelivered` | Yetkazildi | Доставлен |
  | `orderStateCancelled` | Buyurtma bekor qilindi | Заказ отменён |
  | `orderCancelledByYou` `{when}` | Siz bekor qildingiz: {when} | Вы отменили {when} |
  | `orderCancelledAt` `{when}` | Bekor qilindi: {when} | Отменён {when} |
  | `orderCancelReasonQuoted` `{reason}` | Sabab: «{reason}» | Причина: «{reason}» |
  | `progressAccepted` | Qabul qilindi | Принят |
  | `progressShopping` | Xarid | Покупаем |
  | `progressDelivering` | Yo'lda | Везём |
  | `progressDelivered` | Yetkazildi | Доставлен |
  | `orderCanStillChange` | Yig'uvchi boshlamaguncha buyurtmani o'zgartirish yoki bekor qilish mumkin. | Пока сборщик не начал, заказ можно изменить или отменить. |
  | `orderLineBoughtKit` `{quantity}` `{price}` | Sotib olindi: {quantity} × {price} | Куплено {quantity} × {price} |
  | `lineTagBought` | Sotib olindi | Куплено |
  | `lineTagWaiting` | Javobingizni kutmoqda | Ждёт вашего ответа |
  | `lineTagUnavailable` | Bozorda yo'q edi — olib tashlandi | Не было на базаре — убрали |
  | `lineTagRejected` | Siz rad etdingiz — olib tashlandi | Вы отказались — убрали |
  | `lineTagExpired` | Vaqtida javob berilmadi — olib tashlandi | Не ответили вовремя — убрали |
  | `lineTagOperator` | Operator olib tashladi | Убрал оператор |
  | `orderToPayLabel` | To'lov | К оплате |
  | `orderNothingDue` | yo'q | нет |
  | `orderPaidCash` | Naqd to'landi | Оплачено наличными |
  | `orderPaidWhen` `{amount}` `{when}` | {amount}, {when} | {amount}, {when} |
  | `orderToPayAmount` `{amount}` | To'lov: {amount} | К оплате {amount} |
  | `orderCashOnDelivery` | Qabul qilganda kuryerga naqd | Наличными курьеру при получении |
  | `orderAddressTitle` | Yetkazish manzili | Адрес доставки |
  | `supportTitle` | Qo'llab-quvvatlash | Поддержка |
  | `supportHint` | Agar biror narsa noto'g'ri ketsa | Если что-то пошло не так |
  | `callAction` | Qo'ng'iroq | Позвонить |
  | `courierYours` | Sizning kuryeringiz | Ваш курьер |
  | `orderCancelShort` | Bekor qilish | Отменить |
  | `requestYouAsked` | Siz bekor qilishni so'radingiz | Вы попросили отменить |
  | `requestPendingHint` | Operator hal qiladi — sizga xabar beramiz. Hozircha buyurtma ishda. | Решит оператор — мы сообщим. Пока заказ в работе. |
  | `cancelSheetTitle` `{number}` | Buyurtma № {number} bekor qilinsinmi? | Отменить заказ № {number}? |
  | `cancelSheetHint` | Yig'uvchi hali xarid qilishni boshlamadi — darhol bekor qilamiz. | Сборщик ещё не начал покупать — отменим сразу. |
  | `requestSheetTitle` | Bekor qilishni so'raysizmi? | Попросить отменить? |
  | `requestSheetHint` | Yig'uvchi allaqachon xarid qilmoqda. Sababini yozing — operator hal qilib, sizga xabar beradi. | Сборщик уже покупает. Напишите причину — решит оператор и сообщит вам. |
  | `cancelReasonHint` | Masalan: noto'g'ri buyurtma berdim | Например: заказал не то |
  | `orderCancelKeepKit` | Bekor qilmaslik | Не отменять |
  | `requestSend` | Yuborish | Отправить |

- [ ] **Step 4: Delete** ARB keys no Dart file uses any more, each checked with `grep -rn "l10n\.<key>\b" lib` first: candidates `orderCancelConfirm`, `orderCancelKeep`, `orderRequestCancelTitle`, `orderRequestCancelExplained`, `orderLineRemoved`, `orderLineBought`, `orderPaid`, `ordersNeedAnswer`, `myOrdersEmpty` (only if unused), `requestYours`. `flutter gen-l10n`.

- [ ] **Step 5: `DL-92` item 4:**

```markdown
4. **The order page.** One page for every status, as drawings 29–29з show it. The address card is titled "Адрес доставки": the order keeps a snapshot of the street, house and apartment but not the address's label, which may change or go. A cancellation by the Customer says when, not the words typed — those live in the order's history, not in its resource; a cancellation after an approved request quotes the request's reason. While the Courier is on the way, payment, address and support come before the lines. Support is offered on current orders only, the Courier by first name or, without one, by phone. The statuses the drawing did not show read "Заказ собран" (ready or a Courier assigned) and "Ждёт оплаты".
```

- [ ] **Step 6: Commit** `feat(orders): the kit order page with calls, actions and cancel sheets (DL-92 item 4)`.

---

### Task 5: The question cards

**Files:**
- Modify: `frontend/lib/features/orders/presentation/order_questions.dart`
- Texts: both ARB files
- Test: `frontend/test/features/orders/presentation/order_progress_test.dart` (group "the questions"), `frontend/test/features/orders/presentation/order_questions_test.dart` (create)

**Interfaces:**
- Consumes: Task 4's section and widget signatures (unchanged); `TashkentTime.time`.
- Produces: the same `OrderQuestionCard` and `OrderQuestionExpired`, restyled.

**Behaviour** (drawings 29а, 29б). Every rule of today's `_Question` stays: the decision on its way shows a spinner on its own button; after an unanswered decision only "Отправить снова" (`decide-again-<id>`) shows, with `decisionUnanswered`; `questionDropsReplacement` shows for a price question about the original while the line shows a replacement.
- Card: white, radius 16, a 1.5 `warning` outline, padding 16.
- Header row: the type title in 12 / w700 `warning` — `questionFromShopper` (price), `questionSubstitutionTitle`, `questionLessTitle` — and at the right `questionExpires(TashkentTime.time(expiresAt))` in 12 `muted`.
- Product row: a 48 picture and the name (14 / w600) with the ordered quantity under it. For a substitution: the line's picture, an `arrow_forward`, a picture-less 48 well (no image for the replacement in the API), then the replacement's name and `questionInsteadOf(name, quantity)`.
- Body (13 `ink2`): price on the original → `questionPriceKit(perUnit(proposed), perUnit(line price))`; price on a replacement → `questionReplacementPrice` as today; substitution → `questionSubstitution` as today; less → `questionLessKit(proposed, ordered)`.
- The note, when given, on `field` with radius 10: `questionNoteKit(note)`.
- Buttons in one row, equal width, 46 high: `questionReject` outlined (`reject-<id>`) and `questionApprove` primary (`approve-<id>`).
- Footer 11 `muted`: `questionRejectRemoves`.
- Expired (key `question-expired-<lineId>`): a `field` card with radius 16, `questionExpiredTitle` (12 / w700 `muted`), the line's greyed 40 picture and name, `questionExpiredLine`.

**Flows that change in existing tests:** text assertions on the question body use the new texts (`questionPriceKit`, `questionLessKit`); `questionExpired` becomes `questionExpiredTitle` + `questionExpiredLine`; keys are unchanged.

- [ ] **Step 1: Write the failing tests** in `order_questions_test`:
  - `'a price question reads the price today and the price ordered'`: `'Вопрос от сборщика'`, `'Ответьте до 12:55'`, `'Цена сегодня 16 500 сум / кг, при заказе была 14 000 сум / кг. Согласны на эту цену?'`, `'Сборщик: «Остальные мятые, эти свежие»'`.
  - `'a substitution shows both products'`: `'Замена'`, the replacement's name, `'вместо «Помидоры», 2 кг'`.
  - `'a smaller quantity reads both quantities'`: `'Меньше, чем заказали'`, `'Есть только 1 кг, вы заказали 1,5 кг. Согласны на меньшее?'`.
  - `'an expired question says the product goes'`.
  - `'the question cards hold at the extremes'`: three questions, long names and notes, 320×640, text ×2, `uz` and `ru`.

  Rewrite the "the questions" group's text assertions. Run `flutter test test/features/orders`. Expected: FAIL.

- [ ] **Step 2: Implement.** Run the same. Expected: PASS.

- [ ] **Step 3: Texts.**

  | Key | uz | ru |
  |---|---|---|
  | `questionFromShopper` | Yig'uvchidan savol | Вопрос от сборщика |
  | `questionSubstitutionTitle` | Almashtirish | Замена |
  | `questionLessTitle` | Buyurtmadan kam | Меньше, чем заказали |
  | `questionPriceKit` `{price}` `{was}` | Bugungi narx {price}, buyurtma paytida {was} edi. Shu narxga rozimisiz? | Цена сегодня {price}, при заказе была {was}. Согласны на эту цену? |
  | `questionLessKit` `{proposed}` `{ordered}` | Faqat {proposed} bor, siz {ordered} buyurtma qildingiz. Kamiga rozimisiz? | Есть только {proposed}, вы заказали {ordered}. Согласны на меньшее? |
  | `questionInsteadOf` `{name}` `{quantity}` | «{name}» o'rniga, {quantity} | вместо «{name}», {quantity} |
  | `questionNoteKit` `{note}` | Yig'uvchi: «{note}» | Сборщик: «{note}» |
  | `questionExpiredTitle` | Javob vaqti tugadi | Время ответа истекло |
  | `questionExpiredLine` | Bu mahsulot buyurtmadan olib tashlanadi | Этот товар уберут из заказа |

  Delete `questionPrice`, `questionQuantity`, `questionNote`, `questionExpired` if no file uses them (grep first). `flutter gen-l10n`.

- [ ] **Step 4: `DL-92` item 5:**

```markdown
5. **Questions.** The questions stand together above the lines, each with its own answer buttons and the retry under the same key (`DL-71`); the lines carry a "Ждёт вашего ответа" tag. Product names are not inflected or lower-cased, so the texts name them in quotes or say "этот товар"; the old price is written out rather than struck through, so it reads aloud the same.
```

- [ ] **Step 5: Commit** `feat(orders): kit question cards (DL-92 item 5)`.

---

### Task 6: The rating

**Files:**
- Create: `frontend/lib/features/orders/presentation/rate_order_screen.dart`, `frontend/lib/features/orders/presentation/order_rating_card.dart` (`RateOrderCard`, `RatedOrderCard`)
- Modify: `frontend/lib/core/routing/app_paths.dart` (`customerOrderRatePattern`, `customerOrderRate(String id, {int? stars})` → `…/rate?stars=N`), `frontend/lib/features/orders/presentation/orders_routes.dart`, `order_sections.dart` / `orders_screens.dart` (place the cards after the status card), `order_cards.dart` (the boxes open the rate route)
- Texts: both ARB files
- Test: `frontend/test/features/orders/presentation/rate_order_test.dart` (create)

**Interfaces:**
- Consumes: Task 1 `rateProvider`, `CustomerRating`, `RatingReason`, `OrderLabels.ratingReason`; Task 3 boxes; Task 4 page.
- Produces: `RateOrderScreen({required String orderId, int? stars})`; route name `customer-order-rate`; `stars` from the query, ignored unless 1–5.

**Behaviour** (drawings 29ж, 30, 30а, 30б):
- Page block, when `canRate` (key `order-rate`): a white card, `rateBlockTitle` (15 / w700, centred), five 40 star buttons on `field` (keys `order-rate-N`, semantics `rateStarsLabel(N)`) each opening the rate route with `stars: N`, and `rateBlockHint` (11 `muted`).
- Page block, when `rating != null` (key `order-rated`): `ratedTitle`, the stars filled in `warning`, the reasons as chips (`OrderLabels.ratingReason`), the comment in quotes, then `ratedThanksLow` for 1–3 or `ratedThanks` for 4–5.
- Rate screen: white `Scaffold`, `kitAppBar(title: rateTitle)` with a `close` leading button; the order comes from `customerOrderProvider(orderId)`. Body: a 72 `primaryWash` circle with `shopping_bag`, `rateQuestion(number)` (18 / w700), `rateHint`, five 44 stars (keys `rate-star-N`), the word for the chosen stars (`rateStar1`…`rateStar5`); at 1–3: `rateWhatWrong` and four `FilterChip`s (keys `rate-reason-<code>`); the comment field (`rate-comment`, label `rateComment`, hint `rateCommentHintGood` at 4–5 and before a choice, `rateCommentHintBad` at 1–3, 1–4 lines, counter `'$n / 500'` with `trimLikeServer`, refused above 500 with `fieldTooLong(500)`); at 1–3 a `primaryWash` note with `support_agent` and `rateOperatorWillCall`. Footer: primary `rateSend` (key `rate-send`), inactive until stars are chosen; a spinner with `rateSending` while sending.
- Choosing 4 or 5 clears the reasons.
- Sending `rate(stars, reasons, trimmed comment or null)`. An answer → pop back (the page shows the rated card from the reloaded order). `409 order_already_rated` or `order_not_rateable` → pop back (the reload shows the order as it is). `409 rating_window_closed` → stay, show `rateWindowClosed` above the button, the button inactive. Another failure → `FailureMessage` above the button.
- An order that cannot be rated when the screen opens (`canRate == false`) pops back at once.

- [ ] **Step 1: Write the failing tests** in `rate_order_test`:
  - `'a box on the past card opens the screen with its stars'`: tap `order-rate-<id>-2` → `rate-star-2` is chosen, `'Плохо'` and the four reasons show.
  - `'the customer rates 2 with a reason and a comment'`: choose `rate-reason-not_fresh`, type `'  мятые  '`, `rate-send` → `ratings.single == (orderOne, 2, ['not_fresh'], 'мятые')`; back on the page `order-rated` shows `'Несвежее'` and `'Спасибо! Оператор свяжется с вами, чтобы разобраться.'`.
  - `'raising to 4 drops the reasons'`: 2, a reason, then 4 → sent reasons empty.
  - `'two quick taps rate once'`.
  - `'a closed window says so and keeps the screen'`.
  - `'already rated elsewhere returns to the order'`.
  - `'a comment over 500 is refused before sending'`.
  - `'the page offers stars only while it can be rated'`: `canRate` → `order-rate`; rated → `order-rated`; neither → none.
  - large text: the screen at 2★ with reasons and a comment; the page with the rated card.

  Run `flutter test test/features/orders`. Expected: FAIL.

- [ ] **Step 2: Implement.** Run the same. Expected: PASS.

- [ ] **Step 3: Texts.**

  | Key | uz | ru |
  |---|---|---|
  | `rateTitle` | Buyurtmani baholash | Оценка заказа |
  | `rateQuestion` `{number}` | Buyurtma № {number} sizga yoqdimi? | Как вам заказ № {number}? |
  | `rateHint` | Hammasini baholang: mahsulotlar yangiligi, og'irligi va yetkazib berish | Оцените всё: свежесть продуктов, вес и доставку |
  | `rateStar1` | Juda yomon | Очень плохо |
  | `rateStar2` | Yomon | Плохо |
  | `rateStar3` | O'rtacha | Нормально |
  | `rateStar4` | Yaxshi | Хорошо |
  | `rateStar5` | A'lo! | Отлично! |
  | `rateWhatWrong` | Nima noto'g'ri bo'ldi? | Что пошло не так? |
  | `rateComment` | Izoh (ixtiyoriy) | Комментарий (необязательно) |
  | `rateCommentHintGood` | Nima yoqdi? | Что понравилось? |
  | `rateCommentHintBad` | Nima bo'ldi? | Что случилось? |
  | `rateOperatorWillCall` | Operator bahoni ko'radi va vaziyatni aniqlash uchun siz bilan bog'lanadi. | Оператор увидит оценку и свяжется с вами, чтобы разобраться. |
  | `rateSend` | Yuborish | Отправить |
  | `rateSending` | Baho yuborilmoqda | Отправляем оценку |
  | `rateBlockTitle` | Buyurtma yoqdimi? | Как вам заказ? |
  | `rateBlockHint` | Yangilik, og'irlik, yetkazish — 7 kun ichida baholash mumkin | Свежесть, вес, доставка — оценить можно 7 дней |
  | `ratedTitle` | Sizning bahoingiz | Ваша оценка |
  | `ratedThanksLow` | Rahmat! Operator vaziyatni aniqlash uchun siz bilan bog'lanadi. | Спасибо! Оператор свяжется с вами, чтобы разобраться. |
  | `ratedThanks` | Baho uchun rahmat! | Спасибо за оценку! |
  | `rateWindowClosed` | Buyurtmani yetkazilgandan keyin 7 kun ichida baholash mumkin — bu vaqt o'tdi. | Оценить заказ можно в течение 7 дней после доставки — это время прошло. |

- [ ] **Step 4: `DL-92` item 6:**

```markdown
6. **Rating.** The stars on the delivered order and on the past card open one rating screen with those stars chosen. Reasons show at 1 to 3 stars and are dropped when the Customer raises the stars to 4 or 5, as the server refuses them there. The comment is counted and trimmed as the server keeps it, at most 500. Already rated or no longer rateable returns to the order, which loads as it is; a closed window says so on the screen.
```

- [ ] **Step 5: Commit** `feat(orders): rate a delivered order (DL-90 item 1, DL-92 item 6)`.

---

### Task 7: The editor and the picker; docs and tracker

**Files:**
- Create: `frontend/lib/features/orders/presentation/order_line_sheet.dart` (`showOrderLineSheet`)
- Modify: `frontend/lib/features/orders/presentation/order_edit_screen.dart` (presentation only; `_LineDraft`, `_take`, `_toggle`, `_changesNothing`, `_save` keep their rules), `frontend/lib/features/orders/presentation/order_product_picker.dart`, `frontend/lib/features/orders/presentation/orders_routes.dart` (the picker takes `Set<String>` product ids as `extra`), `frontend/lib/features/cart/presentation/cart_line_stepper.dart` (`atMinimum`)
- Modify docs: `docs/DECISIONS.md` (`DL-92` item 7), `docs/03-features.md` §16 and §24, `docs/04-user-flows.md` §33 and §36, `tasks/REDESIGN_CUSTOMER.md` (stage 6 row "In Progress (6a merged PR #99; 6b PR #N)")
- Texts: both ARB files
- Test: `frontend/test/features/orders/presentation/orders_screens_test.dart` (group "editing"), `order_add_test.dart`, `frontend/test/features/cart` (stepper unchanged by default)

**Interfaces:**
- Consumes: `CartLineStepper`, `CardQuantity`, `showQuantitySheet`, `LineOptionsFields`, `EstimatePreview.lineUzs`, `SummaryAmountRow`, `ProductImage`.
- Produces:
  - `CartLineStepper` gains `bool atMinimum = false`: when true the minus shows `Icons.delete_outline` with the tooltip `orderEditRemoveLine`; its key stays `line-minus-<id>`. The cart passes nothing and is unchanged.
  - `Future<OrderLineChoice?> showOrderLineSheet(BuildContext context, {required String name, required UnitCode unit, required String quantity, required String? note, required SubstitutionPolicy policy, required VoidCallback? onRemove})` with `typedef OrderLineChoice = ({String quantity, String? note, SubstitutionPolicy policy})`.

**Behaviour** (drawings 29и, 29к):
- Editor: white `Scaffold`, `kitAppBar(title: orderEditKitTitle(number))` with a `close` leading button that leaves for the order (`_backToOrder`). The `primaryWash` info box `orderEditInfo` on top.
- Each kept line is a row (`edit-line-<key>`, `KeyedSubtree(key: draft.card)` as today):
  - a 56 picture (the line's `imageUrl`, or the product's picture for an added one);
  - the name (14 / w600) and, for an added product, the tag `orderEditNew` on `primaryWash` (key `edit-adds-<key>`);
  - the price per unit: `cartLineEstimate(catalogPricePerUnit(...))` — the line's own price for an ordered line, the product's current one for an added line;
  - the line preview `cartLineEstimate(MoneyFormat.uzs(EstimatePreview.lineUzs(price, normalized quantity)))`;
  - the rule and the note in 12 `muted` when not default, as in the cart;
  - `CartLineStepper(id: draft.key, quantityText: display + unit, atMinimum: CardQuantity.previous(...) == null)`: plus → `CardQuantity.next`; minus → `CardQuantity.previous`, or at the minimum `_toggle(draft)`; the quantity text → `showQuantitySheet`;
  - `edit-unavailable-<key>` (`cartLineUnavailable`, `danger`) after a `product_unavailable` refusal, as today.
  - A tap on the picture or the name (key `edit-options-<key>`) opens `showOrderLineSheet` with `onRemove: () => _toggle(draft)`. The sheet holds `LineOptionsFields` in its own `Form` on copies of the line's values; "Готово" (`saveButton`, key `edit-options-done`) validates and answers the choice, which the editor writes into the draft; closing it any other way changes nothing. Its "Убрать из заказа" (`orderEditRemoveLine`, `danger` text button, key `edit-remove-<key>`) closes it and calls `onRemove`.
- A removed ordered line stays greyed (picture greyscale, name struck) with "Вернуть" (`orderEditKeepLine`, key `edit-remove-<key>`) in place of the stepper.
- Under the lines: `edit-add-product` as an outlined dashed-looking full-width button with `add` and `orderAddProduct`; `edit-full` as today.
- The wish: label `checkoutWishLabel`, field `edit-delivery-wish` on `field` with radius 14, counter `'$n / 160'`, today's validator.
- Summary: one `SummaryAmountRow` `cartGoods(n)` with `cartLineEstimate(sum of the line previews)`, then `orderEditRecount` in 12 `muted`. No delivery, fee or total.
- Footer: primary `saveButton` (key `edit-save`) full width, the spinner with `orderEditSaving` while saving; `edit-none-left` and `FailureMessage` above it.
- Picker (29к): `kitAppBar(title: orderAddTitle)`; the search field on `field` with radius 14 (keys unchanged); categories as today; each product row: a 56 picture, the name, `cartLineEstimate(price)` 14 / w700 with `catalogPerUnit(unit)` ("за кг") under it in 12 `muted`, and at the right either a 36 round `primary` "+" (key `pick-<productId>`) or, for a product in the `extra` id set (else in the order's open lines), `orderPickInOrder` with a `check` in `primaryDark` (key `pick-in-order-<productId>`), which still picks it.

**Flows that change in existing tests:**

| Old flow | New flow |
|---|---|
| type a quantity into the line's field | the stepper's plus or minus, or the quantity sheet via `line-qty-<key>` |
| change a note or a rule on the card | `edit-options-<key>` → the sheet → `line-note` / `substitution-<code>` → `edit-options-done` |
| `edit-remove-<key>` on the card takes a line out | `edit-options-<key>` → `edit-remove-<key>` in the sheet; the row's `edit-remove-<key>` ("Вернуть") brings it back |
| a line to correct out of sight stops the save and is shown | the sheet refuses a note over 300 (`fieldTooLong(300)`) and stays open; closing it leaves the line's note as it was; the save sends the old note |
| a quantity field with a wrong value blocks the save | the stepper and the sheet only produce valid quantities: the test asserts the sheet refuses `'0'` |

- [ ] **Step 1: Write the failing tests** (rewrites per the table, plus):
  - `'an added product is tagged "Новый" and priced now'`.
  - `'the minus at the minimum removes the line'`: an ordered line at 1 kg → `line-minus-<key>` shows the trash; tap → greyed with "Вернуть".
  - `'the editor shows the goods preview and no delivery, fee or total'`: `'Товары (4)'` with `'≈ 79 000 сум'`; `find.text('Доставка')`, `'Сервисный сбор'`, `'Итого'` find nothing; `'Доставку, сбор и итог пересчитаем после сохранения'`.
  - `'the picker marks products already in the order'`: `pick-in-order-<tomato>`; tapping it returns to the editor with the existing snackbar.
  - `'the stepper in the cart is unchanged'` (cart tests pass as they are).
  - large text: the editor with four lines, an added one, the wish; the picker with three rows.

  Run `flutter test test/features/orders test/features/cart`. Expected: FAIL.

- [ ] **Step 2: Implement.** Run the same, then the whole suite `flutter test --concurrency=2`. Expected: PASS. `flutter analyze`, the format check, `git diff --check`: clean.

- [ ] **Step 3: Texts.**

  | Key | uz | ru |
  |---|---|---|
  | `orderEditKitTitle` `{number}` | Buyurtma № {number} ni o'zgartirish | Изменить заказ № {number} |
  | `orderEditInfo` | Yig'uvchi xarid qilishni boshlamaguncha o'zgartirish mumkin. Buyurtmadagi mahsulotlarning narxi o'zgarmaydi. | Менять можно, пока сборщик не начал покупать. У товаров, что уже в заказе, цена остаётся прежней. |
  | `orderEditNew` | Yangi | Новый |
  | `orderEditRecount` | Yetkazish, yig'im va jamini saqlagandan keyin qayta hisoblaymiz | Доставку, сбор и итог пересчитаем после сохранения |
  | `orderPickInOrder` | Buyurtmada | В заказе |

  Delete `orderEditTitle` and `orderAddedLine` if no file uses them (grep first). `flutter gen-l10n`.

- [ ] **Step 4: `DL-92` item 7 and the docs.**

```markdown
7. **The editor.** Quantities change with the cart's stepper — at the minimum the minus becomes a bin that takes the line out — or exactly through the quantity sheet; the note and the rule open in a sheet that applies only on "Сохранить". A line shows a preview of its cost, as the product screen does; the editor shows only the goods' preview and says that delivery, the fee and the total are recounted on saving: the server owns them, and a percentage fee depends on settings the client does not hold. The picker marks the products already in the order.
```

  `docs/03` §16: the home banner while a question waits, the question cards on the order page. `docs/03` §24: the current and past tabs, "Повторить" with its result sheet, the rating from the order and the past card. `docs/04` §33: the sheet after a reorder; §36: where the Customer starts a rating. `tasks/REDESIGN_CUSTOMER.md`: the stage 6 row.

- [ ] **Step 5: Commit** `feat(orders): the kit editor and picker; DL-92 and the docs`.

---

## After the tasks (controller)

- `branch-reviewer` (opus) on `e37a985..HEAD` with this plan and its Review Focus; one fix wave; a scoped re-review.
- No `/security-review`: no access, roles or server data change; the client shows only what the 6a API already scopes to the Customer (reviewed with PR #99).
- PR; set stage 6 in `tasks/REDESIGN_CUSTOMER.md` to "Merged (PR #99, #N)" on the branch before the merge; wait for both required checks; merge.
- Walk on the emulator before the merge (stages 4a and 5 showed layout gaps tests miss): list both tabs, a question answered from the home banner, the order on the way with both calls, cancel and request sheets, a delivered order rated 2★, "Повторить" with its sheet, the editor. 4–5 screenshots for the Owner.
- The report tells the Owner: the 7-day rating window and "repeat from any status" were agent decisions (`DL-91` items 3–4); the editor shows no total until saving (`DL-92` item 7); the list's cancelled card reads "К оплате нет" (`DL-92` item 3).
