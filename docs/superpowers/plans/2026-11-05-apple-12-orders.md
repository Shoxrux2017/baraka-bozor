# Apple Stage 12 — «Мои заказы» Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Customer's «Заказы» tab switches «Текущие · 2» and «Прошлые · 25» under a sliding thumb; each list slides in from its side, keeps its place and loads once (skeletons on the first visit). A failed refresh keeps the orders under «Нет связи · данные на 12:46 · Обновить», the refresh keeps trying, and a pull refreshes. A current card heads with its status («Собирается»), the number small, the stages labelled «Принят ✓ · Сборка · В пути · Доставлен», the Shopper's question right under the status with «Осталось 9 мин» (red at 3) folding away at its deadline. Changes arrive softly and aloud: a strip unfolds with a light haptic, the bar fills, the card glows, a delivered order shows «Доставлен» and then folds into «Прошлые» (+1). A past card shows three pictures «+7» and «Помидоры, Молоко домашнее и ещё 8», «Оцените заказ» with five outline stars that light up and open the rating screen, «Ваша оценка» once rated; past orders stand under month headings and load on as the Customer scrolls. With no current orders the screen offers the last order with «Повторить» and «Все прошлые заказы · 25». A screen reader hears the status first, «этап 2 из 4», «Примерно», «Повторить заказ № 1042», «Текущие, 2 заказа, выбрано» and month headings.

**Architecture:** The server adds to each list summary every open question's expiry and a preview of the first lines (names, pictures, how many). On the client `customerOrdersProvider` becomes an endless feed per tab that keeps its loaded pages across reloads; `OrdersScreen` moves to its own file, watches both tabs, and keeps them in two panes with their own scroll controllers under a sliding segment. The cards are redrawn around one shared stage bar (extracted from the order page). A pure diff of two successive current lists drives the live changes.

**Tech Stack:** Laravel 13 + PostgreSQL, Flutter 3.47.5, flutter_riverpod 3.4.3, go_router 18.1.2; core `Fold`/`FoldingColumn`, `StaleDataLine`, `DeadlineChip`/`minutesLeft`, `SkeletonBar`, `PeriodicRefresh`, `announce`, `textScaleAt`, `KitStar`; `HapticFeedback`; flutter_test (`tester.takeAnnouncements()`, `meetsGuideline(iOSTapTargetGuideline)`, `NonlinearTextScaler`, the `SystemChannels.platform` mock for haptics).

**Spec:** `tasks/APPLE_BATCH.md` stage 12 (`orders-1`, `orders-2` **repro**, `orders-3` **repro**, `orders-4`, `orders-5` **repro** **server**, `orders-6`, `orders-7`, `orders-8` **server**, `orders-9`, `orders-11`; `orders-10` was coded in stage 2); the live test «Тест списка заказов - Apple» in Claude Design, local copy `G:/tools/tmp/w-ord/site/ord.html` (published bytes equal it) — CSS at lines 14–275; script: `goSeg`, `tick`, `pull`, `newQ`, `plus3`, `courier`, `deliver`, `checkMore`, `rate`, `repeat`, `stops`/`curSay`/`pastSay`, `itemVals`, `curVals`, `pastVals`, `pastRowVals`, `renderVals` — it rules wherever this plan is silent; the review's memory note (2026-10-26); `DL-80` (3), `DL-91`, `DL-92`, `DL-113`, `DL-118`, `DL-125`, `DL-126`, `DL-130`; `docs/09-api-contracts.md` §20; `frontend/AGENTS.md`, `backend/AGENTS.md`.

## Global Constraints

- Changes stay in `backend/`, `frontend/`, `docs/` and `tasks/`. No package, no lockfile change, no migration. Generated localizations come from `flutter gen-l10n`, never by hand.
- New strings (ru / uz); the Russian wording is the page's:
  - `ordersCurrentEmptyTitle` «Сейчас заказов в работе нет» / «Hozir jarayondagi buyurtma yo'q»
  - `ordersLastOrderText` «Последний заказ — {day}. Его можно повторить или собрать новую корзину.» / «Oxirgi buyurtma — {day}. Uni takrorlash yoki yangi savat yig'ish mumkin.» (`day` is `orderDay` with its first letter lower-cased: «вчера», «24 окт»)
  - `ordersAllPast` «Все прошлые заказы · {count}» / «Barcha o'tgan buyurtmalar · {count}»; `ordersAllPastSpoken` «Все прошлые заказы, {count}» / «Barcha o'tgan buyurtmalar, {count}»
  - `ordersCount` plural «{count} заказ / заказа / заказов» / «{count} ta buyurtma»; `ordersLoading` «Загружаем заказы» / «Buyurtmalar yuklanmoqda»
  - `monthName` select `m1`…`m12`: «Январь … Декабрь» / «Yanvar, Fevral, Mart, Aprel, May, Iyun, Iyul, Avgust, Sentabr, Oktabr, Noyabr, Dekabr»; `monthYear` «{month} {year}» (both)
  - `orderPreviewTwo` «{first}, {second}» (both); `orderPreviewMore` «{first}, {second} и ещё {count}» / «{first}, {second} va yana {count} ta»
  - `progressListShopping` «Сборка» / «Yig'ish»; `progressListDelivering` «В пути» / «Yo'lda»
  - `orderRateCaption` «Оцените заказ» / «Buyurtmani baholang»; `orderRatedCaption` «Ваша оценка» / «Sizning bahoyingiz»; `orderRatedSpoken` «Ваша оценка: {stars} из 5» / «Sizning bahoyingiz: 5 dan {stars}»; `orderRateStarsSpoken` «Оценить заказ № {number} на {stars} из 5» / «Buyurtma № {number} ni 5 dan {stars} ga baholash»
  - `reorderRepeatSpoken` «Повторить заказ № {number}» / «Buyurtma № {number} ni takrorlash»; `questionAnswerSpoken` «Ответить на вопрос по заказу № {number}» / «Buyurtma № {number} bo'yicha savolga javob berish»; `callCourierSpoken` «Позвонить курьеру заказа № {number}» / «Buyurtma № {number} kuryeriga qo'ng'iroq qilish»
  - `orderCardStageSpoken` «{status}, этап {stage} из 4» / «{status}, {stage}-bosqich, 4 tadan»; `orderCardEstimateSpoken` «Примерно {amount}» / «Taxminan {amount}»
  - `orderAnnounced` «Заказ № {number}: {what}» / «Buyurtma № {number}: {what}»; `orderOnTheWayAnnounced` «Заказ № {number} в пути. Курьер выехал» / «Buyurtma № {number} yo'lda. Kuryer yo'lga chiqdi»; `orderDeliveredAnnounced` «Заказ № {number} доставлен. Он в прошлых заказах — там его можно оценить» / «Buyurtma № {number} yetkazildi. U o'tgan buyurtmalarda — u yerda baholash mumkin»; `orderCancelledAnnounced` «Заказ № {number} отменён. Он в прошлых заказах» / «Buyurtma № {number} bekor qilindi. U o'tgan buyurtmalarda»; `orderQuestionsExpiredAnnounced` «Время ответа на вопрос по заказу № {number} вышло» / «Buyurtma № {number} bo'yicha savolga javob vaqti tugadi»
  - Reused: `ordersTabCurrent`, `ordersTabPast`, `customerOrderTitle`, `orderItemCount`, `orderCardQuestion`, `questionAnswer`, `callCourier`, `reorderRepeat`, `reorderSending`, `deadlineLeft`, `deadlineLeftSpoken`, `progressAccepted`, `progressDelivered`, `staleOffline`, `staleSpoken`, `staleFailed`, `refreshDone`, `retryButton`, `totalNothingDue`, `cartLineEstimate`, `myOrdersEmpty`, `ordersEmptyHint`, `ordersEmptyAction`, `ordersPastEmpty`, `orderWhen`/`orderAt` (via `order_dates.dart`), `OrderLabels.customerStatus`. Removed when no longer used: `rateStarsLabel`, `ratedStarsLabel`.
- New colour token `KitColors.outline = Color(0xFFC9CDCA)` (the page's outlined «Повторить» and «Остаться»).
- Motion, from the page (none of it with reduced motion, `MediaQuery.disableAnimationsOf`, unless said): segment thumb 320 ms `Cubic(0.2, 0.8, 0.2, 1)`, labels' colour 250 ms; incoming pane from 28 px on its side (current from the left, past from the right) with opacity 0→1 in 300 ms `Cubic(0.2, 0.8, 0.2, 1)` — with reduced motion an opacity fade of 200 ms; first cards after skeletons fade in 220 ms, a page added at the end 250 ms; «Прошлые» count bump ×1.3 at 40 % of 340 ms; glow: a 3 px ring of `KitColors.primary` at alpha 0.55 fading to 0 in 1400 ms `Curves.easeOut` over the card's shadow, the headline fading in over 320 ms; stage segments change colour over 500 ms `Curves.easeOut`; strips, the call button and leaving cards use `Fold` as built (300 ms in, 260 ms out — the page's 320/280, `DL-131` (9)); a strip folds 400 ms after its last question ran out; a delivered card folds 1700 ms after it showed «Доставлен»; stars pop 1 → 1.32 (35 %) → 0.94 (70 %) → 1 in 340 ms `Cubic(0.2, 0.8, 0.2, 1)`, each 45 ms after the one before. Haptics (`HapticFeedback.lightImpact`) and announcements stay with reduced motion.
- Drawing, from the page. Cards: white, radius 16, the kit shadow, padding 14, 12 between blocks, 12 between cards, list padding 20/4/20/24. Status headline 16 w700 `ink`; small lines 12 `muted`, one line with ellipsis (wrapping at large text). Stage bar as the order page's (`DL-130`), labels 12 px with the list's words. Date 12 `muted`, sum 15 w700 `ink` at the row's end. Question strip: `warningWash`, radius 12, a 1.5 px inner border `warning`, padding 10/10/10/12, `Icons.help` 20 `warning`, 8, the text 13 w600 `ink` over a `DeadlineChip` 5 px under it, 8, «Ответить» filled `primary`, at least 44 high, padding 0 12, radius 10, 13 w600. Past card: picture tiles 44, radius 12, `card` ground, 32 px picture, 6 apart; the «+N» tile on `field`, 13 w600 `muted`; the status chip (`OrderStatusChip`) at the row's end; names 14 w600 `ink`, two lines with ellipsis; «Заказ № 1042 · street, house» 12 `muted`. Rating: caption 12 `muted`, stars `KitStar` 28 in 44 × 44 buttons (`DL-131` (11)), the row 8 px left of the card's text edge; read-only stars `KitStar` 22, 26 apart, no button. «Повторить»: filled `primary`, 44 high, padding 0 14, radius 10, `Icons.refresh` 18, 6, 14 w600; busy: a 16 px white spinner, opacity 0.7; the outlined one 1 px `KitColors.outline`, white, `ink` text, `primary` icon. Segment: `field`, radius 14, 48 high, padding 4, thumb `primary` radius 10, labels 14 w600 (white on the thumb, else `muted`), the count « · 2» w500. Month heading 17 w700 `ink`, 14 above (2 for the first), 10 under. Skeleton card: a 56 square radius 14, three bars 14/12/12 high at 70/45/55 %, then 12 high at 30 % and 15 high at 28 % at the two ends (`SkeletonBar`).
- Large text: a layout rule reads `textScaleAt(scaler, fontSize)` at the size of the text it holds (`DL-126`); above 1.3 at 12 px the stages stand as a list and the date and sum stack (sum on its own line, never scaled down); above 1.3 at 13 px the strip's button takes the strip's whole width under the text. Tests at large text use `NonlinearTextScaler(2)` on a 360 dp screen.
- Every state this stage draws — current list (with a strip, with the call button), past list (rateable, rated, unrated, cancelled), skeletons, the stale line, the end row, both empty states — passes `meetsGuideline(iOSTapTargetGuideline)` at 100 % and at `NonlinearTextScaler(2)` (batch rule).
- Amounts are the server's (`AGENTS.md` §5): the card shows `total_uzs` with «≈» for an estimate; nothing is computed on the client.
- Tests that pinned the old drawing (the chip headline, the 4 bare segments, the rating boxes, the pagination bar, the 36 px «Повторить», the current-tab empty text with history) are rewritten to the new rule, each named in the task's report; no other test is deleted or weakened.
- The app reads the new summary keys as required (`pending_approval_expires_at`, `preview`), like `working_hours` (`DL-125` (7)): deploy the backend first (a Risks line in `tasks/APPLE_BATCH.md`).
- Backend commands run as `docker compose -f docker/compose.yaml exec app …` from the repo root; never a destructive artisan command (`migrate:fresh`, `db:wipe`, `--env=testing` on the dev database). Flutter runs from PowerShell with `$env:TEMP='G:\tools\tmp'; $env:TMP='G:\tools\tmp'` and `G:\tools\flutter\bin\flutter.bat`; a full suite uses `--concurrency=2`. PHPUnit warnings fail CI: run the backend tests with `--fail-on-warning`.
- Comments read like the surrounding code: short `///` docs in plain English that name `DL-131`. A test's first run is red, and the report quotes the red line.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- `/security-review` once before the pull request: the branch changes what the Customer's order list carries.

## Review Focus

1. Offline for minutes on «Текущие»: every 30 s tick tries once (never two loads at a time), the cards and their scroll stay, the stale line says the time of the last good load; when the network returns the line folds and nothing jumps. Task 6 tests `'a failed refresh keeps the list under the stale line and the next tick tries again'`, `'refreshes never overlap'`.
2. «Прошлые» scrolled into page 3, then a rating or a delivered order reloads it: the same pages come back, no order twice, the scroll offset stays. Task 3 test `'a reload asks again for every page it had and shows no order twice'`; Task 6 test `'a reload of a deep past list keeps the offset'`.
3. A phone whose clock runs ahead: a question the server sends open but whose deadline already passed on the phone keeps its strip (no chip) until the next load, and is never folded with «время вышло» (`DL-130` (6)). Task 7 test `'a deadline already past on the phone keeps the strip without a chip until the next load'`.
4. An order the Customer cancelled on its own page (`DL-113`) leaves «Текущие» quietly — no «Заказ … отменён», no 1.7 s wait — while one delivered while the list is shown is announced and folds, and one found delivered while the list was covered is drawn quietly (`DL-131` (13)). Task 7 tests `'an order the Customer cancelled leaves without words'`, `'a delivered order says Доставлен, then folds into Прошлые, whose count goes up by one'`.
5. 200 % text on a 360 dp phone: segments with counts, the vertical stages, the strip with its full-width button, three pictures with «+7», the stars row wrapping under «Повторить», the empty state with the last order — nothing overflows or shrinks, every target is 44. Tasks 4–6 large-text tests.

---

### Before the tasks (the lead)

- [x] **The test page.** Read 2026-11-05 from the local copy; this plan follows it.
- [ ] **Reproduce `orders-2`, `orders-3`, `orders-5`** on the `barakabozor` emulator with main's build (`b3641f8`) if commit free ≥ 4 GB with no other emulator running: switch the segments twice (a spinner and a reload each time, the place lost); cut the network and wait 30 s (the list is replaced by «Нет подключения»); let a question run out (the strip and «Ответить» stay up to 30 s). Screenshots `G:/tools/tmp/apple12-repro-*.png`. Otherwise the first red runs of the named tests in Tasks 6 and 7 on main's code are the reproduction, and `DL-131` (10) says so.

### Task 1: Server — the preview and the questions' expiries; the decision record

**Files:**
- Modify: `backend/app/Models/Order.php` (two relations), `backend/app/Modules/Orders/CustomerOrders.php`, `backend/app/Modules/Orders/Http/Controllers/CustomerOrderController.php` (`index`), `backend/app/Modules/Orders/Http/Resources/CustomerOrderSummaryResource.php`
- Modify: `docs/09-api-contracts.md` §20, `docs/DECISIONS.md` (new `DL-131`), `tasks/APPLE_BATCH.md` (stage 11's row «Merged (PR #133)», a Risks line)
- Test: `backend/tests/Feature/Orders/CustomerOrdersListApiTest.php`

**Interfaces:**
- Produces, on each summary: `pending_approval_expires_at` — the open questions' (`pending`, `expires_at` after the instant of the request) expiries as ISO-8601 Zulu strings, earliest first, exactly `pending_approval_count` of them; `preview` — `{line_count, lines: [{name_uz, name_ru, image_url}]}`: the preview lines are the lines not removed, or, for an order whose every line is removed, those the Customer did not remove themselves (`customer_removed`); `line_count` counts them; `lines` holds the first `min(line_count, 4)` of them in line order (created, then id), names from the line's snapshots, `image_url` the product's current picture (`ProductImages`), else `null`.
- `Order::openApprovals(): HasMany` (pending, ordered by `expires_at`, then id); `Order::previewItems(): HasMany` (items other than the Customer's own removals, the not-removed first, then created, then id); `CustomerOrders::withPendingApprovalCount(Builder $orders, ?CarbonInterface $at = null)` and `CustomerOrders::withPreviewLineCount(Builder $orders)` (adds `preview_line_count`).

- [ ] **Step 1: Write the failing tests** in `CustomerOrdersListApiTest`:
  - `test_the_summary_lists_the_open_questions_expiries_earliest_first`: an order with pending approvals expiring at +9 and +4 minutes, one pending at −1 minute, one approved, and another order's pending one → `pending_approval_expires_at` is `[+4, +9]` as Zulu strings and `pending_approval_count` is 2; an order with none → `[]`.
  - `test_the_preview_names_the_first_lines_and_counts_them`: ten lines created in order, the third removed `unavailable`, the fifth removed `customer_removed`, the second's product without a picture → `line_count` 8, `lines` the 1st, 2nd, 4th and 6th lines' `name_uz`/`name_ru` snapshots, `image_url` null for the 2nd and the products' current picture URLs for the others.
  - `test_a_cancelled_order_previews_its_lines_but_the_customers_own_removals`: a cancelled order (every line `order_cancelled`, one earlier `customer_removed`) of three lines in all → `line_count` 2, two `lines`.
  - `test_the_list_queries_do_not_grow_with_its_orders`: the query count for a page with one order of two lines equals the one for twenty orders of twelve lines each (`DB::enableQueryLog`).
  - The tests that assert the summary's exact keys gain the two new ones.
- [ ] **Step 2: Run them red:** `docker compose -f docker/compose.yaml exec app php artisan test --filter=CustomerOrdersListApiTest --fail-on-warning` — the new tests fail on the missing keys.
- [ ] **Step 3: Implement.** The controller takes one `$at = now()` for the count and the eager constraint (`openApprovals` with `expires_at > $at`, selecting `id, order_id, expires_at`), and eager-loads `previewItems` with `->limit(4)` (per-parent limit) plus the product's picture. `preview_line_count` is one sub-select: the count of lines not removed, or, when that is 0, the count of lines not removed by the Customer. The resource slices `previewItems` to `min(preview_line_count, 4)`.
- [ ] **Step 4: Run green** (the filter above, then the whole `Orders` folder) and `vendor/bin/pint --test`, `vendor/bin/phpstan analyse`.
- [ ] **Step 5: Docs.** `docs/09` §20's summary list gains both keys with their rules and `DL-131` (1), (2). `DL-131` — «The Apple batch, stage 12: my orders (2026-11-05, agent)» — records, numbered:
  1. `pending_approval_expires_at` carries every open question's expiry, not only the earliest (`orders-5`), so the strip can count down each and fold at the last.
  2. `preview` as above; the names are the lines' snapshots and the pictures current (`DL-91` (1)); a cancelled order previews what was ordered, as a reorder takes it (§26).
  3. Each tab is an endless feed; a reload asks again for every page it had; «Прошлые» loads with the screen, for its count and the empty «Текущие»; past orders stand under Tashkent month headings («Октябрь», another year «Декабрь 2025»); «Текущие» has none.
  4. On the list the 30 s refresh keeps trying after a failure while the list is shown (the page: «обновление пробует дальше само»), unlike the order page (`DL-130` (7)); the stale line is on «Текущие» only; a failed pull on «Прошлые» is announced and keeps the list.
  5. The list card's stages read «Принят · Сборка · В пути · Доставлен» (its page) and the order page's keep «Принят · Покупаем · Везём · Доставлен» (its page): one stage bar, two label sets, each as approved.
  6. The phone's clock counts down only a question it saw running (`DL-130` (6)); one whose deadline already passed on the phone when it arrived counts, without a chip, until the next load.
  7. An order that leaves «Текущие» with a past status shows it (the bar fills), is announced, and folds into «Прошлые» 1.7 s later, whose count then goes up; one the Customer cancelled on its page (`DL-113`) leaves quietly; one not found in «Прошлые» folds at once without words. Changes found while the list is covered or hidden are drawn but not announced and do not buzz.
  8. A new question buzzes lightly on the list (its page), unlike an arrival on the order page (`DL-130` (10)).
  9. `Fold`'s built 300/260 ms stand for the page's 320/280.
  10. How `orders-2`, `orders-3`, `orders-5` were reproduced (filled in by the lead).
  11. The stars are 44 × 44, not the drawn 40 × 44: the batch's 44 rule (`DL-117`) stands; at 360–430 dp the row wraps «Повторить» under the stars either way.
  12. A rating tap lights the stars up to it with a pop and a haptic and opens the rating screen when the last pop ends (45 × (stars − 1) + 340 ms; at once with reduced motion); back from it the stars are unlit.
- [ ] **Step 6: Commit** `feat(orders): the list summary carries the open questions' expiries and a preview of the lines (DL-131)`.

### Task 2: Client data — the summary's new fields

**Files:**
- Modify: `frontend/lib/features/orders/domain/customer_orders.dart`, `frontend/lib/features/orders/data/customer_orders_api.dart` (`parseSummary`), `frontend/test/support/fake_customer_orders_repository.dart`
- Test: `frontend/test/features/orders/data/customer_orders_api_test.dart`

**Interfaces:**
- Produces: `final class OrderPreviewLine { nameUz, nameRu: String; imageUrl: String? }`; `final class OrderPreview { lineCount: int; lines: List<OrderPreviewLine> }`; `OrderSummary.questionDeadlines: List<DateTime>` (earliest first) and `OrderSummary.preview: OrderPreview`.
- Fake: `orderSummaryJson({…, List<String>? deadlines, int? previewCount, List<Map<String, Object?>>? previewLines})` — defaults: `waiting` copies of `'2026-09-28T07:10:00Z'`, `previewCount` = `itemCount`, lines «Pomidor»/«Помидоры», «Sut»/«Молоко домашнее», «Non»/«Лепёшка», «Tuxum»/«Яйца домашние» cut to `min(previewCount, 4)`, pictures null. `FakeCustomerOrdersRepository` gains `int perPage = 20` (the list is cut into pages of it, `lastPage` and `total` true) and `Map<OrdersTab, ApiFailure> listFailures` (the tab's next list load fails once).

- [ ] **Step 1: Failing tests** in `customer_orders_api_test.dart`: `'a summary reads its question deadlines and preview'` (two deadlines, preview of 10 with 4 lines); `FormatException` for: deadlines not as many as `pending_approval_count`; deadlines out of order; `preview.lines` more than 4; `lines` not `min(line_count, 4)`; a missing `preview` or deadlines key; a line without `name_ru`.
- [ ] **Step 2: Run red:** `flutter test test/features/orders/data/customer_orders_api_test.dart`.
- [ ] **Step 3: Implement** the types and the strict parse (`JsonFields`), and the fake's new parameters and paging.
- [ ] **Step 4: Run green**, then `test/features/orders/` whole (every fixture goes through `orderSummaryJson`).
- [ ] **Step 5: Commit** `feat(orders): read the summary's question deadlines and line preview (DL-131)`.

### Task 3: Client state — the endless feed

**Files:**
- Modify: `frontend/lib/features/orders/application/customer_orders_controllers.dart` (`OrdersPageController`, `ordersPageProvider`, `CustomerOrdersListController` go; `OrderCancelController` drops through the feed), `frontend/lib/core/state/list_page_controller.dart` (deleted if nothing else uses it — check with grep), callers of `customerOrdersProvider` (`checkout_controllers.dart` keeps its `invalidate`)
- Test: `frontend/test/features/orders/application/customer_orders_controllers_test.dart`

**Interfaces:**
- Produces:
```dart
final class OrdersFeed {
  final List<OrderSummary> rows;   // newest first, no id twice
  final int total;                 // the server's, minus rows dropped since
  final int? nextPage;             // null at the end
  final int pages;                 // pages loaded
  final DateTime at;               // when the last whole load came (clockProvider)
  final bool loadingMore;
  final ApiFailure? moreFailure;
  final Set<String> dropped;       // ids `drop` took off since the last load
  bool get hasMore;
}
class CustomerOrdersFeed extends AsyncNotifier<OrdersFeed> {
  CustomerOrdersFeed(this.tab);
  Future<void> loadMore();
  void drop(String id);
}
final AsyncNotifierProviderFamily<CustomerOrdersFeed, OrdersFeed, OrdersTab> customerOrdersProvider; // autoDispose
```
- `build()` (after `ref.invalidate` too) loads pages 1 … max(1, pages it had) one after another, stopping at the last page, keeping the first row of each id; another account (or none) starts at page 1; a page answering after the list was rebuilt is dropped by generation, as `ProductListController` does. Riverpod keeps the previous value while a reload runs and after it fails. `loadMore` runs one at a time, never while a reload runs or after one failed, keeps the rows on failure (`moreFailure`) and is called again to retry. `drop` (case-insensitive id) takes the row off, lowers `total`, adds the id to `dropped`; it does nothing before the first answer, during a reload, after a failure or for an id not shown.

- [ ] **Step 1: Failing tests:** `'a reload asks again for every page it had and shows no order twice'` (45 past orders, `perPage` 20, `loadMore` once, a new order put first, `invalidate` → loads `orders:past:1`, `orders:past:2`; 40 rows, the new one first, the order pushed from page 1 to 2 once); `'a failed reload keeps the rows and their time'`; `'load more fails in place and loads on the next call'`; `'a page that lands after the account changed is dropped'` (`holdList`); `'another account starts at page 1'`; `'drop takes the row off and names it dropped until the next load'`; `'a sure cancellation drops the order from Текущие'` (rewritten from the `dropRow` test).
- [ ] **Step 2: Run red.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run green**, then `flutter analyze` (the old list screen may read `.items`/`PaginationBar`: adapt it minimally so the app builds — Task 6 rewrites it).
- [ ] **Step 5: Commit** `feat(orders): each tab of the list is an endless feed that keeps its pages on reload (DL-131)`.

### Task 4: The shared stage bar and the current card

**Files:**
- Create: `frontend/lib/features/orders/presentation/order_stage_bar.dart` (`_StageBar` of `order_sections.dart` made public and parameterised), `frontend/lib/features/orders/presentation/order_card_words.dart` (the cards' spoken words)
- Modify: `order_sections.dart` (uses `OrderStageBar`), `order_cards.dart` (`CurrentOrderCard`, `_QuestionStrip`; `OrderProgressBar` goes if unused), the ARB files, `kit_colors.dart` (`outline`)
- Test: `order_cards_test.dart`, `order_progress_test.dart`, `order_sections_test.dart` (unchanged behaviour)

**Interfaces:**
- Produces:
```dart
class OrderStageBar extends StatelessWidget {
  const OrderStageBar({required this.stage, required this.labels, this.times, this.currentLabel, this.semanticsLabel, super.key});
  final int stage;               // orderStage(status)
  final List<String> labels;     // four
  final List<DateTime?>? times;  // the order page's
  final String? currentLabel;    // the list's current row at large text (the order page: its heading)
  final String? semanticsLabel;  // null: excluded, the card speaks for it
}
List<String> orderPageStageLabels(AppLocalizations l10n);  // Принят, Покупаем, Везём, Доставлен
List<String> orderListStageLabels(AppLocalizations l10n);  // Принят, Сборка, В пути, Доставлен
String currentOrderSpoken(AppLocalizations l10n, AppLanguage language, OrderSummary order, DateTime now, {int? minutesLeft});
class CurrentOrderCard extends ConsumerWidget { const CurrentOrderCard({required this.order, this.questions, this.deadline, super.key}); }
```
- `questions` (default `order.pendingApprovalCount`) and `deadline` (default the first `questionDeadlines` entry after now, else null) are what the strip shows; Task 7 passes them from its clock. The keys `order-stage-$i`, `order-stage-label-$i`, `order-stages-list`, `order-stage-icon-$i` stay; the card keeps `order-${id}`, `order-answer-${id}`, `order-call-courier-${id}` and adds `order-status-${id}`, `order-waiting-${id}` (the strip).
- `currentOrderSpoken` joins with «. »: `customerOrderTitle`; `orderCardStageSpoken(status, stage)`; when questions, `orderCardQuestion(n)` plus «, » `deadlineLeftSpoken(m)` when minutes are known; the sum (`orderCardEstimateSpoken(amount)` for an estimate, the amount for a final one, `totalNothingDue`); `orderAt(…)` «, » `orderItemCount(n)`.

- [ ] **Step 1: Failing tests:** `'the card heads with the status and says the number small'` (headline «Собирается» 16 w700; «Заказ № 1044 · 8 товаров» under it); `'the stages read Принят Сборка В пути Доставлен, a check on those passed, the current bold'`; `'the stage segments change colour softly'` (mid-way at 250 ms after a status change; at once with reduced motion); `'at large text the stages stand as a list and the sum takes its own line'`; `'the question strip sits under the status with the minutes left, red at three'`; `'at large text the strip's Ответить takes the whole width'`; `'the card reads status first with its stage and Примерно'` — the label is «Заказ № 1044. Собирается, этап 2 из 4. Сборщик спрашивает про 1 товар, осталось 9 минут. Примерно 86 000 сум. Сегодня в 12:40, 8 товаров»; `'Ответить and Позвонить курьеру name their order'`; the guideline at 100 % and 200 %. The order page's stage tests still pass with «Покупаем», «Везём».
- [ ] **Step 2: Run red.**
- [ ] **Step 3: Implement** (strings, token, `OrderStageBar` with `TweenAnimationBuilder` colours, the card in the page's order: top row — 56 picture box, headline and two small lines — strip, stages, date and sum, call button).
- [ ] **Step 4: Run green** with `test/features/orders/presentation/`.
- [ ] **Step 5: Commit** `feat(orders): a current card heads with its status over labelled stages and the question's deadline (DL-131)`.

### Task 5: The past card, the stars, «Повторить» and the last-order card

**Files:**
- Create: `frontend/lib/features/orders/presentation/order_preview.dart`
- Modify: `order_cards.dart` (`PastOrderCard`, `_RateBoxes` → `OrderRateStars`, `_RatedStars`, new `LastOrderCard`), `order_card_words.dart`, `reorder_sheet.dart` (`RepeatOrderButton`), the ARB files
- Test: `order_cards_test.dart`, `reorder_sheet_test.dart`

**Interfaces:**
- Produces:
```dart
String previewNames(AppLocalizations l10n, AppLanguage language, OrderPreview preview); // «Помидоры» / «Помидоры, Молоко домашнее» / «Помидоры, Молоко домашнее и ещё 8»
class OrderPictures extends StatelessWidget { const OrderPictures({required this.preview, super.key}); } // up to 4 lines: a tile each; more: 3 tiles + «+N» (N = lineCount − 3); no lines: one placeholder tile; a null picture: the app's placeholder
String pastOrderSpoken(AppLocalizations l10n, AppLanguage language, OrderSummary order, DateTime now);
class OrderRateStars extends StatefulWidget { const OrderRateStars({required this.order, super.key}); }
class LastOrderCard extends ConsumerWidget { const LastOrderCard({required this.order, super.key}); }
RepeatOrderButton({required orderId, required orderNumber, required wide, bool outlined = false})
```
- Past card, from top: `OrderPictures` beside the status chip (at most half the row), names, «Заказ № 1042 · street, house», date and sum, then the rating block (caption over the stars, `Wrap` with `spaceBetween`, 8 and 8, stars and «Повторить») or «Повторить» alone at the end. `pastOrderSpoken` joins with «. »: `customerOrderTitle` «, » the status lower-cased; `previewNames`; `orderWhen(…)`; the sum (as Task 4). A name is the interface language's (`name_ru` for Russian).
- `OrderRateStars`: rateable — five 44 × 44 buttons, each `orderRateStarsSpoken(number, k)`, in a group labelled `orderRateCaption`; a tap on k lights 1…k with the pop, `HapticFeedback.lightImpact`, then after 45 × (k − 1) + 340 ms pushes `AppPaths.customerOrderRate(id, stars: k)` (at once with reduced motion; a second tap meanwhile is ignored); back from it the stars are unlit. Rated — one node `orderRatedSpoken(stars)` under `orderRatedCaption`.
- `LastOrderCard`: `OrderPictures`, names, «{orderWhen} · {sum}», the outlined «Повторить» at the row's end; a tap opens the order; it reads as `pastOrderSpoken`.
- «Повторить» reads `reorderRepeatSpoken(number)`; busy, `reorderSending`.

- [ ] **Step 1: Failing tests:** `'ten lines show three pictures and +7'`; `'four lines show four pictures, one shows one'`; `'the names read Помидоры, Молоко домашнее и ещё 8'` (and the one- and two-line forms); `'a rateable order says Оцените заказ with five outline stars'`; `'a tap lights the stars up to it, buzzes, then opens the rating screen with them'` (route `…/rate?stars=3` after 430 ms, not before; one `HapticFeedback.vibrate` `lightImpact` call); `'with reduced motion the rating screen opens at once'`; `'a rated order says Ваша оценка with its stars'`; `'Повторить is 44 high and names its order'`; `'the past card reads Заказ № 1042, доставлен. Помидоры, Молоко домашнее и ещё 8. Вчера, 19:45. 86 000 сум'`; `'a cancelled order says К оплате нет'`; `'the last-order card has an outlined Повторить'`; the guideline at 100 % and 200 % (rateable, rated, cancelled, last-order).
- [ ] **Step 2: Run red.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run green** with `test/features/orders/presentation/`.
- [ ] **Step 5: Commit** `feat(orders): a past card shows its products, stars to rate and a 44 px Повторить (DL-131)`.

### Task 6: The screen — segments, kept places, months, endless loading, stale line, empty

**Files:**
- Create: `frontend/lib/features/orders/presentation/orders_list_screen.dart` (`OrdersScreen` moved here, its panes, empty states, month headings, end rows), `frontend/lib/features/orders/presentation/orders_segment.dart`
- Modify: `orders_screens.dart` (`OrdersScreen`, `_TabSwitch`, `_Empty` leave), `orders_routes.dart` (import), `core/formatting/order_dates.dart` (`monthHeading`), the ARB files
- Test: create `frontend/test/features/orders/presentation/orders_list_screen_test.dart` (the list tests of `orders_screens_test.dart` move here, rewritten where they pinned the old drawing)

**Interfaces:**
- Consumes: `customerOrdersProvider` (Task 3), `CurrentOrderCard`, `PastOrderCard`, `LastOrderCard` (Tasks 4, 5).
- Produces: `OrdersScreen()` (unchanged constructor); `class OrdersSegment extends StatelessWidget { const OrdersSegment({required this.tab, required this.currentCount, required this.pastCount, required this.pastBumps, required this.onTab, super.key}); }` (`pastBumps` counts the past count's rises, each one bump); `String monthHeading(AppLocalizations l10n, DateTime instant, DateTime now)` (Tashkent month; another year adds it).
- Screen rules: it watches both feeds. The panes are two scroll views kept mounted (the hidden one under `Offstage` and `TickerMode` off), each with its own `ScrollController`; the shown one is the `PrimaryScrollController` above the `Scaffold`, so a re-tap on «Заказы» scrolls it to the top (`DL-118`); a tap on the chosen segment does the same (300 ms `Curves.easeOutCubic`, a jump with reduced motion). A pane without a value shows three skeleton cards as one node `ordersLoading`; without a value and with an error, `LoadFailure` as today. «Текущие»: `PeriodicRefresh` of 30 s, active while the feed has a value and no load runs (failed or not); `StaleDataLine` (key `stale-line`, padding 20/0/20/8) inside a `Fold` while the feed has a value and an error, busy while loading, its button refreshing; the cards in a `FoldingColumn`; a pull refreshes and announces like `OrderScreen._refresh`. «Прошлые»: a lazy `CustomScrollView` with month headings (`Semantics(header: true)`), cards, then two skeleton cards while `hasMore`, or the row «Нет связи · Повторить» (52 high, 13 px, `retryButton` calling `loadMore`) on `moreFailure`; `loadMore` when `extentAfter < 720` and after a build that leaves the content shorter than that; a pull refreshes it and a failure is announced. Counts: «Текущие» = its `total` (+ cards still folding out, Task 7), «Прошлые» = its `total`; a count shows after the label when above 0; the segment's semantics: role tab, `selected`, label «Текущие, 2 заказа» (`ordersCount`). Empty «Текущие» with «Прошлые» loaded and not empty: the page's `emp2` (icon circle 72 with a 34 icon, title as a header, `ordersLastOrderText`, `LastOrderCard` of the newest past order, «За покупками» full width to home, the 44 link `ordersAllPast` spoken `ordersAllPastSpoken` switching to «Прошлые»); while «Прошлые» has no answer, skeletons; «Прошлые» empty or failed, the plain empty as today.

- [ ] **Step 1: Failing tests** (run red on main's screen first where they exist there — `orders-2`, `orders-3` reproduction): `'switching tabs keeps each list and its place and loads nothing again'` (past scrolled to 600; current and back → 600; no second `orders:past:1`); `'the thumb slides and the list comes in from its side'` (mid-way at 150 ms; at once with reduced motion, a fade); `'the first visit shows skeletons, not a spinner'`; `'the segments count their orders and say so'` («Текущие · 2», «Прошлые · 25»; label «Текущие, 2 заказа», selected); `'a failed refresh keeps the list under the stale line and the next tick tries again'`; `'refreshes never overlap'` (a held load and a tick: one request); `'pulling refreshes and says so'`; `'a reload of a deep past list keeps the offset'`; `'past orders stand under month headings and load on as you scroll'` (45 orders over Oct/Sep/Aug, `orders:past:2` at the end, the end skeletons, «Октябрь», «Сентябрь» headers); `'a page that fails at the end says Нет связи · Повторить and loads on retry'`; `'with no current orders the last one is offered'` (title, «Последний заказ — вчера…», the last-order card, «Все прошлые заказы · 25» → «Прошлые» chosen); `'with no orders ever the screen invites to shop'`; `'a re-tap on Заказы scrolls the shown tab to the top'`; the guideline at 100 % and 200 % for each state; at 200 % on 360 dp the segment with counts does not overflow.
- [ ] **Step 2: Run red.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run green** with `test/features/orders/`, `test/core/`, `test/app/route_pages_test.dart`.
- [ ] **Step 5: Commit** `feat(orders): the list keeps both tabs and their places, months, endless loading and the stale line (DL-131)`.

### Task 7: Live changes and the question's clock

**Files:**
- Create: `frontend/lib/features/orders/application/orders_changes.dart`
- Modify: `orders_list_screen.dart`, `order_cards.dart` (`CurrentOrderCard` glow, the strip's `Fold`), the ARB files
- Test: create `frontend/test/features/orders/application/orders_changes_test.dart`; `orders_list_screen_test.dart`

**Interfaces:**
- Produces:
```dart
typedef CurrentChanges = ({
  List<OrderSummary> questionsArrived,  // 0 → n
  List<OrderSummary> questionsGrew,     // n → m > n
  List<({OrderSummary order, OrderStatus from})> moved,
  List<OrderSummary> appeared,
  List<OrderSummary> left,              // the last summary of each order gone, those in `dropped` left out
});
CurrentChanges currentChanges(List<OrderSummary> before, List<OrderSummary> after, {Set<String> dropped = const <String>{}});
```
- The screen compares the rows of two successive loads of «Текущие» (not the first load, not across accounts). A new question: the strip unfolds, `HapticFeedback.lightImpact`, `orderAnnounced(number, question lower-cased)` plus «. » and `deadlineLeftSpoken` capitalised when a running deadline exists. More questions: the glow, the haptic, the same words. A move: the glow, the headline fades in, the stages refill, the call button unfolds when a phone comes; `orderOnTheWayAnnounced` for on the way, else `orderAnnounced(number, status lower-cased)`. An order gone: its last card stays while «Прошлые» reloads; found there `completed` or `cancelled`, the card shows that status (the bar fills on delivery), glows, says `orderDeliveredAnnounced` / `orderCancelledAnnounced`, and 1700 ms later leaves the `FoldingColumn`; the «Прошлые» count leaves it out until then and bumps when it is counted; not found, or the reload failed, it leaves at once without words. Announcements and haptics only while the list's route is current and its tab shown; otherwise the change is drawn quietly.
- The strip's clock (`DL-131` (6)): per order the card's state keeps the deadlines it saw ahead of the phone's clock. Open = the server's count less the seen deadlines now passed; the chip shows the earliest seen deadline still ahead (none: no chip); a `Timer` wakes at it. When open reaches 0 the strip folds 400 ms later and `orderQuestionsExpiredAnnounced(number)` is said; it stays folded until a load brings a question. A load resets the clock to the new deadlines.

- [ ] **Step 1: Failing tests:** pure — `'a question on an order with none arrives, more grow, a status change moves, a new order appears, a gone one leaves unless dropped'`; screen — `'a new question unfolds its strip, buzzes lightly and is announced'`; `'the courier leaving fills the bar, glows, unfolds the call button and is announced'`; `'a delivered order says Доставлен, then folds into Прошлые, whose count goes up by one'`; `'an order the Customer cancelled leaves without words'`; `'an order gone and not in Прошлые leaves at once'`; `'the strip counts down and folds at the deadline with an announcement'` (`orders-5` reproduction: red on main's card — 9 → 3 min red → gone, «Время ответа на вопрос по заказу № 1044 вышло»); `'with two questions the strip counts down to one, then folds'`; `'a deadline already past on the phone keeps the strip without a chip until the next load'`; `'changes found while the order page covers the list are not announced'`; `'with reduced motion nothing glows and strips appear at once'`.
- [ ] **Step 2: Run red.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run green** with `test/features/orders/`, then `flutter analyze` and `dart format --set-exit-if-changed lib test`.
- [ ] **Step 5: Commit** `feat(orders): list changes arrive softly and aloud; a question's strip folds at its deadline (DL-131)`.

### After the tasks (the lead)

- [ ] `DL-131` (10) filled in; `tasks/APPLE_BATCH.md` residual findings parked with rulings.
- [ ] Full suites (`test-runner`): frontend `flutter test --concurrency=2`, backend `php artisan test --fail-on-warning`; `pint --test`, `phpstan analyse`, `flutter analyze`, `git diff --check`.
- [ ] Final review (`branch-reviewer`, opus) → one fix wave → scoped re-review; `/security-review`; PR, both checks green, merge.
