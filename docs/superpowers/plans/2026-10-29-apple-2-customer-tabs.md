# Apple Stage 2 — Customer Tabs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Customer's four tabs keep their place (a switch is instant, with the same scroll and the data already shown), the bar shows labels and a tap on the current tab scrolls its list to the top, and favourites, orders and profile get the header cart button with its count, which bumps when the cart grows.

**Architecture:** The four tab routes move into one `StatefulShellRoute.indexedStack` (go_router's own, no new router), declared by `features/shells` from the tab routes the four features export. Each tab is a branch: its screen stays built while another is shown, so scroll, segment and loaded data stay. Everything opened from a tab (product, cart, order, editor) stays a top-level route on the root navigator, over the tabs and without the bar, as today. Each tab screen keeps drawing its own `CustomerTabBar`, so sheets opened in a tab still cover the bar. A kept tab must not keep working while it is hidden, so `PeriodicRefresh` also waits while its tickers are off. `CartButton` gains a variant for the green header and a bump.

**Tech Stack:** Flutter 3.47.5, go_router 18.0.1 (`StatefulShellRoute`, `StatefulNavigationShell.maybeOf`), flutter_riverpod 3.4.3 (pauses providers under a disabled `TickerMode`), flutter_test (`meetsGuideline(iOSTapTargetGuideline)`).

**Spec:** `tasks/APPLE_BATCH.md` stage 2 (items `home-1`, `fav-2`, `fav-3` tab part, `orders-10`, `profile-8`); the live tests «Тест главной - Apple» (tab bar, item 1), «Тест избранного - Apple» (items 2, 3), «Тест списка заказов - Apple» (item 10), «Тест профиля - Apple» (item 8) in the Claude Design project "BarakaBozor — стиль покупателя" (local copies `G:\tools\tmp\w-home|w-fav|w-ord|w-prof\site`); `DL-80` items 3, 6 and 12; `docs/07-architecture.md` section 29.

## Global Constraints

- Only `frontend/`, `docs/` and `tasks/` change. No package and no `pubspec.lock` change; no `.arb` change: the labels reuse `homeNavHome`, `favoritesTitle`, `homeNavOrders` («Заказы» / «Buyurtmalar»), `profileTitle`, and the cart's label is `cartBadge`.
- Tab bar, exactly: bar 99 high with 65 of content (unchanged); icons 26, the current one `KitColors.primary`, the others `KitColors.muted`; 2 between icon and label; label 11 px, line height 1.2, the device's text scale capped at 15 px (`clamp(maxScaleFactor: 15 / 11)`), one line, `FontWeight.w500` `KitColors.muted`, the current one `FontWeight.w700` `KitColors.primaryDark`. The glow above the current icon stays.
- A tap on the current tab scrolls its main list to the top in 300 ms with `Curves.easeOutCubic`, and jumps there with reduced motion (`MediaQuery.disableAnimationsOf`). At the top it does nothing.
- The cart badge bumps to scale 1.3 at 40 % of 300 ms and back, ease-out, when the cart grows: a product it did not hold, or more of one, in the same cart. Not on the first load, a removal, a smaller quantity or another cart; never with reduced motion.
- The profile header keeps `KitColors.primary` (its `#2D7D38` is stage 16, `profile-4`).
- A tab's path (`AppPaths.customer`, `customerFavorites`, `customerOrders`, `customerProfile`) is reached by the bar or `go`, never pushed: a push from a screen over the tabs would build a second shell.
- Not in this stage: the question badge on «Заказы» (`home-7`, stage 6), the home's one scroll (`home-2`), the heart's tab bump (`fav-7`) and hearts fading in (`fav-3` list part, stage 10), the orders segment's slide (`orders-2`, stage 12), skeletons and stale lines.
- Flutter runs from PowerShell with `$env:TEMP='G:\tools\tmp'; $env:TMP='G:\tools\tmp'` and `G:\tools\flutter\bin\flutter.bat`; a full suite run uses `--concurrency=2`.
- Tests that pin `DL-80` (6) and (12)'s push and replace rule are rewritten to the new rule; no other test is deleted or weakened.
- Comments read like the surrounding code: short `///` docs in plain English that name `DL-118`.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- No `/security-review`: no backend, no access rule. The one data risk, a kept tab outliving its account, has its own test (Review Focus 3).

## Review Focus

1. A tab's path pushed from a screen over the tabs (checkout's «Указать имя», a push notification's open, a future button) builds a second shell with the same keys and crashes. Task 2: checkout opens the name editor instead; the push opener's `go(list)` + `push(order)` is tested from a screen over another tab; a source scan refuses `push(AppPaths.<tab>)`.
2. A hidden tab that keeps polling: the orders list's 30 s refresh and the home's question banner on a tab not shown, or under an order opened over the tabs. Task 1 test (`TickerMode` off) and Task 2 test (the orders tab hidden for 31 s loads nothing).
3. A kept tab outliving its account: a sign-out on the profile tab and a new sign-in must start at the home with fresh tabs, never the old account's favourites, orders or scroll (Task 2 test).
4. The system back: on a tab other than the home it goes home, on the home it leaves the app, and with a sheet open on a tab it closes the sheet first (Task 2 tests).
5. Labels on a 320 px phone in Uzbek with text × 2 (`Buyurtmalar` in bold): no overflow, the label shrinks to fit, never above 15 px (Task 3 test).

---

### Task 1: Refreshing waits while hidden

**Files:**
- Modify: `frontend/lib/core/widgets/periodic_refresh.dart:68`
- Test: `frontend/test/core/widgets/periodic_refresh_test.dart`

**Interfaces:**
- Produces: `PeriodicRefresh` refreshes only while its route is current **and** `TickerMode.valuesOf(context).enabled`. Its class doc says why: a tab kept by the tabs shell and a route covered by another have their tickers off (`DL-118` (6)).

- [ ] **Step 1: Write the failing test** `'waits while its tickers are off'`: a `PeriodicRefresh(interval: 10 s, active: true)` under `TickerMode(enabled: false)`; `pump(11 s)` → `onRefresh` called 0 times; rebuild with `enabled: true`, `pump(11 s)` → called once.
- [ ] **Step 2: Run it and see it fail.** Run: `flutter.bat test test/core/widgets/periodic_refresh_test.dart` — Expected: FAIL (called once while off).
- [ ] **Step 3: Implement** the extra condition in `_tick`'s `shown`.
- [ ] **Step 4: Run the file and the orders, shopper and courier tests** (`flutter.bat test test/core/widgets/periodic_refresh_test.dart test/features/orders test/features/shopper test/features/courier`). Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(core): periodic refresh waits while its tickers are off (DL-118)"`

### Task 2: The tabs shell

**Files:**
- Modify: `frontend/lib/features/shells/presentation/shells_routes.dart` (add the shell)
- Modify: `frontend/lib/features/catalog/presentation/catalog_routes.dart`, `favorites/presentation/favorites_routes.dart`, `orders/presentation/orders_routes.dart`, `profile/presentation/profile_routes.dart`
- Modify: `frontend/lib/core/widgets/customer_tab_bar.dart` (`_open`, docs of `CustomerTab`, `CustomerTabScope`, `CustomerTabBar`)
- Modify: `frontend/lib/features/checkout/presentation/checkout_screen.dart:698`
- Create: `frontend/test/features/shells/presentation/customer_tabs_test.dart`, `frontend/test/core/routing/customer_tab_paths_test.dart`
- Modify: `frontend/test/core/widgets/customer_tab_bar_test.dart` (its navigation cases move to `customer_tabs_test.dart`; Task 3 keeps the rest), `frontend/test/features/checkout/presentation/checkout_screen_test.dart:721-727`, and any test that pinned the push and replace rule (`customer_home_test.dart:101-145`, `orders_screens_test.dart`, `customer_account_screens_test.dart`, `profile_screen_test.dart`, `edit_profile_screen_test.dart`, `role_shell_test.dart`, `favorites_screen_test.dart`)

**Interfaces:**
- Produces: `final GoRoute catalogHomeRoute` (path `AppPaths.customer`, name `catalog-home`), `favoritesTabRoute` (`customer-favorites`), `ordersTabRoute` (`customer-orders`), `profileTabRoute` (`customer-profile`, no child routes), each exported from its feature's `*_routes.dart` and no longer in its fragment. `favoritesRoutes` stays registered with no routes; its doc says its screen is a tab.
- Produces: `profileRoutes` declares `customer-edit-profile` and `customer-delete-account` as top-level routes on `AppPaths.customerEditProfile` and `AppPaths.customerDeleteAccount` (addresses unchanged).
- Produces: in `shellsRoutes`, `StatefulShellRoute.indexedStack(builder: (BuildContext context, GoRouterState state, StatefulNavigationShell shell) => shell, branches: <StatefulShellBranch>[home, favourites, orders, profile])`, no preloading. Branch `i` is `CustomerTab.values[i]`; the enum's doc says so.
- Produces: `CustomerTabBar._open(tab)`: the current tab is left to Task 3; another tab is `StatefulNavigationShell.maybeOf(context)?.goBranch(tab.index)`, or `context.go(<tab path>)` where no shell is above (a screen tested alone). `CustomerTabScope` keeps its rule; on a branch `context.canPop()` is false, so back goes home.

- [ ] **Step 1: Write the failing tests.**
  - `customer_tabs_test.dart`, on `appUnderTest` with a signed-in Customer (pattern: `customer_home_test.dart`'s `open`):
    - `'a tab keeps its place: the same scroll and no new load'`: 30 favourites, open favourites, drag `favorites-grid` up 400, open the home, open favourites again: the grid's `ScrollableState.position.pixels` is still 400, `FakeFavoritesRepository.listLoads` is 1, no `CircularProgressIndicator`.
    - `'a switch is instant'`: tap `open-orders`, one `tester.pump()`: `OrdersScreen` is on stage and `CatalogHomeScreen` is not (a page transition would keep both on stage for its frames).
    - `'a tab keeps its data after a heart elsewhere'`: favourites visited once, back to the home, heart a home card, open favourites: the kept cards show at once (no `CircularProgressIndicator` after one pump).
    - `'the system back on a tab goes home; on the home nothing is left to pop'`: from profile `handlePopRoute` → `CatalogHomeScreen` on stage; then `router.canPop()` is false.
    - `'a sheet open on a tab closes before the tab'`: the profile's language sheet open, `handlePopRoute` → sheet gone, `ProfileScreen` still on stage.
    - `'a screen opened from a tab covers the bar and back returns to the tab'`: profile → name row → `EditProfileScreen`, `find.byType(CustomerTabBar)` finds nothing; back → `ProfileScreen`.
    - `'a push opens the orders tab with the order over it'`: from favourites, `router.go(AppPaths.customerOrders)` then `router.push(AppPaths.customerOrder(id))` (the push opener's two calls) → the order screen; back → `OrdersScreen` with the bar; `open-favorites` → favourites with its kept scroll.
    - `'a hidden orders tab loads nothing'`: orders visited (current orders, so its 30 s refresh is on), open the home, `pump(31 s)`: `FakeCustomerOrdersRepository.loads` unchanged. Same with an order opened over the orders tab.
    - `'another Customer after a sign-out starts at the home with fresh tabs'`: favourites visited and scrolled, profile → sign out → sign in again: `CatalogHomeScreen` on stage; open favourites → `listLoads` is 2 and the grid is at 0.
  - `customer_tab_paths_test.dart` `'no code pushes a tab's path'`: every `*.dart` under `lib/` (generated localization excluded) matched against `\.(push|pushReplacement)(<[^>]*>)?\(\s*AppPaths\.(customer|customerFavorites|customerOrders|customerProfile)\s*[,)]` → no hits.
  - `checkout_screen_test.dart` `'a profile without a name, with the way to the name editor'`: tap `checkout-open-profile` → top is `AppPaths.customerEditProfile`; back → the checkout.
- [ ] **Step 2: Run them and see them fail.** Run: `flutter.bat test test/features/shells test/core/routing test/features/checkout` — Expected: FAIL (scroll lost, two loads, profile pushed).
- [ ] **Step 3: Implement** the exported routes, the shell, the bar's `_open`, the two top-level profile routes and checkout's push of `AppPaths.customerEditProfile`.
- [ ] **Step 4: Run every Customer test** (`flutter.bat test test/features/catalog test/features/favorites test/features/orders test/features/profile test/features/addresses test/features/checkout test/features/cart test/features/shells test/features/notifications test/core test/app`). Expected: PASS; tests of the old push and replace rule rewritten to "back goes home" and "the tab is kept"; report each rewritten test by name.
- [ ] **Step 5: Commit** — `git commit -m "feat(customer): tabs keep their place in one shell (DL-118)"`

### Task 3: Labels and the tap on the current tab

**Files:**
- Modify: `frontend/lib/core/widgets/customer_tab_bar.dart` (`_TabButton`, `_open`)
- Modify: the main lists, which set `primary: true`: `catalog/presentation/home_screen.dart` (`home-body`), `favorites/presentation/favorites_screen.dart` (`favorites-grid`), `orders/presentation/orders_screens.dart` (`orders-list`), `profile/presentation/profile_screen.dart` (`profile-list`)
- Test: `frontend/test/core/widgets/customer_tab_bar_test.dart`, `frontend/test/features/shells/presentation/customer_tabs_test.dart`

**Interfaces:**
- Consumes: Task 2's shell.
- Produces: a tap on the current tab moves `PrimaryScrollController.maybeOf(context)` (the route's, which the main list uses) to 0 when it has clients; nothing otherwise.

- [ ] **Step 1: Write the failing tests.**
  - `customer_tab_bar_test.dart` (the bar alone in a `Scaffold`):
    - `'labels under the icons, the current one bold in the text green'`: four `Text`s with the four labels inside the bar; the current one `FontWeight.w700` and `KitColors.primaryDark`, the others `w500` and `KitColors.muted`; icons size 26, the current one `KitColors.primary`.
    - `'labels stop growing at 15 px'`: text × 2, the label's `RenderParagraph.textScaler.scale(11)` is 15.
    - `'labels fit a 320 px phone in Uzbek with text × 2'`: no exception.
    - Update `'the bar is 99 high, white, with the icons at 28 and labels'` to icons 26.
    - `'every target meets iOSTapTargetGuideline'`.
    - `'with reduced motion the current tab jumps its list to the top'`: a `ListView` scrolled 300 in the same `Scaffold`, `disableAnimations` on, tap the current tab, one pump → 0.
  - `customer_tabs_test.dart` `'a tap on the current tab scrolls its list to the top'`, for each of the four tabs (home `home-body`, favourites, orders with past orders, profile): drag up 300, tap the current tab, `pumpAndSettle` → 0; and at the top a tap changes nothing.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement** the label column and the scroll to the top with the Global Constraints' values; the label scales down to fit the tab's width (`FittedBox(fit: BoxFit.scaleDown)`); the tab keeps its one `Semantics` button with the label.
- [ ] **Step 4: Run `test/core/widgets` and `test/features/shells`, then the four tab features' tests.** Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(customer): tab labels and a tap on the current tab goes to the top (DL-118)"`

### Task 4: The cart button on every tab

**Files:**
- Modify: `frontend/lib/features/cart/domain/cart.dart` (add `grewFrom`)
- Modify: `frontend/lib/features/cart/presentation/cart_widgets.dart` (`CartButton`)
- Modify: `frontend/lib/core/widgets/kit_app_bar.dart:28` (search and actions together)
- Modify: `frontend/lib/features/favorites/presentation/favorites_screen.dart`, `orders/presentation/orders_screens.dart:59-62`, `profile/presentation/profile_header.dart`
- Test: `frontend/test/features/cart/domain/cart_test.dart` (new), `frontend/test/features/cart/presentation/cart_button_test.dart` (new), `favorites_screen_test.dart`, `orders_screens_test.dart`, `profile_screen_test.dart`, `customer_home_test.dart`

**Interfaces:**
- Produces: `bool Cart.grewFrom(Cart before)`: false when `before.id != id`; true when a line's `productId` is not in `before`, or its `QuantityRules.thousandths(quantity)` is larger than the same product's in `before`.
- Produces: `const CartButton({bool onBrand = false, super.key})`, a `ConsumerStatefulWidget`. `ref.listen` on `currentCartProvider` bumps the badge when both values exist and `next.grewFrom(previous)`. `onBrand`: a white bag, a white badge with the count in `KitColors.primaryDark`, no white ring, a 44 × 44 button; otherwise the drawing of today. The bump is a `ScaleTransition` keyed `cart-badge-bump`.
- Produces: `kitAppBar(search: true, actions: [...])` shows the search, then the actions.

- [ ] **Step 1: Write the failing tests.**
  - `cart_test.dart` `'grows with a new product or more of one'` (true), `'does not grow with less, a removal or another cart'` (false), quantities `'1.5'` → `'2'` and `'2'` → `'1.5'`.
  - `cart_button_test.dart`: `'bumps when a product is added'` (the `cart-badge-bump` scale is about 1.3 at 120 ms and 1 after 300 ms); `'bumps when a quantity grows'`; `'does not bump on the first load, a removal or a smaller quantity'`; `'does not bump with reduced motion'`; `'on the brand green: white bag, white badge, green count'`.
  - `favorites_screen_test.dart` `'the header has the search and the cart with its count'`; `orders_screens_test.dart` `'the header says «Заказы» with the cart and its count'` (ru) and `'the cart bumps after «Повторить»'`; `profile_screen_test.dart` `'the header has a white cart button with its count, which opens the cart'` and `'the header keeps its height'` (the header's height equals today's).
  - In each of the four tab screens' tests, `'every target meets iOSTapTargetGuideline'` in the data state.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.** Orders' title is `l10n.homeNavOrders` (`myOrders` stays for the Shopper). The profile's title row is 44 high with the cart at its right, 10 px from the edge as drawn (`right: -10` inside the 20 px padding), the title padded 48 on both sides; the paddings around the row shrink so the header's height does not change. A guideline failure outside this stage's pieces is fixed by growing its hit area to 44 (stage 1's way) when it is small; anything larger goes in the report.
- [ ] **Step 4: Run the cart, catalog, favourites, orders and profile tests.** Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(customer): the cart button on every tab, with a bump (DL-118)"`

### Task 5: Decisions and documents

**Files:**
- Modify: `docs/DECISIONS.md` (append `DL-118`), `docs/07-architecture.md` (section 29's tab bar sentence), `tasks/APPLE_BATCH.md` (stage 1 «Merged (PR #121)», stage 2 «In review», risks from the reports)

- [ ] **Step 1: Append `DL-118 — The Apple batch, stage 2: the Customer's tabs (2026-10-29, agent)`**, numbered:
  1. The four tabs are branches of one `StatefulShellRoute.indexedStack`, declared by `features/shells` from the tab routes the features export (`D-8` holds: each feature still declares its screen's route; the shell only composes). A tab keeps its screen, scroll and data while another is shown, and a switch is instant (`fav-3`). A branch is built on its first visit; tabs never opened ask nothing. Supersedes `DL-80` (6) and (12).
  2. What a tab opens (product, cart, order, search, categories, the name editor, deletion) stays a top-level route over the tabs, without the bar. A tab's path is reached by the bar or `go`, never pushed (a push would build a second shell); a source scan refuses it. The profile's editor and deletion become top-level routes at the same addresses; checkout's «Указать имя» opens the name editor instead of the profile tab.
  3. The system back on a tab other than the home goes to the home; on the home it leaves the app; a sheet open on a tab closes first. Each tab screen keeps drawing the bar, so its sheets cover it.
  4. The bar shows labels under the icons (11 px, at most 15 px with large text, the current one bold in `primaryDark`); a tap on the current tab scrolls its main list to the top in 0.3 s, at once with reduced motion (`home-1`).
  5. The cart button with its count is on all four tabs (`fav-2`, `orders-10`, `profile-8`; restores `DL-80` (3) on favourites, orders and profile); the orders tab is titled «Заказы»; the profile's green header has a white one. The badge bumps when the cart grows: a new product or more of one in the same cart; not on the first load, a removal or another account's cart; never with reduced motion.
  6. `PeriodicRefresh` also waits while its tickers are off, which is a tab not shown and a screen under another; Riverpod pauses those screens' providers the same way.
  7. The four tab screens meet `iOSTapTargetGuideline`.
- [ ] **Step 2: Rewrite section 29's sentence:** "The Customer's bottom bar (home, favourites, orders, profile) switches between four kept tabs; what a tab opens covers the tabs, and the system back from a tab goes to the home (`DL-118`)."
- [ ] **Step 3: Update `tasks/APPLE_BATCH.md`** and run `git diff --check`.
- [ ] **Step 4: Commit** — `git commit -m "docs: DL-118, the Customer's tabs"`

### Task 6 (lead): Suite, review and walk

- [ ] **Step 1:** Full frontend suite through `test-runner` (`flutter.bat test --concurrency=2`), `flutter.bat analyze`, `dart format --set-exit-if-changed lib test`.
- [ ] **Step 2:** `branch-reviewer` on the whole branch, one fix dispatch, scoped re-review; findings not acted on go to `tasks/APPLE_BATCH.md`.
- [ ] **Step 3:** Walk on the `barakabozor` emulator: scroll favourites, go home and back (same place, no spinner); a tap on the current tab; the labels; add from the home and see the badge bump on favourites; «Повторить» on orders; the profile's white cart; back from each tab. Four or five screenshots for the Owner.
