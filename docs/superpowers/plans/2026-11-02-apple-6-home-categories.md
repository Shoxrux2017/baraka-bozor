# Apple Stage 6 — Home and Categories Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The home is one scroll: the mode bar and the address scroll away, the search (now full width — the filter button is gone) sticks with a shadow; skeletons stand in while it loads, a failed refresh keeps what was shown under «Нет связи · данные на 12:46 · Обновить», and a pull refreshes; a Shopper's question unfolds with «Осталось 9 мин» (red from 3), a count on «Заказы», and folds at its expiry; at night a calm line says «Сейчас закрыто. Заказ примем сейчас, соберём и привезём с 8:00»; at 200 % text the categories stand in two columns and the recommended cards widen; a screen reader hears «Адрес доставки: …», «Все категории», a card as one phrase and buttons that name the product. «Все категории» is titled «Категории», shows the cart bar, fits its columns to the width, presses its tiles to 0.96, flies the picture into the category's rail, refreshes by a pull, keeps its tiles offline and reads «Бахча, кнопка».

**Architecture:** The cart answer gains `working_hours` (the one Customer resource every screen with a cart button already holds), and the home derives "closed now" from it for display only; checkout's preview stays the authority. New shared pieces go to `core/`: `Loaded<T>` (data with the time it was loaded), `StaleDataLine`, `PressScale`, `DeadlineChip`, `SkeletonBar.radius`, `ProductImage.fadeIn`. Both category grids share one column rule and one `CategoryButton`; a tile hands a per-tile hero tag to the category route as `extra`, as the product card does (`DL-122` (1)). The home becomes one `CustomScrollView` with a pinned search header. Open questions become a provider that drops a question at its expiry, watched by the banner and the tab bar.

**Tech Stack:** Laravel 12 / PHP 8.4 (in Docker), Flutter 3.47.5, flutter_riverpod 3.4.3, go_router (`extra`), `CustomScrollView` + `SliverPersistentHeader`, `RefreshIndicator`, `Hero`, flutter_test (`tester.takeAnnouncements()`, `meetsGuideline(iOSTapTargetGuideline)`, `SystemChannels.platform` mock for haptics, a mutable `clockProvider` override).

**Spec:** `tasks/APPLE_BATCH.md` stage 6 (items `home-2` … `home-10`, `cats-1` … `cats-7`; `home-2` **repro**, `home-10` **Owner** **server**); the live tests «Тест главной - Apple» and «Тест всех категорий - Apple» in the Claude Design project "BarakaBozor — стиль покупателя" (their "стало" state is the picture); `DL-75`, `DL-80`, `DL-83`, `DL-117` … `DL-124`; `docs/07` section 26; `frontend/AGENTS.md`.

## Global Constraints

- Changes stay in `backend/app/Modules/Settings`, `backend/app/Modules/Orders`, `backend/tests`, `frontend/`, `docs/` and `tasks/`. No package, no lockfile change. Generated localizations come from `flutter gen-l10n`, never by hand.
- Strings (ru / uz), new:
  - `staleOffline` «Нет связи» / «Aloqa yo'q»; `staleFailed` «Не удалось обновить» / «Yangilab bo'lmadi»; `staleShownAt` «данные на {time}» / «{time} holatiga»; `staleRefresh` «Обновить» / «Yangilash»; `staleSpoken` «{reason}. Показаны данные на {time}» / «{reason}. {time} holatidagi ma'lumotlar ko'rsatilgan»; `refreshDone` «Обновлено» / «Yangilandi»
  - `deadlineLeft` «Осталось {minutes} мин» / «{minutes} daqiqa qoldi»; `deadlineLeftSpoken` «осталось {minutes, plural, one{# минута} few{# минуты} many{# минут} other{# минуты}}» / «{minutes} daqiqa qoldi»
  - `questionBannerUntil` «Заказ № {number} · до {time}» / «Buyurtma № {number} · {time} gacha»; `questionSpoken` «Сборщик ждёт вашего ответа. Заказ № {number}, {left}. Ответить» / «Yig'uvchi javobingizni kutmoqda. Buyurtma № {number}, {left}. Javob berish»; `questionArrived` «Сборщик спрашивает про заказ № {number}. {left}» / «Yig'uvchi № {number} buyurtma haqida so'ramoqda. {left}»; `questionExpired` «Время на ответ вышло» / «Javob berish vaqti tugadi»; `homeNavOrdersWaiting` «Заказы, ждут ответа: {count}» / «Buyurtmalar, javob kutilmoqda: {count}»
  - `homeClosedTitle` «Сейчас закрыто.» / «Hozir yopiq.»; `homeClosedBody` «Заказ примем сейчас, соберём и привезём с {time}» / «Buyurtmani hozir qabul qilamiz, soat {time} dan yig'ib, yetkazib beramiz»
  - `deliveryAddressSpoken` «Адрес доставки: {address}. Изменить» / «Yetkazib berish manzili: {address}. O'zgartirish»; `catalogSearchSpoken` «Поиск товаров» / «Mahsulotlarni qidirish»; `homeCategoriesAll` «Все категории» / «Barcha kategoriyalar»; `recommendedAll` «Все рекомендуемые» / «Barcha tavsiyalar»
  - `cardSpoken` «{name}, примерно {price} за {unit, select, …}» / «{name}, taxminan {price}, 1 {unit, select, …} uchun» — the `select` cases copied from `productPriceSpoken`; `cardInCartSpoken` «{card}. В корзине {quantity}» / «{card}. Savatda {quantity}»; `cardAddSpoken` «Добавить в корзину: {name}» / «Savatga qo'shish: {name}»; `cardStepperSpoken` «{name} в корзине» / «{name} savatda»; `favoriteAddSpoken` «Добавить в избранное: {name}» / «Sevimlilarga qo'shish: {name}»; `favoriteRemoveSpoken` «Убрать из избранного: {name}» / «Sevimlilardan olib tashlash: {name}»
  - `cartSummarySpoken` «Корзина: {count}, примерно {sum}. В корзину» / «Savat: {count}, taxminan {sum}. Savatga» (`count` is `cartSummaryCount(n)`)
  - Removed once nothing uses them (grep `lib` and `test` first): `questionBannerOrder`. `catalogCategoriesTitle` stays (the order editor's picker uses it); «Все категории» is titled with `homeCategories`.
- A quantity is written `'${QuantityRules.display(q)} ${CatalogLabels.unit(l10n, unit)}'`, spoken phrases included; only a price phrase uses the unit's full word (`DL-122` (5)).
- Amounts (`AGENTS.md` §5): the cart bar's sum is the cart's `estimatedSubtotalUzs` through `catalogApproxPrice` («≈ …»), as now. Working hours are display only: the closed line never blocks or changes an order; checkout's `outside_working_hours` stays the authority (`docs/07` section 26).
- Category columns, one rule for the home and «Все категории»: `max(2, ((width - 20) / (scaler.scale(88) + 12)).round())`, `width` the grid's width inside the side safe areas; gap 12, side padding 16; names in 3 lines and the picture at 0.52 of the well when the columns are 2, else 2 lines and 0.7.
- The recommended row's card is `min(260, max(150, scaler.scale(150)))` wide; its height stays `kitCardExtent(...)`.
- Motion, exactly: a pressed tile scales to 0.96 in 120 ms `Curves.easeOut` and back in 120 ms, no ripple; a tile's picture flies to the rail's selected well and back as a `Hero` with the shuttle `categoryWellFlight` (radius 14 → 12); data that replaces skeletons fades in over 200 ms `Curves.easeOut`; a category picture not loaded at once fades in over 250 ms `Curves.easeOut`; a tile new after a refresh comes in from scale 0.85 and opacity 0 in 250 ms `Curves.easeOut`; the stale line fades in over 200 ms `Curves.easeOut`; the search's shadow comes and goes in 200 ms; the question banner and the closed line come and go through `Fold` (its 300 ms unfold and 260 ms fold, `DL-119`). With `MediaQuery.disableAnimationsOf(context)`: no scale, no `Hero`, no fades; `Fold` stands still as it does.
- Skeletons are `SkeletonBar`s: pulsing while a load runs, still after it failed.
- Haptic: `HapticFeedback.lightImpact()` once when a question appears after a loaded answer that had none.
- Colours are `KitColors` tokens, except the search header's shadow `Color(0x59151D16)`.
- No `FittedBox` and no ellipsis on a price, a sum or a time this stage draws; amounts never break inside a word (`DL-120` (2)).
- Every screen this stage rewrites — the home and «Все категории» — passes `meetsGuideline(iOSTapTargetGuideline)` (batch rule).
- Tests that pinned the old drawing are rewritten to the new rule, each named in its task; no other test is deleted or weakened.
- Flutter runs from PowerShell with `$env:TEMP='G:\tools\tmp'; $env:TMP='G:\tools\tmp'` and `G:\tools\flutter\bin\flutter.bat`; a full suite uses `--concurrency=2`. Backend commands run as `docker compose -f docker/compose.yaml exec app …` from the repo root. Never run destructive artisan commands (`migrate:fresh`, `db:wipe`, `--env=testing` on the dev database).
- Comments read like the surrounding code: short `///` docs in plain English that name `DL-125`.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- `/security-review` once before the pull request (a server field).

## Review Focus

1. The clock across a boundary while the home is shown: at 07:59 → 08:00 the closed line folds away; at 21:59 → 22:00 it appears; hours over midnight (22:00–02:00) are closed at 03:00 and open at 23:00; always open (00:00–23:59) and unset hours never show it. Task 8 tests `'the line folds away at opening while the home is shown'`, `'hours over midnight'`, `'no line while open, always open or unset'`.
2. Offline after a load: a pull that fails keeps the tiles, the cards and the question, and the line says the first load's time; a later pull that succeeds removes the line and announces «Обновлено»; a cold failure shows «Нет связи · Повторить» over still skeletons and «Повторить» reloads. Task 3 tests `'offline after a load keeps the tiles with the stale line and its time'`, `'a first load that fails shows Нет связи · Повторить over still skeletons'`; Task 5 the home's twins.
3. A question while the home is shown: it reaches its expiry (folds, «Время на ответ вышло», the badge goes in the same frame), a refresh fails before it (stays), it is answered on the order page (folds, no announcement), two wait (the earliest shows, the badge says 2). Task 7 tests.
4. Large text × 2 on 320 × 640, ru and uz, with two sessions, a question, the closed line and the stale line: one scroll, the search pinned and hit-testable, nothing overflows, every target meets the guideline. Task 5 test `'one scroll: at text x2 with two sessions and a question the address scrolls away and the search sticks'`, Task 9 guideline test.
5. One category on two screens in the stack (its home tile and its «Все категории» tile): push and pop raise no "multiple heroes share the same tag"; a rail switch and then back flies nothing and throws nothing. Task 4 tests `'one category on two screens opens and closes without a hero clash'`, `'after a rail switch back flies nothing'`.

---

### Before the tasks (the lead)

- [ ] Reproduce `home-2` on the `barakabozor` emulator with main's build (batch rule **repro**): font size at 200 %, a Shopper in Customer mode (two sessions): the header (mode, address, search) takes about half of the screen and the categories scroll in a strip under it. Screenshots `G:/tools/tmp/apple6-repro-*.png`. Task 5's first test is this reproduction.

### Task 1: The cart answers the working hours (server)

**Files:**
- Modify: `backend/app/Modules/Settings/WorkingHours.php` (`closesAt()`), `backend/app/Modules/Orders/Http/Resources/CartResource.php`, `backend/app/Modules/Orders/Http/Controllers/CartController.php`
- Modify: `docs/09-api-contracts.md` section 17, `docs/05-business-rules.md` (`BR-CHK-009`), `docs/01-*.md` section 15 ("the Customer sees that on the home and at checkout")
- Test: `backend/tests/Feature/Orders/CartChargesApiTest.php`, the existing `WorkingHours` unit test (where `opensAt()` is tested)

**Interfaces:**
- Produces: `WorkingHours::closesAt(): string` — `HH:MM`, like `opensAt()`.
- Produces: every cart answer (GET, POST, PATCH, DELETE) carries `"working_hours":{"opens_at":"08:00","closes_at":"22:00"}`, or `null` while either setting is unset or the hours read as always open (`isAlwaysOpen()`). `CartResource` takes `?WorkingHours $hours` next to its charges; the controller builds it from the settings it already reads.

- [ ] **Step 1: Write the failing tests.** `test_the_cart_answers_the_working_hours` (08:00–22:00 → exactly that object); `test_always_open_and_unset_hours_answer_null` (00:00–23:59 → `null`; both unset → `null`); extend `test_every_cart_answer_carries_the_charges` with the `working_hours` key on all four calls; `closesAt()` beside the `opensAt()` test.
- [ ] **Step 2: Run them and see them fail.** Run: `docker compose -f docker/compose.yaml exec app php artisan test --filter=CartChargesApiTest` — Expected: FAIL.
- [ ] **Step 3: Implement**; write the docs lines: docs/09 §17 names the field and its `null`s and says it is for display (checkout decides, section 18); `BR-CHK-009` adds "the home says so while the business is closed (`DL-125`)".
- [ ] **Step 4: Run** the filter above, then `… exec app vendor/bin/pint --test` and `… exec app vendor/bin/phpstan analyse`. Expected: PASS, clean.
- [ ] **Step 5: Commit** — `git commit -m "feat(cart): the cart answers the working hours (DL-125)"`

### Task 2: Shared pieces in core

**Files:**
- Create: `frontend/lib/core/state/loaded.dart`, `frontend/lib/core/widgets/stale_data_line.dart`, `frontend/lib/core/widgets/press_scale.dart`, `frontend/lib/core/widgets/deadline_chip.dart`
- Modify: `frontend/lib/core/widgets/skeleton_bar.dart` (`radius`), `frontend/lib/core/widgets/product_image.dart` (`fadeIn`), both `.arb` files (the stale and deadline strings)
- Test: `frontend/test/core/widgets/stale_data_line_test.dart`, `press_scale_test.dart`, `deadline_chip_test.dart` (create); the existing skeleton and product image tests

**Interfaces:**
- Produces: `final class Loaded<T> { const Loaded(this.data, {required this.at}); final T data; final DateTime at; }`.
- Produces: `StaleDataLine({required ApiFailure failure, required DateTime? shownAt, required VoidCallback onRetry, Key? key})`, keyed `stale-line` by callers. `KitColors.field`, radius 12, padding left 12 right 4; `Icons.cloud_off` 18 `KitColors.muted`, 8; text 12 `KitColors.ink2`, `Expanded`: the reason (`staleOffline` for a `NetworkFailure`, else `staleFailed`) and, with `shownAt`, `' · ${staleShownAt(TashkentTime.time(shownAt))}'`; a `TextButton` keyed `stale-retry`, at least 44 × 44, padding 0 × 10, 12 `w600` `KitColors.primaryDark`: `staleRefresh` with `shownAt`, else `retryButton`. The text is one live-region node: `staleSpoken(reason, time)`, or the reason alone without `shownAt`. Fades in as Global Constraints say. Callers place it with their own margin.
- Produces: `PressScale({required String label, required VoidCallback onTap, required Widget child, Key? key})` — one `Semantics(button: true, label: label, excludeSemantics: true, onTap: onTap)`; a pointer down scales the child to 0.96 and an up inside taps (Global Constraints' motion), a cancel or a drag out restores without a tap; `HitTestBehavior.opaque`; no ink.
- Produces: `int minutesLeft(DateTime deadline, DateTime now)` — whole minutes rounded up, `0` at or after the deadline. `DeadlineChip({required DateTime deadline, Key? key})`, a `ConsumerStatefulWidget` reading `clockProvider`, keyed `deadline-chip` by callers: white, radius 8, padding 3 × 8; `Icons.timer` 16, 4, `deadlineLeft(m)` 12 `w700`, both `KitColors.warningDark`, `KitColors.danger` when `m <= 3`; a `Timer` rebuilds it at each change of `m`; nothing at `m == 0`; excluded from semantics (its parent speaks `deadlineLeftSpoken`).
- Produces: `SkeletonBar.radius` (`double?`, default `height / 2`); `ProductImage.fadeIn` (`bool`, default `false`): a picture not loaded synchronously fades in (`Image.frameBuilder`), at once with reduced motion.

- [ ] **Step 1: Write the failing tests.** `stale_data_line_test.dart`: `'offline with data it says when the data is from and refreshes'` (`NetworkFailure`, 12:46 Tashkent → `Нет связи · данные на 12:46`, `Обновить` calls back, the spoken label `Нет связи. Показаны данные на 12:46`, live region); `'a cold failure offers Повторить'`; `'another failure says Не удалось обновить'`; `'meets iOSTapTargetGuideline at 320 and text x2'`. `press_scale_test.dart`: `'pressing shrinks to 0.96 and a release taps'` (scale 0.96 after 120 ms held; one tap on up); `'a drag out restores without a tap'`; `'with reduced motion it does not scale'`; `'it is one button node with its label'`. `deadline_chip_test.dart`: `'shows the minutes left rounded up and turns red at 3'` (9 min 10 s → `Осталось 10 мин`; 3 min → danger); `'counts down each minute and hides at the deadline'`. `SkeletonBar` `'a radius rounds its corners'`; `ProductImage` `'fadeIn fades a picture that loads later'`.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/core/widgets` — Expected: FAIL.
- [ ] **Step 3: Implement**; `flutter.bat gen-l10n`.
- [ ] **Step 4: Run** `flutter.bat test test/core`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(core): loaded data, the stale line, press scale, the deadline chip (DL-125)"`

### Task 3: «Все категории» and the shared tile

**Files:**
- Modify: `frontend/lib/features/catalog/application/catalog_controllers.dart` (`catalogCategoriesProvider` → `Loaded`) and its users (`home_screen.dart`, `all_categories_screen.dart`, `category_screen.dart`, `more_in_category.dart`, `orders/presentation/order_product_picker.dart`), `category_tile.dart`, `all_categories_screen.dart`, `cart/presentation/cart_summary_bar.dart`, both `.arb` files (`cartSummarySpoken`)
- Test: `frontend/test/features/catalog/category_screens_test.dart` (group `'all categories'`), `catalog_screens_test.dart` where it reads the old title or retry

**Interfaces:**
- Consumes: Task 2's `Loaded`, `StaleDataLine`, `PressScale`, `SkeletonBar.radius`, `ProductImage.fadeIn`.
- Produces: `catalogCategoriesProvider` is `FutureProvider.autoDispose<Loaded<List<CatalogCategory>>>`, `at` read from `clockProvider` once the rows came; users read `.data`.
- Produces: `int categoryColumns(double width, TextScaler scaler)` (Global Constraints' rule) in `category_tile.dart`.
- Produces: `CategoryTile({required CatalogCategory category, required int columns, double? size, Object? heroTag, Key? key})` — lines and picture share by `columns`; the well passes `fadeIn: true`; `heroTag` is Task 4's.
- Produces: `CategoryButton({required CatalogCategory category, required int columns, double? size, Key? key})`, keyed `category-<id>` by callers: a `PressScale` labelled with the name alone (a letter tile's letter is not read) around a `CategoryTile`; a tap pushes `CatalogPaths.category(id)`.
- «Все категории»: title `homeCategories`; a `Stack` of a `RefreshIndicator` (`KitColors.primary`) around the `GridView` keyed `category-grid` (always scrollable, padding 16 + the side safe areas, bottom `16 + CartSummaryBar.reserved(context)`, `mainAxisExtent` tile + 6 + `scaler.scale(12) * 1.25 * lines` + 2) and the `CartSummaryBar` at the bottom. Loading without data: 12 pulsing skeleton tiles (a square `SkeletonBar` radius 14, under it a 60 % × 10 bar). A failed load with data: a `StaleDataLine` (margin 8 16 0, `shownAt` the `Loaded.at`) above the tiles, scrolling with them. Without data: the line with «Повторить» above still skeletons. A pull refreshes (`ref.refresh(catalogCategoriesProvider.future)`, failures caught) and announces `refreshDone` or the line's spoken words; a tile whose id this screen had not shown comes in as Global Constraints say.
- `CartSummaryBar`: one node — `Semantics(button: true, label: cartSummarySpoken(cartSummaryCount(n), MoneyFormat.uzs(sum)), excludeSemantics: true, onTap: …)`.

- [ ] **Step 1: Write the failing tests.** `'the title is Категории'`; `'the cart bar shows while the cart holds a line and the last tiles stay clear of it'`; `'columns follow the width: 4 at 375, 2 at text x2 with three-line names, 8 lying at 812'`; `'loading shows pulsing skeletons, then the tiles fade in'`; `'pull to refresh brings a new category in at the end'`; `'offline after a load keeps the tiles with the stale line and its time'`; `'a first load that fails shows Нет связи · Повторить over still skeletons'` (`stale-retry` reloads); `'a tile reads as its name and a button, a letter tile without the letter'`; `'the cart bar is one phrase'`; `'pressing a tile shrinks it to 0.96 and opens the category'`. Rewrite the tests that look for `catalogCategoriesTitle` on this screen or its `retry-load`.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/catalog/category_screens_test.dart test/features/catalog/catalog_screens_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement**; `flutter.bat gen-l10n`.
- [ ] **Step 4: Run** `flutter.bat test test/features/catalog test/features/cart test/features/orders`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(catalog): all categories titled, with the cart bar, columns by width, a pull and the stale line (DL-125)"`

### Task 4: The picture flies into the rail

**Files:**
- Modify: `category_tile.dart` (`CategoryButton` owns a tag; `categoryWellFlight`), `catalog_routes.dart` (the category route reads `extra`), `category_screen.dart` (`opening`, the rail's Hero)
- Test: `category_screens_test.dart` (group `'opening from a tile'`)

**Interfaces:**
- Produces: `final class CategoryOpening { const CategoryOpening({required Object heroTag}); }`.
- Produces: `Widget categoryWellFlight(BuildContext flightContext, Animation<double> animation, HeroFlightDirection direction, BuildContext fromContext, BuildContext toContext)` — a `CategoryPictureWell` keyed `category-well-flight` that fills the flight's box, radius `lerpDouble(14, 12, animation.value)`, the category from the destination hero.
- `CategoryButton`: `final Object _heroTag = Object();` in its State; with motion allowed its tile's well is `Hero(tag: _heroTag, flightShuttleBuilder: categoryWellFlight)`; a tap pushes with `extra: CategoryOpening(heroTag: _heroTag)`.
- `CategoryScreen({required String categoryId, CategoryOpening? opening, Key? key})`: the selected rail item's well is `Hero(tag: opening.heroTag, flightShuttleBuilder: categoryWellFlight)` only with an opening and motion allowed. A rail switch (`context.replace`) carries no opening.

- [ ] **Step 1: Write the failing tests.** `'the picture flies from the tile into the rail, and back on pop'` (from «Все категории»: `category-well-flight` found 150 ms into the push and into the pop, gone when settled); `'from the home's tile too'`; `'a category far down the rail lands where its well ends up'` (12 categories, open `c-12`: the shuttle's rect one frame before the end is within 1 px of the rail well's settled rect); `'one category on two screens opens and closes without a hero clash'` (home → «Все категории» → `c-1` → pop → pop, `takeException()` null each step); `'after a rail switch back flies nothing'`; `'with reduced motion no Hero'`.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/catalog/category_screens_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter.bat test test/features/catalog test/app`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(catalog): a tile's picture flies into the category's rail (DL-125)"`

### Task 5: The home in one scroll, loading, offline and large text

**Files:**
- Modify: `home_screen.dart` (rewritten), `recommended_row.dart` (skeletons, card width), `addresses/presentation/delivery_address_widgets.dart` (the loading bars)
- Test: `frontend/test/features/catalog/customer_home_test.dart`, `frontend/test/features/shells/presentation/customer_tabs_test.dart` (`home-body` → `home-scroll`)

**Interfaces:**
- Consumes: Tasks 2–4 (`StaleDataLine`, `SkeletonBar`, `categoryColumns`, `CategoryButton`, `Loaded.at`).
- `CatalogHomeScreen`: the body is one `CustomScrollView` keyed `home-scroll`, `primary: true`, always scrollable, inside a `RefreshIndicator` (`KitColors.primary`), its slivers in this order: `ActiveModeBar` with the way back to staff; the address and cart row (padding 16 8 4 0); the search, a pinned `SliverPersistentHeader` keyed `home-search-bar` — white, padding 16 8 16 8, the field (`catalog-search`) full width, extent `16 + max(50, 28 + h)` with `h` a one-line `TextPainter` height of the hint at 14 under the context's `TextScaler`, the shadow `BoxShadow(color: Color(0x59151D16), offset: Offset(0, 8), blurRadius: 12, spreadRadius: -10)` while `shrinkOffset > 0`; a slot for Task 8's closed line; `QuestionBanner`; the home's stale line (margin 8 16 0); the categories' `SectionTitle` and grid (padding 16 8 16 8, `CategoryButton`s by `categoryColumns`, the first eight); `RecommendedRow(placeholders: true)`; 16 at the bottom. `headerShare`, `_FilterButton` and `_openSort` go.
- Loading without data: the address line shows two pulsing bars 90 × 14 and 170 × 10 (gap 6) instead of «…»; the categories 8 skeleton tiles; with `placeholders` the recommended row its title and 3 skeleton cards (a 130 high bar radius 12, then 80 % × 12, 55 % × 14 and a 44 × 44 radius 12 bar at the end). Data that replaces skeletons fades in.
- The home's line shows while the categories' or the recommended's last load failed: `failure` the categories' error, else the recommended's; `shownAt` the categories' `Loaded.at` while they hold data. Sections with data stay; one without data keeps still skeletons. Its retry and a pull both run `_refresh`: `ref.refresh` of the categories and of `productListProvider(const ProductListQuery(featuredOnly: true))` awaited with failures caught, `ref.invalidate(pendingQuestionProvider)` (Task 7 renames it to `pendingQuestionsProvider`) and `CartController.refresh()`; it announces `refreshDone` when both loads came, else the line's spoken words.
- `RecommendedRow`: `placeholders` (`bool`, default `false`); the card width of Global Constraints.

- [ ] **Step 1: Write the failing tests.** The reproduction first: `'one scroll: at text x2 with two sessions and a question the address scrolls away and the search sticks'` (320 × 640, ru and uz: one vertical `Scrollable` besides the recommended row; drag −400 → `catalog-search`'s top at the safe top and `.hitTestable()`, `delivery-address` not hit-testable, the categories' title on screen; drag back → `switch-to-staff-button` shown). Then `'the search sticks with a shadow only once scrolled'`; `'no filter button; the search takes the full width'`; `'loading shows bars for the address, eight tiles and three cards, then the data fades in'`; `'pull to refresh reloads the categories and the recommended'`; `'offline after a load keeps everything under Нет связи · данные на 12:46'` (and `refreshDone` after a pull that succeeds); `'a first load that fails shows Нет связи · Повторить over still skeletons'`; `'at text x2 the categories stand in two columns and the cards are 260 wide with the price whole'` (ru and uz at 320; the price's `TextPainter.didExceedMaxLines` false); `'lying at 812 eight categories stand in one row'`. Rewrite: `'the sections come in order: address and cart, search, categories, recommended'` (no `open-sort`), `'no recommended section when its request fails'` → the row keeps still skeletons under the line, `'sections that failed to load keep their retry above the bar'` → `stale-retry`, `'with the keyboard open at large text and two sessions the header scrolls inside what is left and nothing overflows'` → the one-scroll rule with the keyboard open, `'the search entry and the sort button expose a tap action'` → the search only. Delete, as they pin the button this stage removes: `'the filter button asks the sort and opens every product in it'`, `'dismissing the sort sheet opens nothing'` (the sort sheet keeps its tests in `product_lists_test.dart`).
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/catalog/customer_home_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter.bat test test/features/catalog test/features/shells test/features/addresses test/features/cart`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(catalog): the home in one scroll with a sticky search, skeletons, a pull and the stale line (DL-125)"`

### Task 6: The home for a screen reader

**Files:**
- Modify: `delivery_address_widgets.dart` (`DeliveryAddressLine`'s label), `home_screen.dart` (the search's label), `section_title.dart` (`seeAllLabel`, the title a header), `recommended_row.dart` and `home_screen.dart` (pass `recommendedAll`, `homeCategoriesAll`), `kit_product_card.dart`, both `.arb` files
- Test: `frontend/test/features/catalog/kit_product_card_test.dart`, `customer_home_test.dart`

**Interfaces:**
- `DeliveryAddressLine` with an address: one button node `deliveryAddressSpoken('${label}, ${street}')` (the street alone without a label); other states keep their words.
- The home's search: label `catalogSearchSpoken`.
- `SectionTitle({…, String? seeAllLabel})`: the title in `Semantics(header: true)`; «Все» read as `seeAllLabel` when given.
- `KitProductCard`: the card is one button node `cardSpoken(name, MoneyFormat.uzs(price), unit.name)`, with `cardInCartSpoken(…, quantity)` while a quantity is shown, and the existing "not sold" word for a card no longer sold; the picture, name and price say nothing apart. The heart keeps its own node, tooltip and label `favoriteAddSpoken(name)` / `favoriteRemoveSpoken(name)`. The «+» reads `cardAddSpoken(name)`. The stepper is one adjustable node — `cardStepperSpoken(name)`, value the quantity, `increasedValue` / `decreasedValue` when a step exists, `onIncrease` / `onDecrease` doing the steps (the decrease at the bin removes, as its tap does) — and its buttons keep their keys and taps.

- [ ] **Step 1: Write the failing tests.** `kit_product_card_test.dart`: `'the card is one stop that names the product and its price'` (`Помидор, примерно ${MoneyFormat.uzs(12075, AppLanguage.ru)} за килограмм`; no node reading `Помидор` or `≈ …` alone); `'in the cart it says how much'` (`… . В корзине 1 кг`); `'the add and the heart name the product'`; `'the stepper is one adjustable node'` (increase → `1,5 кг` reaches the queue; no separate minus or plus node); uz `'the card speaks Uzbek'`. `customer_home_test.dart`: `'the address says доставка'`; `'«Все» says what it opens and the titles are headings'`; `'the search reads Поиск товаров'`.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/catalog/kit_product_card_test.dart test/features/catalog/customer_home_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement**; `flutter.bat gen-l10n`.
- [ ] **Step 4: Run** `flutter.bat test test/features`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(catalog): the home and its cards for a screen reader (DL-125)"`

### Task 7: The Shopper's question on the home

**Files:**
- Modify: `orders/application/customer_orders_controllers.dart` (`pendingQuestionsProvider`, `openQuestionsProvider`), `orders/presentation/question_banner.dart`, `core/widgets/customer_tab_bar.dart` (a `ConsumerWidget` with the badge), `home_screen.dart` (the refresh's invalidation), both `.arb` files (remove `questionBannerOrder` once unused)
- Test: `frontend/test/features/orders/application/customer_orders_controllers_test.dart`, `customer_home_test.dart` (group `'the question banner'`), `frontend/test/core/widgets/customer_tab_bar_test.dart` (or where the tab bar is tested)

**Interfaces:**
- Consumes: Task 2's `DeadlineChip`, `minutesLeft`.
- Produces: `pendingQuestionsProvider` — `FutureProvider.autoDispose<List<PendingQuestion>>`, every pending question, earliest expiry first; replaces `pendingQuestionProvider` (its invalidation after a decision follows).
- Produces: `openQuestionsProvider` — `Provider.autoDispose<List<PendingQuestion>>`: the last loaded list, kept while a refresh fails, without the questions whose `expiresAt` is not after `clockProvider`'s now; a `Timer` to the earliest expiry invalidates it (cancelled on dispose).
- `QuestionBanner`: the first open question in `Fold(shown: …)`, keeping the last one while it folds; built first with a question it stands; a question that appears after a loaded answer without one unfolds, buzzes and announces `questionArrived(number, deadlineLeftSpoken(m))`; at its expiry it folds and announces `questionExpired`; one that leaves by a refresh (answered) folds silently. The card as today, its second line `questionBannerUntil(number, time)`, then 6 lower the `DeadlineChip`; one button node `questionSpoken(number, deadlineLeftSpoken(m))` that opens the order. `PeriodicRefresh` stays (30 s).
- `CustomerTabBar`: «Заказы» shows the open questions' count while there is one — a pill at least 18 × 18, radius 9, a 2 px white ring, `KitColors.danger`, white 11 `w700`, its top 8 from the bar's top and its left 6 right of the icon's centre — and reads `homeNavOrdersWaiting(count)`.

- [ ] **Step 1: Write the failing tests.** Controllers: `'open questions leave out the expired and drop one at its expiry'`; `'a failed refresh keeps the questions'`; `'the earliest comes first'`. Banner: `'a question that arrives unfolds, buzzes and is announced'` (one `lightImpact`, `Сборщик спрашивает про заказ № 1044. осталось 9 минут`); `'a question known at the first build stands still and silent'`; `'Осталось 9 мин turns red at 3 and the banner folds at its expiry'` (announcement `Время на ответ вышло`, the badge gone in the same pump); `'an answered question folds without a word'`; `'the banner is one stop that opens the order'`; `'with reduced motion it stands and goes at once'`. Tab bar: `'Заказы shows how many questions wait, until their expiry'` (two questions → `2`, label `Заказы, ждут ответа: 2`). Rewrite the existing banner tests that read `questionBannerOrder`.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/orders test/features/catalog/customer_home_test.dart test/core/widgets` — Expected: FAIL.
- [ ] **Step 3: Implement**; `flutter.bat gen-l10n`.
- [ ] **Step 4: Run** `flutter.bat test test/features test/core`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(orders): the question unfolds with the minutes left, a count on Заказы, folds at expiry (DL-125)"`

### Task 8: The home says when the store is closed

**Files:**
- Create: `frontend/lib/features/cart/domain/store_hours.dart`, `frontend/lib/features/catalog/presentation/store_closed_line.dart`
- Modify: the `Cart` domain class (`hours`), the cart DTO (`working_hours`), `frontend/test/support/fake_cart_repository.dart` (and the cart JSON fixtures), `home_screen.dart` (the slot), both `.arb` files
- Test: `frontend/test/features/cart/domain/store_hours_test.dart` (create), the cart DTO test, `customer_home_test.dart` (group `'closed'`)

**Interfaces:**
- Consumes: Task 1's `working_hours`.
- Produces: `final class StoreHours { const StoreHours({required int opensMinute, required int closesMinute}); factory StoreHours.parse(String opensAt, String closesAt); bool isOpenAt(DateTime instant); DateTime nextChangeAfter(DateTime instant); String get opensAt; }` — minutes of the Tashkent day (`TashkentTime.offset`), open from opening up to, not including, closing; a closing before the opening spans midnight; `opensAt` is `HH:MM`; value `==` and `hashCode`.
- Produces: `Cart.hours` (`StoreHours?`, default `null`) from `working_hours`: `null`, or both times `HH:MM`; anything else is a malformed response, as the DTO treats its other fields.
- Produces: `StoreClosedLine({Key? key})`, a `ConsumerStatefulWidget` keyed `store-closed` inside: shown while the cart's hours exist and are closed at `clockProvider`'s now; a `Timer` to `nextChangeAfter(now)` reads again; comes and goes through `Fold` (built first, it stands). `KitColors.warningWash`, radius 14, padding 10 × 12, margin 0 16 8; `Icons.schedule` 20 `KitColors.warningDark`, 10; text 13 height 1.4 `KitColors.ink2`: `homeClosedTitle` `w700` `KitColors.warningDark`, a space, `homeClosedBody(opensAt)`. One node reading both sentences.

- [ ] **Step 1: Write the failing tests.** `store_hours_test.dart`: `'open from opening up to closing'` (08:00–22:00: open 08:00 and 21:59, closed 22:00 and 07:59 Tashkent); `'hours over midnight'` (22:00–02:00: open 23:00 and 01:59, closed 03:00); `'the next change'`. DTO: `'working hours parse, null stays null, a half pair is malformed'`. Home: `'at night the home says it is closed and when it opens'` (23:10 → `Сейчас закрыто. Заказ примем сейчас, соберём и привезём с 8:00`); `'the line folds away at opening while the home is shown'`; `'it comes at closing while the home is shown'`; `'no line while open, always open or unset'`; `'the line is one phrase'`; uz `'the line speaks Uzbek'`.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/cart test/features/catalog/customer_home_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement**; `flutter.bat gen-l10n`.
- [ ] **Step 4: Run** `flutter.bat test test/features`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(catalog): the home says when the store is closed and when it opens (DL-125)"`

### Task 9: The whole screens and the records

**Files:**
- Test: `customer_home_test.dart` — `'every target of the home meets iOSTapTargetGuideline'` (two sessions, a question, the closed line and the stale line, at text × 1 and × 2); `category_screens_test.dart` — `'every target of all categories meets iOSTapTargetGuideline'` (the cart bar and the stale line, × 1 and × 2)
- Modify: `docs/DECISIONS.md` (`DL-125`), `docs/04-user-flows.md` (the home's description, if it names the filter button or a fixed header), `tasks/APPLE_BATCH.md`

**`DL-125` — The Apple batch, stage 6: home and categories (2026-11-02, agent; item `home-10` Owner)**, items:
1. **One scroll** (`home-2`, reproduced on the emulator first): the mode bar and the address scroll away on the home, the search sticks; every other screen keeps the mode bar fixed (`DL-75`).
2. **No filter button** (`home-3`): sorting stays in the product lists; supersedes `DL-83` (3)'s "the home's filter button always opens every product".
3. **Loading and offline** (`home-4`, `cats-6`): `Loaded<T>` keeps a load's time; `StaleDataLine` in `core/` says «Нет связи» for a network failure and «Не удалось обновить» for another; skeletons pulse while loading and stand still after a failure; a pull refreshes.
4. **The question** (`home-7`): open questions drop at their expiry by a timer; `DeadlineChip` in `core/`; a count on «Заказы» on every tab; the banner comes and goes through `Fold` (300 ms, the app's one unfold, not the drawing's 260).
5. **Large text and width** (`home-8`, `cats-3`, `cats-4`): one column rule for both grids; recommended cards 150 to 260 wide.
6. **Screen reader** (`home-9`, `cats-7`): the address with «доставка», named «Все», headings; the card as one phrase, a named «+», a named heart (the card's part of `fav-8`) and one adjustable stepper; tiles as name and button; the cart bar as one phrase.
7. **Closed (Owner, 2026-10-25, home test item 10):** «Сейчас закрыто. Заказ примем сейчас, соберём и привезём с 8:00» — customer-facing text. The cart answers `working_hours`: the Customer resource every screen with a cart button already holds, so no new request; the app compares it with its clock for this line only, and checkout's preview still decides (`docs/07` section 26, `BR-CHK-009`).
8. **Title** (`cats-1`): «Категории», as the home and the kit's drawing 10б.
9. **Cart bar on «Все категории»** (`cats-2`): extends `DL-80` (3).
10. **Press and flight** (`cats-5`): `PressScale` in `core/`; each tile owns its hero tag and hands it to the category route, so a category on two screens in the stack never shares a tag (as `DL-122` (1)).

- `tasks/APPLE_BATCH.md`: stage 6 «In review»; the stage 3 residual "the card grows from `build()`" stays for stage 7.

- [ ] **Step 1: Write** the two guideline tests; run `flutter.bat test test/features/catalog` — Expected: PASS (or fix the target it names in the task that owns it).
- [ ] **Step 2: Write** the records above.
- [ ] **Step 3: Check** `git diff --check` and that `DL-125` is the next free number. Expected: clean, not used before.
- [ ] **Step 4: Commit** — `git commit -m "docs: DL-125, home and categories"`

### After the tasks (the lead)

- Full suite through `test-runner` (`flutter.bat test --concurrency=2`), `flutter.bat analyze`, `dart format --set-exit-if-changed lib test`, the backend suite in Docker (sequential, about 2.5 min), Pint, PHPStan, `git diff --check`.
- `branch-reviewer` on `main..HEAD` with this plan, its Review Focus and the ledger; one fix wave; scoped re-review; `/security-review`.
- Push, pull request, both required checks green, merge, clean up.
- Real-stack walk on the `barakabozor` emulator (backend in Docker on 8001, the `WalkthroughSeeder`): the home at 200 % with a Shopper in Customer mode (one scroll, the search sticks); pull to refresh; the backend stopped → «Нет связи · данные на …» → started → «Обновить»; working hours set so the store is closed → the line; «Все» → «Категории» with the cart bar, a tile press and the flight into the rail, back; landscape. Four or five screenshots for the Owner.
