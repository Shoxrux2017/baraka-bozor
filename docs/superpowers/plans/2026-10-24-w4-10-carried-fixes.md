# W4-10 Carried P3 Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A row that an action's sure answer takes off a list leaves the list under that page at once, instead of showing until the list's reload answers; and the Customer-mode app-bar row is closed as already fixed by the redesign.

**Architecture:** Riverpod 3 pauses the providers of a screen that another page covers. An action's `ref.invalidate(list)` therefore reloads the list under the page only once that page closes, and until the reload answers the list shows its last answer (`skipLoadingOnRefresh`), so a delivered order shows as the Courier's for about a second. The lead reproduced it with a widget test and checked the fix in a throwaway spike (2026-10-24). The three lists under an order page become `AsyncNotifier`s on one core base class with `drop(id)`. A sure answer that ends the order's place in the list drops the row before invalidating the list, and the server's next answer replaces the page.

**Tech Stack:** Flutter 3.47.5, flutter_riverpod 3.4.3, go_router 18, flutter_test.

**Spec:** `tasks/WAVE_4.md` W4-10, `tasks/WAVE_3.md` risk row "a list left under a page reloads when the page is closed…", `tasks/WAVE_2.md` row 82 and `tasks/WAVE_3.md` row 410 (the six app-bar actions), `frontend/AGENTS.md` sections 5 and 11, `docs/07-architecture.md` section 28.

## Global Constraints

- Only `frontend/`, `docs/` and `tasks/` change. No package, no `pubspec.lock` change, no generated file edited.
- Flutter runs from PowerShell with `$env:TEMP='G:\tools\tmp'; $env:TMP='G:\tools\tmp'` and `G:\tools\flutter\bin\flutter.bat`; a full suite run uses `--concurrency=2`.
- A row is dropped only after a sure success answer (`perform` calls `reload` with a non-null result). A refusal, a lost answer, a `5xx` or `idempotency_in_progress` never drops one.
- `dropRow` never creates a list provider: a list nobody holds is not loaded for a drop (`ref.exists`).
- A drop keeps `page`, `perPage` and `lastPage`, lowers `total` by the rows removed (never below 0), and compares ids in lower case, as the routes and the API do.
- The list is still invalidated after every drop, after the drop, exactly where it is invalidated today; no existing invalidation is removed.
- Rows that stay in a list after an action (accept, start, an edit, a cancellation request, a line bought) are not dropped or patched (`DL-113` (3)).
- Provider names stay as they are (`courierOrdersProvider`, `shopperOrdersProvider`, `customerOrdersProvider`); every existing caller compiles unchanged.
- Comments read like the surrounding code: short `///` docs in plain English that name the `DL-` they follow.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. A failed or uncertain action that drops a row anyway, so a delivery still the Courier's vanishes (Task 1 controller test: a lost answer and a refusal keep the row).
2. A drop on a list no screen holds, which would start a list request for nobody, for example a delivery opened from a push (Task 1 core test: `dropRow` on an unheld list loads nothing).
3. A drop during a load, or after a failed load, replacing the spinner or the failure with stale data (Task 1 core test: loading without a value and an error stay as they are).
4. A Customer cancel dropping the row from the wrong tab, or a cancellation request dropping it at all (Task 3 tests).
5. The Shopper's line answer that keeps the order (`assignment != null`) dropping its row (Task 2 test).

---

### Task 1: The droppable list page, and the Courier's list

**Files:**
- Create: `frontend/lib/core/state/list_page_controller.dart`
- Modify: `frontend/lib/features/courier/application/courier_orders_controllers.dart` (the list provider, `CourierOutcomeController._reload`)
- Modify: `frontend/test/support/fake_courier_orders_repository.dart` (add `holdList`)
- Test: `frontend/test/core/state/list_page_controller_test.dart` (new), `frontend/test/features/courier/application/courier_orders_controllers_test.dart`, `frontend/test/features/courier/presentation/courier_screens_test.dart`

**Interfaces:**
- Produces: `abstract class ListPageController<T> extends AsyncNotifier<Paged<T>>`, with `@protected String idOf(T row)` (abstract) and `void drop(String id)`.
  - `drop` acts only while `state.hasValue && !state.hasError`.
  - It removes every row whose `idOf(row).toLowerCase() == id.toLowerCase()`.
  - When nothing matched, it leaves `state` untouched (the same object).
  - Otherwise it sets `state = AsyncData(Paged(items: kept, page, perPage, total: max(0, total - removed), lastPage))`.
- Produces: `void dropRow<T>(Ref ref, AsyncNotifierProvider<ListPageController<T>, Paged<T>> list, String id)`. It calls `ref.read(list.notifier).drop(id)` only when `ref.exists(list)`. If the analyzer rejects the provider type for a family's instance, use the narrowest Riverpod 3 type that both a plain and a family instance satisfy, and state it in the report.
- Produces: `class CourierOrdersListController extends ListPageController<CourierOrder>`. Its `build()` is today's `courierOrdersProvider` body and `idOf` is `order.id`. `courierOrdersProvider` becomes `AsyncNotifierProvider.autoDispose<CourierOrdersListController, Paged<CourierOrder>>(CourierOrdersListController.new)`, with the same doc line.
- Produces (test support): `Completer<void>? holdList` on `FakeCourierOrdersRepository`. Its doc: "Holds the list's loads only, until the test completes it." `orders()` awaits it after recording the load.

- [ ] **Step 1: Write the failing core tests** in `list_page_controller_test.dart`. Use a private `_Rows extends ListPageController<String>` whose `build()` answers a `Completer<Paged<String>>` the test holds and counts its builds; `idOf` is the string itself. Each test uses a `ProviderContainer`.
  - `'drop takes the row off and keeps the page where it is'`: page 2 of rows `['a', 'b', 'c']`, `perPage: 3`, `total: 7`, `lastPage: 3`. After `drop('b')`: `isA<AsyncData>()`, items `['a', 'c']`, page 2, perPage 3, total 6, lastPage 3.
  - `'drop matches the id in any case'`: `drop('B')` removes `'b'`.
  - `'a row not on the page changes nothing'`: `drop('z')` leaves `same(before)`.
  - `'before the first answer, and after a failed one, drop changes nothing'`: while the completer is open, the state stays `isA<AsyncLoading>()` without a value; after `completeError`, it stays `hasError`.
  - `'dropRow leaves a list nobody holds unloaded'`: nothing listens to the list. A `Provider<void>` that calls `dropRow(ref, rows, 'a')` is read. The build count stays 0 and `container.exists(rows)` is false.
  - `'dropRow takes the row off a list a screen holds'`: `container.listen(rows, …)` and the first page answered, then `dropRow` through the same helper provider; `'a'` is gone.

- [ ] **Step 2: Run them and see them fail**
  Run: `flutter.bat test test/core/state/list_page_controller_test.dart`
  Expected: compile failure (`ListPageController` is not defined).

- [ ] **Step 3: Implement `list_page_controller.dart`**. Its class doc says the controller is one page of a list a screen shows, which a sure answer on one row's own page can take that row off at once, before the list's own reload answers (`DL-113`).

- [ ] **Step 4: Run the core tests**: all six pass.

- [ ] **Step 5: Write the failing Courier tests.**
  - In `courier_orders_controllers_test.dart`, the container also listens to `courierOrdersProvider`, which holds `[A]` (setUp) plus `courierOrderB` `on_the_way`. Each test awaits `container.read(courierOrdersProvider.future)` first.
  - `'a handover that ended the delivery takes it off the list at once'`: set `orders.holdList = Completer<void>()`, await `outcome.delivered(55600)`. `container.read(courierOrdersProvider).value!.items` ids are `[B]` while the reload is held. Complete the hold, and they are still `[B]`.
  - `'a not delivered takes it off the list at once'`: the same with `outcome.notDelivered(<any reason but other>, null)`, since only `other` takes a note.
  - `'a handover without a sure answer, or refused, keeps it on the list'`: for each of `NetworkFailure()` and `ApiRefusal(ApiError(status: 409, code: 'cash_amount_mismatch'))`, with `holdList` set, the ids still contain A after the call.
  - In `courier_screens_test.dart`, a new group `'the list under a delivery'`. Its setUp has A `on_the_way` with `afterAction[A]` ended, as the handover group at line ~990 does. Open with no `at`, tap `courier-order-$courierOrderA`, and hand over as the test `'takes the cash typed, and leaves for the list, told so'` does. Set `courier.holdList` just before tapping `courier-delivered-confirm`.
  - `'a delivery handed over leaves the list under it at once'`: after the confirm settles, the location is `AppPaths.courier`, `courier-order-$courierOrderA` is `findsNothing` and `courier-order-$courierOrderB` is `findsOneWidget`. Complete the hold, settle, and the same holds.

- [ ] **Step 6: Run them and see them fail**
  Run: `flutter.bat test test/features/courier`
  Expected: the three "takes it off / leaves" tests fail with A still listed. The "keeps it" test may already pass.

- [ ] **Step 7: Implement the Courier side.** Convert the provider as Interfaces says. Change `CourierOutcomeController._reload(CourierOrder? answered)` to call `dropRow(ref, courierOrdersProvider, orderId)` when `answered != null`, then `ref.invalidate(courierOrdersProvider)` as today. Add one sentence to the class doc: a sure outcome takes the delivery off the list under the page at once (`DL-113`). Add `holdList` to the fake.

- [ ] **Step 8: Run** `flutter.bat test test/core/state test/features/courier`, then `flutter.bat analyze` and `dart format --set-exit-if-changed lib test`. All pass, no issues.

- [ ] **Step 9: Commit** — `fix(courier): a delivery handed over or not delivered leaves the list under its page at once`.

### Task 2: The Shopper's list

**Files:**
- Modify: `frontend/lib/features/shopper/application/shopper_orders_controllers.dart` (the list provider, `ShopperLineController._reload`, `ShopperCompleteController.complete`'s reload)
- Modify: `frontend/test/support/fake_shopper_orders_repository.dart` (add `holdList`, as Task 1's)
- Test: `frontend/test/features/shopper/presentation/shopper_market_test.dart`

**Interfaces:**
- Consumes: `ListPageController<T>`, `dropRow` (Task 1).
- Produces: `class ShopperOrdersListController extends ListPageController<ShopperOrderRow>` (`idOf` = `row.id`). `shopperOrdersProvider` becomes `AsyncNotifierProvider.autoDispose<ShopperOrdersListController, Paged<ShopperOrderRow>>`.

- [ ] **Step 1: Write the failing tests** in `shopper_market_test.dart`, next to the tests they copy.
  - `'an order the last line's answer cancelled leaves the list under it at once'`: copy the test around line 690 that expects `shopperOrderCancelled`, but reach the order by tapping `shopper-order-<id>` on the list. Give the list a second row, and set `holdList` before the confirming tap. After it settles: the location is `AppPaths.shopper`, the order's row is absent and the second row is present.
  - `'a line answer that keeps the order keeps its row'`: one line marked unavailable whose answer keeps `assignment` (any test of that kind in the file). With `holdList` set, after it settles, go back to the list (`tester.pageBack()`), and the row is present.
  - `'a completion that answers after the Shopper left takes the order off the list at once'`: copy the test at line ~1174 (`'a Shopper who left the order while its completion ran is told…'`). Once the Shopper is back on the list and before the held completion is released, set `holdList`. After release and settle, the order's row is absent while the list reload is held.

- [ ] **Step 2: Run** `flutter.bat test test/features/shopper/presentation/shopper_market_test.dart`. Expected: the first and the third new tests fail with the row still shown, and the second passes. If one that should fail passes, stop and report it; never weaken a test.

- [ ] **Step 3: Implement.**
  - Convert the provider.
  - In `ShopperLineController._reload`, when `answered != null && answered.assignment == null`, call `dropRow(ref, shopperOrdersProvider, line.orderId)` before the existing invalidations.
  - In `ShopperCompleteController.complete`, the reload becomes `(ShopperOrder? done) { if (done != null) dropRow(ref, shopperOrdersProvider, orderId); ref.invalidate(shopperOrdersProvider); }`.
  - Add one sentence to each class doc, naming `DL-113`.

- [ ] **Step 4: Run** `flutter.bat test test/features/shopper`, `flutter.bat analyze` and `dart format --set-exit-if-changed lib test`. All pass.

- [ ] **Step 5: Commit** — `fix(shopper): an order the Shopper no longer holds leaves the list under its page at once`.

### Task 3: The Customer's orders

**Files:**
- Modify: `frontend/lib/features/orders/application/customer_orders_controllers.dart` (the list family, `OrderCancelController.cancel`)
- Modify: `frontend/test/support/fake_customer_orders_repository.dart` (add `holdList`; `orders()` awaits it after recording the load)
- Test: `frontend/test/features/orders/presentation/orders_screens_test.dart`

**Interfaces:**
- Consumes: `ListPageController<T>`, `dropRow` (Task 1).
- Produces: `class CustomerOrdersListController extends ListPageController<OrderSummary>`, constructed with the `OrdersTab tab` (as `OrdersPageController` is); `idOf` = `order.id`. `customerOrdersProvider` becomes `AsyncNotifierProvider.autoDispose.family<CustomerOrdersListController, Paged<OrderSummary>, OrdersTab>`. Every caller, `ref.invalidate(customerOrdersProvider)` of the whole family included, compiles unchanged.

- [ ] **Step 1: Write the failing tests** in the `'cancelling'` group.
  - `'a cancelled order leaves the current orders under it at once'`: the fake holds two current orders (`orderOne` and a second row). `open(tester, at: AppPaths.customerOrders)`, tap `order-$orderOne`, then cancel as `'asks first, sends the reason, and shows the order cancelled'` does, setting `orders.holdList` before `cancel-confirm`. Then `tester.pageBack()` and settle. `order-$orderOne` is absent and the second order's card is present. Complete the hold, settle, and the same holds.
  - `'a cancel without a sure answer keeps the order on the list'`: the same with `orders.failure = const NetworkFailure()`, and `order-$orderOne` is present after going back.
  - In the `'a cancellation request'` group, `'a cancellation request keeps the order on the list'`: a request sent from the order reached from the list, with `holdList` set, and the card is present after going back.

- [ ] **Step 2: Run** `flutter.bat test test/features/orders/presentation/orders_screens_test.dart`. Expected: the first new test fails, the other two pass.

- [ ] **Step 3: Implement.** Convert the family. `OrderCancelController.cancel` passes `reload: (CustomerOrder? cancelled) { if (cancelled != null) dropRow(ref, customerOrdersProvider(OrdersTab.current), orderId); reload(cancelled); }`. A cancelled order belongs to the past tab, and that tab loads when it is shown (`docs/09` section 20). Add one sentence to the class doc, naming `DL-113`.

- [ ] **Step 4: Run** `flutter.bat test test/features/orders`, `flutter.bat analyze` and `dart format --set-exit-if-changed lib test`. All pass.

- [ ] **Step 5: Commit** — `fix(orders): a cancelled order leaves the current orders under its page at once`.

### Task 4: The record, the documents and the full suite

**Files:**
- Modify: `docs/DECISIONS.md` (append `DL-113`), `docs/07-architecture.md` section 28 (one sentence), `tasks/WAVE_4.md` (W4-10 row and task notes, the carried row), `tasks/WAVE_3.md` (rows 410 and 418), `tasks/WAVE_2.md` (row 82)

- [ ] **Step 1: Append `DL-113 — Carried P3 fixes from W4-10 (2026-10-24, agent)`**, in the voice of `DL-112`, with numbered items:
  1. **The cause.** Riverpod 3 pauses a covered screen's providers, so the action's reload of the list under a page runs only once the page closes. Until it answers, the list shows its last answer.
  2. **The drop.** The Courier's, the Shopper's and the Customer's order lists are `ListPageController`s. A sure answer that takes the order off a list drops its row at once, before the list loads again:
     - delivered and not delivered, for the Courier;
     - a completion, and a line answer that left the Shopper without the order;
     - a direct cancel, from the Customer's current tab.
     The page keeps its place, the total is one lower, and the server's next answer replaces it. This is not the optimistic patching that `frontend/AGENTS.md` section 11 forbids: the server has already answered. A list that no screen holds is not loaded for it.
  3. **Rows that stay are not patched.** An accept, a start, an edit, a cancellation request and a bought line keep their row in its old state until the reload. Tapping it opens the order's own page, which loads fresh.
  4. **Customer mode's app bar** (`tasks/WAVE_2.md`, `tasks/WAVE_3.md`) was already fixed:
     - the Customer home has no app bar (`DL-75` items 4 and 5);
     - every other Customer screen's app bar holds at most one action;
     - a Shopper's or Courier's holds one menu (`DL-98` (3)), and `customer_home_test.dart` and the staff screen tests pin it.
     The row is closed with no code change.
- [ ] **Step 2: Add to `docs/07` section 28** a sentence after its first: a sure answer that takes a row off a list removes it from the list under the page at once, before that list loads again (`DL-113`).
- [ ] **Step 3: Update the task files.**
  - `tasks/WAVE_4.md`: the W4-10 row becomes `Done`. Under the task notes, each bullet ends with its outcome. The risk row `Carried from Wave 3, P3: …` becomes `Closed by W4-10 (`DL-113`)`.
  - `tasks/WAVE_3.md` rows 410 and 418, and `tasks/WAVE_2.md` row 82: the status becomes `Closed by W4-10 (`DL-113`)`.
- [ ] **Step 4: Run** the full frontend suite with `flutter.bat test --concurrency=2`, then `flutter.bat analyze`, `dart format --set-exit-if-changed lib test`, and `git diff --check`. All pass.
- [ ] **Step 5: Commit** — `docs: W4-10 carried fixes, DL-113`.
