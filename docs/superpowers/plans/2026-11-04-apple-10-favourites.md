# Apple Stage 10 — «Избранное» Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Favourites become an ordinary product list: «24 товара · Сначала новые ⌄» over the cards (new, cheaper, dearer), skeletons, the stale line, paging, and the not-sold favourites at the end under «Нет в продаже · 2 · Убрать все», whose cards are no links. Taking a heart off melts the card, the neighbours glide into its place and «Убрали из избранного: Помидоры · Вернуть» stays 5 s; the removal reaches the server when the bar ends, and offline the card comes back with the reason. Back on the tab the list is where it was, hearts set elsewhere fade in at the top, and offline the list stays under «Нет связи · Повторить». Empty favourites show a heart, the «Рекомендуем» row and «Все категории →»; a heart there flies the card into the list. Every heart set pops, taps a light haptic and bumps the «Избранное» tab. A screen reader hears «Избранное: 24 товара, 2 нет в продаже», named hearts, the removal and «Вернуть».

**Architecture:** The server orders favourites (available first, then the chosen order), counts the not-sold ones and removes them all in one call. On the client a favourites list is a `ProductListQuery` with `favorites: true` in the same `productListProvider`, so `KitProductGrid` and `ProductListCountRow` serve it unchanged; the old favourites controller and `FavoriteProduct` go. The list controller gains in-place operations (withdraw, restore, settle, put, a quiet refresh), and the grid animates any change of the same query that is not a later page: leaving cards melt, moved ones glide, new ones arrive. A pending removal lives in one per-account `FavoriteRemovals` notifier that sends it when its undo bar closes.

**Tech Stack:** Laravel 12 + PostgreSQL (order by subquery), Flutter 3.47.5, flutter_riverpod 3.4.3, go_router 18.1.2, `TweenSequence`, `OverlayEntry`, `TickerMode.valuesOf`, `HapticFeedback`, flutter_test (`tester.takeAnnouncements()`, `meetsGuideline(iOSTapTargetGuideline)`, `NonlinearTextScaler`, `SystemChannels.platform` mock for haptics).

**Spec:** `tasks/APPLE_BATCH.md` stage 10 (`fav-1` **repro**, `fav-3` list part **repro**, `fav-4` **server**, `fav-5` **server**, `fav-6`, `fav-7`, `fav-8`); the live test «Тест избранного - Apple» (local copy `G:/tools/tmp/w-fav/site/fav.html`, its «стало» state is the picture; its script holds the exact words and timings); `DL-78` (5), `DL-80` (3), `DL-118`, `DL-119`, `DL-125` … `DL-128`; `docs/09-api-contracts.md` §58; `frontend/AGENTS.md`, `backend/AGENTS.md`.

## Global Constraints

- Changes stay in `backend/`, `frontend/`, `docs/` and `tasks/`. No package, no lockfile change, no migration. Generated localizations come from `flutter gen-l10n`, never by hand.
- Strings (ru / uz), new:
  - `sortNewest` «Сначала новые» / «Avval yangilari»
  - `cardNotSoldSpoken` «{name}, нет в продаже» / «{name}, sotuvda yo'q»
  - `favoritesNotSoldSpoken` «Нет в продаже, {count}» / «Sotuvda yo'q, {count}»; `favoritesRemoveAll` «Убрать все» / «Hammasini olib tashlash»; `favoritesRemoveAllSpoken` «Убрать все снятые с продажи: {count}» / «Sotuvdan olinganlarni olib tashlash: {count}»
  - `favoriteRemoved` «Убрали из избранного: {name}» / «Sevimlilardan olib tashlandi: {name}»; `favoriteRestoredSpoken` «Снова в избранном: {name}» / «Yana sevimlilarda: {name}»; `favoriteRemoveOffline` «Не удалось убрать: нет связи» / «Olib tashlab bo'lmadi: aloqa yo'q»; `favoriteRemoveFailed` «Не удалось убрать. Попробуйте ещё раз» / «Olib tashlab bo'lmadi. Qaytadan urinib ko'ring»
  - `favoritesEntrySpoken` «Избранное: {count}» / «Sevimlilar: {count}»; `favoritesEntryNotSoldSpoken` «Избранное: {count}, {notSold} нет в продаже» / «Sevimlilar: {count}, {notSold} tasi sotuvda yo'q» (`notSold` a plain number)
  - Changed: `favoriteAddSpoken` «{name}: добавить в избранное» / «{name}: sevimlilarga qo'shish»; `favoriteRemoveSpoken` «{name}: убрать из избранного» / «{name}: sevimlilardan olib tashlash» (the product first).
  - Reused: `catalogUnavailable` (heading and card line), `catalogProductCount` for every `{count}` above that is a number of products (and for `{name}` of `favoriteRemoved` / `favoriteRestoredSpoken` when several go at once), `undoAction`, `recommendedTitle`, `searchAllCategories` (with a trailing 16 px `Icons.arrow_forward` outside semantics), `favoritesEmptyTitle`, `favoritesEmptyText`, `favoritesEmptyAction`, `favoriteFailed`, `categoryShownSpoken`, `sortPriceAsc`, `sortPriceDesc`. `favoritesEmptyAction` stays only for the row-less empty state.
- Motion, exactly. A card leaving melts in 190 ms `Curves.easeIn` to opacity 0 and scale 0.88 (with reduced motion: a 150 ms `Curves.easeIn` fade) and takes no taps; it leaves the list 200 ms after the tap (160 ms with reduced motion). A card whose place changed glides from its old place in 280 ms `Cubic(0.2, 0.8, 0.2, 1)`; a card not drawn before arrives by scale 0.9 → 1 and opacity 0 → 1 in 260 ms `Cubic(0.2, 0.8, 0.2, 1)`; with reduced motion nothing glides and an arrival fades in 200 ms `Curves.easeOut`. A later page keeps its 250 ms fade (`DL-127`). The removal's undo bar lasts 5 s; a failure bar the snack bar's default 4 s. A heart set pops in 340 ms: scale 1 → 1.34 (35 %) → 0.94 (35 %) → 1 (30 %), each segment `Cubic(0.2, 0.8, 0.2, 1)`; the «Избранное» tab icon bumps in 340 ms to `translateY(-3)` and scale 1.24 at 40 % and back, same curve. A heart taken off neither pops nor bumps. With reduced motion a heart set only changes colour; the light haptic stays (it is not motion). The empty state's card flies its photo 440 ms `Cubic(0.2, 0.8, 0.2, 1)`, laid out at the target's size and scaled from where it was (origin top-left), while the arriving card's photo is hidden; with reduced motion nothing flies.
- Drawing, from the test page. Not-sold heading: «Нет в продаже» 17 px w700 `KitColors.ink`, 6 px, the count 13 px w500 `KitColors.muted`, then «Убрать все» at the end as a 44 px text button 14 px w700 `KitColors.primaryDark`; 10 px above it. Empty state with products to recommend: top-aligned, a 112 px `KitColors.primaryWash` circle with a 60 px `Icons.favorite` in `KitColors.primary`, the title 20 px w700, the text 14 px / 1.4 `KitColors.muted`, «Рекомендуем» 17 px w700 start-aligned 28 px above and 6 px below the home's `RecommendedRow` (its cards as on the home), then «Все категории →» as a 44 px text button 14 px w700 `KitColors.primaryDark` 6 px below. Without products to recommend: today's centred layout with a 160 px circle holding a 96 px `Icons.favorite` and «За покупками».
- Colours are `KitColors` tokens. Amounts (`AGENTS.md` §5) are untouched; no `FittedBox` and no ellipsis on a price.
- A layout rule that follows text reads `textScaleAt(scaler, fontSize)` at the size of the text it holds (`DL-126`); tests at large text use `NonlinearTextScaler(2)`.
- Every state this stage draws — the list with the count row, the not-sold heading, the empty state with the row, the row-less empty state — passes `meetsGuideline(iOSTapTargetGuideline)` (batch rule).
- Tests that pinned the old drawing are rewritten to the new rule, each named in its task; no other test is deleted or weakened.
- Backend commands run as `docker compose -f docker/compose.yaml exec app …` from the repo root; never a destructive artisan command (`migrate:fresh`, `db:wipe`, `--env=testing` on the dev database). Flutter runs from PowerShell with `$env:TEMP='G:\tools\tmp'; $env:TMP='G:\tools\tmp'` and `G:\tools\flutter\bin\flutter.bat`; a full suite uses `--concurrency=2`.
- Comments read like the surrounding code: short `///` docs in plain English that name `DL-129`.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- `/security-review` once before the pull request: the branch adds a Customer route that deletes the Customer's data.

## Review Focus

1. Offline, a heart taken off on favourites: the bar ends, the removal fails, the card comes back at its old place with the neighbours gliding apart, its heart is red again on every screen, and «Не удалось убрать: нет связи» says why; a list rebuilt meanwhile never shows it twice. Task 5 test `'offline the card comes back to its place and says why'`.
2. A removal the server confirmed, then a scroll to the next page: no favourite is skipped and none repeats (the server's offsets moved by one). Task 3 test `'after a settled removal the next page neither skips nor repeats a product'`.
3. A new order or a pull while the undo bar shows: the bar goes, the removal reaches the server before the list is asked for, and the card does not come back. Task 5 tests `'a new order during the bar sends the removal first'`, `'a pull during the bar sends the removal first'`.
4. «Убрать все» with more not-sold favourites than are loaded (25 not sold, 20 loaded): all of them go in one call, the count row says the right number, no placeholder row or later page stays; «Вернуть» brings back the loaded ones and the rest of the list. Task 3 test `'withdrawNotSold takes every not-sold product, loaded or not, and ends the list'`, Task 5 test `'«Убрать все» takes every not-sold card and sends one removal'`.
5. Another Customer signs in on the phone while a removal waits for its bar: nothing is sent with the new session, and the new account's list never shows the old account's cards, counts or bar. Task 5 test `'another Customer during the bar: nothing is sent'`.

---

### Before the tasks (the lead)

- [ ] Reproduce `fav-1` (a heart taken off reloads the whole list from page 1: cut to 20, the scroll jumps, no undo) and `fav-3` list part (a heart set on the home reloads favourites from page 1 while the tab is hidden: the place below 20 is lost; nothing fades in; offline the return shows no stale line) on the `barakabozor` emulator with main's build (`a7c725e`), if the machine has the memory for it (commit free ≥ 4 GB with nothing else's emulator running); screenshots `G:/tools/tmp/apple10-repro-*.png`. If it has not, the first test of Task 5 and of Task 6, run red on main's code, stands as the reproduction, and `DL-129` says so.

### Task 1: Server — favourites order, the not-sold count, removing every not-sold one; the decision record

**Files:**
- Modify: `backend/app/Modules/Customer/Http/Controllers/FavoriteController.php`, `backend/app/Modules/Customer/Http/Requests/ListFavoritesRequest.php`, `backend/app/Modules/Customer/Actions/ChangeFavorites.php`, `backend/app/Modules/Customer/CustomerFavorites.php`, `backend/app/Modules/Customer/Http/Resources/FavoriteProductResource.php`, `backend/routes/api/v1/customer.php`
- Modify: `docs/09-api-contracts.md` §58, `docs/DECISIONS.md` (`DL-129`), `tasks/APPLE_BATCH.md` (rows 8 and 9 → «Merged (PR #131)»)
- Test: `backend/tests/Feature/Customer/FavoritesApiTest.php`

**Interfaces:**
- Produces: `GET /customer/favorites?sort=default|price_asc|price_desc&page=&per_page=` — the available favourites first, then the not-sold ones; inside each group `default` is newest first (`created_at` desc, then `id` desc), `price_asc` / `price_desc` the product's `market_price_uzs` (one markup orders the customer prices too, as the catalog does), ties newest first then `id`. An unknown `sort` is `422 validation_failed`. `meta` carries `unavailable_count` beside `pagination`: the Customer's favourites not available now, over the whole list.
- Produces: `DELETE /customer/favorites/unavailable` (no body) removes the Customer's own favourites that are not available now and answers `204`, also when there are none; any body field is `422`; registered before `favorites/{product}`.
- "Available" is one rule for the flag, the order, the count and the removal: the product is among `CustomerCatalogListing::visibleProducts()`. `FavoriteProductResource`'s `is_available` reads the same rule.

- [ ] **Step 1: Write the failing tests.** `test_favorites_list_the_available_first_newest_first`; `test_favorites_sort_by_price_both_ways_ties_newest_first`; `test_an_unknown_sort_is_refused`; `test_the_list_counts_the_not_sold_favourites_over_every_page` (25 favourites, 3 not sold — inactive product, archived product, inactive category — `per_page=10` → `meta.unavailable_count` 3 on page 1 and page 3); `test_removing_the_not_sold_favourites_keeps_the_available_and_other_customers_rows`; `test_removing_the_not_sold_favourites_refuses_a_body`; `test_removing_the_not_sold_favourites_needs_a_customer` (`401` with no token, `403` for an Operator); `test_the_unavailable_route_is_not_read_as_a_product`.
- [ ] **Step 2: Run them and see them fail.** Run: `docker compose -f docker/compose.yaml exec app php artisan test --filter=FavoritesApiTest` — Expected: FAIL.
- [ ] **Step 3: Implement**; order by subqueries on `customer_favorites.product_id` (no join that could repeat a row). docs/09 §58: the `sort` parameter and the order, `meta.unavailable_count`, the new route.
- [ ] **Step 4: Write `DL-129`** — the stage's decisions as this plan states them: the server order and its reasons (not-sold last so the heading groups them; newest first is the list's own "default"), `unavailable_count` in `meta`, one bulk removal (it also takes the not-sold favourites not yet loaded; a product that stops being sold during the 5 s bar goes with them), a favourites list as a `ProductListQuery`, the grid's motion rule, the removal sent when its bar closes and first when the list is asked for again, the quiet refresh when the tab shows, the haptic kept with reduced motion, the empty state's row being the home's `RecommendedRow` (cards with «+», wider than the test's), the reproduction (emulator or red tests). Flip rows 8 and 9 of `tasks/APPLE_BATCH.md` to «Merged (PR #131)».
- [ ] **Step 5: Run** the favourites and catalog backend tests, `pint --test`, `phpstan analyse`. Expected: PASS.
- [ ] **Step 6: Commit** — `git commit -m "feat(favorites): server order, not-sold count and removal of every not-sold favourite (DL-129)"`

### Task 2: Favourites through the product list and the kit grid

**Files:**
- Modify: `frontend/lib/features/catalog/domain/catalog.dart` (`CatalogProduct.isAvailable`, `ProductListQuery.favorites`), `frontend/lib/features/catalog/application/catalog_controllers.dart`, `frontend/lib/features/catalog/presentation/sort_menu.dart`, `frontend/lib/features/catalog/presentation/kit_product_grid.dart` (`_onlySortDiffers`), `frontend/lib/features/catalog/presentation/search_screen.dart` (its query comparison), `frontend/lib/features/catalog/presentation/kit_product_card.dart` (not-sold card)
- Modify: `frontend/lib/features/favorites/data/favorites_api.dart`, `frontend/lib/features/favorites/domain/favorites_repository.dart`, `frontend/lib/features/favorites/application/favorites_controllers.dart`, `frontend/lib/features/favorites/presentation/favorites_screen.dart`; delete `frontend/lib/features/favorites/domain/favorites.dart`
- Modify: `frontend/test/support/fake_favorites_repository.dart`, `frontend/test/app/page_transitions_test.dart`, `frontend/test/features/shells/presentation/customer_tabs_test.dart` (fixtures only)
- Test: `frontend/test/features/favorites/data/favorites_api_test.dart`, `frontend/test/features/favorites/favorites_screen_test.dart` (rewritten), `frontend/test/features/catalog/kit_product_card_test.dart`; delete `frontend/test/features/favorites/application/favorites_controllers_test.dart` (its list tests move to Task 3's file, its override tests to `frontend/test/features/favorites/application/favorite_overrides_test.dart`)

**Interfaces:**
- Produces: `CatalogProduct.isAvailable` (`bool`, default `true`); the favourites parse `is_available` into it.
- Produces: `ProductListQuery({…, bool favorites = false})` with `favorites` in `==` / `hashCode`; `const ProductListQuery.favorites({ProductSort sort = ProductSort.shop})`. Every place that compares or copies a query field by field carries `favorites`.
- Produces: `final class FavoritesPage { const FavoritesPage({required Paged<CatalogProduct> products, required int unavailable}); }`; `FavoritesRepository.list({required ProductSort sort, required int page}) → Future<FavoritesPage>`, `add`, `remove`, `removeNotSold() → Future<void>` (`DELETE /customer/favorites/unavailable`). `FavoriteProduct`, `FavoritesListState`, `FavoritesListController` and `favoritesListProvider` go.
- Produces: `ProductListState.unavailable` (`int`, default 0) and `ProductListState.perPage` (`int`, default 20, from the page); `ProductListController` asks the favourites repository for a favourites query (first page and later ones) and the catalog otherwise.
- Produces: `favoritesSortProvider` (`NotifierProvider<FavoritesSortController, ProductSort>`, `ProductSort.shop` at first, kept for the app's run, another account starts afresh) in `favorites_controllers.dart`.
- Produces: `sortLabel(AppLocalizations l10n, ProductSort sort, {bool newestFirst = false})` — `shop` reads `sortNewest` with `newestFirst`; `showSortMenu(anchor, current, {bool newestFirst = false})`; `ProductListCountRow` and the grid's order announcement pass `newestFirst: query.favorites`.
- Interim until Task 6: `FavoriteOverrides.change` invalidates the favourites lists of every order that exists, instead of `favoritesListProvider`.
- The screen: `kitAppBar` as today; body `KitProductGrid(query: ProductListQuery.favorites(sort: …), header: [ProductListCountRow(…)], empty: _Empty())`; today's full-screen error and spinner go (the grid's skeletons and stale line take their place). The count row is not drawn while the list is empty.
- A not-sold card (`available: false`) is no link (no tap, `Semantics(button: false)`), reads `cardNotSoldSpoken(name)`, keeps a working heart.

- [ ] **Step 1: Write the failing tests.** API: `'the favourites ask for the order and read the not-sold count'` (query `sort=price_asc`, `unavailable_count` 2 → `FavoritesPage.unavailable` 2), `'a favourite reads is_available into the product'`, `'removeNotSold deletes the not-sold favourites'`, `'a page without unavailable_count is malformed'`. Screen: `'favourites show the count and the order: «24 товара · Сначала новые»'`, `'the order menu offers new, cheaper and dearer and asks the server again'`, `'favourites load with skeletons and page two rows ahead'`, `'a failed first page stands as still skeletons under the stale line'`, `'empty favourites draw no count row'`, `'favourites pass the tap-target guideline'`. Card: `'a not-sold card is no link and reads «Черешня, нет в продаже»'`.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/favorites test/features/catalog/kit_product_card_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement.** Rewrite the screen tests that pinned the spinner, the full-screen error and the old `_Grid` to the grid's rule.
- [ ] **Step 4: Run** `flutter.bat test test/features/favorites test/features/catalog test/app test/features/shells`, `flutter.bat analyze`, `dart format --set-exit-if-changed lib test`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(favorites): favourites are a product list on the kit grid, with count and order (DL-129)"`

### Task 3: In-place operations on a product list

**Files:**
- Modify: `frontend/lib/features/catalog/application/catalog_controllers.dart`
- Test: `frontend/test/features/catalog/product_list_controller_test.dart`

**Interfaces:**
- Produces: `final class ListWithdrawal` — the products taken out with their indices, and the list's `total`, `unavailable` and `nextPage` before; opaque to callers.
- Produces on `ProductListController`: `ListWithdrawal? withdraw(Set<String> ids)` (loaded ones only; `null` when none is loaded; `total` and `unavailable` lowered); `ListWithdrawal? withdrawNotSold()` (every not-sold product: the loaded ones out, `total -= unavailable`, `unavailable = 0`, `nextPage = null` — the server puts them last, so nothing else is left to load); `void restore(ListWithdrawal w)` (back at their indices, clamped, with the counts and `nextPage` as they were; nothing on a list rebuilt since, by generation); `void settle(ListWithdrawal w)` (the server removed them: while more remain, `nextPage = items.length ~/ perPage + 1`, so the next page starts where the server's offsets now are and the id dedupe drops what repeats); `void put(CatalogProduct product)` (at the top, `total + 1`); `Future<void> quietRefresh()` (pages 1 to as many as are loaded, one after another, then the list replaced at once — no loading state; a failure sets `AsyncError` keeping the previous data, so the grid keeps the cards under the stale line; a page that `loadMore` brings meanwhile is dropped).

- [ ] **Step 1: Write the failing tests.** `'withdraw takes loaded products out with their places and lowers the counts'`; `'restore puts them back at their places with the counts and the next page'`; `'restore after the list was rebuilt changes nothing'`; `'withdrawNotSold takes every not-sold product, loaded or not, and ends the list'` (45 favourites, 25 not sold, 2 pages loaded → `total` 20, `unavailable` 0, `hasMore` false; `restore` → 45, 25, page 3 next); `'after a settled removal the next page neither skips nor repeats a product'` (fake server of 30, withdraw the 3rd, the fake deletes it, `settle`, `loadMore` → 29 distinct ids, every one of the server's); `'put adds a product at the top and counts it'`; `'quietRefresh reloads as many pages as were loaded with no loading state'`; `'a quietRefresh that fails keeps the list under its failure'`; `'a page loaded during a quietRefresh is dropped'`.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/catalog/product_list_controller_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the file, `flutter.bat analyze`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(catalog): product lists withdraw, restore, settle, put and refresh quietly (DL-129)"`

### Task 4: The grid's motion and the not-sold heading

**Files:**
- Create: `frontend/lib/features/catalog/presentation/grid_glide.dart`
- Modify: `frontend/lib/features/catalog/presentation/kit_product_grid.dart`, `frontend/lib/features/catalog/presentation/kit_product_card.dart` (`onHeartOff`)
- Test: `frontend/test/features/catalog/grid_glide_test.dart` (create), `frontend/test/features/catalog/grid_motion_test.dart` (create)

**Interfaces:**
- Produces: `typedef GridCellPlace = Offset Function(int index);` `GridCellPlace gridCellPlace({required int columns, required double cellWidth, required double rowExtent, int? tailStart, double tailTop = 0})` — a card's top-left in the list by its row and column; cards from `tailStart` on start a new row under an extra `tailTop` (the heading's laid-out height). `Map<String, Offset> glideOffsets({required List<String> before, required List<String> after, required GridCellPlace placeBefore, required GridCellPlace placeAfter})` — old place less new place for every id in both lists whose place changed.
- Produces on `KitProductGrid`: `Set<String> leaving = const {}` (those cards melt and take no taps); `Widget Function(int count)? notSoldHeading` (when set, the not-sold cards stand after this full-width heading, built with `state.unavailable`, drawn from the first not-sold card loaded on); `ValueChanged<CatalogProduct>? onHeartOff` (passed to each card); `Future<void> Function()? beforeRefresh` (awaited before a pull or «Повторить» asks again).
- Produces: `KitProductCard.onHeartOff` (`ValueChanged<CatalogProduct>?`) — a tap on a red heart calls it instead of changing the favourite.
- The rule: when the same query's items change and the change is not a later page appended, each card in `glideOffsets` glides and each id not drawn before arrives (Global Constraints); a removed one is gone at once (it has melted, or was hidden). The page fade of `DL-127` is unchanged. Moving onto rows of new widgets loses no glide: the offset is known at build time from the indices.
- The heading the favourites give: «Нет в продаже» + count + «Убрать все» (Global Constraints), `Semantics(header: true, label: favoritesNotSoldSpoken(catalogProductCount(count)))`, the button labelled `favoritesRemoveAllSpoken(…)`.

- [ ] **Step 1: Write the failing tests.** Unit: `'gridCellPlace puts a card by its row and column'`, `'not-sold cards start a row under the heading'`, `'glideOffsets gives each moved card its old place less its new one'`, `'a card that kept its place gets no offset'`. Widget: `'a leaving card melts and takes no taps'` (95 ms: 0 < opacity < 1; 190 ms: 0; a tap opens nothing); `'when a card is withdrawn its neighbours glide into place'` (the 2nd row's first card at 140 ms between its old and new place, at 280 ms in place); `'a restored card arrives at its old place'`; `'a later page still fades in and nothing glides'`; `'with reduced motion nothing glides and an arrival only fades'`; `'not-sold cards stand under «Нет в продаже · 2» with «Убрать все»'`; `'the heading waits for the first not-sold card'`; `'a red heart with onHeartOff calls it and sends nothing'`; `'a pull awaits beforeRefresh before asking again'`; `'the grid with the heading passes the tap-target guideline'`.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/catalog/grid_glide_test.dart test/features/catalog/grid_motion_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement**; the favourites screen passes `notSoldHeading` (its «Убрать все» left for Task 5).
- [ ] **Step 4: Run** `flutter.bat test test/features/catalog test/features/favorites`, `flutter.bat analyze`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(catalog): grid cards melt, glide and arrive; a not-sold heading (DL-129)"`

### Task 5: A heart taken off, with «Вернуть»; «Убрать все»

**Files:**
- Create: `frontend/lib/features/favorites/application/favorite_removals.dart`
- Modify: `frontend/lib/features/favorites/application/favorites_controllers.dart` (`FavoriteOverrides.mark`, `forget`), `frontend/lib/features/favorites/presentation/favorites_screen.dart`, the ru / uz `.arb` files
- Test: `frontend/test/features/favorites/application/favorite_removals_test.dart` (create), `frontend/test/features/favorites/favorites_screen_test.dart`

**Interfaces:**
- Consumes: Task 3's `withdraw`, `withdrawNotSold`, `restore`, `settle`; Task 4's `leaving`, `onHeartOff`, `beforeRefresh`, `notSoldHeading`.
- Produces: `FavoriteOverrides.mark(String productId, {required bool favorite})` (no request) and `forget(Iterable<String> productIds)`.
- Produces: `final class FavoriteRemoval { FavoriteRemoval({required ProductListQuery query, required ListWithdrawal withdrawal, required List<String> productIds, required bool everyNotSold}); }`; `FavoriteRemovals extends Notifier<FavoriteRemoval?>` (`favoriteRemovalsProvider`, rebuilt for another account — what it held is dropped unsent): `void hold(FavoriteRemoval removal, {required VoidCallback closeBar})` (a removal already held is committed first); `void undo(FavoriteRemoval removal)` (restore, `forget`, no request); `Future<ApiFailure?> commit(FavoriteRemoval removal)` (`removeNotSold()` for `everyNotSold`, else `remove` per id; success → `settle`, hearts stay off; failure → `restore`, `forget`; sends nothing when the account changed); `Future<void> flush()` (closes the held one's bar and awaits its commit); `bool get holding`.
- The screen: a red heart on a favourite → `mark(off)`, the card in `leaving`; 200 ms later (160 reduced) `withdraw`, `hold`, `showUndoBar(text: favoriteRemoved(name), duration: 5 s)`, announce `favoriteRemoved(name)`. «Вернуть» → `undo`, announce `favoriteRestoredSpoken(name)`. The bar closed any other way → `commit`; a failure shows `favoriteRemoveOffline` for a `NetworkFailure`, else `favoriteRemoveFailed`. «Убрать все» → the same with every loaded not-sold card leaving and `withdrawNotSold`, the name being `catalogProductCount(n)`. A new order and the grid's `beforeRefresh` await `flush()` first.

- [ ] **Step 1: Write the failing tests** (the first is the reproduction of `fav-1`: run it on main's code first and keep the red output for `DL-129`). `'taking a heart off keeps the other cards and asks the server for no list'`; `'the card melts and the bar says «Убрали из избранного: Помидоры · Вернуть» for 5 s, then the removal is sent'`; `'«Вернуть» puts the card back at its place and sends nothing'`; `'offline the card comes back to its place and says why'`; `'a second heart taken off sends the first at once; «Вернуть» brings back only the second'`; `'«Убрать все» takes every not-sold card and sends one removal'`; `'a new order during the bar sends the removal first'`; `'a pull during the bar sends the removal first'`; `'another Customer during the bar: nothing is sent'`; `'a screen reader hears the removal and «Вернуть»'`.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/favorites` — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter.bat test test/features/favorites test/features/catalog test/core/widgets/undo_bar_test.dart`, `flutter.bat gen-l10n`, `flutter.bat analyze`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(favorites): a heart taken off melts the card with «Вернуть»; «Убрать все» (DL-129)"`

### Task 6: Back on the tab

**Files:**
- Modify: `frontend/lib/features/favorites/presentation/favorites_screen.dart`, `frontend/lib/features/favorites/application/favorites_controllers.dart` (the interim invalidation goes)
- Test: `frontend/test/features/favorites/favorites_screen_test.dart`, `frontend/test/features/shells/presentation/customer_tabs_test.dart`

**Interfaces:**
- Consumes: Task 3's `quietRefresh`, Task 5's `holding`.
- The screen becomes shown (as `PeriodicRefresh` reads it: `ModalRoute.isCurrent` and `TickerMode.valuesOf(context).enabled`, after the frame) with a list loaded and no removal held → `quietRefresh()`. Shown with a list, and when the first page of a list comes, it announces `favoritesEntrySpoken(count)` or, with not-sold ones, `favoritesEntryNotSoldSpoken(count, notSold)`.
- `FavoriteOverrides.change` no longer touches the favourites lists.

- [ ] **Step 1: Write the failing tests** (the first two reproduce `fav-3`; run them on main's code first). `'a heart set on the home keeps the favourites place and pages'` (40 favourites loaded, scrolled past 20, a heart on the home, back → still 40, same offset); `'returning offline keeps the list under the stale line'`; `'a heart set elsewhere fades in at the top when the tab shows'`; `'a heart taken off elsewhere leaves the list when the tab shows'`; `'no quiet refresh while a removal waits for its bar'`; `'entering favourites says «Избранное: 24 товара, 2 нет в продаже»'`; `'a product page closed over favourites refreshes them quietly'`.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/favorites test/features/shells` — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the same, `flutter.bat analyze`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(favorites): the tab refreshes quietly when shown; new hearts fade in (DL-129)"`

### Task 7: A heart answers, on every card

**Files:**
- Modify: `frontend/lib/features/catalog/presentation/kit_product_card.dart`, `frontend/lib/features/favorites/application/favorites_controllers.dart` (`favoriteAddedProvider`), `frontend/lib/core/widgets/customer_tab_bar.dart`, the ru / uz `.arb` files (`favoriteAddSpoken`, `favoriteRemoveSpoken`)
- Test: `frontend/test/features/catalog/kit_product_card_test.dart`, `frontend/test/core/widgets/customer_tab_bar_test.dart`

**Interfaces:**
- Produces: `favoriteAddedProvider` (`NotifierProvider<FavoriteAdded, int>`, `void bump()`): a count of hearts set, per account.
- The card: a heart set → the pop, `HapticFeedback.lightImpact()`, `bump()`, then `FavoriteOverrides.change`; taken off → none of these. The tab bar's «Избранное» icon bumps on each new count (`ref.listen`), unless motion is reduced.

- [ ] **Step 1: Write the failing tests.** `'a heart set pops, taps a light haptic and bumps the «Избранное» tab'` (scale > 1.2 at 119 ms; `HapticFeedback.vibrate` with `HapticFeedbackType.lightImpact` on the platform channel; the tab icon's transform at 136 ms); `'a heart taken off neither pops nor bumps'`; `'with reduced motion a heart set only changes colour, the haptic stays'`; `'a heart on the home row, a grid and search bumps the tab alike'`; `'a heart reads «Помидоры: убрать из избранного»'`.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/catalog/kit_product_card_test.dart test/core/widgets/customer_tab_bar_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement**; update the tests that read the old heart words.
- [ ] **Step 4: Run** `flutter.bat test test/features/catalog test/core/widgets`, `flutter.bat gen-l10n`, `flutter.bat analyze`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(catalog): a heart set pops, taps a haptic and bumps the favourites tab (DL-129)"`

### Task 8: Empty favourites teach the heart

**Files:**
- Create: `frontend/lib/core/widgets/fly_over.dart`
- Modify: `frontend/lib/features/favorites/presentation/favorites_screen.dart`, `frontend/lib/features/catalog/presentation/recommended_row.dart` (`onHearted`), `frontend/lib/features/catalog/presentation/kit_product_card.dart` (`onHearted`, `photoKey`, `photoHidden`), `frontend/lib/features/catalog/presentation/kit_product_grid.dart` (`landing`)
- Test: `frontend/test/core/widgets/fly_over_test.dart` (create), `frontend/test/features/favorites/favorites_screen_test.dart`

**Interfaces:**
- Consumes: Task 3's `put`, `withdraw`.
- Produces: `Future<void> flyOver(BuildContext context, {required Rect from, required Rect? Function() to, required Widget child, Duration duration = const Duration(milliseconds: 440), Curve curve = const Cubic(0.2, 0.8, 0.2, 1)})` — an `OverlayEntry` that draws `child` laid out at the target's size and scaled from `from` (origin top-left), reading the target each frame, under `IgnorePointer` and `ExcludeSemantics`; it completes and removes itself when it lands or when the target is gone.
- Produces: `KitProductCard.onHearted` (`void Function(CatalogProduct product, Rect photo, Future<ApiFailure?> answer)?`, called as a heart is set, with the photo well's global rect), `photoKey` (`GlobalKey?`), `photoHidden` (`bool`, default `false`); `RecommendedRow.onHearted` passed to its cards; `KitProductGrid.landing` (`Map<String, GlobalKey>`: those cards get the key on their photo and hide it).
- The empty state (Global Constraints): a heart in the row → `put(product)`, the id into `landing`, after the frame `flyOver` from the row's photo to the new card's; on landing the id leaves `landing`. A failed answer → `withdraw({id})` (the card's own bar says `favoriteFailed`). With reduced motion no flight. «Все категории →» opens `CatalogPaths.categories`. Featured products loaded and none → the row-less state with «За покупками».

- [ ] **Step 1: Write the failing tests.** `'flyOver flies from one rect to the other and removes itself'`; `'flyOver ends when its target is gone'`; `'empty favourites show a heart, the texts, «Рекомендуем» and «Все категории»'`; `'a heart in the row puts the card into the list and its photo flies there'` (at 220 ms the ghost between the two rects and the card's photo hidden; at 440 ms no ghost, photo shown); `'a heart that fails takes the card back out'`; `'with reduced motion the card only fades in'`; `'without products to recommend «За покупками» stays'`; `'«Все категории» opens the categories'`; `'both empty states pass the tap-target guideline'`.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/core/widgets/fly_over_test.dart test/features/favorites` — Expected: FAIL.
- [ ] **Step 3: Implement**; rewrite the empty-state tests that pinned the basket picture.
- [ ] **Step 4: Run** `flutter.bat test test/features/favorites test/features/catalog test/core/widgets`, `flutter.bat analyze`, `dart format --set-exit-if-changed lib test`. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(favorites): empty favourites show «Рекомендуем»; a heart flies the card in (DL-129)"`

### After the tasks (the lead)

- [ ] Full suites by `test-runner`: frontend `flutter.bat test --concurrency=2`, backend `php artisan test`; `git diff --check`.
- [ ] `branch-reviewer` (opus) on `main..HEAD` with this plan and its Review Focus; one fix wave; findings not acted on go to `tasks/APPLE_BATCH.md` "Review findings not acted on" with a ruling.
- [ ] `/security-review`; push, pull request, both required checks green, merge, delete the branch and the SDD workspace.
- [ ] Walk on the emulator (deploy order: the backend first — the app now requires `unavailable_count`): un-heart with «Вернуть», offline un-heart, «Убрать все», a new order, a heart on the home then back to the tab, the empty state's flight, text at 200 %; 3–5 shots `G:/tools/tmp/apple10-walk-*.png`.
