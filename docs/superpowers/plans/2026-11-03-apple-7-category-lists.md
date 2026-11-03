# Apple Stage 7 — Category Screen and Product Lists Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On the category screen a rail tap keeps the header and the rail: the item presses to 0.96, one green marker glides to it, the phone clicks, only the products cross-fade, and a tap on the selected item takes the products back to the top; a section seen before comes at once, a new one shows skeletons, a pull refreshes, offline the cards stay under «Нет связи · данные на 12:46 · Обновить»; at 200 % the rail becomes a chips row under the header and the cards take the full width in two columns with three-line names and a whole price; lying, nothing sits under the camera and four columns stand; a screen reader hears «Овощи, выбрано, 1 из 12» and, after a switch, «Напитки: 3 товара». Every product list (category, «Рекомендуем», «Все товары», search) shows «24 товара · Как в магазине ⌄» whose order opens as a menu at its button, asks for the next page two rows before the end with placeholder cards that fade in, keeps a failed page in place as «Нет связи — следующие товары не загрузились · Повторить», and shows a thin scroll indicator sized by the server's total. The cart bar slides up, rolls its sum, and at large text shows an arrow instead of «В корзину →».

**Architecture:** No server change. `KitProductGrid` becomes one `CustomScrollView` that owns every state of a list (skeletons, stale line, pull, rows by width, the list end, the scroll indicator) so all four lists change at once. The category screen keeps its selected section in its own state instead of replacing the route, and keeps every section it showed alive for its lifetime. The order chooser becomes one popup route anchored to its button, shared by every list. New shared pieces go to `core/`: `ListScrollIndicator`, `PressScale.selected`, `KitColors.chip`, the busy label of `StaleDataLine`.

**Tech Stack:** Flutter 3.47.5, flutter_riverpod 3.4.3 (`ref.listenManual`, `ref.refresh`), go_router 18.1.2, `CustomScrollView` + `RefreshIndicator`, `PopupRoute`, `AnimatedPositioned`, flutter_test (`tester.takeAnnouncements()`, `meetsGuideline(iOSTapTargetGuideline)`, `SystemChannels.platform` mock for haptics, `NonlinearTextScaler`, `MediaQueryData.padding` for a notch).

**Spec:** `tasks/APPLE_BATCH.md` stage 7 (`catpage-1` **repro**, `catpage-2`, `catpage-3`, `catpage-4`, `catpage-6` **repro**, `catpage-7`, `rec-3`, `rec-4` **repro**, `all-3`, `all-4`) and the two stage 6 residuals it takes (the busy stale button's label, the category screen's stale line); the live tests «Тест категории - Apple», «Тест подборки - Apple», «Тест всех товаров - Apple» in the Claude Design project "BarakaBozor — стиль покупателя" (local copies `G:/tools/tmp/w-catpage/site/catpage.html`, `w-rec/site/rec.html`, `w-all/site/all.html`; their "стало" state is the picture); `DL-80`, `DL-83`, `DL-117`, `DL-119`, `DL-120`, `DL-124` … `DL-126`; `frontend/AGENTS.md`.

## Global Constraints

- Changes stay in `frontend/`, `docs/` and `tasks/`. No package, no lockfile change, no server change. Generated localizations come from `flutter gen-l10n`, never by hand.
- Strings (ru / uz), new:
  - `staleRefreshing` «Обновляем…» / «Yangilanmoqda…»
  - `categoryRailSpoken` «{name}, {index} из {count}» / «{name}, {count} tadan {index}»; `categoryShownSpoken` «{name}: {count}» / «{name}: {count}» (`count` is `catalogProductCount(n)`)
  - `sortSpoken` «Порядок: {sort}» / «Tartib: {sort}»
  - `catalogMoreOffline` «Нет связи — следующие товары не загрузились» / «Aloqa yo'q — keyingi mahsulotlar yuklanmadi»; `catalogMoreFailed` «Следующие товары не загрузились» / «Keyingi mahsulotlar yuklanmadi»
  - Reused: `catalogProductCount` for «24 товара», `sortShop` / `sortPriceAsc` / `sortPriceDesc`, `sortTitle` (the menu's route name), `retryButton`, `refreshDone`, `staleSpoken`. `catalogLoadMore` stays (the order picker's `ProductList`).
- Motion, exactly. Rail: press 0.96 by `PressScale` (120 ms in, 120 ms out, no ink); the marker glides 320 ms `Cubic(0.2, 0.8, 0.2, 1)` from where it is drawn; the well's colour changes in 200 ms `Curves.easeOut`; products fade in 220 ms `Curves.easeOut`; the title fades from 0.25 to 1 in 180 ms `Curves.easeOut`; the rail or the chips scroll 250 ms `Curves.easeOut` only when the item is not wholly in view; to the top 300 ms `Curves.easeOut`. Lists: data after skeletons fades in 200 ms (`FadeInSliver`); cards of a new page fade in 250 ms `Curves.easeOut`; old cards dim to 0.45 in 150 ms while another order loads; the page-failure row fades in 200 ms. Menu: scale 0.86 → 1 from its top-end corner with opacity 0 → 1, 180 ms `Cubic(0.2, 0.8, 0.2, 1)`; closes by a 150 ms fade. Scroll indicator: shown on a scroll, fades out over 300 ms `Curves.easeOut` 900 ms after the last one. Cart bar: up 360 ms `Cubic(0.2, 0.8, 0.2, 1)`, down 240 ms `Cubic(0.4, 0, 1, 1)`; the sum rolls up from 45 % of its height with a fade in 240 ms `Curves.easeOut`; the picture from scale 0.7 and opacity 0 in 260 ms `Curves.easeOut`. With `MediaQuery.disableAnimationsOf(context)`: no scale, no glide, no roll, no dim animation; the cart bar, the menu, the sum and the picture fade in 200 ms; everything else is at once.
- Haptic: `HapticFeedback.selectionClick()` once per section switch (not on a tap of the selected one).
- Colours are `KitColors` tokens, plus: the new `KitColors.chip = Color(0xFFF1F3F1)`; the scroll thumb `KitColors.ink` at alpha 0.42; the menu's shadows `BoxShadow(color: Color(0x33151D16), offset: Offset(0, 12), blurRadius: 32)` and `BoxShadow(color: Color(0x0F151D16), spreadRadius: 1)`.
- A layout rule that follows text reads `textScaleAt(scaler, fontSize)` at the size of the text it holds (`DL-126`); tests at large text use `NonlinearTextScaler(2)`.
- Amounts (`AGENTS.md` §5): the cart bar's sum stays `cart.estimatedSubtotalUzs` through `catalogApproxPrice`, as now. No `FittedBox` and no ellipsis on a price or a sum this stage draws; amounts never break inside a word (`DL-120` (2)).
- Every screen this stage rewrites — category (rail, chips at ×2, lying), «Рекомендуем», «Все товары», and the open order menu — passes `meetsGuideline(iOSTapTargetGuideline)` (batch rule).
- Tests that pinned the old drawing are rewritten to the new rule, each named in its task; no other test is deleted or weakened.
- Flutter runs from PowerShell with `$env:TEMP='G:\tools\tmp'; $env:TMP='G:\tools\tmp'` and `G:\tools\flutter\bin\flutter.bat`; a full suite uses `--concurrency=2`. Never run destructive artisan commands.
- Comments read like the surrounding code: short `///` docs in plain English that name `DL-127`.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- No `/security-review`: no server field, no access or data change.

## Review Focus

1. Quick switches while pages load: three rail taps within 100 ms, each section's first page held back — the screen ends on the last section's products only (no earlier section's cards under its title), three clicks, the marker on the last item, one announcement, for the last. Task 7 test `'three quick switches end on the last section and announce only it'`.
2. A section seen before, offline: its cards come at once and stay under the stale line with their time; a pull back online clears the line and announces «Обновлено»; inside it a failed next page shows its row and «Повторить» loads it. Task 8 test `'offline a section shown before keeps its cards under Нет связи · данные на 12:46'`, Task 3 test `'a pull back online clears the line and announces Обновлено'`, Task 4 test `'a failed next page keeps the cards and offers Повторить in place of the placeholders'`.
3. An order change while the next page of the old order is on its way: the late page never lands in the new list; the old cards dim, then the new list stands from the top. Task 3 test `'a new order while the next page loads drops that page'`.
4. Text ×2 on 320 × 640, ru and uz, with two sessions, a cart and the stale line: chips, count row, three-line names, the arrow cart bar — nothing overflows, every target ≥ 44. Task 8 test `'at text x2 with two sessions and a cart nothing overflows'` and the guideline tests.
5. Lying at 812 × 375 with 47 px side insets on the category screen, «Рекомендуем» and «Все товары»: nothing under the camera (rail, cards, cart bar, scroll indicator), four columns, the menu inside the screen. Task 5 test `'lying, the menu stays inside the screen'`, Task 8 test `'lying with a notch nothing sits under the camera and four columns stand'`, Task 3 test `'columns follow the width: 2 at 375, 4 lying at 812 with the side insets'`, Task 6 test `'lying with a notch it keeps clear of the camera'`.

---

### Before the tasks (the lead)

- [ ] Reproduce the three **repro** items on the `barakabozor` emulator with main's build (`ab1fa5f`): `catpage-1` — a rail tap slides a whole new page in, with the ink ripple, and the rail re-centres; `catpage-6` — with Developer options → «Simulate a display with a cutout» (tall) and the phone lying, the rail and the cart bar sit under the cutout and the products keep two wide columns; `rec-4` — at the end of «Все товары» a spinner turns and the next cards pop in only when the end is in view. Screenshots `G:/tools/tmp/apple7-repro-*.png`. Task 7's first test is `catpage-1`'s reproduction, Task 8's landscape test `catpage-6`'s, Task 4's first test `rec-4`'s. If the AVD hangs at start, suggest a Windows reboot first (stage 3's lesson).

### Task 1: Core pieces

**Files:**
- Create: `frontend/lib/core/widgets/list_scroll_indicator.dart`
- Modify: `frontend/lib/core/widgets/stale_data_line.dart`, `frontend/lib/core/widgets/press_scale.dart`, `frontend/lib/core/theme/kit_colors.dart`, both `.arb` files (`staleRefreshing`)
- Test: `frontend/test/core/widgets/list_scroll_indicator_test.dart` (create), `stale_data_line_test.dart`, `press_scale_test.dart`

**Interfaces:**
- Produces: `ListScrollIndicator({required Widget child, required double Function(ScrollMetrics metrics) fullExtent, double bottomInset = 0, Key? key})` — wraps a vertical scroll view and draws over its right edge a thumb keyed `scroll-indicator`: 3 wide, 2 from the right, radius 2, the thumb colour of Global Constraints. Track from 4 to `viewport − 4 − bottomInset`; `full = max(fullExtent(metrics), metrics.maxScrollExtent + metrics.viewportDimension)`; length `max(32, track × viewport / full)`; top `4 + (track − length) × clamp(pixels / (full − viewport), 0, 1)`. Shown by depth-0 `ScrollUpdateNotification`s, faded as Global Constraints say; nothing while `full <= viewport`; `IgnorePointer`, `ExcludeSemantics`.
- Produces: `PressScale.selected` (`bool?`, default `null`), passed to its `Semantics` node.
- Produces: `KitColors.chip`.
- `StaleDataLine`: the busy button's spinner carries `Semantics(label: staleRefreshing)`.

- [ ] **Step 1: Write the failing tests.** `'shows while scrolling and fades 0.9 s after'` (opacity 1 during a drag; 1 at +899 ms after the end; 0 at +1200 ms); `'its length follows the full extent, not the loaded one'` (viewport 600, content 1200, `fullExtent` 2400 → length `(600 − 8) × 600 / 2400` ± 0.5); `'at the end of the loaded part it is not at the bottom of the track'`; `'nothing when the content fits'`. `StaleDataLine` `'a busy button reads Обновляем…'`. `PressScale` `'selected is on its node'`.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/core/widgets` — Expected: FAIL.
- [ ] **Step 3: Implement**; `flutter.bat gen-l10n`.
- [ ] **Step 4: Run** `flutter.bat test test/core`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(core): scroll indicator, selected press, busy stale label (DL-127)"`

### Task 2: The list's time, columns by width, the card at large text

**Files:**
- Modify: `frontend/lib/features/catalog/application/catalog_controllers.dart` (`ProductListState.at`), `frontend/lib/features/catalog/presentation/kit_product_card.dart` (`KitCardType.largeText`, the name and price lines), `frontend/lib/features/catalog/presentation/kit_product_grid.dart` (`kitCardExtent`, `productColumns`)
- Test: `frontend/test/features/catalog/product_list_controller_test.dart`, `kit_product_card_test.dart`, `kit_card_fixes_test.dart` where it pins two name lines at ×2

**Interfaces:**
- Produces: `ProductListState.at` (`DateTime`, required) — when the first page came, read from `clockProvider`; kept by `loadMore` and its failures.
- Produces: `static bool KitCardType.largeText(TextScaler scaler, KitCardSize size)` — `textScaleAt(scaler, of(size).nameSize) > 1.3`. Then the card's name takes up to 3 lines (else 2) and the price up to 2 lines, wrapping at spaces, no ellipsis (else 1 line); `kitCardExtent` counts the same lines.
- Produces: `int productColumns(double width, TextScaler scaler, KitCardSize size)` — `max(2, ((width + 12) / (base × textScaleAt(scaler, KitCardType.of(size).nameSize) + 12)).floor())`, `base` 124 compact, 150 regular; `width` is the grid's width inside its side padding.

- [ ] **Step 1: Write the failing tests.** `'the list keeps the time its first page came'` (a mutable clock: page 1 at 12:46, `loadMore` at 12:50 → `at` stays 12:46). `'at text x2 the name takes three lines and the price wraps whole, and the extent fits them'` (`NonlinearTextScaler(2)`, compact card 165 wide, a 40-character name, `≈ 142 100 so'm`: no overflow, the price paragraph not `didExceedMaxLines`, the card's height equals `kitCardExtent`). `'productColumns'`: compact 261 → 2, 246 → 2, 604 → 4; regular 343 → 2, 686 → 4; regular 343 at `NonlinearTextScaler(2)` → 2. Rewrite tests that pin two name lines at ×2.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/catalog/product_list_controller_test.dart test/features/catalog/kit_product_card_test.dart test/features/catalog/kit_card_fixes_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter.bat test test/features/catalog`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(catalog): list time, columns by width, three-line names at large text (DL-127)"`

### Task 3: `KitProductGrid` — one scroll with every state

**Files:**
- Modify: `frontend/lib/features/catalog/presentation/kit_product_grid.dart`, `recommended_screen.dart`, `all_products_screen.dart` (the side safe areas)
- Test: `frontend/test/features/catalog/product_lists_test.dart`, `search_screen_test.dart` where it waits for a spinner or reads `retry-load`

**Interfaces:**
- Consumes: Task 1's `ListScrollIndicator` (wired in Task 4); Task 2's `ProductListState.at`, `productColumns`, `kitCardExtent`.
- Produces: `KitProductGrid({required ProductListQuery query, KitCardSize size = KitCardSize.regular, double imageHeight = 150, Widget? empty, EdgeInsets padding = const EdgeInsets.fromLTRB(16, 8, 16, 16), List<Widget> header = const <Widget>[], Future<Object?> Function()? alsoRefresh, ({ApiFailure failure, DateTime at})? alsoFailed, ScrollController? controller, Key? key})` — a `ConsumerStatefulWidget`; `columns` goes (from `productColumns` on the width inside `padding`).
- The scroll view keeps the key `product-grid` and starts fresh at the top for another query (a `KeyedSubtree` keyed by the query around it); it is always scrollable, inside a `RefreshIndicator` (`KitColors.primary`). Slivers, in order: the stale line (keyed `stale-line`, margin `padding.left` 0 `padding.right` 10, inside the top padding); the `header` widgets; then one of:
  - no data, loading: 6 skeleton cards in rows (`product-skeletons`), pulsing — a card's well `SkeletonBar(radius: 12)` of `imageHeight`, 12 px bars at 90 % and 55 %, a `KitCardType.buttonSide(size)` square (radius 10) at the bottom end;
  - no data, failed: the stale line with «Повторить» (`shownAt: null`; `stale-retry` reloads), over still skeletons;
  - empty: `empty`, else `catalogNoProducts`, centred in the room left;
  - data: the rows (height `kitCardExtent`, gap 12, cards keyed by product id) inside a `FadeInSliver` that animates only after skeletons were shown; Task 4's end follows.
- The stale line shows the list's failure with `shownAt: state.at`, busy while the list reloads; when the list has none, `alsoFailed`'s. A pull refreshes the list (`ref.refresh(productListProvider(query).future)`) and runs `alsoRefresh` beside it, failures caught; then announces `refreshDone`, or the line's spoken words with the list's time.
- Another order: while the new query has no data and only `sort` differs from the query last drawn, the last drawn cards stay at opacity 0.45 (150 ms) under `IgnorePointer` instead of skeletons, until the new list replaces them.
- Screens: «Рекомендуем» and «Все товары» put their body inside `SafeArea(top: false, bottom: false)`.

- [ ] **Step 1: Write the failing tests** (on «Все товары» and «Рекомендуем»). `'the first load shows pulsing skeletons, then the cards fade in'` (`gates['']` holds page 1); `'a first load that fails shows Нет связи · Повторить over still skeletons'`; `'a pull refreshes; offline it keeps the cards under the stale line with their time'` (a fixed clock → `Нет связи · данные на 12:46`; announcement `Нет связи. Показаны данные на 12:46`); `'a pull back online clears the line and announces Обновлено'`; `'columns follow the width: 2 at 375, 4 lying at 812 with the side insets'` (padding left/right 47 → the first card's left ≥ 47 + 16); `'a new order dims the old cards until the new ones come'`; `'a new order while the next page loads drops that page'`. Rewrite `'a failed first page offers a retry'` to the stale line.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/catalog/product_lists_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter.bat test test/features/catalog`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(catalog): product lists in one scroll with skeletons, stale line, pull and columns by width (DL-127)"`

### Task 4: The list's end and its scroll indicator

**Files:**
- Modify: `frontend/lib/features/catalog/presentation/kit_product_grid.dart`, both `.arb` files (`catalogMoreOffline`, `catalogMoreFailed`)
- Test: `frontend/test/features/catalog/product_lists_test.dart`

**Interfaces:**
- Consumes: Task 1's `ListScrollIndicator`; Task 3's grid.
- While `hasMore`, the rows end in one row of `columns` placeholder cards keyed `product-placeholders` (Task 3's skeleton card, pulsing). After a failed next page that row gives way to `product-page-failure`: min height 56, radius 14, white with a 1 px `KitColors.line` border, padding start 12 end 4; `Icons.cloud_off` 18 `KitColors.muted`, 8; text 13 `KitColors.ink2` (`catalogMoreOffline` for a `NetworkFailure`, else `catalogMoreFailed`), `Expanded`; a `TextButton` keyed `load-more`, at least 44 × 44, 13 `w600` `KitColors.primaryDark`, `retryButton`, which calls `loadMore`. It fades in as Global Constraints say.
- The next page is asked when `metrics.extentAfter < 3 × (kitCardExtent + 12)` — the last two rows and the placeholder row — on every depth-0 scroll update and metrics change, and once after a frame that drew new data (a page that does not fill the screen asks at once); never while one loads, after a failure until «Повторить», or without more. `ProductListEnd` is no longer used by the grid (the order picker keeps it).
- A card whose product came with the latest page fades in once, the first time it is built; with reduced motion at once.
- The grid's scroll view sits in `ListScrollIndicator(bottomInset: padding.bottom)`; `fullExtent` = the laid-out extent plus `(⌈total / columns⌉ − ⌈loaded / columns⌉) × (kitCardExtent + 12)`, minus the placeholder row while more is to come.

- [ ] **Step 1: Write the failing tests.** The `rec-4` reproduction first: `'the next page is asked two rows before the end'` (60 products, `pageSize` 20; scrolled to `extentAfter` just over 3 rows → only page 1 asked; 20 px further → page 2 asked while `product-placeholders` is still below the screen). `'while the next page loads the placeholders stand at the end; then the new cards fade in'` (opacity of a new card < 1 at +100 ms, 1 at +260 ms). `'a short first page asks for the next at once'` (`pageSize` 4, 10 products, 800 high). `'a failed next page keeps the cards and offers Повторить in place of the placeholders'` (rewrite of `'a failed next page keeps the loaded ones and offers a retry'`). `'the scroll indicator's length follows the total'` (100 products, page 1 loaded: length = `track × viewport / fullExtent` ± 1).
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/catalog/product_lists_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement**; `flutter.bat gen-l10n`.
- [ ] **Step 4: Run** `flutter.bat test test/features/catalog`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(catalog): next page two rows ahead, placeholders, in-place failure, scroll indicator (DL-127)"`

### Task 5: The order menu and the count row

**Files:**
- Create: `frontend/lib/features/catalog/presentation/sort_menu.dart`
- Delete: `frontend/lib/features/catalog/presentation/sort_sheet.dart`
- Modify: `recommended_screen.dart`, `all_products_screen.dart`, `search_screen.dart` (`_openSort`), both `.arb` files (`sortSpoken`)
- Test: `frontend/test/features/catalog/product_lists_test.dart`, `search_screen_test.dart` where it opens the sheet

**Interfaces:**
- Consumes: Task 3's `KitProductGrid.header`.
- Produces: `String sortLabel(AppLocalizations l10n, ProductSort sort)` (moved from `sort_sheet.dart`).
- Produces: `Future<ProductSort?> showSortMenu(BuildContext anchor, ProductSort current)` — a `PopupRoute<ProductSort>` with a transparent, dismissible barrier (no dim), `null` on a tap outside. Placed 2 below the `anchor`'s box, its end 6 inside the anchor's end, kept 8 inside the screen's safe area. Width 232, padding 6 vertical, radius 14, white, the shadows of Global Constraints; opens and closes as Global Constraints say. Items keyed `sort-shop`, `sort-price-asc`, `sort-price-desc`: min height 48, padding start 10 end 16, a 24-wide check column (`Icons.check` 20 `KitColors.primaryDark` on the current), 6, text 15 `KitColors.ink` (`w600` current, else `w500`), a 1 px `KitColors.line` under all but the last; each one node `Semantics(button: true, selected: …, inMutuallyExclusiveGroup: true, label: …)`; the route is named `sortTitle`.
- Produces: `ProductListCountRow({required int? total, required ProductSort sort, required ValueChanged<ProductSort> onSort, Key? key})`, keyed `list-count-row` by callers: padding start 16 end 6; `catalogProductCount(total)` 13 `KitColors.muted` with the number `w600` `KitColors.ink`, `Flexible`, nothing while `total` is `null`; a button keyed `list-sort` — min height 44, padding start 10 end 6, radius 10, `sortLabel` 13 `w600` `KitColors.primaryDark` and `Icons.expand_more` 20 — one node labelled `sortSpoken(sortLabel)`, opening `showSortMenu` from its own context; a choice other than `sort` calls `onSort`.
- «Рекомендуем» and «Все товары» pass `ProductListCountRow` as the grid's `header` (total from the list's value); «Все товары» loses its chip; «Рекомендуем» lists `ProductListQuery(featuredOnly: true, sort: sort)`. Every list takes `productSortProvider`. Search opens `showSortMenu` from the `search-sort` button's context (stage 9 moves it).

- [ ] **Step 1: Write the failing tests.** `'Рекомендуем shows 3 товара · Как в магазине and the menu re-sorts it'`; `'Все товары has the count row instead of the chip'`; `'the menu opens at its button with a check on the current order, without a dim, and a tap outside closes it'` (rewrite of `'the sheet marks the current choice and returns the tapped one'`; no `ModalBarrier` colour); `'menu items read their name, selected or not'`; `'lying, the menu stays inside the screen'` (812 × 375, insets 47); `'the open menu meets the tap target guideline'`; search `'the sort button opens the menu'`.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/catalog/product_lists_test.dart test/features/catalog/search_screen_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement**; `flutter.bat gen-l10n`.
- [ ] **Step 4: Run** `flutter.bat test test/features/catalog`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(catalog): order menu at its button and the count row on every list (DL-127)"`

### Task 6: The cart bar slides, rolls and keeps its sum whole

**Files:**
- Modify: `frontend/lib/features/cart/presentation/cart_summary_bar.dart`
- Test: `frontend/test/features/cart/cart_summary_bar_test.dart` (create); `product_lists_test.dart` `'the cart bar appears after a quick add and opens the cart'` (pump through the entrance)

**Interfaces:**
- `CartSummaryBar` becomes a `ConsumerStatefulWidget` (same constructor and `reserved`): it keeps the last cart with lines so it can leave; a bar already holding lines at its first build stands at once; the first line slides it up, an emptied cart slides it down, then it takes no room. A new `estimatedSubtotalUzs` rolls the sum; a new last line's picture comes in; the count changes in place. Motion and reduced motion as Global Constraints say.
- Large text — `textScaleAt(scaler, 14) > 1.3`: «В корзину →» gives way to `Icons.chevron_right` 30 white (excluded from semantics; the bar's phrase is unchanged), and the count and the sum take up to 2 lines each, the sum without ellipsis; `reserved` counts those lines then.
- The bar's side padding is `20 + MediaQuery.paddingOf(context).left` / `.right`.

- [ ] **Step 1: Write the failing tests.** `'slides up when the first line comes and down when the cart empties'` (translation at 0, 180, 360 ms; after emptying, 240 ms later no `cart-summary`); `'stands at once when the screen opens with a cart'`; `'the sum rolls to the new value'` (both sums at +120 ms, only the new at +240 ms); `'with reduced motion it fades'`; `'at text x2 an arrow replaces the words and the sum is whole'` (`NonlinearTextScaler(2)`, 320 wide, a six-digit sum, no `didExceedMaxLines`, no «В корзину» text; the semantics label unchanged); `'reserved fits the bar at text x2'`; `'lying with a notch it keeps clear of the camera'` (left inset 47 → the bar's left ≥ 67).
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/cart/cart_summary_bar_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter.bat test test/features/cart test/features/catalog`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(cart): the cart bar slides up, rolls its sum and shows an arrow at large text (DL-127)"`

### Task 7: The category screen switches in place

**Files:**
- Modify: `frontend/lib/features/catalog/presentation/category_screen.dart`, `category_tile.dart` (`CategoryPictureWell`'s letter out of semantics, its colour change), `frontend/lib/core/widgets/kit_app_bar.dart` (`fadeTitle`), both `.arb` files (`categoryRailSpoken`, `categoryShownSpoken`)
- Test: `frontend/test/features/catalog/category_screens_test.dart` (group `'category screen'`, `'opening from a tile'`)

**Interfaces:**
- Consumes: Task 1's `PressScale.selected`; Task 3's `KitProductGrid(controller: …)`.
- Produces: `kitAppBar(…, bool fadeTitle = false)` — the title fades in as Global Constraints say each time its text changes (at once with reduced motion).
- `CategoryScreen` becomes a `ConsumerStatefulWidget`; its selected section starts at `categoryId` and changes in its state; the location keeps the opened category, so back leaves the screen to where the Customer came from. The opening's `Hero` stands on the opened category's well only while it is selected (after a switch back flies nothing, as now). The grid gets a `ScrollController` the screen owns.
- Rail item, keyed `rail-<id>`: a `PressScale` labelled `categoryRailSpoken(name, index, count)` with `selected`, no ink. A tap on the selected one scrolls the products to the top. Another: `HapticFeedback.selectionClick()`, the section changes, the products fade in from the top, the title fades (`fadeTitle: true`), the rail scrolls only when the item is not wholly in view (on opening it still centres the selected one, as now). On a switch the screen announces `categoryShownSpoken(name, catalogProductCount(total))` once the section's first page is known — at once for one already loaded — and only for the section still selected then.
- One marker keyed `rail-marker` (3 wide, `KitColors.primary`, radius 2 on its left corners) at the selected item's top and height, measured after layout, gliding as Global Constraints say (`AnimatedPositioned`, which starts an interrupted glide from where it is drawn); placed without motion on the first frame and with reduced motion. The selected well's colour (`KitColors.primaryWash`) changes as Global Constraints say.

- [ ] **Step 1: Write the failing tests.** The `catpage-1` reproduction first: `'a rail tap keeps the page: no new route, header and rail stay'` (the router's match count and the rail's scroll offset unchanged, the title is the new section's). `'a press shrinks the rail item to 0.96, no ink'`; `'the marker glides 320 ms to the new item; with reduced motion it jumps'`; `'a switch clicks the selection haptic once'`; `'only the products fade in, from the top'`; `'a tap on the selected item scrolls the products to the top'`; `'the rail scrolls only when the item is not wholly in view'`; `'rail items read name, selected or button, and N из M; a letter is not read'`; `'a switch announces Фрукты: 1 товар'`; `'three quick switches end on the last section and announce only it'`; `'back after switches returns to where the Customer came from'`. Rewrite `'choosing another rail item shows its products and title, …'` to the in-place switch; `'after a rail switch back flies nothing'` stays.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/catalog/category_screens_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement**; `flutter.bat gen-l10n`.
- [ ] **Step 4: Run** `flutter.bat test test/features/catalog test/core`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(catalog): the category screen switches sections in place (DL-127)"`

### Task 8: The category screen keeps sections, chips at large text, lying

**Files:**
- Modify: `frontend/lib/features/catalog/presentation/category_screen.dart`
- Test: `frontend/test/features/catalog/category_screens_test.dart`

**Interfaces:**
- Consumes: Task 3's grid (`header`, `alsoRefresh`, `alsoFailed`); Task 5's `ProductListCountRow`; Task 7's switch.
- Kept sections: the screen subscribes (`ref.listenManual`) to each section's list it showed and holds the subscriptions for its life. A section shown before comes at once and refreshes quietly (`ref.invalidate`), keeping its cards if that fails; a new one shows the grid's skeletons.
- The grid lists `ProductListQuery(categoryId: selected, sort: productSortProvider)` with `header: [ProductListCountRow(…)]`, `alsoRefresh` refreshing `catalogCategoriesProvider`, and `alsoFailed` from the categories' failure with their `Loaded.at` (the stage 6 residual).
- Large text — `textScaleAt(scaler, 11) > 1.3`: the rail gives way to a chips row under the header keyed `category-chips` (horizontal, padding 2 16 10, gap 8); a chip keyed `chip-<id>`: min height 44, padding 4 × 16, radius 22, `KitColors.chip`, 13 `w600` `KitColors.ink2` on one line; the selected one `KitColors.primaryWash` with a 2 px inner `KitColors.primary` border and `KitColors.primaryDark` text, colours changing in 200 ms; the same `PressScale`, semantics, haptic and announcement as a rail item; the selected chip centred on opening, scrolled minimally on a switch. The grid then takes the full width (padding 16 at the sides).
- Lying: the body sits in `SafeArea(top: false, bottom: false)`; columns follow `productColumns`.

- [ ] **Step 1: Write the failing tests.** The `catpage-6` reproduction: `'lying with a notch nothing sits under the camera and four columns stand'` (812 × 375, insets 47: the rail's left ≥ 47, the last card's right ≤ 812 − 47, four cards in the first row, the cart bar inside). `'a section shown before comes at once; a new one shows skeletons'` (`requests`); `'offline a section shown before keeps its cards under Нет связи · данные на 12:46'`; `'a pull refreshes the section and the categories'` (`categoryLoads` + 1); `'the categories failing alone show their stale line'`; `'shows 1 товар · Как в магазине and the menu re-sorts the section'`; `'at text x2 the rail becomes chips under the header and the products take the full width in two columns'`; `'a chip reads like a rail item and switches the same way'`; `'at text x2 with two sessions and a cart nothing overflows'` (320 × 640, ru and uz); `'the category screen meets the tap target guideline'` (rail, chips at ×2, lying).
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/catalog/category_screens_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter.bat test test/features/catalog test/features/cart test/core`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(catalog): kept sections, chips at large text and the safe sides on the category screen (DL-127)"`

### Task 9: Decisions, documents and the batch file

**Files:**
- Modify: `docs/DECISIONS.md` (`DL-127`), `docs/03-*.md` (the catalog paragraph's "sort any list by price"), `docs/07-*.md` section 29 (a rail switch is not a route), `tasks/APPLE_BATCH.md` ("Review findings not acted on")

- [ ] **Step 1: Write `DL-127` — The Apple batch, stage 7: category screen and product lists (agent).** One numbered line per decision: (1) a section switch changes the screen's state, not the route; back leaves the screen (`catpage-1`, reproduced); (2) the screen keeps the sections it showed for its life and refreshes a revisited one quietly (`catpage-2`); (3) `KitProductGrid` owns every list state, so «Рекомендуем», «Все товары» and search change with the category; another order dims the old cards (`rec-3`'s «мягко»); (4) the next page at `extentAfter < 3` rows, one placeholder row, the failure in its place (`rec-4`, reproduced); (5) columns `productColumns` (124 / 150 × the name's text factor), side safe areas on every list screen and the cart bar (`catpage-6`, reproduced); (6) large text from `textScaleAt(…, 11) > 1.3` for chips and `> 1.3` at the name size for three-line names (`catpage-3`); (7) one order for every list (`productSortProvider`), chosen from a popup route at its button (`all-3`), which supersedes the sort sheet of drawing 10в and `DL-83`'s sheet; the count row on every list (`rec-3`, the agent's DL the rec test promised); (8) the scroll indicator sized by the server's total (`all-4`); (9) the cart bar's motion and arrow (`catpage-4`); (10) the rail's and the chips' spoken position and the switch announcement (`catpage-7`).
- [ ] **Step 2: docs/03** — "sort any list by price" → "every product list shows how many products it holds and orders them as in the shop, cheaper first or dearer first, from a menu at its order button (`DL-127`)". **docs/07 section 29** — one line: the category screen's rail and chips switch the shown section inside the page; the location keeps the opened category (`DL-127`).
- [ ] **Step 3: APPLE_BATCH** — the two stage 6 residuals (busy button label, the category screen's stale line) get "Fixed in stage 7 (`DL-127`)."; the stage 3 residual on the card's grow from `build()` gets "Stage 7 touched only the card's text lines; still open." Park the final review's findings not acted on, with rulings. Stage 7's row is flipped by the next stage's branch, as before.
- [ ] **Step 4: Verify** — `flutter.bat analyze`, `dart format --set-exit-if-changed lib test`, `git diff --check`, the full suite through `test-runner` (`flutter.bat test --concurrency=2`). Expected: clean, PASS.
- [ ] **Step 5: Commit** — `git commit -m "docs: stage 7 decisions, docs/03 and docs/07 lines, batch residuals (DL-127)"`

### After the tasks (the lead)

- [ ] Final `branch-reviewer` (opus) on `main..HEAD` against this plan and its Review Focus; one fix wave; a scoped re-review.
- [ ] Push, pull request, both required checks green, merge, delete the branch and the SDD workspace.
- [ ] Walk on the `barakabozor` emulator with the merged build: the rail switch (mid-glide), a revisit offline (stale line), 200 % (chips, three-line names, arrow bar), lying with the simulated cutout, the order menu, the next page's placeholders. 4–5 key shots `G:/tools/tmp/apple7-walk-*.png` for the Owner.
