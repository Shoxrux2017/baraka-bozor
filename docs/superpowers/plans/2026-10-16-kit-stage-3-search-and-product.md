# Kit Stage 3 — Search and Product Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Search and the product screen look and work like the approved `kit/03-poisk-tovar.dc.html`. Search gets its own screen with recent queries on the device, "Рекомендуем", results with a count, the sort and a nothing-found state. A search icon appears in the list headers. The product screen gets the kit layout with the substitution rule, the note, "Ещё в категории", a bottom bar with the stepper and "В корзину", an in-cart state that saves the cart line, and a gone state.

**Architecture:** Feature `catalog` gains `search_screen.dart` (route `/customer/search`), `recommended_row.dart` (the home's "Рекомендуем" row, now shared) and a rebuilt `ProductScreen` split into focused widgets (`product_screen.dart`, `product_bar.dart`, `more_in_category.dart`). Recent queries live in `features/catalog/application/recent_searches.dart`, which stores them per account through `PreferenceStore`, as `DeliveryAddressChoice` does. A domain helper `EstimatePreview` in `core/orders/` previews `≈ price × quantity` by `BR-MONEY-003`. There is no backend change: the API already searches, sorts and returns `meta.pagination.total`.

**Tech Stack:** Flutter 3.47.5, Riverpod 3, go_router, `flutter gen-l10n` (template `app_uz.arb`), Montserrat, `KitColors`, `flutter_secure_storage` (through `PreferenceStore`).

**Spec:** `kit/03-poisk-tovar.dc.html`, approved by the Owner 2026-10-16: 15 Поиск, 15а Значок поиска в шапке списков, 16 Результаты поиска, 16а Ничего не нашли, 17 Сортировка, 18 Товар, 18а Товар уже в корзине, 18б Товара больше нет. The Owner's `DL-82`: no reviews or stars now, both go to the roadmap. Docs: `docs/03` §5 (line 35), `docs/04` §6 (line 60), `docs/05` `BR-CAT-005`, `BR-MONEY-003`, `BR-CART-004`, `docs/09` §14 (lines 97, 108).

## Global Constraints

- Branch `task/kit-3-search-product` from `main` `1a6a659`. Never commit to `main`.
- Flutter: `G:/tools/flutter/bin/flutter` with `TEMP`/`TMP` = `G:\tools\tmp`, run from `frontend/`; `flutter analyze`; `dart format --set-exit-if-changed lib test`.
- Kit look exactly: colours only from `KitColors`; Montserrat; the card stays as `DL-81` built it. Sizes follow the drawing on a 375-wide screen and scale with the width.
- Prices: every product shows `≈ <MoneyFormat.uzs(price)>` with the unit as "за кг" / "kg uchun". There are no struck-out prices, discounts, stars, reviews or carousel dots.
- The server decides what a Customer sees, the price and the totals. The only client figure is the product screen's `≈` preview, made by `EstimatePreview` (Task 1), never in a widget. Quantities follow `QuantityRules` and the steps of `CardQuantity`.
- Every new or rebuilt screen has a widget test at 320×640 with `textScaleFactorTestValue = 2`, in `uz` and `ru`, without an exception. Pattern: `test/features/catalog/customer_home_test.dart:236-248`.
- No new package; `pubspec.lock` unchanged. Generated l10n is regenerated, never hand-edited. Texts are in Uzbek (the template) and Russian.
- Agent decisions are items of `DL-83` (agent) in `docs/DECISIONS.md`, written in the task that implements them; the affected `docs/01–09` section is updated in the same task. `DL-82` (Owner) is written in Task 1.
- Never delete, skip or weaken a test. A test whose flow changed is rewritten to assert the new flow; the home's search tests move to the search screen.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

- **Two accounts on one phone.** A query typed by account A never shows up in B's recent list. Signing out with the search screen open saves nothing under the wrong account, or under none.
- **The product screen against a cart that is loading, failing or changed elsewhere.** "В корзину" waits while the cart loads. An add answered with `cart_item_already_exists` turns into the in-cart state with the server's values, never a second line. A line removed from another device turns the screen back to a new add.
- **Fractional quantities.** A typed 1,25 kg steps to 1,75 and 0,75. The minus is disabled at the step (0,5 kg, 1 шт.). The plus stops at 9 999. The preview rounds half up: 12 075 × 1,5 = 18 112,5 → "≈ 18 113 сум".
- **Content at the extremes.** A 60-character name, a 2 000-character description, no description, no picture, a category missing from the category list: the screen holds at 320×640 with text ×2, and "Ещё в категории" hides itself when the category has nothing else.
- **Back navigation.** Home → search → product → back returns to the search with its query and results. Back from the search returns to where it was opened. "Все категории" in the nothing-found state opens every category, and back returns to the search.

---

### Task 1: Recent searches, the preview sum, the route and the Owner's decision

**Files:**
- Create: `frontend/lib/features/catalog/application/recent_searches.dart`, `frontend/lib/core/orders/estimate_preview.dart`
- Modify: `frontend/lib/features/catalog/presentation/catalog_paths.dart` (`static const String search = '/customer/search';`), `docs/DECISIONS.md`, `docs/06-roadmap.md` (the "later" row of the waves table and its section)
- Test: create `frontend/test/features/catalog/application/recent_searches_test.dart`, `frontend/test/core/orders/estimate_preview_test.dart`

**Interfaces:**
- Produces:
  - `class RecentSearches extends AsyncNotifier<List<String>>` with ctor `RecentSearches(this.account)`.
    - `static const int limit = 10`.
    - `static String preferenceKey(String account) => 'recent_searches.$account'`.
    - `Future<void> remember(String query)`: takes `ProductListQuery.searchOf(query)`; ignores a result shorter than 2 runes; puts it first; drops an earlier entry equal to it after folding (lower case, `ё` read as `е`); keeps at most `limit`; writes the list as a JSON array string.
    - `Future<void> clear()`: writes `[]`.
    - `build()` reads the key. A missing, unreadable or non-array value is an empty list, never an exception.
  - `final AsyncNotifierProviderFamily<RecentSearches, List<String>, String> recentSearchesProvider`: keyed by the account id and **not** auto-disposed, so a screen may call `remember` from `dispose` through a notifier it captured earlier.
  - `abstract final class EstimatePreview { static int lineUzs(int unitPriceUzs, String quantity); }`: `half_up(unitPriceUzs × quantity)` in integers through `QuantityRules.thousandths(quantity)`, as `BR-MONEY-003`; never a `double`.

- [ ] **Step 1: Failing tests.**
  - Recent searches (with `InMemoryPreferenceStore`, `test/support/in_memory_stores.dart`):
    - `remember('  помидоры ')` stores `["помидоры"]`; `remember('Помидоры')` then leaves one entry, the new spelling first.
    - `remember('ёжик')` after `remember('ежик')` keeps one.
    - Eleven different queries keep the newest ten.
    - `remember('a')` stores nothing.
    - Account `a` and account `b` read separate lists.
    - `clear()` empties the list.
    - A stored `not json` or `{"x":1}` reads as `[]`.
  - Preview: `lineUzs(12075, '1')` = 12075; `lineUzs(12075, '1.5')` = 18113; `lineUzs(21850, '2')` = 43700; `lineUzs(999, '0.001')` = 1; `lineUzs(1, '0.499')` = 0; `lineUzs(4945, '3')` = 14835.

  Run `flutter test test/features/catalog/application/recent_searches_test.dart test/core/orders/estimate_preview_test.dart` — FAIL.
- [ ] **Step 2: Implement** as in **Interfaces**, following `features/addresses/application/delivery_address.dart` (key per account, `preferenceStoreProvider`) and `core/orders/quantity_rules.dart` (thousandths).
- [ ] **Step 3: Run** the tests and `flutter analyze` — PASS.
- [ ] **Step 4: Docs.** In `docs/DECISIONS.md`, after `DL-81`:

```markdown
## DL-82 — Search and the product screen, kit stage 3 (2026-10-16, Owner)

The Owner approved the drawing `kit/03-poisk-tovar.dc.html`: search on its own screen, the search icon in the list headers, the nothing-found state, the three sorts of `DL-78`, the product screen with the substitution rule, the note, "Ещё в категории", the in-cart and gone states. Reviews and stars on the product screen, which the kit shows, are not built now. They go to the roadmap as a later item, to be decided on their own: who may review, moderation in the panel, and whether a rating belongs to the product or to the order.

## DL-83 — Search and the product screen, kit stage 3 (2026-10-16, agent)

1. **Recent searches** are kept on the device per account, as the delivery address is (`DL-75`): at most ten, newest first, repeats folded as the catalog search folds them (`DL-20`), queries under two letters ignored. A query is remembered when the Customer presses search on the keyboard, taps a recent query, or leaves the search screen with it typed. "Очистить" empties the list. They never reach the server.
2. **The product screen's sum** under "В корзину" is a preview, `half_up(price × quantity)` as `BR-MONEY-003`, computed by one domain helper. The cart and the order keep the server's figures.
```

  In `docs/06-roadmap.md`, add to the "later" row of the waves table: "product reviews and ratings (`DL-82`)". In the matching section, add one sentence: "Product reviews and ratings: the kit draws them; the Owner postponed them (`DL-82`)."
- [ ] **Step 5: Commit** — `feat(catalog): recent searches, the preview sum and the search path`.

---

### Task 2: The search screen and its entry points

**Files:**
- Create: `frontend/lib/features/catalog/presentation/search_screen.dart`, `frontend/lib/features/catalog/presentation/recommended_row.dart` (the home's `_Recommended`, made public as `RecommendedRow`, unchanged in look)
- Modify:
  - `frontend/lib/features/catalog/presentation/home_screen.dart`: the field becomes a tap target that pushes the search, with no inline results. `_query`, the debounce and the grid branch leave the home. The filter button keeps opening the sort and then every product.
  - `frontend/lib/features/catalog/presentation/catalog_routes.dart`: route `catalog-search` at `CatalogPaths.search`.
  - `frontend/lib/core/widgets/kit_app_bar.dart`: `kitAppBar({required String title, bool automaticallyImplyLeading = true, bool search = false})`. With `search`, the bar gets an action `IconButton` with key `open-search`, icon `Icons.search` 26 in `KitColors.ink`, tooltip `l10n.openSearch`, which pushes `CatalogPaths.search`.
  - The five call sites pass `search: true`: `favorites_screen.dart:36`, `all_products_screen.dart:27`, `all_categories_screen.dart:31`, `category_screen.dart:43`, `recommended_screen.dart:21`.
  - ARB files.
- Test: create `frontend/test/features/catalog/search_screen_test.dart`. Move into it, rewritten to the new screen, the search cases of `customer_home_test.dart` (:297, :348, :535, :547) and `catalog_screens_test.dart` (:186, :207, :231, :252). The home's test now asserts that tapping `catalog-search` opens the search. Add header cases to the existing test of each of the five list screens.

**Interfaces:**
- Consumes: Task 1 (`recentSearchesProvider`, `CatalogPaths.search`); `customerAccountProvider`; `productListProvider(ProductListQuery)` and its `ProductListState.total`; `productSortProvider`; `showSortSheet(BuildContext, ProductSort)`; `KitProductGrid`; `ProductListQuery.searchOf` and `searchMaxLength`.
- Produces: `SearchScreen()`. `static const Duration searchPause = Duration(milliseconds: 300)` moves here from the home. Keys:
  - `search-field`: autofocused, hint `catalogSearchHint`, `TextInputAction.search`, `LengthLimitingTextInputFormatter(ProductListQuery.searchMaxLength)`;
  - `search-back`, `search-clear`;
  - `search-sort`: only while a query is shown;
  - `recent-clear`, and `recent-<i>` for each chip;
  - `search-found`, `search-nothing`, `search-all-categories`.
  - `RecommendedRow()` keeps the key `open-recommended` and the behaviour of the home's row.

- [ ] **Step 1: Failing tests.**
  - **Typing.** Typing waits 300 ms before asking (one request for "помидор" typed letter by letter). An answer to an earlier query never replaces the current one. A 150-character paste is cut to 100. "  " shows the empty state, not a search.
  - **Empty field (15).** Shows "Недавние запросы" with the stored chips and "Очистить", then "Рекомендуем". With no recent queries the section is absent. With no featured product "Рекомендуем" is absent. Tapping `recent-1` fills the field, searches at once and moves that chip to the front.
  - **Results (16).** "Найдено: 4 товара" in `ru` and "Topildi: 4 ta mahsulot" in `uz`, plural forms 1/2/5 in `ru`. The grid shows the results in the current sort. `search-sort` → "Сначала дешевле" re-orders the results and is remembered by `productSortProvider`.
  - **Nothing found (16а).** The query in quotes, and `search-all-categories` opens every category. A failed page shows the existing retry.
  - **Remembering.** Submitting on the keyboard remembers the query. Going back with a query typed remembers it. Going back with an empty field remembers nothing. Account A's query is not in account B's list after switching the session in the harness.
  - **Back stack.** Opening a product from the results and going back shows the same query and results. `search-all-categories`, then back, returns to the search with its query.
  - **Entry points.** On the home, tapping `catalog-search` opens the search with the field focused, and back returns home. The home no longer shows results under its field. Each of the five list screens shows `open-search`, which opens the search.
  - All of the above at 320×640, text ×2, `uz`/`ru`.

  Run `flutter test test/features/catalog/search_screen_test.dart test/features/catalog/customer_home_test.dart` — FAIL.
- [ ] **Step 2: Implement** per drawings 15, 15а, 16, 16а, 17.
  - **Top row.** `chevron_left` 28, then the field (`KitColors.field`, radius 14, 50 high, a 1.5 `primary` ring while focused, `search` icon 22, `close` 20 `muted` when not empty), then the 50×50 `primary` radius 14 `tune` button while a query is shown.
  - **Sections.** "Недавние запросы" 16/700 with "Очистить" 13/500 `primary` at the right. Chips are `KitColors.field` radius 10 with a `history` 16 `muted` icon and text 13 `ink2`. "Рекомендуем" is `RecommendedRow`.
  - **Results.** The count line is 13 `muted` with the number part 600 `ink`, then `KitProductGrid(query: ProductListQuery(search: q, sort: sort), empty: <nothing-found>)`.
  - **Nothing found.** A 96 circle `primaryWash` with `search_off` 44 `primaryDark`, title 18/700, text 13 `muted`, and an outlined `primary` button "Все категории".
  - **Remembering.** Capture `ref.read(recentSearchesProvider(account).notifier)` while mounted. Call `remember` on submit, on a chip tap, and from `dispose` when the shown query is not empty. Never use `ref` inside `dispose`.
  - **ARB:**

    | Key | uz | ru |
    |---|---|---|
    | `searchRecentTitle` | "So'nggi so'rovlar" | "Недавние запросы" |
    | `searchRecentClear` | "Tozalash" | "Очистить" |
    | `searchFound` (plural) | "{count, plural, other{Topildi: {count} ta mahsulot}}" | "{count, plural, one{Найдено: {count} товар} few{Найдено: {count} товара} other{Найдено: {count} товаров}}" |
    | `searchNothingTitle` | "Hech narsa topilmadi" | "Ничего не нашли" |
    | `searchNothingText` | "«{query}» bo'yicha mahsulot yo'q. Yozilishini tekshiring — biz o'zbekcha ham, ruscha ham qidiramiz." | "По запросу «{query}» товаров нет. Проверьте написание — мы ищем и по-русски, и по-узбекски." |
    | `searchAllCategories` | "Barcha kategoriyalar" | "Все категории" |
    | `openSearch` | "Qidirish" | "Поиск" |

    Remove ARB keys that only the home's inline results used; check each with `grep`.
- [ ] **Step 3: Run** the catalog and favourites tests, `flutter analyze`, format — PASS.
- [ ] **Step 4: Docs.**
  - `DL-83` item 3: "**Search has its own screen** (`/customer/search`): the home's field opens it, and so does the search icon in the headers of every category, all categories, "Рекомендуем", every product and favourites. It searches the whole catalog in the current sort and shows the server's count. "Популярное сейчас" of the kit is "Рекомендуем", because no popularity figure exists."
  - `docs/03` §5 (line 35), after "search by name in both languages at once": "on a search screen opened from the home or from any list's header, which keeps the Customer's recent queries on the device (`DL-83`)".
  - `docs/07` §29: add `/customer/search` to the list inside `/customer`.
- [ ] **Step 5: Commit** — `feat(catalog): the search screen and the search icon in list headers`.

---

### Task 3: The product screen — layout, adding, "Ещё в категории" and the gone state

**Files:**
- Create: `frontend/lib/features/catalog/presentation/product_screen.dart` (`ProductScreen` moves here from `catalog_screens.dart`), `frontend/lib/features/catalog/presentation/product_bar.dart`, `frontend/lib/features/catalog/presentation/more_in_category.dart`
- Modify: `frontend/lib/features/catalog/presentation/catalog_screens.dart` (delete it if nothing else remains; move `_Retry` where it is used), `catalog_routes.dart` (import), ARB files
- Delete from use: `AddToCartSection` (`features/cart/presentation/add_to_cart.dart`) once nothing imports it; `LineOptionsFields` and `QuantityField` stay, because the cart uses them.
- Test: create `frontend/test/features/catalog/product_screen_test.dart`. Rewrite the product cases of `catalog_screens_test.dart` there and assert the new layout; never drop a case.

**Interfaces:**
- Consumes: `catalogProductProvider(id)`, `catalogCategoriesProvider`, `productListProvider(ProductListQuery(categoryId: …))`, `addToCartProvider(productId).notifier.add(NewCartLine)`, `currentCartProvider`, `favoriteOverridesProvider` / `isFavorite(ref, product)`, `CardQuantity.next`/`previous`, `QuantityRules.display`, `EstimatePreview.lineUzs`, `MoneyFormat.uzs`, `catalogEstimateExplain`, `cartNote`, the substitution labels, `cartAdded`, `cartOpen`.
- Produces:
  - `ProductScreen({required String productId})`.
  - `ProductBar({required CatalogProduct product, required String quantity, required ValueChanged<String> onQuantity, required Key actionKey, required String actionLabel, required VoidCallback? onAction, required bool busy})`: the stepper and the button. `onAction == null` disables the button; `busy` shows it waiting and ignores taps. Keys `product-minus`, `product-qty`, `product-plus`, and `product-sum` for the sum line (`≈ MoneyFormat.uzs(EstimatePreview.lineUzs(price, quantity))`). The button key is `actionKey`: `add-to-cart` here, `save-line` in Task 4.
  - `MoreInCategory({required CatalogProduct product})`: key `more-in-category`, header link `more-all`.

- [ ] **Step 1: Failing tests.**
  - **Layout (18).**
    - The app bar is `arrow_back`, the title "О товаре", and the heart `product-heart`. Tapping the heart fills it, and a refusal restores it with the snackbar.
    - Below: the picture well, the name, "≈ 12 075 сум" and "за кг", then the estimate panel with `catalogEstimateExplain`.
    - A description over three lines shows "Читать далее" (`product-more`), which expands it; no description means no paragraph.
    - Then "Если товара не будет" with three radios, `allowSimilar` chosen; the existing keys `line-substitution` and `substitution-<code>` stay.
    - Then the note field `line-note` with the hint and a counter "0 / 300", where 301 characters are refused.
    - The other-language name is no longer shown.
  - **Bar.**
    - Starts at "1 кг" (`product-qty`), with `product-minus` disabled at the step and `product-sum` "≈ 12 075 сум".
    - Plus gives "1,5 кг" and "≈ 18 113 сум". A piece product steps by 1. Plus at 9 999 stays.
    - `add-to-cart` sends `NewCartLine(quantity: '1.5', customerNote: <trimmed or null>, substitutionPolicy: <chosen>)` and shows `cartAdded` with the action "Открыть корзину".
    - While the add is in flight the button is busy, and a second tap sends nothing.
    - With the cart still loading, `add-to-cart` is disabled.
  - **More in category.** Up to four other products of the same category, never the product itself. The header uses the category's name; a category missing from the list uses `productMoreGeneric`. `more-all` opens `CatalogPaths.category(categoryId)`. The block is absent when the category has no other product, or when its list fails.
  - **Gone (18б).** A 404 from the fake shows `product-gone` with the title, the text and `product-gone-action`, which goes home. Another failure shows the existing `retry-load`.
  - Layout at 320×640, text ×2, `uz`/`ru`, with a 60-character name and a 2 000-character description.

  Run `flutter test test/features/catalog/product_screen_test.dart` — FAIL.
- [ ] **Step 2: Implement** per drawings 18 and 18б.
  - **Page.** A scrolling page with `ProductBar` as the `Scaffold.bottomNavigationBar`: white, shadow `0 -6 20 rgba(0,0,0,.06)`, padding 12/16 plus the bottom inset. The active-mode bar stays where `ProductScreen` shows it today.
  - **Picture.** The well is `KitColors.card`, radius 20, 20 from the sides, height `min(250, width × 0.67)`, with `ProductImage` at 68% of the height.
  - **Text.** Name 20/700 at line height 1.35. Price 22/700, unit 13 `muted`. The estimate panel is `primaryWash` radius 14 with an `info` 20 `primaryDark` icon and text 12 `ink2`. The description is 13 `ink2` at line height 1.6, three lines collapsed.
  - **Sections.** Headings 15/700, separated by a 1 px `line`. Radio rows are 44 high; `LineOptionsFields` may be split so the screen can place its parts, but the cart keeps its look. The note field is `KitColors.field` radius 14, at least 76 high.
  - **Bar.** The stepper is `KitColors.field` radius 14, 54 high, with 38 square `remove`/`add` buttons in `primaryDark`. The quantity is 14/600 with a dotted underline, because it opens Task 4's sheet. The button is `primary` radius 14, 54 high, with the label 15/600 and the sum under it 12/600.
  - **Gone.** As 16а, with `remove_shopping_cart`.
  - **ARB:**

    | Key | uz | ru |
    |---|---|---|
    | `productTitle` | "Mahsulot haqida" | "О товаре" |
    | `productReadMore` | "Batafsil" | "Читать далее" |
    | `productReadLess` | "Yig'ish" | "Свернуть" |
    | `productIfMissing` | "Mahsulot bo'lmasa" | "Если товара не будет" |
    | `productNoteHint` | "Masalan: qattiqroq, pishib o'tmagan" | "Например: покрепче, не перезрелые" |
    | `productMoreIn` | "«{category}» bo'limidan yana" | "Ещё в «{category}»" |
    | `productMoreGeneric` | "Shu bo'limdan yana" | "Ещё из этой категории" |
    | `productAddToCart` | "Savatga" | "В корзину" |
    | `productGoneTitle` | "Bu mahsulot endi sotilmaydi" | "Товара больше нет в продаже" |
    | `productGoneText` | "U katalogdan olib tashlangan. O'xshash mahsulotlarni bo'limlarda topish mumkin." | "Его убрали из каталога. Похожие товары можно найти в категориях." |
    | `productGoneAction` | "Katalogga" | "В каталог" |
- [ ] **Step 3: Run** the catalog and cart tests, `flutter analyze`, format — PASS.
- [ ] **Step 4: Docs.**
  - `DL-83` item 4: "**The product screen** follows the kit: a picture, the name, the `≈` price and the estimate's explanation, the description, then the substitution rule and the note that `docs/04` §6 puts on this screen, "Ещё в категории" (up to four products of the same category in the shop's order) and a bottom bar with the stepper and "В корзину". The stepper steps as the card does (`DL-80` item 2). The other-language name is dropped, because the search matches both languages anyway. A product the Customer can no longer see (`404`) shows that it is gone and leads to the catalog."
  - `docs/04` §6 (line 60): "from a product card with one tap or from the product screen, where the substitution rule and the note are chosen".
- [ ] **Step 5: Commit** — `feat(catalog): the kit product screen`.

---

### Task 4: The product already in the cart, and an exact quantity

**Files:**
- Create: `frontend/lib/features/catalog/presentation/quantity_sheet.dart`
- Modify: `product_screen.dart`, `product_bar.dart`, ARB files
- Test: `frontend/test/features/catalog/product_screen_test.dart`, `frontend/test/features/catalog/quantity_sheet_test.dart` (create)

**Interfaces:**
- Consumes: Task 3; `currentCartProvider` (the line whose `productId` is this product), `cartLineProvider(line.id).notifier.change(CartLinePatch)`, `CartLinePatch.between(line, quantity:, customerNote:, substitutionPolicy:)` and `isEmpty`, `QuantityField` (`line-quantity`), `QuantityRules.normalize`.
- Produces: `Future<String?> showQuantitySheet(BuildContext context, {required UnitCode unit, required String current})`. The sheet holds `QuantityField` and a `primary` button `quantity-done` "Готово". It returns the normalized quantity, or `null` when dismissed; an invalid entry shows the field's existing error and does not close.

- [ ] **Step 1: Failing tests.**
  - **In cart (18а).**
    - With the fake cart holding this product at "2" kg, "contact before" and the note "Покрепче", the screen shows `product-in-cart` "В корзине: 2 кг" above the name. The bar shows "2 кг" and "≈ 43 700 сум"; the radio and the note show the line's values. The button is `save-line` "Сохранить", disabled while nothing is changed.
    - Changing the quantity, the note or the radio enables it. Tapping it sends exactly `CartLinePatch.between(line, …)`, shows `productSaved`, and the button is disabled again.
  - **Moving between states.**
    - After a successful add on a new product, the screen turns into the in-cart state.
    - An add answered with `cart_item_already_exists` refreshes the cart, shows `productAlreadyInCart` and the in-cart state with the server's values. No second add is sent.
    - The line disappearing from the cart (fake refresh) turns the screen back to `add-to-cart` with "1".
    - The Customer's unsaved edits are not overwritten by a cart refresh that does not change this line.
  - **Exact quantity.** Tapping `product-qty` opens the sheet. "1,25" + `quantity-done` gives "1,25 кг"; then plus gives "1,75", minus "0,75". "0" and "abc" show the field's error and keep the sheet open. A piece product refuses "1,5".
  - At 320×640, text ×2, `uz`/`ru`, with the sheet open.

  Run `flutter test test/features/catalog/product_screen_test.dart test/features/catalog/quantity_sheet_test.dart` — FAIL.
- [ ] **Step 2: Implement** per drawing 18а.
  - The chip is `primarySoft` radius 8 with a `shopping_bag` 16 icon and text 12/600 `primaryDark`.
  - The sheet is white with a top radius of 28, a grab handle and the title "Количество" 16/700.
  - **ARB:**

    | Key | uz | ru |
    |---|---|---|
    | `productInCart` | "Savatda: {quantity}" | "В корзине: {quantity}" |
    | `productSave` | "Saqlash" | "Сохранить" |
    | `productSaved` | "Savat yangilandi" | "Корзина обновлена" |
    | `productAlreadyInCart` | "Bu mahsulot savatda bor — o'zgartirib, saqlashingiz mumkin" | "Этот товар уже в корзине — можно изменить и сохранить" |
    | `quantitySheetTitle` | "Miqdor" | "Количество" |
    | `quantitySheetDone` | "Tayyor" | "Готово" |
- [ ] **Step 3: Run** — PASS; analyze, format.
- [ ] **Step 4: Docs.** `DL-83` item 5: "**A product already in the cart** opens with its cart line: the quantity, the rule and the note. "Сохранить" changes that line and is active only when something changed, so the screen never creates a second line (`docs/04` §6). Tapping the quantity opens a sheet to type an exact amount, as the cart allows."
- [ ] **Step 5: Commit** — `feat(catalog): the product in the cart and an exact quantity`.

---

### Task 5: The card's carry-overs, favourites cleanup and the tracker

**Files:**
- Modify:
  - `frontend/lib/features/catalog/presentation/kit_product_card.dart`: `_Absorb` :453-461, the bottom row's `GestureDetector` :415-417, and the picture `Positioned.fill` :274-298.
  - `frontend/lib/features/favorites/application/favorites_controllers.dart`: delete `toggle` :35-36.
  - `tasks/REDESIGN_CUSTOMER.md`.
- Test: `frontend/test/features/catalog/kit_product_card_test.dart`, `frontend/test/features/favorites/application/favorites_controllers_test.dart` (the `toggle` calls at :53, :64, :78, :89, :92, :98, :111, :114, :168 become `change`, which returns `null` on success and the `ApiFailure` otherwise; the same cases, the same assertions on state).

- [ ] **Step 1: Failing tests.**
  - **TalkBack.** With `tester.ensureSemantics()`, a single card exposes exactly three tap targets: the card, the heart and "Добавить". Check with `find.semantics.byAction(SemanticsAction.tap)`: `findsNWidgets(3)`. In the cart, it exposes the card, the heart, minus and plus.
  - **Picture and heart.** For the compact (84), home (112) and grid (150) wells at widths 320 and 375, text ×1 and ×2, the rect of `picture-<id>` does not overlap the rect of `heart-<id>`.

  Run `flutter test test/features/catalog/kit_product_card_test.dart` — FAIL.
- [ ] **Step 2: Implement.**
  - **TalkBack.** Set `excludeFromSemantics: true` on `_Absorb`'s `GestureDetector` and on the bottom row's `GestureDetector`. The visible buttons keep their own semantics.
  - **Picture.** The side stays `0.7 × min(height, width)`. When the centred picture would reach the heart's 32×32 square at the top right, it moves down until its top is 2 below that square. It shrinks only if the well is too short for that, to `height − 34`.
  - **Favourites.** Delete `toggle` and move its tests to `change`.
- [ ] **Step 3: Run** the catalog and favourites tests, `flutter analyze`, format — PASS.
- [ ] **Step 4: Docs.** `tasks/REDESIGN_CUSTOMER.md`:
  - stage 2 → "Merged (PR #89, #90, #91, #92)";
  - stage 3 → "Поиск и товар", "In Progress";
  - remove the risk "The list screens' header search icon arrives with stage 3";
  - remove the two findings this task resolves (`toggle`; the TalkBack node and the picture corner);
  - keep the `ceilToDouble()` slack with the ruling "no functional effect, kept";
  - add any new risk.
- [ ] **Step 5: Commit** — `fix(catalog): the card's TalkBack node and picture corner; favourites cleanup`.

---

## After the tasks

1. Run the full frontend suite through `test-runner`, then `git diff --check`.
2. Run `branch-reviewer` with this plan, BASE `1a6a659` and HEAD, then one fix wave and a scoped re-review.
3. Open the PR, wait for both required checks to pass by grep, then merge.
4. Walk the real stack on port 8001 with the emulator `barakabozor`; the demo catalog already has real photos (`G:\tools\demo-photos`). Path: home → search "пом" → results → sort → product → «В корзину» → reopen the product (in cart) → change → «Сохранить» → nothing found → a category's search icon. Take 4–5 screenshots for the Owner: search with recent queries, results, the product screen, in cart, nothing found.
5. Restore `APP_URL=http://localhost:8000` in `backend/.env` after the walk.
