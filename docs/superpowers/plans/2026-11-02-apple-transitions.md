# Page Transitions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every route builds its page through one shared builder, so a page the person opens over another comes in by the platform's own transition — with the edge back-swipe on iOS — while the flat pages (sign-in, an area's home, the tabs, the web panel) still replace what was shown in place.

**Architecture:** One function, `appPage(state, child, {entry})` in `lib/core/routing/app_page.dart`, returns a `MaterialPage` (the theme's per-platform transition) or, for an entry page, go_router's `NoTransitionPage`. Every `GoRoute`, `ShellRoute` and the `StatefulShellRoute` in `lib/` uses `pageBuilder:` with it; no route keeps a `builder:`, so go_router's own default page — which is the transition-less one in this app — is never used. A route-table test pins which routes are entry pages.

**Tech Stack:** Flutter 3.47.5 (`MaterialPage`, `PageTransitionsTheme` defaults, `TargetPlatformVariant`), go_router 18.0.1 (`pageBuilder`, `NoTransitionPage`, `GoRouterState`), flutter_test.

**Spec:** `tasks/APPLE_BATCH.md` → Risks, second item; `DL-122` (1) (the product's own page); `DL-118` (the tabs switch in place); `docs/07-architecture.md` §29 (the login screens are flat routes); the Owner's ruling of 2026-11-02, option «1»: this task as a session of its own, before stage 6.

**Why go_router itself cannot fix it (checked 2026-11-02):** go_router picks its default page by looking for `package:material_ui`'s `MaterialApp` above the router (`lib/src/pages/material.dart`, since 18.0.0 "Migrates to material_ui and cupertino_ui"). The app is built on Flutter's own `MaterialApp` from `package:flutter/material.dart`, a different class in Flutter 3.47.5, so go_router falls back to "WidgetsApp configuration" — `NoTransitionPage` for every route. The newest release, 18.1.2, still looks for the `material_ui` class, so a version bump does not help; moving the app to `material_ui` would change every import and the theme classes. Our own page builder is the fix.

## Global Constraints

- Only `frontend/lib`, `frontend/test`, `docs/` and `tasks/` change. go_router stays at 18.0.1: no `pubspec.yaml` or `pubspec.lock` change.
- Every `GoRoute` that shows a screen, both `ShellRoute`s (admin, operations) and the Customer's `StatefulShellRoute` build their page with `pageBuilder:` calling `appPage`. No route class in `lib/` has a `builder:` argument (`navigatorContainerBuilder` stays). The redirect-only `GoRoute(path: AppPaths.admin, redirect: …)` stays as it is.
- The theme gets no `pageTransitionsTheme`: Flutter 3.47.5's defaults stand — Android `PredictiveBackPageTransitionsBuilder` (the predictive-back gesture, and `FadeForwardsPageTransitionsBuilder`, 450 ms, for a push), iOS and macOS `CupertinoPageTransitionsBuilder` (500 ms, the edge back-swipe), Windows and Linux `ZoomPageTransitionsBuilder`.
- Entry pages (`entry: true`), by route name, exactly these 27: `bootstrap`; the sign-in screens `customer-phone`, `customer-code`, `staff-login`, `change-password`, `staff-password`, `customer-name`, `session-unreachable`, `wrong-surface`; `account-deleted`; the tabs `catalog-home`, `customer-favorites`, `customer-orders`, `customer-profile`; the staff homes `shopper-orders`, `courier-orders`, `shell-manager`; the whole web panel `admin-categories`, `admin-products`, `admin-product-new`, `admin-product`, `admin-staff`, `admin-customers`, `admin-legal-documents`, `admin-settings`, `operations-board`, `operations-order`. The three shell routes are entry pages too. Every other route — 23 of them — is a platform page.
- Why those: a flat route reached by `go` replaces the whole screen and has no page beneath to slide over or swipe back to. The sign-in screens are flat by design (`docs/07` §29), and their own motion is later stages' (`vhod-5` stage 20, `sys-2` stage 22, `profile-1` stage 16); `account-deleted` is stage 21's (`del-10`); the tabs switch in place (`DL-118`, `fav-3`); the web panel's pages are a website's, with the browser's own back and forward.
- The tab switch stays instant: `_tabsContainer` in `shells_routes.dart` does not change.
- No screen, string, navigation call (`push` / `go`) or widget changes; only the route files, `app/router.dart` and the new `core/routing/app_page.dart`.
- Tests are never deleted, skipped or weakened. A test that relied on a page appearing in one frame (the spike found none) would let the transition run — `await tester.pumpAndSettle()`, or a `pump` of 500 ms where a repeating animation keeps the screen from settling — and keep every assertion it had.
- Flutter runs from PowerShell with `$env:TEMP='G:\tools\tmp'; $env:TMP='G:\tools\tmp'` and `G:\tools\flutter\bin\flutter.bat`; a full suite run uses `--concurrency=2`.
- Comments read like the surrounding code: short `///` docs in plain English that name `DL-124`.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. An iOS back-swipe on a page that holds its back (`PopScope(canPop: false)`: the new address's second step, «Заказ оформлен», the order editor while it saves) must leave the page where it is — Flutter turns the swipe off for such a route. Task 1 test `'on iOS a page that holds its back stays under a swipe'`.
2. A page pushed over the tabs and swiped back must return to the same tab with its place kept, not to a rebuilt shell. Task 3 test `'a swipe back from a page over the favourites tab returns to it, scroll kept'`.
3. A second tap on a card while its page slides in must open one page, not two (the incoming route's modal barrier takes it). Task 3 test `'a second tap while the product comes in opens one page'`.
4. The tab switch must stay instant after the change. Task 3 test `'a tab switch is still instant'`.
5. A screen reached by `go` that is a platform page (checkout → the order, the editor → the order, the Shopper's done screen) comes in with the transition and has no page beneath; its own back still works. No new test: the existing checkout, order-editor and Shopper tests walk those paths and must pass after Task 2.

---

### Task 1: The shared page builder

**Files:**
- Create: `frontend/lib/core/routing/app_page.dart`
- Test: `frontend/test/core/routing/app_page_test.dart`

**Interfaces:**
- Produces: `Page<void> appPage(GoRouterState state, Widget child, {bool entry = false})`. Without `entry` it returns `MaterialPage<void>`; with `entry: true` it returns go_router's `NoTransitionPage<void>`. Both carry `key: state.pageKey`, `name: state.name ?? state.path`, `arguments: <String, String>{...state.pathParameters, ...state.uri.queryParameters}`, `restorationId: state.pageKey.value` — the values go_router's own default page carries.

- [ ] **Step 1: Write the failing tests**

A state for the unit tests comes from a throwaway router's configuration:

```dart
GoRouterState stateFor({String? name = 'p'}) {
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(path: '/p/:id', builder: (_, _) => const SizedBox()),
    ],
  );
  addTearDown(router.dispose);
  return GoRouterState(
    router.configuration,
    uri: Uri.parse('/p/7?tab=a'),
    matchedLocation: '/p/7',
    name: name,
    path: '/p/:id',
    fullPath: '/p/:id',
    pathParameters: const <String, String>{'id': '7'},
    pageKey: const ValueKey<String>('/p/7'),
  );
}
```

Tests:
- `'a page the person opens is a MaterialPage with the route\'s key, name and arguments'`: `appPage(stateFor(), child)` is `MaterialPage<void>`; `key == const ValueKey<String>('/p/7')`, `name == 'p'`, `arguments == <String, String>{'id': '7', 'tab': 'a'}`, `restorationId == '/p/7'`, `(page as MaterialPage<void>).child` is identical to `child`.
- `'an entry page has no transition'`: `appPage(stateFor(), child, entry: true)` is `NoTransitionPage<void>` with the same key, name, arguments and child, and `transitionDuration == Duration.zero`.
- `'a route without a name is named by its path'`: `appPage(stateFor(name: null), child).name == '/p/:id'`.

The three behaviour tests pump `MaterialApp.router(routerConfig: router)` with a two-route router built on `appPage` — `/` shows `Text('first')` (entry), `/second` shows `Text('second')` (platform page), `/held` shows `PopScope(canPop: false, child: Text('held'))` (platform page) — each page's child wrapped in a full-size `Scaffold`, and open the second page with `router.push(...)`:
- `'a pushed page slides over the one beneath'` (default platform, Android): after `push('/second')`, `pump()` and `pump(const Duration(milliseconds: 100))`, both `find.text('first')` and `find.text('second')` find one widget; after `pumpAndSettle()`, `find.text('first')` finds nothing.
- `'on iOS an edge swipe takes the page back'` (`variant: TargetPlatformVariant.only(TargetPlatform.iOS)`): after `push('/second')` and `pumpAndSettle()`, `tester.dragFrom(const Offset(5, 300), const Offset(600, 0))` then `pumpAndSettle()` → `find.text('first')` finds one widget and `find.text('second')` finds nothing.
- `'on iOS a page that holds its back stays under a swipe'` (iOS variant): the same with `push('/held')` → after the drag and `pumpAndSettle()`, `find.text('held')` still finds one widget.

The view is 800 × 600 at pixel ratio 1 (`tester.view.physicalSize`, `addTearDown(tester.view.reset)`).

- [ ] **Step 2: Run them to see them fail**

Run: `G:\tools\flutter\bin\flutter.bat test test/core/routing/app_page_test.dart`
Expected: FAIL — `app_page.dart` does not exist.

- [ ] **Step 3: Write `appPage` in `frontend/lib/core/routing/app_page.dart`**

The signature and values from the Interfaces block. Its `///` doc says: the page every route of the app is built on (`DL-124`); a page the person opens comes in by the platform's transition from the theme — Cupertino's slide with the back-swipe on iOS, the predictive-back transition on Android; an `entry` page — the bootstrap, a sign-in screen, an area's home, a tab, a page of the web panel — replaces what was shown in place, as a tab switch does (`DL-118`).

- [ ] **Step 4: Run them to see them pass**

Run: `G:\tools\flutter\bin\flutter.bat test test/core/routing/app_page_test.dart`
Expected: all 6 pass.

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/core/routing/app_page.dart frontend/test/core/routing/app_page_test.dart
git commit -m "feat(routing): one page builder with the platform's transition (DL-124)"
```

### Task 2: Every route on the shared builder

**Files:**
- Modify: `frontend/lib/app/router.dart` (the bootstrap route)
- Modify: every `frontend/lib/features/*/presentation/*_routes.dart` that declares a route: `addresses`, `admin`, `auth`, `cart`, `catalog`, `checkout`, `courier`, `favorites`, `legal`, `operations`, `orders`, `profile`, `shells`, `shopper`
- Test: `frontend/test/app/route_pages_test.dart` (new)
- Modify: the existing tests listed in Step 5

**Interfaces:**
- Consumes: `appPage` from Task 1.
- Produces: the converted route table; nothing new for later tasks.

- [ ] **Step 1: Write the failing route-table test**

`frontend/test/app/route_pages_test.dart` walks `buildRouter().configuration.routes` depth-first through `GoRoute.routes`, `ShellRoute.routes` and `StatefulShellRoute.branches[*].routes`:

- `'no route keeps a builder'`: every `GoRoute`, `ShellRoute` and `StatefulShellRoute` has `builder == null`; every `GoRoute` has `pageBuilder != null` unless it has a `redirect` (the admin entry); both `ShellRoute`s and the `StatefulShellRoute` have `pageBuilder != null`.
- `'the flat routes stand in place and the rest slide in'` (a `testWidgets`, for a `BuildContext` from a pumped `SizedBox`): for every `GoRoute` with a `pageBuilder`, build a `GoRouterState(router.configuration, …)` whose `uri`, `matchedLocation`, `path` and `fullPath` are the route's path with every `:param` replaced by `1`, `pathParameters` maps each `param` to `'1'`, `name` is the route's name and `pageKey` is `ValueKey<String>(<that location>)`; call `route.pageBuilder!(context, state)`. Collect the names whose page is a `NoTransitionPage`: they equal exactly the 27 entry names of Global Constraints (as a `Set`), and every other page is a `MaterialPage` — 23 names: `catalog-categories`, `catalog-category`, `catalog-recommended`, `catalog-search`, `catalog-all-products`, `catalog-product`, `cart`, `checkout`, `customer-order`, `customer-order-edit`, `customer-order-add`, `customer-order-rate`, `customer-edit-profile`, `customer-delete-account`, `customer-addresses`, `customer-address-new`, `customer-address`, `legal-terms`, `legal-privacy`, `shopper-order`, `shopper-replace`, `shopper-done`, `courier-order`.
- `'the panel shells stand in place'`: each `ShellRoute`'s `pageBuilder!(context, state, const SizedBox())` is a `NoTransitionPage` (state as above for the shell's first child route).

- [ ] **Step 2: Run it to see it fail**

Run: `G:\tools\flutter\bin\flutter.bat test test/app/route_pages_test.dart`
Expected: FAIL — routes still have `builder`.

- [ ] **Step 3: Move every route onto `appPage`**

Each `builder: (BuildContext context, GoRouterState state) => <screen>,` becomes `pageBuilder: (BuildContext context, GoRouterState state) => appPage(state, <screen>)`, with `entry: true` for the 27 entry names. The two `ShellRoute`s' `builder: (BuildContext context, GoRouterState state, Widget child) => PanelShell(…)` become `pageBuilder: (…) => appPage(state, PanelShell(…), entry: true)`; the `StatefulShellRoute`'s becomes `pageBuilder: (BuildContext context, GoRouterState state, StatefulNavigationShell shell) => appPage(state, shell, entry: true)`. The product route's own `MaterialPage` (`DL-122` (1)) becomes `appPage(state, ProductScreen(…))` and its comment says the photo flies by the shared page's transition. Comments inside a builder (the operations order's lower-case note) move with the screen expression. Each file imports `core/routing/app_page.dart`. Then `dart format lib` and `flutter analyze` (no issues).

An aid outside the repo, from the spike: `python G:/tools/tmp/transitions/convert.py frontend/lib` does the mechanical part with the entry list above. By hand afterwards: the product route (its `MaterialPage`) and the operations order (the comment ahead of the screen breaks the script's output). The route-table test is the check, not the script.

- [ ] **Step 4: Run the route-table test to see it pass**

Run: `G:\tools\flutter\bin\flutter.bat test test/app/route_pages_test.dart`
Expected: 3 pass.

- [ ] **Step 5: Fix the one helper the page's own fade confuses**

A spike on 2026-11-02 (every route on `appPage`, the full suite: 2294 passed, 2 failed) found no test that waited for an instant page — every navigation in the suite already settles. The 2 failures are `'the placed card rises from below with a light haptic'` and `'with reduced motion the placed card stands at once, and still buzzes'` in `frontend/test/features/checkout/presentation/checkout_screen_test.dart`: its helper `cardOpacity` reads the single `FadeTransition` above `checkout-placed-card`, and the checkout page's own transition (Android's fade) now adds a second one higher up — `Bad state: Too many elements`. Fix: `cardOpacity` takes `.first` of `find.ancestor(…)` — the nearest, the card's own fade — as `circleScale` beside it already does. Both tests keep every assertion.

- [ ] **Step 6: Run the full suite**

Run: `G:\tools\flutter\bin\flutter.bat test --concurrency=2`
Expected: all pass. A failure not listed in Step 5 is fixed by the same rule only when its cause is a page still coming in; anything else is reported, not worked around.

- [ ] **Step 7: Commit**

```bash
git add frontend/lib frontend/test
git commit -m "feat(routing): every route on the shared page builder; tests wait for the transition (DL-124)"
```

### Task 3: The transitions in the running app

**Files:**
- Test: `frontend/test/app/page_transitions_test.dart` (new)

**Interfaces:**
- Consumes: the converted routes (Task 2); `appUnderTest` (`test/support/app_harness.dart`); the signed-in Customer setup of `test/features/shells/presentation/customer_tabs_test.dart` (tokens + `auth.identities[SessionSlot.customer] = user(id: 'c')`, one product `catalogProduct()` — «Pomidor» — featured, 30 favourites, view 800 × 2000 at ratio 1).

They pin the real app and pass at once after Task 2. The first two use the cart, not the product: the product already had its own `MaterialPage` on `main` (`DL-122` (1)), the cart had none — so those two fail on `main`; the last two pass there too and guard against a regression.

- [ ] **Step 1: Write the tests**

- `'the cart slides in over the home'`: at the home, `GoRouter.of(tester.element(find.byType(Scaffold).first)).push(CartPaths.cart)`, `pump()`, `pump(const Duration(milliseconds: 100))` → `find.byType(CatalogHomeScreen)` and `find.byType(CartScreen)` each find one widget; after `pumpAndSettle()` `find.byType(CatalogHomeScreen)` finds nothing.
- `'a swipe back from a page over the favourites tab returns to it, scroll kept'` (`variant: TargetPlatformVariant.only(TargetPlatform.iOS)`): tap `open-favorites`, settle, `drag(byKey('favorites-grid'), const Offset(0, -400))`, settle, read the grid's `position.pixels` (as `gridPixels` in `customer_tabs_test.dart`), push `CartPaths.cart`, settle, `dragFrom(const Offset(5, 300), const Offset(600, 0))`, settle → `find.byType(FavoritesScreen)` finds one widget, `find.byType(CartScreen)` finds nothing, and the grid's pixels equal the value read before the push.
- `'a second tap while the product comes in opens one page'`: at the home, `final Offset at = tester.getCenter(find.text('Pomidor').first)`, `tapAt(at)`, `pump(const Duration(milliseconds: 50))`, `tapAt(at)`, `pumpAndSettle()`, then `tester.binding.handlePopRoute()` and `pumpAndSettle()` → `find.byType(CatalogHomeScreen)` finds one widget.
- `'a tab switch is still instant'`: at the home, tap `byKey('open-orders')`, one `pump()` → `find.byType(OrdersScreen)` finds one widget and `find.byType(CatalogHomeScreen)` finds nothing.

- [ ] **Step 2: Run them**

Run: `G:\tools\flutter\bin\flutter.bat test test/app/page_transitions_test.dart`
Expected: 4 pass.

- [ ] **Step 3: Commit**

```bash
git add frontend/test/app/page_transitions_test.dart
git commit -m "test(routing): pages slide in, swipe back to a kept tab, tabs stay instant (DL-124)"
```

### Task 4: The record

**Files:**
- Modify: `docs/DECISIONS.md` (new `DL-124` after `DL-123`)
- Modify: `docs/07-architecture.md` §29
- Modify: `frontend/AGENTS.md` §6
- Modify: `tasks/APPLE_BATCH.md`

- [ ] **Step 1: `DL-124 — Every page by one builder: the platform's transition, flat pages in place (2026-11-02, agent; placement Owner)`**, in the shape of `DL-122`, numbered points:
  1. Cause: go_router 18 looks for `material_ui`'s `MaterialApp`; the app's is Flutter's own, so every route had `NoTransitionPage` since the scaffold (`32bdcbb`) — no push transition, no iOS back-swipe. 18.1.2 (newest, 2026-11-02) is the same; moving to `material_ui` would touch every import and the theme. Hence `appPage` in `core/routing/app_page.dart` for every route, and no `builder:` left.
  2. Platform pages use the theme's default transitions (no override): Android predictive back and FadeForwards 450 ms, iOS Cupertino 500 ms with the edge back-swipe, which Flutter turns off on a page that holds its back.
  3. Entry pages stand in place: the bootstrap, the sign-in screens (flat, §29; their motion is `vhod-5`, `sys-2`, `profile-1`), `account-deleted` (`del-10`), the tabs (`DL-118`), the staff homes, the whole web panel (a website's page swaps, the browser's back and forward). `route_pages_test.dart` pins the list.
  4. The product's own `MaterialPage` (`DL-122` (1)) folds into `appPage`.
  5. Tests that took a page as appearing in one frame now let the transition run; none lost an assertion.
  6. Owner: this task as a session of its own before stage 6 (2026-11-02, option «1»).
- [ ] **Step 2: `docs/07-architecture.md` §29**: after the sentence on the bottom bar, add: «A page opened over another comes in by the platform's own transition — on iOS with the edge back-swipe — and a flat page (the bootstrap, the sign-in screens, an area's home, a tab, the web panel) replaces the screen in place; every route builds its page through one builder (`DL-124`).»
- [ ] **Step 3: `frontend/AGENTS.md` §6**: add the line «Every route builds its page with `appPage` (`lib/core/routing/app_page.dart`); a route never uses go_router's `builder:` (`DL-124`).»
- [ ] **Step 4: `tasks/APPLE_BATCH.md`**: stage 5's row → «Merged (PR #126)»; the Risks item on transitions ends with «Fixed: one page builder for every route; pages opened over another slide in, with the iOS back-swipe, and flat pages stand in place (`DL-124`).»
- [ ] **Step 5: Commit**

```bash
git add docs/DECISIONS.md docs/07-architecture.md frontend/AGENTS.md tasks/APPLE_BATCH.md
git commit -m "docs: DL-124, every page by one builder; stage 5 merged"
```

### After the tasks (the lead)

- [ ] `flutter analyze`, `dart format --set-exit-if-changed lib test`, `git diff --check`, the full suite once more.
- [ ] Final review by `branch-reviewer`; one fix wave; push, pull request, both required checks green, merge.
- [ ] Walk on the `barakabozor` emulator (Android 16): home → product (slides in), back gesture (predictive back), a category from the home, cart → checkout, a tab switch (instant), sign-out → sign-in (in place). Three or four screenshots mid-transition for the Owner. iOS cannot be walked here (no macOS): the back-swipe rests on the tests.
