# Apple Stage 18 — «Мои адреса» Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** «Мои адреса» in the kit: a white centred bar, white cards with an icon by label, the line with the flat, «Ориентир: …», a green ring and «Доставка сюда» on the delivery address, a «⋯» menu (Изменить · Доставлять сюда · Удалить) and a swipe that reveals «Удалить» or removes on a long pull; a full-width «Добавить адрес» at the bottom. Deletion asks nothing: the card folds, «Удалили «Работа» · Вернуть» stays 5 s, the server is told when the bar ends, and offline the card comes back saying «Нет связи — адрес не удалён»; the home's address sheet deletes the same way. Three skeleton cards while loading, the kit block with a green «Повторить» on failure, a pin and one button when empty; a saved address unfolds or glows and its bar names it; a reader hears one stop per card with its actions.

**Architecture:** Client only — no server field, no migration, no package. A kept-alive `AddressRemovals` notifier holds the one removal whose bar is up and the ids being removed; a derived `shownAddressesProvider` (the loaded list minus those ids) feeds the list, the home sheet, the delivery address (home line, cart card, profile row) and checkout, so an address being removed is gone everywhere at once and comes back everywhere on «Вернуть» or a failure. `SwipeToRemove` moves from the cart to `core/` and gains a reveal mode. One flow, `removeAddress`, drives a removal on the list (the page's undo bar) and in the sheet (an `InlineUndoBar` inside the sheet, since a page's bar lies under the sheet's barrier). The address form names the saved address in its bar and pops it for an edit too, so the list can unfold and glow it.

**Tech Stack:** Flutter 3.47.5, flutter_riverpod 3.4.3, go_router 18.x; core `Fold` / `FoldingColumn` (`DL-119`, `DL-121`), `showUndoBar` (`DL-119`, `DL-128`), `announce`, `SkeletonBar`, `KitEmptyState`, `kitAppBar`, `kitFilled`, `textScaleAt` (`DL-126`); `FavoriteRemovals` (`DL-129`) as the pattern for a removal held until its bar ends; flutter_test (`fakeAsync`, `tester.takeAnnouncements()`, `meetsGuideline(iOSTapTargetGuideline)`, `NonlinearTextScaler`, `SystemChannels.platform` mock for haptics).

**Spec:** `tasks/APPLE_BATCH.md` stage 18 (`addr-1` … `addr-9`; `addr-6`, `addr-9` **repro**); no **Owner** item (`addr-3` supersedes the agent's `DL-33` (2) and `DL-86` (5)). The live test «Тест адресов - Apple», local copy `G:/tools/tmp/w-addr/site/addr.html` (CSS `.abk .swc.kc .lead .chip .t4 .glw .mnu .mi .skc .blk .bic .gbtn .ft .fbtn .snk .swa`; script `cardSay`, `instantDelete`, `collapse`, `unfold`, `glow`, `commitPend`, `undo`, `choose`, `addNew`, `editRab`, `reopen`, `pUp`, `stops`). Also closes the stage 4 residual on the checkout's address card (APPLE_BATCH, «Review findings not acted on»: "taken with stage 18 or 19").

## Global Constraints

- Changes stay in `frontend/`, `docs/` and `tasks/`. No backend change, no package; `pubspec.lock` untouched. Generated localizations come from `flutter gen-l10n`, never by hand.
- An address is named everywhere by `Address.name` (new getter: `label ?? streetLine`).
- New strings (ru / uz):
  - List: `addressesAdd` «Добавить адрес» / «Manzil qo'shish»; `addressesEmptyText` «Добавьте адрес — курьер привезёт заказ туда. Точку отметите на карте.» / «Manzil qo'shing — kuryer buyurtmani o'sha yerga olib keladi. Nuqtani xaritada belgilaysiz.»; `addressesFailedTitle` «Не удалось загрузить адреса» / «Manzillar yuklanmadi»; `addressesFailedOffline` «Проверьте интернет и нажмите «Повторить».» / «Internetni tekshirib, «Qayta urinish»ni bosing.»; `addressesFailedOther` «Попробуйте ещё раз: нажмите «Повторить».» / «Yana bir bor urinib ko'ring: «Qayta urinish»ni bosing.»; `addressesLoadingSpoken` «Загружаем адреса» / «Manzillar yuklanmoqda».
  - Card and menu: `addressDeliveryHere` «Доставка сюда» / «Shu yerga yetkaziladi»; `addressDeliveryHereSpoken` «доставка сюда» / «shu yerga yetkaziladi»; `addressDeliverHere` «Доставлять сюда» / «Shu yerga yetkazish»; `addressActionsSpoken` «Действия: {name}» / «Amallar: {name}»; `addressEditHint` «изменить» / «o'zgartirish»; `addressNotRemovedOffline` «Нет связи — адрес не удалён» / «Aloqa yo'q — manzil o'chirilmadi»; `addressNotRemovedOther` «Не удалось удалить адрес» / «Manzilni o'chirib bo'lmadi».
  - Removal: `addressRemovedBar` «Удалили «{name}».» / ««{name}» o'chirildi.»; `addressRemovedBarDelivery` «Удалили «{name}». Доставка теперь: «{next}».» / ««{name}» o'chirildi. Endi yetkazish: «{next}».»; `addressRemovedSpoken` «Адрес «{name}» удалён. Вернуть — кнопка внизу.» / ««{name}» manzili o'chirildi. Qaytarish — pastdagi tugma.»; `addressRemovedSpokenDelivery` «Адрес «{name}» удалён. Доставка теперь: «{next}». Вернуть — кнопка внизу.» / ««{name}» manzili o'chirildi. Endi yetkazish: «{next}». Qaytarish — pastdagi tugma.»; `addressRestoredSpoken` «Адрес «{name}» возвращён» / ««{name}» manzili qaytarildi»; `addressNotRemovedSpoken` «Нет связи, адрес «{name}» не удалён» / «Aloqa yo'q, «{name}» manzili o'chirilmadi»; `addressNotRemovedOtherSpoken` «Адрес «{name}» не удалён» / ««{name}» manzili o'chirilmadi»; `addressDeliveryChosenSpoken` «Доставка: «{name}»» / «Yetkazish: «{name}»».
  - Saves: `addressAdded` «Адрес «{name}» добавлен» / ««{name}» manzili qo'shildi»; `addressSavedNamed` «Адрес «{name}» сохранён» / ««{name}» manzili saqlandi».
  - Reused: `addressesTitle`, `addressNone`, `addressMenuEdit`, `addressRemove`, `undoAction`, `retryButton`, `addressLandmarkLine`, `addressApartmentShort`, `addressAddNew` (the sheet's button), `deliveryAddressRetry` and `retryButton` (checkout card).
  - Removed when no longer used: `addressRemoveConfirm`, `addressSaved`.
- Drawing (from `addr.html`). **Page** white; `kitAppBar(title: addressesTitle)`; the list's padding 4 / 20 / 24, 12 above each card. **Card**: white, radius 16, shadow `0 2 14` `Color(0x12151D16)`, padding 14 top / 4 right / 14 bottom / 14 left, 12 between the lead and the text; the delivery card adds a 1.5 px `primary` border inside. **Lead** 44 × 44, radius 12, `primaryWash`, icon 24 `primary`: `Icons.home_outlined` for «Дом»/«Uy», `Icons.work_outline` for «Работа»/«Ish» (`addressLabelKindOf`), else `Icons.location_on_outlined`. **Text**: title 15 w700 `ink` height 1.4, 2 above; line 13 `ink2` height 1.45, 3 above (labelled: `addressFullLine` with the flat; unlabelled: `addressApartmentPart` or nothing); landmark 12 `muted` height 1.45, 2 above (`addressLandmarkLine`); no line limit. **Chip** «Доставка сюда» 8 above: min height 24, padding 2 / 10 / 2 / 6, radius 12, `primaryWash`, `Icons.check` 16 and 12 w600 `primaryDark`, 4 gap. **Red line** 6 above: 13 w600 `danger`. **«⋯»** 44 × 44 at the top right (−4 from the card's padding), `Icons.more_vert` `ink`. **Glow** over the card: a 2 px inside ring `Color(0xE63A9E46)` and a 4 px outside ring `Color(0x473A9E46)`, radius 16. **Menu** (`PopupMenuButton`, `PopupMenuPosition.under`): white, radius 14, elevation 8 with `KitColors.shadow`, vertical padding 6, min width 208; items 44 high, padding 16 sides, a 20 icon, 12 gap, 14 text — `Icons.edit_outlined` «Изменить», `Icons.where_to_vote_outlined` «Доставлять сюда» (not on the delivery card, not in the sheet), `Icons.delete_outline` «Удалить» in `danger` (icon and text). **Swipe** red box radius 16, `danger`, an 88-wide button at its right: `Icons.delete_outline` 22 over «Удалить» 12 w600 white, 2 gap. **Footer**: white, shadow `0 −6 20` `Color(0x0F000000)`, padding 12 / 20 / 12 over the bottom inset; `FilledButton.icon` `kitFilled()` (54, radius 14), `Icons.add` 22, 10 gap, 15 w600, key `address-new`; hidden while the list is empty. **Skeleton card**: the card's frame, padding 14; a 44 × 44 `SkeletonBar` radius 12; then (4 above) bars 14 × 42 %, 12 × 78 %, 11 × 56 % of the text's width, 9 between; three cards. **Failure**: `KitEmptyState(quiet: true, icon: Icons.cloud_off, actionIcon: Icons.refresh)` — `addressesFailedTitle`, `addressesFailedOffline` for a `NetworkFailure` else `addressesFailedOther`, «Повторить». **Empty**: `KitEmptyState(icon: Icons.location_on, actionIcon: Icons.add)` — `addressNone`, `addressesEmptyText`, «Добавить адрес» (key `address-new`). `KitEmptyState.quiet` draws the circle `KitColors.chip` and the icon `muted`; `actionIcon` stands 22 before the label with 10 between; both default to today's look.
- Motion (none of it with reduced motion, `MediaQuery.disableAnimationsOf`, unless said): a removed card folds by `FoldingColumn` (260 ms) and one that comes back unfolds (300 ms); the cards replacing the skeleton fade 0 → 1 in 260 ms `easeOut` (a list shown at once does not fade); the chip pops when its card becomes the delivery address while shown — scale 1 → 1.12 at 35 % → 0.97 at 70 % → 1 over 340 ms `Cubic(0.2, 0.8, 0.2, 1)`; the glow's opacity 0 → 1 by 15 %, 1 until 45 %, → 0 at 100 % over 1500 ms `easeOut`, starting 200 ms after it is asked (0 with reduced motion — the glow plays then too, it is not motion); a new address scrolls the list to the top in 300 ms `Cubic(0.2, 0.8, 0.2, 1)` (a jump with reduced motion); an edited one is brought into view the nearest way in 300 ms. The sheet's `InlineUndoBar` comes in by opacity 0 → 1 and a 16 px rise in 250 ms `Cubic(0.2, 0.8, 0.2, 1)` and leaves by opacity in 200 ms `easeIn` (opacity only with reduced motion).
- Swipe, reveal mode (from `pUp`): the row follows the finger left and resists right as today; it settles from where the drag began (0, or −88 when open). On release, `projected = offset + velocity / 1000 × 0.99 / (1 − 0.99)`: if `offset < −0.6 w`, or `offset < −0.35 w` and `projected < −0.9 w`, the row slides to `−w` in 200 ms `easeOut` and then calls `onRemove`; else if `projected < −44` it settles at −88 in 300 ms `Cubic(0.2, 0.8, 0.2, 1)` and reports `onRevealChanged(true)`; else it springs back to 0 and reports `false` if it was open. The cart's mode (`reveal: false`) keeps today's thresholds and timings exactly.
- Timing: the removal's bar stays 5 s (`addressUndoDuration`); with a screen reader it stays until its action, a swipe or the next bar (`showUndoBar`, `DL-119`), and `InlineUndoBar` does the same. At most one removal is held: a new one sends the held one at once and ends its bar.
- Haptics: `HapticFeedback.lightImpact` on «Доставлять сюда».
- Large text: layout rules read `textScaleAt(scaler, fontSize)` (`DL-126`); tests at large text use `NonlinearTextScaler(2)` on 360 × 640 dp.
- Every face this branch draws passes `meetsGuideline(iOSTapTargetGuideline)` at 100 % and at `NonlinearTextScaler(2)` (batch rule): the list loaded, with a revealed card, loading, failed, empty; the open menu; the sheet with its bar.
- The server stays authoritative (`AGENTS.md` §5, `DL-17`): an address is removed only by a `204` (or a `404 resource_not_found`, which means it is already gone); until then it is only hidden on this phone. Nothing is sent for an account other than the one that asked; a removal held when the account changes is dropped unsent. The delivery choice (`DL-75`) is never rewritten by a removal: the stored id stays, so «Вернуть» brings the delivery address back and a removed one falls back to the newest.
- Tests that pinned the old faces are rewritten, not deleted: the Material list with trashes and the FAB, «Удалить этот адрес?» with its green «Удалить», «Адрес сохранён», the sheet's ask-first deletion and its `FailureMessage`, the spinner and outlined «Повторить». No expectation about what reaches the server is dropped.
- Flutter runs from PowerShell with `$env:TEMP='G:\tools\tmp'; $env:TMP='G:\tools\tmp'` and `G:\tools\flutter\bin\flutter.bat`; multi-file runs use `--concurrency=1`; no background jobs. Never a destructive artisan command.
- Comments read like the surrounding code: short `///` docs in plain English that name `DL-137`. A test's first run is red, and the report quotes the red line.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- `/security-review` once before the pull request: the branch changes when a Customer's address deletion reaches the server and what happens to it across accounts.

## Review Focus

1. The account changes (log out, another Customer signs in) while a removal's bar is up or its delete is on its way: nothing is sent for the old account after the change, and its answer changes nothing the new account sees. Task 2 tests `'a removal held when the account changes is dropped unsent'` and `'an answer for the previous account changes nothing'`.
2. A second address removed while the first one's bar is up: the first is sent at once and its bar ends, each address gets exactly one `DELETE`, and «Вернуть» brings back only the second. Task 2 test `'a second hold sends the first at once and ends its bar'`, Task 5 test `'a second removal sends the first at once'`.
3. «Вернуть» pressed as the bar ends, after the delete was sent: nothing comes back that the server removed, and nothing is sent twice. Task 2 test `'undo after the send brings nothing back'`.
4. The delivery address removed, then brought back: the mark returns to it on the list, the home line and checkout; removed for real, the newest takes over. Task 2 test `'undoing the delivery address's removal makes it the delivery address again'`.
5. Swipes against scrolling and each other: a mostly vertical drag never moves a card, only one card is open at a time, opening the menu or scrolling closes an open card. Task 1 test `'a mostly vertical drag does not move the row'`, Task 5 test `'revealing a card closes the one open'`.

---

### Before the tasks (the lead)

- [x] **The test page.** Read 2026-11-16 from the local copy `G:/tools/tmp/w-addr/site/addr.html`; this plan follows it. The home sheet is not drawn there; its deletion follows `addr-3`'s words, with the bar inside the sheet (`DL-137` (3)).
- [ ] **Reproduce the repro items.** As in stages 11–17, the first red runs of these tests on main's code are the reproduction, quoted in `DL-137` (12): `addr-6` — Task 4 `'loading shows three skeleton cards and the add button works'` (on main a spinner on an empty page) and `'a failed load shows the kit block with a green retry'` (on main a red line and an outlined button); `addr-9` — Task 3 `'a card is one stop with its actions'` (on main a row and its own unnamed «Удалить») and Task 5 `'the reader's Удалить removes and is announced'` (on main a dialog that names nothing, and silence).

### Task 1: The swipe in core, with a reveal mode, and the decision record

**Files:**
- Move: `frontend/lib/features/cart/presentation/swipe_to_remove.dart` → `frontend/lib/core/widgets/swipe_to_remove.dart` (`git mv`; `cart_line_tile.dart`'s import follows)
- Move: `frontend/test/features/cart/presentation/swipe_to_remove_test.dart` → `frontend/test/core/widgets/swipe_to_remove_test.dart`
- Modify docs: `docs/DECISIONS.md` (`DL-137`), `docs/03-features.md` §4 (two sentences: the list marks the delivery address and lets it be chosen; a deletion hides the address at once with «Вернуть» for 5 s and reaches the server when the bar ends), `docs/07-architecture.md` (the address paragraph: one sentence — an address being removed is hidden on every screen until the server answers, `DL-137` (10)), `tasks/APPLE_BATCH.md` (rows 17 and 22 → «Merged (PR #140)»)

**Interfaces:**
- Produces: `SwipeToRemove({required Widget child, required String label, required VoidCallback onRemove, required bool removing, bool reveal = false, bool revealed = false, ValueChanged<bool>? onRevealChanged, double radius = 14, bool semanticsAction = true, Key? buttonKey})`. With `reveal` the red box shows the 88-wide button (Global Constraints, «Swipe»); its tap calls `onRemove` at once; a tap on the row while `revealed` reports `onRevealChanged(false)` and does not reach the child; `revealed` turned false by the parent springs the row back. `semanticsAction: false` drops the widget's own custom action, so the child's node carries the actions.

- [ ] **Step 1: Move the file and its test** with `git mv`; run the moved test and the cart tests — they pass unchanged.
- [ ] **Step 2: Write the failing tests** in the moved test file:
  - `'a medium swipe reveals the red button and keeps the row at -88'` — drag −150 slowly on a 360 row: the child's translation −88, `onRevealChanged(true)`, the button (`buttonKey`) shows «Удалить» and `Icons.delete_outline`, `onRemove` not called.
  - `'tapping the revealed button removes'` — `onRemove` called once; the row stays at −88.
  - `'a long swipe removes at once'` — drag −0.65 w: the row reaches −w and `onRemove` is called after 200 ms; a fling past −0.35 w with a projection past −0.9 w does the same.
  - `'a short swipe springs back'` — drag −30 slowly: back at 0, no reveal.
  - `'a tap on a revealed row closes it and does not reach the row'` — the child's `onTap` not called; `onRevealChanged(false)`.
  - `'turning revealed off from outside springs the row back'`.
  - `'a mostly vertical drag does not move the row'` — a drag of (−20, −120) inside a `ListView`: the list scrolls, the row's offset stays 0 (Review Focus 5).
  - `'without the semantics action the row adds no custom action'`.
  - `'reduced motion moves the row without sliding'` — `disableAnimations`: the reveal lands at −88 on the next frame.
- [ ] **Step 3: Run and see them fail.**
- [ ] **Step 4: Implement** the reveal mode in `SwipeToRemove`, leaving the cart's path as it is.
- [ ] **Step 5: Run** the swipe tests and `test/features/cart/` — all pass.
- [ ] **Step 6: Write `DL-137`** — «The Apple batch, stage 18: addresses (2026-11-16, agent)», with these points (later tasks only add rulings to (13)):
  1. **The kit look** (`addr-1`): white centred bar, white cards like the sheet's (drawing 21), a full-width «Добавить адрес» at the bottom instead of the floating button that covered rows at large text.
  2. **Menu and swipe** (`addr-2`): «⋯» opens Изменить · Доставлять сюда · Удалить (red), one menu widget shared with the home sheet (which has no «Доставлять сюда»: there a tap on the card chooses). A swipe left reveals an 88-wide «Удалить»; a long or fast swipe removes at once. `SwipeToRemove` moves to `core/` with a reveal mode; the cart's swipe is unchanged.
  3. **Deletion at once** (`addr-3`, superseding `DL-33` (2) and `DL-86` (5)): no question; the card folds in 0.26 s, «Удалили «Работа» · Вернуть» stays 5 s, and the `DELETE` goes when the bar ends — on its time, a swipe, the next removal (which sends the held one at once), the app going out of sight, or the screen's bar being replaced. A removal held when the account changes is dropped unsent. A `404 resource_not_found` means the address is already gone and counts as removed. A failure brings the card back where it stood with «Нет связи — адрес не удалён» (or «Не удалось удалить адрес»), spoken too, until the next removal. The home sheet deletes the same way, with the bar inside the sheet above «Добавить новый адрес» (a page's bar would lie under the sheet's barrier); closing the sheet ends its bar and sends the removal.
  4. **The delivery address** (`addr-4`): a 1.5 px green ring and «Доставка сюда»; «Доставлять сюда» writes the `DL-75` choice with a light haptic and the chip's pop, and is spoken «Доставка: «Мама»». Removing the delivery address names where delivery goes now — the newest left, as `DL-75` falls back. The stored choice is never rewritten by a removal, so «Вернуть» brings it back.
  5. **What a card says** (`addr-5`): the line with the flat, «Ориентир: …», an icon by label (home, work, pin), as the sheet's cards say it.
  6. **Loading and failure** (`addr-6`): three skeleton cards (the add button works meanwhile), then the cards fade in; a failure is the kit block with a green «Повторить». `KitEmptyState` gains a quiet (grey) face and an icon on its button. Opened from the profile, whose row keeps the list loaded, the screen shows the cards at once.
  7. **Empty** (`addr-7`): a pin in a green circle, why an address is needed, one «Добавить адрес».
  8. **After a save** (`addr-8`): the form's bar names the address («Адрес «Сестра» добавлен», «Адрес «Работа» сохранён») wherever the form was opened from, and it pops the saved address for an edit too. The list scrolls a new address into view at the top, where it unfolds and glows; an edited card is brought into view and glows. The glow waits for the card if the reloaded list arrives later.
  9. **Screen reader** (`addr-9`): one stop per card — «Дом, доставка сюда, Navoiy ko'chasi, 12, кв. 5, Ориентир: …», a button whose tap edits, with the actions «Удалить» and «Доставлять сюда»; «⋯» is «Действия: Дом»; removal, «Вернуть», a failure and a new delivery address are announced.
  10. **One shown list**: `shownAddressesProvider` is the loaded list without the addresses being removed; the list, the sheet, the home line, the cart card, the profile row and checkout read it, so a removal shows everywhere at once and «Вернуть» everywhere too. The server's list is reloaded once a removal succeeds.
  11. **Checkout's address card** (stage 4 residual): a list that failed to load reads «Адрес не загрузился — повторить» with «Повторить», not «Добавить».
  12. **Reproduction**: the repro items' red runs on main, quoted per item.
  13. **Rulings** made while coding (added by later tasks).
- [ ] **Step 7: Docs and the batch rows** as listed under Files.
- [ ] **Step 8: Commit** — `feat(core): the swipe moves to core and can reveal its button (DL-137)`.

### Task 2: Removals, the shown list and its readers

**Files:**
- Create: `frontend/lib/features/addresses/application/address_removals.dart`
- Modify: `frontend/lib/features/addresses/domain/addresses.dart` (`Address.name`), `frontend/lib/features/addresses/application/addresses_controllers.dart` (`shownAddressesProvider`), `frontend/lib/features/addresses/application/delivery_address.dart` (reads the shown list), `frontend/lib/features/checkout/presentation/checkout_screen.dart` (reads, watches and listens to `shownAddressesProvider`; invalidations stay on `addressesProvider`), `frontend/lib/features/checkout/presentation/checkout_sections.dart` (`CheckoutDeliveryCard.listFailed`), `tasks/APPLE_BATCH.md` (the stage 4 checkout-card residual: «Fixed in stage 18: … (`DL-137` (11))»)
- Test: create `frontend/test/features/addresses/application/address_removals_test.dart`; modify `frontend/test/features/addresses/application/delivery_address_test.dart`, `frontend/test/features/checkout/presentation/checkout_sections_test.dart`

**Interfaces:**
- Produces:
  - `String get name` on `Address`.
  - `final class AddressRemoval { AddressRemoval(Address address); final Address address; }` — account, build, undone flag and its one send kept privately, as `FavoriteRemoval` does.
  - `final class AddressRemovalsState { const AddressRemovalsState({AddressRemoval? held, Set<String> hidden = const <String>{}, ({String id, ApiFailure failure})? notRemoved}); }` — `hidden` holds the held id, the ids being sent and those the server removed.
  - `class AddressRemovals extends Notifier<AddressRemovalsState>` with `void hold(AddressRemoval removal, {required VoidCallback closeBar})` (sends the held one at once and calls its `closeBar`; clears `notRemoved`), `bool undo(AddressRemoval removal)` (true only when it brought the address back), `Future<ApiFailure?> commit(AddressRemoval removal)` (one send however often asked; `null` when sent, undone or not this account's), `Future<void> flush()` (sends the held one, ends its bar, awaits every send). `build()` watches `customerAccountProvider`; `ref.onDispose` ends the held bar; an `AppLifecycleListener(onHide: flush)` lives with the build.
  - `final NotifierProvider<AddressRemovals, AddressRemovalsState> addressRemovalsProvider` (kept alive).
  - `final Provider<AsyncValue<List<Address>>> shownAddressesProvider` (autoDispose): `addressesProvider` without `hidden`, keeping its loading and error flags and its previous value.
  - `CheckoutDeliveryCard({…, bool listFailed = false})`.

- [ ] **Step 1: Write the failing tests** (`address_removals_test.dart`, a `ProviderContainer` over `FakeAddressesRepository` with three addresses, newest first, and a signed-in Customer):
  - `'a held address is off the shown list and the delivery address at once'`.
  - `'undo brings it back and sends nothing'` — `undo` answers true; `removed` empty after `commit`.
  - `'the bar's end sends one delete and keeps it hidden'` — with `hold` set on the fake: hidden while sending; after the answer still hidden, the list reloaded without it, `removed == [id]`; a second `commit` sends nothing.
  - `'a second hold sends the first at once and ends its bar'` — the first's `closeBar` called, one `DELETE` each (Review Focus 2).
  - `'undo after the send brings nothing back'` — `undo` answers false, the address stays hidden (Review Focus 3).
  - `'a lost delete brings the address back with why'` — `NetworkFailure`: shown again at its place, `notRemoved == (id, NetworkFailure)`, `commit` answers the failure; the next `hold` clears `notRemoved`.
  - `'an address already gone counts as removed'` — `ApiRefusal` 404 `resource_not_found`: hidden, `notRemoved` null, `commit` answers null.
  - `'a removal held when the account changes is dropped unsent'` — switch the account: its `closeBar` called, `commit` sends nothing, the new state's `hidden` is empty (Review Focus 1).
  - `'an answer for the previous account changes nothing'` — switch while the send waits on `hold`; then fail it: the new account's state has no `notRemoved` and no hidden id.
  - `'hiding the app sends the held removal'` — `handleAppLifecycleStateChanged(AppLifecycleState.hidden)`: one `DELETE`, `closeBar` called.
  - `'undoing the delivery address's removal makes it the delivery address again'` (in `delivery_address_test.dart`) — choice `a-2` held: delivery is the newest other; `undo`: delivery is `a-2`; held and sent: the newest other (Review Focus 4).
  - `'a reload keeps its loading flag and the list without the held address'` — `invalidate(addressesProvider)` under `loadHold`: `shownAddressesProvider` is loading with the previous list minus the held id.
  - `'a list that failed says so on the address card'` (`checkout_sections_test.dart`) — `listFailed: true`, `address: null`: «Адрес не загрузился — повторить» and the link «Повторить».
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement** the files listed; checkout passes `listFailed: addresses.hasError && !addresses.hasValue`.
- [ ] **Step 4: Run** the new tests, `test/features/addresses/` and `test/features/checkout/` — all pass.
- [ ] **Step 5: Commit** — `feat(addresses): a removal waits for its bar and hides the address everywhere (DL-137)`.

### Task 3: The card and the menu

**Files:**
- Create: `frontend/lib/features/addresses/presentation/address_card.dart`
- Modify: `frontend/lib/core/localization/l10n/app_ru.arb`, `app_uz.arb` (the card, menu and list strings), regenerate
- Test: create `frontend/test/features/addresses/presentation/address_card_test.dart`

**Interfaces:**
- Consumes: `Address.name` (Task 2).
- Produces:
  - `AddressListCard({required Address address, required bool delivery, required VoidCallback onEdit, required VoidCallback? onChoose, required VoidCallback onDelete, ApiFailure? notRemoved, int glow = 0, Key? key})` — the card face (Global Constraints, «Drawing»), its one semantics node (`addr-9`), its menu; the chip pops when `delivery` turns true after the first build; the card glows each time `glow` grows, and on its first build when `glow > 0`. Key of the tappable face: `address-card-<id>`.
  - `AddressMenuButton({required Address address, required String keyPrefix, required VoidCallback onEdit, required VoidCallback onDelete, VoidCallback? onChoose, Key? key})` — keys `<keyPrefix>-menu-<id>`, `<keyPrefix>-edit-<id>`, `<keyPrefix>-choose-<id>`, `<keyPrefix>-delete-<id>`; tooltip and label `addressActionsSpoken(name)`.

- [ ] **Step 1: Write the failing tests:**
  - `'a labelled card shows the line with the flat and the landmark'` — «Дом», «Navoiy ko'chasi, 12, кв. 5», «Ориентир: Напротив школы № 64»; title 15 w700 `ink`, line 13 `ink2`, landmark 12 `muted`.
  - `'an unlabelled card is named by its street and shows the flat under it'` — «Bobur ko'chasi, 7» over «кв. 3»; without a flat, nothing under it.
  - `'the icon follows the label'` — «Дом»/«Uy» `Icons.home_outlined`, «Работа»/«Ish» `Icons.work_outline`, «Мама» and none `Icons.location_on_outlined`; the lead 44 × 44 on `primaryWash`.
  - `'the delivery card has a green ring and Доставка сюда'` — a 1.5 `primary` border and the chip; another card has neither.
  - `'the chip pops when the card becomes the delivery address'` — rebuilt with `delivery: true`: scale above 1.05 at 120 ms, 1 at 340 ms; no pop on a first build nor with reduced motion.
  - `'a card is one stop with its actions'` (**repro** `addr-9`) — the face's node: label «Дом, доставка сюда, Navoiy ko'chasi, 12, кв. 5, Ориентир: Напротив школы № 64», a button, tap hint «изменить», custom actions [«Удалить»]; a non-delivery card [«Удалить», «Доставлять сюда»]; no other node inside the face; «⋯» is «Действия: Дом».
  - `'the menu offers edit, deliver here and a red delete'` — the three items in this order, 44 high, «Удалить» and its icon `danger`; no «Доставлять сюда» on the delivery card or without `onChoose`; each item calls its callback.
  - `'a failed removal says why on the card'` — `NetworkFailure`: «Нет связи — адрес не удалён» 13 w600 `danger`, also at the end of the stop's label; another failure: «Не удалось удалить адрес».
  - `'the glow plays once when asked'` — glow 0 → 1: the glow layer's opacity 0 at 150 ms, ≈ 1 at 200 + 400 ms, 0 after 1800 ms; with reduced motion it starts at once.
  - `'large text keeps the card whole'` — `NonlinearTextScaler(2)`, 360 wide: no overflow; `meetsGuideline(iOSTapTargetGuideline)`, also with the menu open.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement** `address_card.dart` and the strings.
- [ ] **Step 4: Run** the card tests — all pass.
- [ ] **Step 5: Commit** — `feat(addresses): the address card says the flat, the landmark and where delivery goes (DL-137)`.

### Task 4: The list screen

**Files:**
- Create: `frontend/lib/features/addresses/presentation/addresses_list_screen.dart` (`AddressesScreen` moves here from `addresses_screens.dart`; `addresses_routes.dart` imports it)
- Modify: `frontend/lib/core/widgets/kit/kit_empty_state.dart` (`quiet`, `actionIcon`)
- Test: create `frontend/test/features/addresses/addresses_list_screen_test.dart`; modify `frontend/test/core/widgets/kit/kit_empty_state_test.dart`; the list tests of `customer_account_screens_test.dart` that pin the old faces move here, rewritten

**Interfaces:**
- Consumes: `shownAddressesProvider`, `deliveryAddressProvider`, `deliveryAddressChoiceProvider`, `addressRemovalsProvider` (`notRemoved`, `hidden`) (Task 2); `AddressListCard` (Task 3).
- Produces: `AddressesScreen` as a `ConsumerStatefulWidget` (Tasks 5 and 6 add to its state); the cards in a `FoldingColumn<Address>` keyed by id inside the list's scroll view (key `addresses-list`); skeleton cards keyed `address-skeleton`; `KitEmptyState({…, bool quiet = false, IconData? actionIcon})`.

- [ ] **Step 1: Write the failing tests:**
  - `'the list is the kit: white bar, cards, a full-width add button'` — the bar's title centred; white page; no `FloatingActionButton`; `address-new` 54 high and the screen's width − 40 wide.
  - `'loading shows three skeleton cards and the add button works'` (**repro** `addr-6`) — under `loadHold`: three `address-skeleton`, no `CircularProgressIndicator`, one node «Загружаем адреса»; a tap on `address-new` opens the form.
  - `'the cards fade in where the skeleton stood'` — opacity between 0 and 1 at 130 ms, 1 at 260 ms; with reduced motion 1 at once.
  - `'a failed load shows the kit block with a green retry'` (**repro** `addr-6`) — «Не удалось загрузить адреса» and «Проверьте интернет и нажмите «Повторить».» for a `NetworkFailure` (`addressesFailedOther` otherwise); «Повторить» a `primary` filled button with `Icons.refresh`; its tap shows the skeleton, then the cards.
  - `'no addresses: a pin, why, one add button'` — `addressNone`, `addressesEmptyText`, exactly one `address-new`, no footer.
  - `'opened from the profile the list shows at once'` — through the profile row: cards on the first frame after the push, no skeleton.
  - `'Доставлять сюда moves the mark with a light tap'` — menu → «Доставлять сюда» on «Мама»: the chip on «Мама», `HapticFeedbackType.lightImpact` sent, announcement «Доставка: «Мама»», the stored choice is «Мама»'s id.
  - `'tapping a card opens its edit'`.
  - `'every face fits at large text and meets the tap target guideline'` — 360 × 640, `NonlinearTextScaler(2)`: loaded, loading, failed, empty.
  - `kit_empty_state_test.dart`: `'the quiet face is grey and the button can carry an icon'` — circle `chip`, icon `muted`, `Icons.refresh` before the label; the defaults unchanged.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement** the screen. Until Task 5 the menu's «Удалить» opens the old question and `addressListActionsProvider.remove`, so `'removing an address asks first'` and the remove part of `'a failure shows where it happened and nowhere else'` only change their finders (`address-menu-a-1` → `address-delete-a-1` instead of the trash) and keep their expectations; Task 5 rewrites them.
- [ ] **Step 4: Run** the new tests and `test/features/addresses/` — all pass.
- [ ] **Step 5: Commit** — `feat(addresses): the address list in the kit with skeletons, a kit failure and an empty state (DL-137)`.

### Task 5: Deletion on the list

**Files:**
- Create: `frontend/lib/features/addresses/presentation/address_removal_flow.dart`
- Modify: `frontend/lib/features/addresses/presentation/addresses_list_screen.dart`, the removal strings in both ARBs, regenerate
- Test: `frontend/test/features/addresses/addresses_list_screen_test.dart`; in `customer_account_screens_test.dart` `'removing an address asks first'` gives way to the tests below and the remove part of `'a failure shows where it happened and nowhere else'` checks the card's red line (and that the form never shows it)

**Interfaces:**
- Consumes: `AddressRemovals` (Task 2), `SwipeToRemove` reveal mode (Task 1), `AddressListCard` (Task 3).
- Produces:
  - `const Duration addressUndoDuration = Duration(seconds: 5);`
  - `abstract interface class UndoOffer { Future<void> show({required String text, required VoidCallback onUndo}); void close(); }` — `show` completes when the bar has ended, however it ended.
  - `final class ScreenUndoOffer implements UndoOffer { ScreenUndoOffer(ScaffoldMessengerState messenger); }` — `showUndoBar(…, duration: addressUndoDuration)`.
  - `Future<void> removeAddress(BuildContext context, {required ProviderContainer container, required Address address, required UndoOffer offer, ValueChanged<String>? onRestored})` — holds the removal (the bar's text and spoken words name where delivery goes when it was the delivery address, from `deliveryAddressProvider` after the hold), offers «Вернуть» (undo → `onRestored(id)` and «Адрес «…» возвращён»), announces the removal, and when the bar ends commits and announces a failure while `context` is mounted.
- The list wires the menu's «Удалить», the card's reader action and the swipe (`reveal: true`, `radius: 16`, `semanticsAction: false`, `removing:` the id is hidden) to `removeAddress`; it keeps one revealed card (`String? _revealed`), closed by a tap elsewhere, the menu opening and a scroll start; `onRestored` asks the card to glow.

- [ ] **Step 1: Write the failing tests:**
  - `'removing folds the card and offers Вернуть for 5 s'` — menu → «Удалить» on «Работа»: the card gone after 260 ms; the bar «Удалили «Работа».» with «Вернуть»; `removed` empty at 4.9 s, `['a-work']` after 5 s.
  - `'Вернуть brings the card back, glowing, and sends nothing'` — announcement «Адрес «Работа» возвращён»; the card's glow plays; `removed` empty after 6 s.
  - `'removing the delivery address says where delivery goes now'` — bar «Удалили «Дом». Доставка теперь: «Мама».», the chip on «Мама» (the newest left); spoken «Адрес «Дом» удалён. Доставка теперь: «Мама». Вернуть — кнопка внизу.»
  - `'offline the card returns and says it was not removed'` — `removeFailure = NetworkFailure()`: after 5 s the card unfolds at its place with «Нет связи — адрес не удалён»; announcement «Нет связи, адрес «Работа» не удалён».
  - `'a long swipe removes, a medium one reveals Удалить'` — the revealed button removes like the menu.
  - `'revealing a card closes the one open'` — and the menu opening closes it, and a scroll does (Review Focus 5).
  - `'a second removal sends the first at once'` — one `DELETE` each; «Вернуть» on the second bar brings back only the second (Review Focus 2).
  - `'the reader's Удалить removes and is announced'` (**repro** `addr-9`) — `performAction` of the custom action «Удалить» on the card's node: announcement «Адрес «Работа» удалён. Вернуть — кнопка внизу.»
  - `'leaving the screen keeps the bar and the removal'` — back to the profile during the bar: after 5 s the `DELETE` is sent and the profile row no longer shows «Работа» if it was the delivery address.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement** the flow and the wiring.
- [ ] **Step 4: Run** the list tests and `test/features/addresses/` — all pass.
- [ ] **Step 5: Commit** — `feat(addresses): an address is removed at once with Вернуть and sent when the bar ends (DL-137)`.

### Task 6: A saved address is named and shown

**Files:**
- Modify: `frontend/lib/features/addresses/presentation/addresses_screens.dart` (`_submit`), `frontend/lib/features/addresses/presentation/addresses_list_screen.dart`, the save strings in both ARBs, regenerate
- Test: `frontend/test/features/addresses/addresses_list_screen_test.dart`, `frontend/test/features/addresses/customer_account_screens_test.dart` (bar texts that read «Адрес сохранён»)

**Interfaces:**
- Consumes: `AddressListCard.glow` (Task 3).
- Produces: the form's bar is `addressAdded(saved.name)` for a new address and `addressSavedNamed(saved.name)` for an edit; the form pops `saved` for both (an unchanged edit still says «Нет изменений» and pops nothing). The list awaits `push<Address>` from the footer, the empty state's button and a card's edit; a new address scrolls the list to the top; the result's card glows once it is in the list (a new one unfolds by `FoldingColumn` first).

- [ ] **Step 1: Write the failing tests:**
  - `'a new address unfolds at the top and glows; the bar names it'` — list scrolled down; save «Сестра»: offset 0, «Сестра» first, its glow plays, bar «Адрес «Сестра» добавлен».
  - `'an edited address glows and the bar names it'` — the last card, edited from below the fold: it is in view after 300 ms, glows, bar «Адрес «Работа» сохранён».
  - `'the glow waits for a list that reloads late'` — `loadHold` on the reload after the save: no glow until the reload answers, then one glow.
  - `'a new address from the home still becomes the delivery address'` — the `DL-75` path through `addDeliveryAddress` still chooses it, its bar names it.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement** the form's bar and pop, and the list's await, scroll and glow.
- [ ] **Step 4: Run** `test/features/addresses/` and `test/features/checkout/` — all pass.
- [ ] **Step 5: Commit** — `feat(addresses): a saved address is named in its bar and glows in the list (DL-137)`.

### Task 7: The home sheet deletes the same way

**Files:**
- Modify: `frontend/lib/core/widgets/undo_bar.dart` (`InlineUndoBar`), `frontend/lib/features/addresses/presentation/delivery_address_widgets.dart`, `frontend/lib/features/addresses/application/addresses_controllers.dart` (`AddressListActions` and `addressListActionsProvider` go), both ARBs (`addressRemoveConfirm`, `addressSaved` go if unused), regenerate
- Test: `frontend/test/core/widgets/undo_bar_test.dart`, `frontend/test/features/addresses/delivery_address_sheet_test.dart` (the three ask-first tests rewritten)

**Interfaces:**
- Consumes: `removeAddress`, `UndoOffer`, `addressUndoDuration` (Task 5); `AddressMenuButton` (Task 3).
- Produces: `InlineUndoBar({required String text, required String actionLabel, required VoidCallback onUndo, required VoidCallback onEnded, required Duration duration, Key? key})` (core knows no feature constant; the sheet passes `addressUndoDuration`) — the undo bar's look (`_UndoContent` shared), ends after `duration` (not while a screen reader is on), on «Вернуть» after `onUndo`, and when removed from the tree; `onEnded` runs once. The sheet's own `UndoOffer` shows it between the cards and «Добавить новый адрес»; the sheet's cards stand in a `FoldingColumn`, use `AddressMenuButton(keyPrefix: 'delivery-address')` without «Доставлять сюда», and show the red line of `notRemoved`.

- [ ] **Step 1: Write the failing tests:**
  - `undo_bar_test.dart`: `'an inline bar ends after its time, on Вернуть and when removed, once each'`; `'an inline bar stays while a screen reader is on'`.
  - `'delete folds the card at once and offers Вернуть in the sheet'` — no dialog; the card folds; the bar inside the sheet; `removed` empty until 5 s, then one `DELETE`; the sheet stays open.
  - `'Вернуть in the sheet brings the card back and sends nothing'`.
  - `'closing the sheet ends the bar and sends the removal'`.
  - `'offline the card returns in the sheet with why'` — «Нет связи — адрес не удалён» on the card.
  - `'deleting the chosen address moves the radio to the newest'` — and «Вернуть» moves it back.
  - `'the sheet's menu has icons and no Доставлять сюда'`.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement**; remove `AddressListActions`, `addressListActionsProvider` and the unused strings.
- [ ] **Step 4: Run** `test/features/addresses/`, `test/features/catalog/`, `test/features/cart/`, `test/features/checkout/`, `test/core/` (`--concurrency=1`) — all pass; `flutter analyze` clean; `dart format --set-exit-if-changed lib test` clean.
- [ ] **Step 5: Commit** — `feat(addresses): the home's address sheet removes at once with its own Вернуть (DL-137)`.

### After the tasks (the lead)

- [ ] The full frontend suite through `test-runner`; the final `branch-reviewer` (opus) with this plan, BASE `2737186` (the branch's start, PR #140's head), the ledger and the generated localizations to skip; one fix dispatch; a scoped re-review; residuals parked in APPLE_BATCH with a ruling.
- [ ] `/security-review`; merge `main` into the branch if PR #140 landed meanwhile; push, pull request, both required checks green, merge.
