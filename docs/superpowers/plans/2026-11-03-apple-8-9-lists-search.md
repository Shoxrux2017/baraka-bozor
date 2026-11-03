# Apple Stages 8 + 9 — «Рекомендуем», «Все товары» and Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** «Все 24 ›» on the home row opens «Рекомендуем» with the visible row cards flying to their grid places and the title flying into the header; the list ends with «Это вся подборка: 24 товара · Все товары →», an empty one shows a picture, «Подборка пока пуста» and «Все категории», and a screen reader hears the count, each new page and each new order. «Категории» starts with a wide «Все товары · 42 товара ›» tile whose title flies into the header; «Все товары» in the shop's order goes aisle by aisle under headings «Овощи 8», with a chips row under the header that lights the aisle in view and glides to the one tapped. The home's search field flies up into the search screen's field, which stays full width; typing dims the old cards under a 2 px line and rolls the count; matching sections show on top from the first letter; scrolling hides the keyboard and the cart bar shows whenever the keyboard is down; each recent query has ×, «Очистить» has «Вернуть» for 5 s; nothing found is a compact message over the «Рекомендуем» row.

**Architecture:** One server change: each Customer category carries `product_count`, and the whole-catalog list in the shop's order goes category by category. A new core page, `flightPage`, opens a screen over the one below by a fade while chosen pieces (cards, a title, the search field) fly from where they were tapped to their places, and back; the platform's back gestures still drive it. `KitProductGrid` gains a list end, announcements, kept cards across queries, an empty slot at the top, and aisles. The aisles' state lives in one `ProductAisles` notifier shared by the chips row and the grid.

**Tech Stack:** Laravel 12 + PostgreSQL (Eloquent `withCount`, `orderBy` by subquery), Flutter 3.47.5, flutter_riverpod 3.4.3, go_router 18.1.2, `PageRoute` + `PageTransitionsTheme.buildTransitions`, `SliverVariedExtentList`, `ScrollController.animateTo`, flutter_test (`tester.takeAnnouncements()`, `meetsGuideline(iOSTapTargetGuideline)`, `debugDefaultTargetPlatformOverride`, `tester.view.viewInsets`, `NonlinearTextScaler`).

**Spec:** `tasks/APPLE_BATCH.md` stage 8 (`rec-1`, `rec-2`, `rec-5`, `rec-6`, `all-1`, `all-2` **server**, `all-5`) and stage 9 (`search-1`, `search-2` **repro**, `search-3`, `search-4`, `search-5` **repro**, `search-6`, `search-7`, `search-8`); the live tests «Тест подборки - Apple», «Тест всех товаров - Apple», «Тест поиска - Apple» (local copies `G:/tools/tmp/w-rec/site/rec.html`, `w-all/site/all.html`, `w-search/site/search.html`; their "стало" state is the picture); `DL-83`, `DL-118`, `DL-124` … `DL-127`; `docs/09-api-contracts.md` §14; `frontend/AGENTS.md`, `backend/AGENTS.md`.

## Global Constraints

- Changes stay in `backend/`, `frontend/`, `docs/` and `tasks/`. No package, no lockfile change, no migration. Generated localizations come from `flutter gen-l10n`, never by hand.
- Strings (ru / uz), new:
  - `homeSeeAllCount` «Все {count}» / «Barchasi {count}»; `recommendedAllSpoken` `{count, plural, one{Все {count} рекомендуемый товар} few{Все {count} рекомендуемых товара} other{Все {count} рекомендуемых товаров}}` / «Barcha {count} ta tavsiya etilgan mahsulot» (the spoken name starts with the visible words)
  - `recommendedEnd` «Это вся подборка: {count}» / «Bu butun to'plam: {count}»; `recommendedEmptyTitle` «Подборка пока пуста» / «To'plam hozircha bo'sh»; `recommendedEmptyText` «Все товары магазина — в категориях.» / «Do'kondagi barcha mahsulotlar — bo'limlarda.» (`recommendedEmpty` goes)
  - `catalogMoreLoading` «Загружаем ещё товары» / «Yana mahsulotlar yuklanmoqda»; `catalogMoreLoaded` «Загружено ещё {count}» / «Yana {count} yuklandi»
  - `aisleHeadingSpoken` «{name}, {count}» / «{name}, {count}»; `aisleChipSpoken` «{name}, раздел {index} из {count}» / «{name}, {count} tadan {index}-bo'lim»
  - `searchClearQuery` «Стереть запрос» / «So'rovni o'chirish»; `searchRecentClearSpoken` «Очистить недавние запросы» / «Oxirgi so'rovlarni tozalash»; `searchRecentSpoken` «{query}, недавний запрос» / «{query}, oxirgi so'rov»; `searchRecentRemove` «Убрать «{query}» из недавних» / ««{query}» so'rovini olib tashlash»; `searchRecentCleared` «Недавние запросы удалены» / «Oxirgi so'rovlar o'chirildi»; `searchSectionCaption` «раздел» / «bo'lim»; `searchSectionSpoken` «{name}, раздел» / «{name}, bo'lim»; `searchNothingSpoken` «Ничего не нашли по запросу «{query}»» / ««{query}» bo'yicha hech narsa topilmadi»
  - Reused: `categoryShownSpoken` «{name}: {count}» for «Рекомендуем: 24 товара», «Все товары: 42 товара» and «Сначала дешевле: 24 товара»; `catalogProductCount` for every `{count}` above that is a number of products; `searchFound`, `searchNothingTitle`, `searchNothingText`, `searchAllCategories`, `allProductsTitle`, `recommendedTitle`, `undoAction`, `sortLabel`. `catalogSearchClear` stays for the order picker.
- Motion, exactly. Flight page: pieces fly 400 ms `Cubic(0.2, 0.8, 0.2, 1)` (the search field 380 ms in, 360 ms back); the page fades in 240 ms `Curves.easeOut` after 60 ms and out 220 ms `Curves.easeIn`; the screen below stays still. A card or a title is laid out at its place's size and scaled from where it was (origin top-left); the search field stretches (laid out at the moving size). With reduced motion: no flight, the page fades in 200 ms `easeOut` and out 200 ms `easeIn`. The «Все товары» tile presses to 0.96 (`PressScale`, 120 ms). Lists: the end block fades in 250 ms `easeOut`. Aisles: the chips row folds and unfolds in 220 ms `Cubic(0.2, 0.8, 0.2, 1)`; a chip's colours change in 200 ms; a jump glides 400 ms `Cubic(0.2, 0.8, 0.2, 1)`; the chips row scrolls a chip into view 250 ms `easeOut`. Search: sections fade in 180 ms `easeOut`; the 2 px line's bar runs 1 s `easeInOut` from −40 % to 100 % of the width, over and over; the count rolls up from 45 % of its height with a fade in 240 ms `easeOut`. With reduced motion every one of these is at once, except the count (200 ms fade) and the 2 px line (still, full width, opacity 0.5).
- Colours are `KitColors` tokens. The chip of an aisle is `KitColors.chip` with `KitColors.ink2` text; the current one `KitColors.primaryWash` with `KitColors.primaryDark` text and a 1.5 px inner `KitColors.primaryDark` border.
- A layout rule that follows text reads `textScaleAt(scaler, fontSize)` at the size of the text it holds (`DL-126`); tests at large text use `NonlinearTextScaler(2)`.
- Amounts (`AGENTS.md` §5) are untouched; no `FittedBox` and no ellipsis on a price or a sum.
- Every screen this stage rewrites — «Рекомендуем» (list, end, empty), «Категории» with its tile, «Все товары» with chips and headings, search (landing with recent queries and sections, results, nothing found) — passes `meetsGuideline(iOSTapTargetGuideline)` (batch rule).
- Tests that pinned the old drawing are rewritten to the new rule, each named in its task; no other test is deleted or weakened.
- Backend commands run as `docker compose -f docker/compose.yaml exec app …` from the repo root; never a destructive artisan command (`migrate:fresh`, `db:wipe`, `--env=testing` on the dev database). Flutter runs from PowerShell with `$env:TEMP='G:\tools\tmp'; $env:TMP='G:\tools\tmp'` and `G:\tools\flutter\bin\flutter.bat`; a full suite uses `--concurrency=2`.
- Comments read like the surrounding code: short `///` docs in plain English that name `DL-128`.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- `/security-review` once before the pull request: the branch changes a Customer API answer.

## Review Focus

1. Back in mid-flight (a tap on back 150 ms after the push, or a back-swipe let go halfway): the pieces turn back from where they are drawn, and when it settles nothing stays hidden — not the home's title or field, not a grid card on a reopened page. Task 2 tests `'a back mid-flight turns back from where it is and leaves nothing hidden'`, `'a back-swipe let go halfway stays open and shows every piece'`.
2. The screen's size changes while a flight page is open (the phone turned): back fades out without flying to places that no longer exist. Task 2 test `'after the screen size changes back fades without a flight'`.
3. A chip tap on an aisle beyond the loaded pages while offline: the jump stops at the in-place failure row, «Повторить» loads, nothing glides to a heading that is not there; a second chip tap during a jump wins. Task 6 tests `'a jump that cannot load stops at the failure row'`, `'a second chip tap during a jump goes to the second aisle'`.
4. A new search text that fails while another query's cards stand dimmed: those cards go, still skeletons stand under «Нет связи · Повторить», the found row hides; «Повторить» brings the results. Task 8 test `'a new query that fails drops the dimmed cards of another'`.
5. Recent queries: × on one, then «Очистить», then «Вернуть» gives back the list as it was before «Очистить»; leaving the screen while the undo bar shows keeps it cleared; another Customer on the phone never sees them. Task 9 tests `'Вернуть gives back the list as it was before Очистить'`, `'leaving during the undo keeps the list cleared'`.

---

### Before the tasks (the lead)

- [ ] Reproduce `search-2` (typing a second query swaps the cards for a spinner, the list jumps) and `search-5` (scrolling keeps the keyboard up, the cart bar rides above it; none on the landing) on the `barakabozor` emulator with main's build (`e2bd1da`), if the machine has the memory for it (commit free ≥ 4 GB with nothing else's emulator running); screenshots `G:/tools/tmp/apple89-repro-*.png`. If it has not, the first test of Task 7 and of Task 8, run red on main's code, stands as the reproduction, and `DL-128` says so.
- [ ] Remove the stage 7 SDD workspace (its walk was dropped by the Owner on 2026-11-03).

### Task 1: Server — the categories' product count, the whole list aisle by aisle

**Files:**
- Modify: `backend/app/Modules/Catalog/CustomerCatalogListing.php`, `backend/app/Modules/Catalog/Http/Resources/CustomerCategoryResource.php`, `docs/09-api-contracts.md` §14
- Modify: `frontend/lib/features/catalog/domain/catalog.dart` (`CatalogCategory.productCount`), `frontend/lib/features/catalog/data/catalog_api.dart` (`parseCategory`), every test fixture that builds a `CatalogCategory` or a category JSON
- Test: `backend/tests/Feature/Catalog/CustomerCatalogApiTest.php`, `frontend/test/features/catalog/catalog_api_test.dart`

**Interfaces:**
- Produces: every category of `GET /catalog/categories` carries `product_count` (integer ≥ 1): its active, unarchived products (`withCount` with the visibility rule of `visibleProducts`).
- Produces: `GET /catalog/products` with no `category_id`, no `search` and no `featured` orders, after the price order when there is one, by the category's `sort_order`, then its `name_uz`, then `products.category_id`, then `CatalogSearch::ordered` — by subqueries, not a join (the class's rule). Lists with any of the three filters keep their order.
- Produces: `CatalogCategory.productCount` (`int`, required); a category without `product_count` is malformed (`FormatException`), as `working_hours` is (`DL-125` (7)).

- [ ] **Step 1: Write the failing tests.** Backend: `test_categories_carry_the_count_of_their_visible_products` (an inactive and an archived product are not counted); `test_the_whole_list_in_the_shop_order_goes_aisle_by_aisle` (two categories with `sort_order` 2 and 1, products with `sort_order` that would interleave them → every product of the second category first, each block in product order); `test_a_price_order_breaks_ties_aisle_by_aisle`; `test_search_featured_and_category_lists_keep_their_order`. Frontend: `'a category carries its product count'`, `'a category without product_count is malformed'`.
- [ ] **Step 2: Run them and see them fail.** Run: `docker compose -f docker/compose.yaml exec app php artisan test --filter=CustomerCatalogApiTest`, `flutter.bat test test/features/catalog/catalog_api_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement**; docs/09 §14: categories carry `product_count`; "Both lists are ordered by …" becomes the categories' order, the products' order, and the whole list's aisle order (`DL-128`).
- [ ] **Step 4: Run** the backend catalog tests, `pint --test`, `phpstan analyse`, `flutter.bat test test/features/catalog`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(catalog): categories carry their product count; the whole list goes aisle by aisle (DL-128)"`

### Task 2: The flight page

**Files:**
- Create: `frontend/lib/core/routing/flight_page.dart`
- Modify: `frontend/lib/core/widgets/kit_app_bar.dart` (`titleFlight`)
- Test: `frontend/test/core/routing/flight_page_test.dart` (create)

**Interfaces:**
- Produces: `enum FlightFit { scale, stretch }`; `final class FlightItem { const FlightItem({required String id, required Rect from, required WidgetBuilder builder, FlightFit fit = FlightFit.scale}) }`; `final class FlightOpening { const FlightOpening({required List<FlightItem> items, required Size screen, ValueNotifier<bool>? holding}) }` — `from` in global coordinates, `screen` the size it was measured on; `holding` is true while the pieces are away from their sources, so a source can hide itself.
- Produces: `Page<void> flightPage(GoRouterState state, Widget child, {required FlightOpening? opening, Duration flight = const Duration(milliseconds: 400), Duration flightBack = const Duration(milliseconds: 400)})` — `appPage(state, child)` when `opening` is `null`; else a `PageRoute` page (opaque, `maintainState`) whose transition lasts `flight + 20 ms` in and `max(flightBack, 220 ms) + 20 ms` out (200 ms both with reduced motion, read from the page builder's context). Its `buildTransitions` hands `Theme.of(context).pageTransitionsTheme.buildTransitions(this, context, kAlwaysCompleteAnimation, secondaryAnimation, scene)` so the platform keeps its back gestures (Cupertino's edge swipe, Android's predictive back) and the page below its parallax, while `scene` follows the route's own `animation`. If the theme's builder cannot be driven so, write the iOS edge drag by hand after Flutter's `CupertinoBackGestureController` (`packages/flutter/lib/src/cupertino/route.dart`).
- Produces: `FlightTarget({required String id, required Widget child})` — a place a piece lands on; drawn at opacity 0 while its piece flies; a no-op outside a flight page.
- The scene: the page fades as Global Constraints say; above it each item whose target is built and at least partly on the screen flies between `from` and the target's rect, read each frame (an item without such a target does not fly); `holding` is set while the route animates and cleared when it settles; when the screen's size differs from `opening.screen`, nothing flies (fade only). Copies are wrapped in `HeroMode(enabled: false)`, `IgnorePointer` and `ExcludeSemantics`.
- `kitAppBar(…, bool titleFlight = false)` wraps the title in `FlightTarget(id: 'title')`.

- [ ] **Step 1: Write the failing tests** (a test router with a source page and a flight page). `'the page fades in over the still page below and the pieces fly from where they were'` (a piece's rect at 0, 200 and 400 ms: at 0 `from`, at 400 the target's; the page's opacity 0 at 60 ms, 1 at 300 ms; the target at opacity 0 until 400 ms); `'back flies the pieces home and fades the page out'`; `'a back mid-flight turns back from where it is and leaves nothing hidden'` (Review Focus 1); `'a back-swipe let go halfway stays open and shows every piece'` and `'a back-swipe past half closes the page'` (`TargetPlatform.iOS`); `'after the screen size changes back fades without a flight'` (Review Focus 2); `'holding is true while the pieces are away'`; `'a piece whose target is off the screen does not fly'`; `'with reduced motion it only fades, 200 ms'`; `'without an opening the platform page is used'`.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/core/routing/flight_page_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter.bat test test/core test/app`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(core): the flight page — fade over the page below while pieces fly to their places (DL-128)"`

### Task 3: «Все 24 ›» and the row's flight into «Рекомендуем»

**Files:**
- Modify: `frontend/lib/features/catalog/presentation/recommended_row.dart`, `section_title.dart` (`count`, `titleKey`, `holding`), `kit_product_grid.dart` (cards in `FlightTarget(id: 'card-<id>')`), `recommended_screen.dart` (`titleFlight: true`), `catalog_routes.dart` (`flightPage` for `catalog-recommended` when `extra` is a `FlightOpening`), both `.arb` files
- Test: `frontend/test/features/catalog/customer_home_test.dart`, `product_lists_test.dart`, `frontend/test/app/route_pages_test.dart` (the route's flight page with an opening, the platform's without)

**Interfaces:**
- Consumes: Task 2's `FlightOpening`, `FlightItem`, `FlightTarget`, `flightPage`, `kitAppBar(titleFlight:)`.
- `SectionTitle({…, int? count, GlobalKey? titleKey, ValueListenable<bool>? holding})` — with `count`, «Все» reads `homeSeeAllCount(count)` with `Icons.chevron_right` 18 after it (4 px pulled in at the end), spoken `seeAllLabel`; while `holding` is true the title is drawn at opacity 0.
- `RecommendedRow`: «Все» shows only while the featured list's `total` > `RecommendedRow.shown` (10), as «Все 24 ›», spoken `recommendedAllSpoken(total)`. Its tap measures the row cards that overlap the row's own box horizontally and the title, and pushes `CatalogPaths.recommended` with `FlightOpening(items: [one 'card-<id>' item per such card — a `KitProductCard` of the grid's size (`imageHeight` 150) —, a 'title' item — the app bar's title text], screen: …, holding: …)`; with reduced motion the items list is empty.

- [ ] **Step 1: Write the failing tests.** `'Все shows the total and only when the row cannot hold all'` (24 → «Все 24» with the chevron, spoken «Все 24 рекомендуемых товара»; 10 → no «Все»); `'the visible row cards fly to their grid places and the title into the header'` (at 200 ms a copy between the row card's rect and the grid card's; the grid card at opacity 0 until 420 ms; the home's title hidden while flying); `'back flies them home'`; `'with reduced motion Рекомендуем fades in'`; `'opened from the search icon it slides in as before'`. Rewrite tests that find a bare «Все» on the home row.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/catalog/customer_home_test.dart test/features/catalog/product_lists_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement**; `flutter.bat gen-l10n`.
- [ ] **Step 4: Run** `flutter.bat test test/features/catalog`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(catalog): Все 24 on the home row, its cards and title fly into Рекомендуем (DL-128)"`

### Task 4: The list's end, its announcements and the empty «Рекомендуем»

**Files:**
- Modify: `frontend/lib/features/catalog/presentation/kit_product_grid.dart`, `recommended_screen.dart`, both `.arb` files
- Test: `frontend/test/features/catalog/product_lists_test.dart`

**Interfaces:**
- `KitProductGrid` gains: `Widget? end` — drawn after the last row once the list has no more (not while empty); `String Function(ProductListQuery query, int total)? spokenOnQuery` — announced when the first page of a query comes, once per query, unless only its order changed from the query drawn before; `Alignment emptyAlignment = Alignment.center`.
- Every grid also: announces `categoryShownSpoken(sortLabel(sort), catalogProductCount(total))` when another order's first page comes; `catalogMoreLoaded(catalogProductCount(n))` when a later page adds `n` products; the failure row's text when a later page fails; the placeholder row is one node labelled `catalogMoreLoading`.
- «Рекомендуем»: `spokenOnQuery` gives `categoryShownSpoken(recommendedTitle, catalogProductCount(total))`; `end` is a block keyed `list-end`: top border 1 px `KitColors.line`, margin 22 16 0 inside the grid's padding, padding 18 16 16, centred column, gap 10; `recommendedEnd(catalogProductCount(total))` 13 / 1.4 `KitColors.muted`; a button keyed `list-end-all` — min height 44, padding 0 18, radius 12, `KitColors.primaryWash`, «Все товары» 14 `w600` `KitColors.primaryDark` and `Icons.arrow_forward` 20, gap 4 — pushing `CatalogPaths.products`; it fades in as Global Constraints say. `empty` (keyed `recommended-empty`): a 110 circle of `KitColors.primaryWash` with `Icons.shopping_basket_outlined` 56 `KitColors.primary`; 20; `recommendedEmptyTitle` 18 `w700` `KitColors.ink`; 8; `recommendedEmptyText` 13 / 20 px `KitColors.muted`; 22; a `FilledButton` keyed `recommended-empty-categories` — min height 46, padding 0 28, radius 12, `KitColors.primary`, `searchAllCategories` 14 `w600` — pushing `CatalogPaths.categories`; padding 0 40 at the sides.

- [ ] **Step 1: Write the failing tests.** `'the list ends with Это вся подборка: 24 товара and Все товары'` (none while more is to come; the button opens «Все товары»); `'an empty selection shows the picture, Подборка пока пуста and Все категории'` (rewrite of the test that reads «Пока нет рекомендованных товаров»); `'opening announces Рекомендуем: 24 товара once'` (a pull does not repeat it); `'a new order announces Сначала дешевле: 24 товара'`; `'a later page announces Загружено ещё 4 товара'`; `'a later page that fails announces its row'`; `'the placeholders read Загружаем ещё товары'`; `'Рекомендуем with its end and empty state meets the tap target guideline'`.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/catalog/product_lists_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement**; `flutter.bat gen-l10n`.
- [ ] **Step 4: Run** `flutter.bat test test/features/catalog`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(catalog): list end, announcements and the empty selection (DL-128)"`

### Task 5: The «Все товары» tile and its title's flight

**Files:**
- Modify: `frontend/lib/features/catalog/presentation/all_categories_screen.dart`, `category_tile.dart` (`AllProductsTile`), `all_products_screen.dart` (`titleFlight: true`, `spokenOnQuery`), `catalog_routes.dart` (`flightPage` for `catalog-all-products`)
- Test: `frontend/test/features/catalog/category_screens_test.dart` (group `'all categories'`), `product_lists_test.dart`, `frontend/test/app/route_pages_test.dart`

**Interfaces:**
- Consumes: Task 1's `CatalogCategory.productCount`; Task 2's flight; Task 4's `spokenOnQuery`.
- `AllProductsTile({required List<CatalogCategory> categories})`, keyed `all-products-tile`, first in the categories' scroll once they are loaded (a sliver before the grid, inside the grid's side padding, 14 below it): a `PressScale` labelled `categoryShownSpoken(allProductsTitle, catalogProductCount(Σ productCount))`; min height 72, padding 10 6 10 12, radius 16, `KitColors.primaryWash`; a 92 × 40 stack of the first three categories' pictures in 40 circles (white, the picture 26, a 2 px `KitColors.primaryWash` ring) at 0, 26 and 52 (fewer when fewer); 12; a column — «Все товары» 16 / 1.25 `w700` `KitColors.ink`, then `catalogProductCount(Σ)` 12 / 1.35 `KitColors.muted` —; `Icons.chevron_right` 24 `KitColors.primaryDark`. At large text (`textScaleAt(scaler, 16) > 1.3`) the pictures stay out. Its tap pushes `CatalogPaths.products` with a 'title' item from the tile's title (empty items with reduced motion); the tile's title hides while `holding`.
- «Все товары»: `spokenOnQuery` gives `categoryShownSpoken(allProductsTitle, catalogProductCount(total))`.

- [ ] **Step 1: Write the failing tests.** `'Категории starts with the Все товары tile and the sum of the counts'` (42 from three categories; read «Все товары: 42 товара», a button); `'the tile presses to 0.96'`; `'its title flies into the header of Все товары'`; `'with reduced motion Все товары fades in'`; `'at text x2 on 320 wide the tile fits without pictures'`; `'Категории with the tile meets the tap target guideline'`.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/catalog/category_screens_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter.bat test test/features/catalog`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(catalog): the Все товары tile on Категории, its title flies into the header (DL-128)"`

### Task 6: Aisles on «Все товары»

**Files:**
- Create: `frontend/lib/features/catalog/presentation/aisles.dart`
- Modify: `frontend/lib/features/catalog/application/catalog_controllers.dart` (`loadThrough`), `kit_product_grid.dart` (`aisles`), `all_products_screen.dart`, both `.arb` files
- Test: `frontend/test/features/catalog/aisles_test.dart` (create), `product_list_controller_test.dart`

**Interfaces:**
- Consumes: Task 1's order and counts; Task 4's announcements.
- Produces: `ProductListController.loadThrough(int count) → Future<void>` — next pages one after another until `count` products are loaded, there is no more, a page fails, or the list was rebuilt.
- Produces: `class ProductAisles extends ChangeNotifier` — `ProductAisles(List<CatalogCategory> categories)`; `categories` (settable, notifies); `String? current`; `Map<String, double> starts` (each aisle's heading offset in the scroll view, written by the grid after layout through `report(Map<String, double>)`); `int endOf(String id)` (the count of products up to and including that aisle, from `productCount`); `void follow(double pixels)` (current = the last aisle whose start ≤ `pixels + 10`; ignored while locked); `void lock()` / `unlock()`.
- Produces: `AisleHeading({required CatalogCategory category, Key? key})` keyed `aisle-<id>`: name 17 / 1.3 `w700` `KitColors.ink`, 6, `${productCount}` 13 `w500` `KitColors.muted`, on one baseline, wrapping as a whole; padding top 14 (2 for the first), bottom 10; one node, a heading, labelled `aisleHeadingSpoken(name, catalogProductCount(productCount))`. `double aisleHeadingExtent(CatalogCategory c, double width, TextScaler scaler, TextDirection d, {required bool first})` measures it by `TextPainter`.
- Produces: `AisleChips({required ProductAisles aisles, required ValueChanged<String> onTap, Key? key})` keyed `aisle-chips`: horizontal, padding 2 16 4, gap 6; a chip keyed `aisle-chip-<id>` — a 44 high target around a 34 high pill, padding 0 14, radius 17, 13 `w500` (`w700` current), colours of Global Constraints; one node labelled `aisleChipSpoken(name, index, count)` with `selected` on the current; the current chip scrolled into view as Global Constraints say.
- `KitProductGrid(aisles: ProductAisles?)`: when given and the query's order is `ProductSort.shop`, the rows are one `SliverVariedExtentList` — a heading row (`aisleHeadingExtent`) before each run of products of one category (only once its first product is loaded; an unknown category gets no heading), card rows (`extent + 12`), a half-filled row before a heading. After each layout it reports each heading's offset (the sliver's `constraints.precedingScrollExtent` plus the rows before). The scroll indicator's full extent counts, per aisle, the rows still to come and a heading for each aisle not begun.
- «Все товары»: under the app bar, outside the scroll, the chips row, folding as Global Constraints say when the order is not the shop's, with a 1 px `KitColors.line` under it while open; the grid has a `ScrollController` the screen owns, which drives `follow`. A chip tap: `lock`, current = that aisle; if `endOf(id)` products are not loaded, `await loadThrough(endOf(id))`; then, if its start is known, glide to `start − 6` (clamped; a jump with reduced motion), announce `aisleHeadingSpoken`, `unlock` 700 ms after the glide; a later tap cancels the earlier one's glide and announcement. Another order resets current to the first aisle and the chips to their start.

- [ ] **Step 1: Write the failing tests.** `'loadThrough loads pages until the count'` and `'loadThrough stops at a failure'`. `'in the shop order the products stand under aisle headings'` (Овощи 8, Фрукты 3: headings «Овощи 8» as headings, read «Овощи, 8 товаров»; a half row before «Фрукты»); `'a price order is flat and the chips fold'`; `'scrolling lights the aisle in view'`; `'a chip tap glides to its aisle and announces it'`; `'a chip tap beyond the loaded pages loads them first'` (60 products, `pageSize` 20, the last aisle → pages 2 and 3, then the glide); `'a jump that cannot load stops at the failure row'` and `'a second chip tap during a jump goes to the second aisle'` (Review Focus 3); `'chips read Фрукты, раздел 2 из 8 and the current one is selected'`; `'at text x2 on 320 wide the headings wrap and nothing overflows'`; `'lying with a notch the chips row keeps clear of the camera'`; `'Все товары with chips meets the tap target guideline'`.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/catalog/aisles_test.dart test/features/catalog/product_list_controller_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement**; `flutter.bat gen-l10n`.
- [ ] **Step 4: Run** `flutter.bat test test/features/catalog`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(catalog): Все товары goes aisle by aisle with a chips row (DL-128)"`

### Task 7: The search field's flight, the found row, the keyboard and the cart bar

**Files:**
- Modify: `frontend/lib/features/catalog/presentation/search_screen.dart`, `home_screen.dart` (`_SearchEntry`), `sort_menu.dart` (`ProductListCountRow.countText`, `keepAcrossSearch`), `kit_product_grid.dart` (`keyboardDismissBehavior`), `catalog_routes.dart` (`flightPage` for `catalog-search`, 380 / 360 ms), `frontend/lib/features/cart/presentation/cart_summary_bar.dart` (`hidden`)
- Test: `frontend/test/features/catalog/search_screen_test.dart`, `customer_home_test.dart`, `frontend/test/features/cart/cart_summary_bar_test.dart`, `frontend/test/app/route_pages_test.dart`

**Interfaces:**
- Consumes: Task 2's flight.
- `_SearchEntry`'s tap pushes `CatalogPaths.search` with one `FlightItem(id: 'search-field', fit: FlightFit.stretch)` — the field's look (`KitColors.field`, radius 14, `Icons.search` 22 `KitColors.muted`, the hint 14 `KitColors.muted`) — and hides itself while `holding`; the search screen's field is `FlightTarget(id: 'search-field')` and keeps `autofocus`, so the keyboard rises with the flight.
- The field takes the row's whole width (the `search-sort` square goes). Results: the grid's `header` holds `ProductListCountRow(countText: searchFound, keepAcrossSearch: true)` keyed `search-found`. `ProductListCountRow({…, String Function(int count)? countText, bool keepAcrossSearch = false})` — `countText` replaces `catalogProductCount` (the number found anywhere in it is drawn in ink, `w600`); with `keepAcrossSearch` the last total stays while another search loads and goes when it fails.
- `KitProductGrid(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag)` on search; the landing's list the same.
- `CartSummaryBar({bool hidden = false})` — while `hidden` it slides away (and with reduced motion fades) as an emptied cart does, and comes back as a first line does. Search shows the bar over the landing and the results, `hidden` while `MediaQuery.viewInsetsOf(context).bottom > 0` (supersedes `DL-83` (3)).

- [ ] **Step 1: Write the failing tests.** The `search-5` reproduction first: `'scrolling the results hides the keyboard'`; `'no cart bar while the keyboard is up; it comes back when it goes down'` (`tester.view.viewInsets`); `'the landing shows the cart bar'`. `'the home field flies up and stretches into the search field'` (at 190 ms the copy's width between the two fields'; the home field hidden while flying; focus on the field); `'with reduced motion search fades in'`; `'the field stays full width with a query; Найдено: 4 товара · Как в магазине sits above the cards'` (rewrite of `'the sort button opens the menu'` onto `list-sort`); `'the bar's hidden slides it away and back'` (cart bar test).
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/catalog/search_screen_test.dart test/features/cart/cart_summary_bar_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter.bat test test/features/catalog test/features/cart`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(catalog): the search field flies up, stays full width; keyboard and cart bar take turns (DL-128)"`

### Task 8: Typing without flicker

**Files:**
- Create: `frontend/lib/core/widgets/swap_in.dart` (the cart bar's `_Swap`, made public as `SwapIn`)
- Modify: `frontend/lib/features/cart/presentation/cart_summary_bar.dart` (uses `SwapIn`), `sort_menu.dart` (the count rolls), `kit_product_grid.dart` (`keepCardsOf`), `search_screen.dart` (the 2 px line)
- Test: `frontend/test/features/catalog/search_screen_test.dart`, `product_lists_test.dart`

**Interfaces:**
- Produces: `SwapIn({required Object swapKey, required int duration, required bool reduced, required Widget child, double? scaleFrom, double? riseFrom})` — the cart bar's behaviour unchanged.
- `ProductListCountRow`: the number rolls in by `SwapIn(riseFrom: 0.45, duration: 240)` when it changes from one known value to another.
- `KitProductGrid({bool Function(ProductListQuery drawn, ProductListQuery next)? keepCardsOf})` — default: only the order differs (as now). While the next query has no data and `keepCardsOf` holds, the drawn cards stay dimmed (as now); when the next query fails and its search text differs from the drawn one, they go and still skeletons stand under the stale line. Search passes: same category and `featuredOnly`.
- Search: a 2 px line keyed `search-progress` along the field's bottom edge (overlaying, `KitColors.primaryWash`, its bar 40 % wide `KitColors.primary`), while a query loads with another query's cards dimmed; as Global Constraints say.

- [ ] **Step 1: Write the failing tests.** The `search-2` reproduction first: `'typing a second query keeps the first one's cards dimmed under a 2 px line'` (opacity 0.45, `search-progress` shown, no skeletons); `'the new cards come and the count rolls to the new number'`; `'the first query shows skeletons'`; `'a new query that fails drops the dimmed cards of another'` (Review Focus 4); `'a refresh of the same query that fails keeps its cards under the stale line'`; `'with reduced motion the line stands still at half opacity'`. The cart bar's tests stay green unchanged.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/catalog/search_screen_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter.bat test test/features/catalog test/features/cart test/core`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(catalog): typing dims the old cards under a line and rolls the count (DL-128)"`

### Task 9: Sections on top, recent queries, nothing found, the reader

**Files:**
- Modify: `frontend/lib/features/catalog/presentation/search_screen.dart`, `frontend/lib/features/catalog/application/recent_searches.dart` (`forget`, `restore`, the fold made public), `frontend/lib/core/widgets/undo_bar.dart` (`duration`, `margin`), both `.arb` files
- Test: `frontend/test/features/catalog/search_screen_test.dart`, `frontend/test/features/catalog/application/recent_searches_test.dart`

**Interfaces:**
- Consumes: Task 4's `spokenOnQuery`, `emptyAlignment`; Task 7's screen.
- Produces: `RecentSearches.fold(String) → String` (static, public: lower case, `ё` as `е`, every apostrophe form as `'`); `forget(String query)`; `Future<List<String>> clear()` returning the list it cleared; `restore(List<String> list)`.
- Produces: `showUndoBar(…, Duration duration = undoBarDuration, EdgeInsetsGeometry? margin)`.
- Sections: on every keystroke, the categories (`catalogCategoriesProvider`) whose name in either language contains the folded text, at most 2, in category order, above the recent queries or the found row, keyed `search-sections`, with a 1 px `KitColors.line` under them and 8 below, fading in as Global Constraints say. A row keyed `search-section-<id>`: min height 56, padding 6 8 6 16, gap 12; a 44 well (radius 10, `KitColors.primaryWash`, the picture 28); the shown name 15 / 1.3 `KitColors.ink2` with the matched part `w700` `KitColors.ink`, under it `searchSectionCaption` 12 / 1.3 `KitColors.muted`; `Icons.chevron_right` `KitColors.muted`; one node labelled `searchSectionSpoken(name)`; its tap remembers the typed text and pushes `CatalogPaths.category(id)`.
- Recent queries: the title is a heading; «Очистить» (min height 44, padding 0 8, radius 10, 13 `w600` `KitColors.primaryDark`) spoken `searchRecentClearSpoken` clears them and shows the undo bar «Недавние запросы удалены · Вернуть» for 5 s above the cart bar when it shows; «Вернуть» calls `restore`. A chip (min height 44, radius 12, `KitColors.field`): the text part (padding start 12, `Icons.history` 16 `KitColors.muted`, 6, the query 13 `KitColors.ink2` on one line with an ellipsis) labelled `searchRecentSpoken(query)`, and a 44 × 44 × (`Icons.close` 18 `KitColors.muted`) labelled `searchRecentRemove(query)` that calls `forget`, without undo.
- The field's clear button reads `searchClearQuery`.
- Nothing found (the grid's `empty`, `emptyAlignment: Alignment.topCenter`): padding 12 32 4; a 64 circle of `KitColors.primaryWash` with `Icons.search_off` 30 `KitColors.primaryDark`; 10; `searchNothingTitle` 18 / 1.3 `w700`; 8; `searchNothingText(query)` 13 / 1.5 `KitColors.muted`; 16; the outlined «Все категории» (min height 48, padding 0 24, radius 14); then the `RecommendedRow`.
- `spokenOnQuery` on search: `searchFound(total)` or, at 0, `searchNothingSpoken(query.search)`.

- [ ] **Step 1: Write the failing tests.** `'from the first letter the matching sections show on top'` («фрукт» → «Фрукты и ягоды» and «Сухофрукты» even with no products; the matched part bold; at most two); `'a section opens its category and remembers the query'`; `'× takes away one query'`; `'Очистить clears them and Вернуть gives them back within 5 s'`; `'Вернуть gives back the list as it was before Очистить'` and `'leaving during the undo keeps the list cleared'` (Review Focus 5); `'nothing found is compact with the Рекомендуем row under it'` (rewrite of the test that reads the centred block); `'a finished search announces Найдено: 4 товара or Ничего не нашли по запросу «x»'`; `'the reader hears Стереть запрос, Очистить недавние запросы and …, недавний запрос'`; `'at text x2 on 320 wide the landing, sections and nothing found do not overflow'`; `'search meets the tap target guideline'` (landing with chips and sections, results, nothing found). RecentSearches: `'forget drops one query'`, `'clear returns what it cleared and restore puts it back'`.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/catalog/search_screen_test.dart test/features/catalog/application/recent_searches_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement**; `flutter.bat gen-l10n`.
- [ ] **Step 4: Run** `flutter.bat test test/features/catalog test/core`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(catalog): sections on top, recent queries with x and Вернуть, compact nothing found (DL-128)"`

### Task 10: Decisions, documents and the batch file

**Files:**
- Modify: `docs/DECISIONS.md` (`DL-128`), `docs/03-*.md` (the catalog and search paragraphs), `docs/07-*.md` section 29 (flight pages), `tasks/APPLE_BATCH.md`

- [ ] **Step 1: Write `DL-128` — The Apple batch, stages 8 and 9: «Рекомендуем», «Все товары» and search (agent).** One numbered line per decision: (1) categories carry `product_count`; the whole list in the shop's order goes aisle by aisle, other lists keep theirs (`all-2`); (2) the flight page: a fade over the page below while pieces fly, driven by the route's own animation under the platform's back gestures (`rec-1`, `all-1`, `search-1`); (3) «Все N ›» from the featured total, hidden at ≤ 10, its spoken name starting with the visible words (`rec-2`); (4) the list end, the empty selection, and the announcements of every list — opening, each page, each order, a failed page (`rec-5`, `rec-6`); (5) the «Все товары» tile from the categories' counts (`all-1`); (6) aisles: headings from the categories' counts, chips under the header, the aisle in view lit at 10 px, a jump loads through the aisle first (`all-2`, `all-5`); (7) the field full width, the order in the found row (`search-3`); (8) another query's cards stay dimmed under a 2 px line until the new ones come; a new text that fails drops them (`search-2`, reproduced how); (9) sections from the categories list, matched in both languages, at most two (`search-4`); (10) the keyboard leaves on a scroll, the cart bar shows whenever the keyboard is down, the landing included — supersedes `DL-83` (3) (`search-5`, reproduced how); (11) × without undo, «Очистить» with «Вернуть» for 5 s (`search-6`, as the test page draws it); (12) compact nothing found with the row (`search-7`); (13) the reader's names and announcements (`search-8`).
- [ ] **Step 2: docs/03** — the catalog paragraph: «Все товары» goes aisle by aisle in the shop's order; the search paragraph: sections on top, recent queries removable one by one, «Очистить» undoable. **docs/07 section 29** — one line: «Рекомендуем», «Все товары» and search opened from their home row, tile or field come by a flight page (`DL-128`).
- [ ] **Step 3: APPLE_BATCH** — stage 7's row reads «Merged (PR #130)»; Risks: the app now also requires `product_count` (deploy the backend first, as `working_hours`); park the final review's findings not acted on, with rulings. Stage 8's and 9's rows are flipped by the next stage's branch.
- [ ] **Step 4: Verify** — `flutter.bat analyze`, `dart format --set-exit-if-changed lib test`, `git diff --check`, the full frontend suite through `test-runner` (`flutter.bat test --concurrency=2`), the full backend suite (`php artisan test`, sequential), `pint --test`, `phpstan analyse`. Expected: clean, PASS.
- [ ] **Step 5: Commit** — `git commit -m "docs: stages 8 and 9 decisions, docs/03 and docs/07 lines, batch rows (DL-128)"`

### After the tasks (the lead)

- [ ] Final `branch-reviewer` (opus) on `main..HEAD` against this plan and its Review Focus; one fix wave; a scoped re-review.
- [ ] `/security-review`; push, pull request, both required checks green, merge, delete the branch and the SDD workspace.
- [ ] Walk on the `barakabozor` emulator if the machine has the memory (the Owner decides whether it is needed): «Все 24 ›» mid-flight, the list end, «Все товары» chips and a jump, the search field's flight, typing over results, the keyboard and the cart bar. 4–5 key shots `G:/tools/tmp/apple89-walk-*.png`. Then delete the 30 temporary products «Sinov ichimligi 01..30».
