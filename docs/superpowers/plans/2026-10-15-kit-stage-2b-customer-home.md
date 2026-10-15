# Kit Stage 2b — Customer Home Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Customer's home and catalog lists look and work like the approved `kit/02-glavnaya.dc.html`: the kit home, every category, a category with its rail, "Рекомендуем", every product in a chosen order, favourites, the four-tab bar, kit product cards with a heart, an approximate price, quick add and an in-card stepper, and the bar that leads to the cart.

**Architecture:** Feature `catalog` gains the kit screens (one file per screen) and shared kit widgets (`KitProductCard`, `KitProductGrid`, `CartSummaryBar`, `CategoryTile`); a new feature `favorites` holds the favourites API, the optimistic heart state and the screen; `core/widgets/customer_tab_bar.dart` is the four-tab bar used by the home, favourites, orders and profile. Data comes from stage 2a's API (`featured`, `sort`, `is_favorite`, category `image_url`, `/customer/favorites`). The product screen, search screens, cart, checkout, orders and profile keep their content until their own stages.

**Tech Stack:** Flutter 3.47.5, Riverpod 3, go_router, `flutter gen-l10n` (template `app_uz.arb`), Montserrat, `KitColors`.

**Spec:** `kit/02-glavnaya.dc.html` (approved 2026-10-15): 10 Главная, 10а сотрудник в режиме клиента / адреса нет, 10б Все категории, 10в Сортировка, 10г Все товары, 11–12 Раздел, 13 Рекомендуем, 14 Товар добавлен, 14а Избранное, 14б Избранное пусто; the Owner's `DL-78`; stage 2a's `DL-79` and API (`docs/09` §14, §58).

## Global Constraints

- Branch `task/kit-2b-customer-home` from `main` after stage 2a is merged. Never commit to `main`.
- Flutter: `G:/tools/flutter/bin/flutter` with `TEMP`/`TMP` = `G:\tools\tmp`, run from `frontend/`; `flutter analyze`, `dart format --set-exit-if-changed lib test`.
- Kit look exactly: colours only from `KitColors` (`primary #5AC268`, `primaryDark #44BA53`, `primarySoft #D5EFD9`, `primaryWash #EEF9F0`, `ink #151D16`, `ink2 #303731`, `muted #8E948F`, `line #EEF0EF`, `field #F9F9F9`, `card #FAFAFA`, `danger #F04438`); Montserrat; card radius 14, image well radius 12, buttons radius 9–10; the heart of a favourite is filled `danger`. Sizes follow the drawing (home card 150 wide, rail grid card 119, two-column card 161 on a 375 screen, scaling with the width).
- Prices: every product shows `≈ <MoneyFormat.uzs(price)>` and below it `за кг` / `kg uchun` (the unit's short label); no struck-out price anywhere.
- Every new or rebuilt screen has a widget test at 320×640 with `textScaleFactorTestValue = 2` in `uz` and `ru` without an exception (pattern: `test/features/catalog/customer_home_test.dart:236-248`). With two sessions the active-mode label stays whole at that size on the home.
- The server decides: the client never filters what a Customer may see, never computes a price; quantities follow `QuantityRules`.
- No new package; `pubspec.lock` unchanged; generated l10n regenerated, never hand-edited. Texts in Uzbek (template) and Russian.
- Each agent decision is an item of `DL-80` (agent) in `docs/DECISIONS.md`, written in the task that implements it; the affected `docs/01–09` section is updated in the same task.
- Never delete, skip or weaken a test; a test whose flow changed is rewritten to assert the new flow (the home's tests change most).
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

- Rapid taps on the in-card stepper or "Добавить": no duplicate line, no lost tap that leaves the shown quantity different from the cart's; the buttons wait while a change is in flight; a `cart_item_already_exists` answer turns into the stepper, not an error.
- A heart tapped while offline or refused: it returns to its previous state and says so; another account on the same phone never sees the previous account's hearts.
- Fractional units: "1,5 кг" shows and steps by 0,5; the minus at 0,5 kg or at 1 piece removes the line; a quantity typed elsewhere as 1,25 kg steps to 1,75 and 0,75.
- Back navigation: from a tab other than the home the system back returns to the home, never closes the app; a screen pushed over a tab (a product, an order) still goes back to that tab.
- A category with no picture, a very long category or product name, an empty "Рекомендуем", an empty favourites list, a list that fails to load: each shows the drawing's state or a retry, never a crash or overflow.

---

### Task 1: Catalog and favourites data for the kit

**Files:**
- Modify: `frontend/lib/features/catalog/domain/catalog.dart` (`CatalogCategory.imageUrl`, `CatalogProduct.isFavorite`, `ProductListQuery.featuredOnly` and `.sort`, new `enum ProductSort { shop('default'), priceAsc('price_asc'), priceDesc('price_desc') }`), `frontend/lib/features/catalog/data/catalog_api.dart` (send `featured=1` and `sort`; parse `image_url`, `is_favorite`), `frontend/lib/features/catalog/application/catalog_controllers.dart` (`productSortProvider`)
- Create: `frontend/lib/features/favorites/domain/favorites.dart`, `frontend/lib/features/favorites/domain/favorites_repository.dart`, `frontend/lib/features/favorites/data/favorites_api.dart`, `frontend/lib/features/favorites/application/favorites_controllers.dart`
- Test: `frontend/test/features/catalog/data/catalog_api_test.dart`, create `frontend/test/features/favorites/data/favorites_api_test.dart`, `frontend/test/features/favorites/application/favorites_controllers_test.dart`, create `frontend/test/support/fake_favorites_repository.dart`; modify `frontend/test/support/fake_catalog_repository.dart` (honour `featuredOnly` and `sort`), `frontend/test/support/app_harness.dart` (`favorites:` parameter)

**Interfaces:**
- Produces:
  - `final class FavoriteProduct { final CatalogProduct product; final bool isAvailable; }`
  - `abstract interface class FavoritesRepository { Future<Paged<FavoriteProduct>> list({required int page}); Future<void> add(String productId); Future<void> remove(String productId); }` (use the `Paged` type of `core/network/paged.dart`)
  - `favoritesRepositoryProvider`; `favoriteOverridesProvider` — a notifier keyed to the signed-in Customer account (cleared when the account changes, as the cart's account-keyed providers are) holding `Map<String, bool>`, with `Future<bool> toggle(String productId, {required bool current})` that sets the override to `!current` at once, calls add/remove, and on failure restores the previous value and returns `false`; `bool isFavorite(WidgetRef ref, CatalogProduct p)` = override ?? `p.isFavorite`.
  - `favoritesListProvider` — paged list (`AsyncNotifier`, `loadMore()`), refreshed after a toggle completes.
  - `productSortProvider` — `NotifierProvider<…, ProductSort>`, default `ProductSort.shop`, kept for the app's run.

- [ ] **Step 1: Failing tests.** API: `ProductListQuery(featuredOnly: true, sort: ProductSort.priceAsc)` sends `featured=1&sort=price_asc`; `ProductSort.shop` sends no `sort`; `image_url` and `is_favorite` parse, missing `is_favorite` is a malformed response (as other required fields are). Favourites API: `GET /customer/favorites?page=` parses entries and `is_available`; `PUT` and `DELETE /customer/favorites/<id>` send no body. Controller: toggle flips at once; a failing fake restores and returns false; switching the signed-in account clears overrides.
  Run `flutter test test/features/catalog/data test/features/favorites` — FAIL.
- [ ] **Step 2: Implement** as in **Interfaces**, following `catalog_api.dart`'s parsing helpers and the cart's account-keyed provider pattern (`cart_controllers.dart`).
- [ ] **Step 3: Run** the tests, `flutter analyze` — PASS.
- [ ] **Step 4: Commit** — `feat(catalog): kit data — sort, recommended, pictures, favourites`.

---

### Task 2: The kit product card with quick add and the in-card stepper

**Files:**
- Create: `frontend/lib/features/catalog/presentation/kit_product_card.dart`, `frontend/lib/features/cart/application/card_quantity.dart`
- Modify: ARB files (+ regenerate)
- Test: create `frontend/test/features/catalog/kit_product_card_test.dart`, `frontend/test/features/cart/application/card_quantity_test.dart`

**Interfaces:**
- Consumes: Task 1 (`isFavorite`, `favoriteOverridesProvider`), the cart's `AddToCartController.add(NewCartLine)`, `CartLineController.change(CartLinePatch)`, `CartListActions.remove(String lineId)`, `currentCartProvider`, `QuantityRules`.
- Produces:
  - `enum KitCardSize { compact, regular }` — compact for the rail grid (image well 84), regular for the home row and two-column grids (image well 112 on the home, 150 in grids via `imageHeight`).
  - `KitProductCard({required CatalogProduct product, KitCardSize size = KitCardSize.regular, double? imageHeight, bool available = true})`; keys: `product-card-<id>`, `heart-<id>`, `add-<id>`, `step-minus-<id>`, `step-plus-<id>`, `step-qty-<id>`, `unavailable-<id>`.
  - `abstract final class CardQuantity { static String step(UnitCode unit); static String? next(UnitCode unit, String current); static String? previous(UnitCode unit, String current); }` — `step` is `'0.5'` for units that take fractions and `'1'` otherwise; `next` adds the step, capped at `QuantityRules.maxWhole`; `previous` subtracts it and returns `null` when the result is not positive (the line is removed). Values are normalized by `QuantityRules.normalize`.

- [ ] **Step 1: Failing tests.** `CardQuantity`: kg `1` → next `1.5`, previous `0.5`; kg `0.5` → previous `null`; kg `1.25` → next `1.75`, previous `0.75`; piece `1` → previous `null`, next `2`; next of `9999` stays `9999`. Card: shows the name (Russian or Uzbek per locale), `≈ 12 000 сум` and `за кг`; tap `add-<id>` calls the fake cart with quantity `1`, `allowSimilar`, no note, then shows `step-qty-<id>` with `1 кг`; plus calls change with `1.5`; minus at `1 шт.` calls remove; while a change is pending both step buttons are disabled; a fake answering `cart_item_already_exists` refreshes the cart and shows the stepper; `heart-<id>` toggles the filled state and back on failure with a snackbar; `available: false` shows `unavailable-<id>` "Нет в продаже" and no add; tapping the card opens `CatalogPaths.product(id)`; compact and regular at 320×640, text ×2, `uz`/`ru`, a 60-character name — no overflow.
  Run `flutter test test/features/catalog/kit_product_card_test.dart test/features/cart/application/card_quantity_test.dart` — FAIL.
- [ ] **Step 2: Implement.** Layout per the drawing: white card, radius 14, padding 8, shadow `0 2 12 rgba(21,29,22,.06)`; image well `KitColors.card` radius 12 with `ProductImage` and the heart top-right (outline `ink`, filled `danger`); name 12/17 (13/20 regular) weight 500, two lines, ellipsis; price 13 (15 regular) weight 700 with `≈ `; unit line 11 (12) `muted`; full-width "Добавить" 32 (38) high, `primary`, white 12–13 weight 600; stepper: square `primary` buttons with `remove`/`add` icons and the quantity `QuantityRules.display(q) unit` between. ARB: `catalogApproxPrice` "≈ {price}"; `catalogPerUnit` uz "{unit} uchun" / ru "за {unit}"; `catalogAdd` "Qo'shish" / "Добавить"; `catalogUnavailable` "Sotuvda yo'q" / "Нет в продаже"; `favoriteFailed` "Saqlab bo'lmadi. Qayta urinib ko'ring" / "Не удалось сохранить. Попробуйте ещё раз"; semantic labels `favoriteAdd` "Sevimlilarga qo'shish" / "Добавить в избранное", `favoriteRemove` "Sevimlilardan olib tashlash" / "Убрать из избранного", `cartStepMinus` / `cartStepPlus`.
- [ ] **Step 3: Run** — PASS; analyze, format.
- [ ] **Step 4: Docs.** Start `DL-80` in `docs/DECISIONS.md`:

```markdown
## DL-80 — The Customer's kit home, kit stage 2b (2026-10-15, agent)

1. **The card.** Every list shows the kit card: picture, heart, name, `≈` price and "за кг". "Добавить" sits under the price at full width, because a price in сум is two to three times longer than the kit's "$12". A tap adds one unit (one kilogram, one piece) with "allow similar" and no note; a product already in the cart shows the stepper instead.
2. **The in-card stepper** steps by 0,5 for kilograms, litres and metres and by 1 otherwise; the minus at the step or below removes the line; any exact quantity is still typed in the cart. One change at a time per card.
```
  and `docs/04` §6 (line 60): "adds from a product card with one tap or from the product screen".
- [ ] **Step 5: Commit** — `feat(catalog): kit product card with quick add`.

---

### Task 3: Product lists — the grid, the cart bar, "Рекомендуем", every product and the sort

**Files:**
- Create: `frontend/lib/features/catalog/presentation/kit_product_grid.dart`, `frontend/lib/features/cart/presentation/cart_summary_bar.dart`, `frontend/lib/features/catalog/presentation/recommended_screen.dart`, `frontend/lib/features/catalog/presentation/all_products_screen.dart`, `frontend/lib/features/catalog/presentation/sort_sheet.dart`
- Modify: `frontend/lib/features/catalog/presentation/catalog_paths.dart` (`recommended = '/customer/recommended'`, `products = '/customer/products'`), `frontend/lib/features/catalog/presentation/catalog_routes.dart`, ARB files
- Test: create `frontend/test/features/catalog/product_lists_test.dart`

**Interfaces:**
- Consumes: Tasks 1–2; `ProductListController` (paged, `catalog_controllers.dart:73`).
- Produces: `KitProductGrid({required ProductListQuery query, int columns = 2, KitCardSize size = KitCardSize.regular, double imageHeight = 150, Widget? empty})` — paged, loads more at the end, failed load shows the existing retry; `CartSummaryBar()` — shown when the cart has a line: last line's picture, "N товар(а/ов)" (plural via ARB), `≈ <estimatedSubtotalUzs>`, "В корзину →", key `cart-summary`, opens `CartPaths.cart`; `Future<ProductSort?> showSortSheet(BuildContext context, ProductSort current)` — keys `sort-shop`, `sort-price-asc`, `sort-price-desc`; `RecommendedScreen()`, `AllProductsScreen()` (title "Все товары", a chip `sort-chip` with the current sort that reopens the sheet).

- [ ] **Step 1: Failing tests.** Recommended lists only featured products (fake honours `featuredOnly`); every product respects `productSortProvider` and the chip changes it (`sort-price-asc` → the fake's order by price); the sheet marks the current choice; `cart-summary` appears after a quick add with `1 товар` and `≈ 18 000 сум` and opens the cart; an empty recommended list shows its empty text; a failed page shows retry; both screens at 320×640, text ×2, `uz`/`ru`.
- [ ] **Step 2: Implement** per drawings 10в, 10г, 13, 14. Sheet: white, top radius 28, grab handle, title "Сортировка", rows 52 high separated by `line`, `check_circle` green when chosen. Bar: `primary`, radius 16, 64 high, 20 from the sides, above the bottom inset, shadow `0 6 18 rgba(90,194,104,.35)`, a white fade above it. ARB: `sortTitle` "Saralash"/"Сортировка"; `sortShop` "Do'kondagidek"/"Как в магазине"; `sortPriceAsc` "Avval arzonlari"/"Сначала дешевле"; `sortPriceDesc` "Avval qimmatlari"/"Сначала дороже"; `allProductsTitle` "Barcha mahsulotlar"/"Все товары"; `recommendedTitle` "Tavsiya etamiz"/"Рекомендуем"; `recommendedEmpty`; `cartSummaryCount` (plural) "{count} ta mahsulot" / "{count} товар|товара|товаров"; `cartSummaryOpen` "Savatga"/"В корзину".
- [ ] **Step 3: Run** — PASS; analyze, format.
- [ ] **Step 4: Docs.** `DL-80` item 3: "**The cart bar** appears on the product lists without the tab bar (a category, "Рекомендуем", every product) while the cart holds a line; the tab screens show the count on the cart button instead." Item 4: "**The sort** is remembered while the app runs and applies to every product and to the home's search results; it starts as the shop's order."
- [ ] **Step 5: Commit** — `feat(catalog): recommended, every product, the sort and the cart bar`.

---

### Task 4: Every category and a category with its rail

**Files:**
- Create: `frontend/lib/features/catalog/presentation/category_tile.dart`, `frontend/lib/features/catalog/presentation/all_categories_screen.dart`, `frontend/lib/features/catalog/presentation/category_screen.dart`
- Modify: `catalog_paths.dart` (`categories = '/customer/categories'`), `catalog_routes.dart` (`catalog-category` builds `CategoryScreen`), `frontend/lib/features/catalog/presentation/catalog_screens.dart` (remove `CategoryProductsScreen` and what only it used), ARB files
- Test: create `frontend/test/features/catalog/category_screens_test.dart`; rewrite the category cases of `frontend/test/features/catalog/catalog_screens_test.dart` to the new screen

**Interfaces:**
- Produces: `CategoryTile({required CatalogCategory category, double? size})` — the picture (`ProductImage`) on `KitColors.card`, or the first letter of the localized name in `primaryDark` on `primaryWash`; the name under it, two lines; key `category-<id>`. `AllCategoriesScreen()` — every category, four per row. `CategoryScreen({required String categoryId})` — title is the category's name; a 94-wide left rail of every category (selected: `primaryWash` well, bold name, a 3-wide `primary` line at its right edge, scrolled into view); the right side a `KitProductGrid(columns: 2, size: compact, imageHeight: 84)` on `KitColors.card`; choosing another rail item replaces the location (`context.replace(CatalogPaths.category(id))`) so back returns to where the Customer came from; `CartSummaryBar` at the bottom.

- [ ] **Step 1: Failing tests.** All categories shows every category of the fake; a category without `imageUrl` shows its letter; tapping a tile opens its category; the category screen shows the rail with the current one selected and its products; tapping another rail item shows that category's products and title, and back leaves the screen; an unknown category id (not in the list) shows the existing not-found text; a 40-character name wraps in two lines without overflow; both screens at 320×640, text ×2, `uz`/`ru`.
- [ ] **Step 2: Implement** per drawings 10б, 11, 12.
- [ ] **Step 3: Run** — PASS; analyze, format.
- [ ] **Step 4: Docs.** `DL-80` item 5: "**A category's screen** carries a rail of every category, as the kit's subcategory rail, because categories are flat (`docs/08` §6); switching replaces the location. A category without a picture shows its first letter."
- [ ] **Step 5: Commit** — `feat(catalog): every category and the category rail`.

---

### Task 5: The tab bar and favourites

**Files:**
- Create: `frontend/lib/core/widgets/customer_tab_bar.dart`, `frontend/lib/features/favorites/presentation/favorites_screen.dart`, `frontend/lib/features/favorites/presentation/favorites_routes.dart`
- Modify: `frontend/lib/core/routing/app_paths.dart` (`customerFavorites = '$customer/favorites'`), `frontend/lib/app/router.dart` (register the favourites fragment), `frontend/lib/features/orders/presentation/orders_screens.dart` (`OrdersScreen` gets the bar), `frontend/lib/features/profile/presentation/profile_screen.dart` (gets the bar), ARB files
- Test: create `frontend/test/core/widgets/customer_tab_bar_test.dart`, `frontend/test/features/favorites/favorites_screen_test.dart`; adjust `frontend/test/features/orders/…` and `frontend/test/features/profile/…` tests that pump these screens (they now show the bar)

**Interfaces:**
- Produces: `enum CustomerTab { home, favorites, orders, profile }`; `CustomerTabBar({required CustomerTab current})` — white, 99 high including the inset, shadow `0 -6 20 rgba(0,0,0,.05)`, icons `home`, `favorite`, `receipt_long`, `person` at 28, current filled in `primary` with the soft `primarySoft` glow above it; keys `open-home`, `open-favorites`, `open-orders`, `open-profile` (the last two keep the keys the home's tests use); each icon has a semantic label (`homeNavHome`, `favoritesTitle`, `homeNavOrders`, `profileTitle`). Navigation: the current tab does nothing; Home → `context.go(AppPaths.customer)`; another tab from the home → `context.push(path)`; another tab from a tab → `context.pushReplacement(path)`. So the system back from any tab returns to the home and never closes the app. `FavoritesScreen()` — title "Избранное" centred, a two-column `KitProductCard` grid of `favoritesListProvider` (`available: entry.isAvailable`), the empty state of 14б (`Icons.shopping_basket_outlined` 96 in `primary` on a `primaryWash` circle, no new asset), its button "За покупками" → home, and the tab bar with `favorites` current; un-hearting removes the card after the server confirms.

- [ ] **Step 1: Failing tests.** Tab bar: from the home tapping `open-favorites` opens favourites and the system back returns home; from favourites tapping `open-orders` replaces it and back returns home; `open-home` from orders goes home. Favourites: lists the fake's favourites with filled hearts; an unavailable one shows "Нет в продаже"; un-hearting removes it; the empty state and its button; a failed load shows retry; 320×640, text ×2, `uz`/`ru`. Orders and profile tests: the bar is present with the right tab current.
- [ ] **Step 2: Implement.** ARB: `favoritesTitle` "Sevimlilar"/"Избранное"; `favoritesEmptyTitle` "Hozircha bo'sh"/"Пока пусто"; `favoritesEmptyText` "Mahsulotdagi yurakchani bosing — u shu yerda paydo bo'ladi va uni qayta buyurtma qilish oson bo'ladi" / "Нажмите сердечко на товаре — он появится здесь, и его будет легко заказать снова"; `favoritesEmptyAction` "Xaridga"/"За покупками".
- [ ] **Step 3: Run** — PASS; analyze, format.
- [ ] **Step 4: Docs.** `DL-80` item 6: "**The tab bar** (`DL-78` item 6) is drawn by the home, favourites, orders and profile, which stay separate routes: a tab opened from the home is pushed over it and one opened from another tab replaces that tab, so the system back always returns to the home. Orders and profile keep their content until their stages." `docs/07` §29 (Navigation): `/customer/favorites`, `/customer/categories`, `/customer/recommended`, `/customer/products`. `docs/03` §5: favourites screen.
- [ ] **Step 5: Commit** — `feat(customer): the tab bar and favourites`.

---

### Task 6: The kit home

**Files:**
- Create: `frontend/lib/features/catalog/presentation/home_screen.dart` (`CatalogHomeScreen` moves here and is rebuilt)
- Modify: `frontend/lib/features/catalog/presentation/catalog_routes.dart`, `frontend/lib/features/catalog/presentation/catalog_screens.dart` (keeps only `ProductScreen` and what it uses), `frontend/lib/features/addresses/presentation/delivery_address_widgets.dart` (`DeliveryAddressLine` in the kit look: green `location_on` 26, the address label or street 15/500 with a chevron, the full line under it 11 `muted`; "Добавить адрес доставки" / "Куда привезти заказ" when none), `frontend/lib/features/cart/presentation/cart_widgets.dart` (`CartButton`: `shopping_bag` 26 in `ink`, a `primary` count badge with a white 2 border; drop `onBrand`), `frontend/lib/core/widgets/active_mode_bar.dart` (kit look: `primaryWash` rounded 12 strip, 16 from the sides, icon and label in `ink2`/`primaryDark`, the action as a `primaryDark` text button; it still moves the action to its own line when it does not fit), ARB files
- Delete: `frontend/lib/features/catalog/presentation/customer_home_header.dart`, `frontend/lib/features/catalog/presentation/customer_home_nav.dart`, `frontend/lib/core/theme/brand_colors.dart` (nothing uses it after this task — check with `grep -rn BrandColors lib test`)
- Test: rewrite `frontend/test/features/catalog/customer_home_test.dart` to the kit home; adjust `catalog_screens_test.dart`, `customer_account_screens_test.dart` and `cart_screens_test.dart` where they find the old header, nav or `onBrand`

**Interfaces:**
- Consumes: everything above; `DeliveryAddressLine`, `showDeliveryAddressSheet`, `ActiveModeBar(action:)` with the existing "back to staff" action.
- Produces: `CatalogHomeScreen()` top to bottom: `ActiveModeBar` (only with two sessions, `DL-75` item 5), the address line with `CartButton` at its right, the search field (`catalog-search`, `KitColors.field`, radius 14, 50 high) with the filter button (`open-sort`, `primary` 50×50 radius 14, `tune` icon) which opens `showSortSheet` and then `CatalogPaths.products`; then either — with an empty query — "Категории" + "Все" (`open-categories`) and the first eight `CategoryTile`s four in a row, then "Рекомендуем" + "Все" (`open-recommended`) and a horizontal row of up to ten featured `KitProductCard`s 150 wide (the section is absent when there is none or when it fails — a failed category list shows the existing retry), or — with a query — the search results as a `KitProductGrid` in the current sort; the `CustomerTabBar(current: home)` at the bottom; lists stop above the bar by its own height (`DL-75` item 6).

- [ ] **Step 1: Failing tests** (rewriting `customer_home_test.dart`): the order of sections; eight tiles of ten categories and `open-categories` opens all; `open-recommended`; no "Рекомендуем" when the fake has no featured product; a query shows results and `open-sort` → choose "Сначала дешевле" → every product in that order; the cart badge counts lines; with no address the line reads "Добавить адрес доставки" and opens the sheet; with two sessions the mode bar shows "Режим клиента" whole and its action at 320×640, text ×2, in `uz` and `ru` (closes the part-1 residual of `tasks/REDESIGN_CUSTOMER.md`); the debounce of the search is kept; the whole home at 320×640, text ×2, `uz`/`ru`.
- [ ] **Step 2: Implement** per drawings 10 and 10а. ARB: `homeCategories` "Kategoriyalar"/"Категории"; `homeSeeAll` "Barchasi"/"Все"; `homeRecommended` = `recommendedTitle`; `deliveryAddressEmptyHint` "Buyurtmani qayerga olib borish kerak"/"Куда привезти заказ". Remove ARB keys only the deleted widgets used (check each with `grep`).
- [ ] **Step 3: Run** the whole frontend suite through `test-runner`, `flutter analyze`, format — PASS.
- [ ] **Step 4: Docs.** `DL-80` item 7: "**The home's header** follows the kit: the address line on top with the cart at its right, then the search and the filter button. This moves the address above the search (supersedes the position in `DL-74` item 3; the behaviour of `DL-75` item 3 stands). The active-mode bar takes the kit's look everywhere it appears." Item 8: "**Brand values of design 4a** (`BrandColors`) are gone; `KitColors` is the one palette." `docs/03` §4 (line 31): "The Customer's home names the delivery address above its search". `tasks/REDESIGN_CUSTOMER.md`: stage 2 "Merged" is set by the merge, here "In Progress"; remove the risk about the part-1 header and the part-1 residual (now asserted); add any new risk.
- [ ] **Step 5: Commit** — `feat(catalog): the kit home`.

---

## After the tasks

Full frontend suite through `test-runner`; `git diff --check`; `branch-reviewer` with this plan, BASE (the `main` commit the branch starts from) and HEAD; one fix wave; PR; required checks green; merge. Then the real stack on port 8001 with the emulator `barakabozor` (`WalkthroughSeeder`, a few products marked "Рекомендуем", one category picture uploaded in the panel) and 4–5 screenshots for the Owner: home, a category, "Рекомендуем" with the cart bar, favourites, the panel's product form.
