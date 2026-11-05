# Apple Stage 13 — «Изменение заказа» Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The order's editor shows what the Customer will pay before saving — delivery, fee and «Итого ≈ …» in the list and over the button with «+8 000 сум» and «Было ≈ 91 000», all from a server preview of the edit — and says at once when the goods fall short of the minimum («До минимальной суммы 50 000 сум не хватает 41 000 сум · Добавить», the button grey «Не хватает 41 000 сум»). × and system back with changes ask «Выйти без сохранения?» with the list of changes. The picker stays open: its plus becomes a stepper in the row, a bar says «Добавлено: 2 товара · ≈ … · Готово», sections are photo tiles with «‹ Все разделы · Овощи». A removed line folds to «Лепёшка — убрали из заказа · Вернуть»; new lines scroll into view, unfold and flash green; sums roll; light haptics. Each line has a «Комментарий · замена похожим» row; its sheet has × «Отмена» and «Готово». The button says «Нет изменений» / «Сохранить изменения (3)» / «Сохраняем…» / ✓ «Сохранено», and the order page shows «Заказ изменён · Итого ≈ …» for 4 s. With a Shopper assigned an amber note says to save at once; a refusal because shopping started shows what did not save, «Позвонить в поддержку» and «Открыть заказ». A product no longer sold is framed red with «Убрать» in its line and in a footer strip, the button grey until it goes. Large text stacks sum and stepper, wraps the picker's prices and puts the tiles in one column; a screen reader hears «Лепёшка — убрали из заказа», named actions and every change with the new total.

**Architecture:** The server gains `POST /customer/orders/{order}/items/preview`: the edit's own plan, under the same checks and refusals, priced without a lock or a write, answering the order's new sums, the change from now and the minimum's shortfall. On the client the editor's draft moves out of the screen into `orderDraftProvider(orderId)`, shared by the editor and the picker, and a second notifier asks the preview 400 ms after each change of the lines (one request at a time, the latest wins). The editor and the picker are redrawn on that state; the order page shows the success banner when the editor returns the saved order.

**Tech Stack:** Laravel 13 + PostgreSQL, Flutter 3.47.5, flutter_riverpod 3.4.3, go_router 18.1.2; core `Fold`/`FoldingColumn`, `SoftChange`, `announce`, `textWidth`/`textScaleAt`, `PressScale`, `CategoryPictureWell`; orders `LineFlash`; cart `CartLineStepper`, `FooterTotal`; catalog `ProductList`, `showQuantitySheet`; `HapticFeedback`; flutter_test (`tester.takeAnnouncements()`, `meetsGuideline(iOSTapTargetGuideline)`, `NonlinearTextScaler`, the `SystemChannels.platform` mock for haptics).

**Spec:** `tasks/APPLE_BATCH.md` stage 13 (`edit-1` **server**, `edit-2` **server**, `edit-3` **repro**, `edit-4` … `edit-8`, `edit-9` **repro**, `edit-10`, `edit-11` **repro**, `edit-12` **repro**); the live test «Тест изменения заказа - Apple» in Claude Design, local copy `G:/tools/tmp/w-edit/site/edit.html` (published bytes equal it) — CSS at lines 14–262, template 264–480, script: `changes`, `stepLine`, `removeLine`, `undoLine`, `openOpts`/`closeSheet`, `pickNew`/`pickStep`/`leavePick`, `arrive`, `collapse`, `morph`, `rolls`, `saveBlock`/`save`/`answer`/`locked`, `close`/`exitKeep`/`exitLeave`, `stops`, `infoText`, `saveVals`, `itemVals`, `renderVals` — it rules wherever this plan is silent; the review's memory note (2026-10-28); `DL-43`, `DL-51` (4)–(5), `DL-52`, `DL-119` (4), `DL-126`, `DL-130`, `DL-131` (9); `docs/03-features.md` §11, `docs/09-api-contracts.md` §21; `frontend/AGENTS.md`, `backend/AGENTS.md`.

## Global Constraints

- Changes stay in `backend/`, `frontend/`, `docs/` and `tasks/`. No package, no lockfile change, no migration. Generated localizations come from `flutter gen-l10n`, never by hand.
- New strings (ru / uz); the Russian wording is the page's, made gender-free where the page agrees a word with the product («убрана/убран» → «убрали», «добавлена» → «Добавили:», «закончилась» → «нет в продаже»), since a product's grammatical gender is not known (`DL-132` (7)):
  - Editor: `orderEditInfoAssigned` «Сборщик уже назначен и скоро начнёт покупать — после этого заказ не изменить. Сохраните изменения сразу. Цена товаров, что уже в заказе, не меняется.» / «Yig'uvchi tayinlangan va tez orada xarid qilishni boshlaydi — shundan keyin buyurtmani o'zgartirib bo'lmaydi. O'zgarishlarni darhol saqlang. Buyurtmadagi mahsulotlar narxi o'zgarmaydi.»; `orderEditCloseSpoken` «Закрыть изменение заказа» / «Buyurtmani o'zgartirishni yopish»; `orderEditComment` «Комментарий» / «Izoh»; `orderEditOptions` «{note} · {rule}» (both); `orderEditOptionsSpoken` «Комментарий и замена: {value}» / «Izoh va almashtirish: {value}»; `substitutionShortSimilar` «замена похожим» / «o'xshashiga almashtirish», `substitutionShortContact` «позвонить перед заменой» / «almashtirishdan oldin qo'ng'iroq», `substitutionShortRemove` «нет — убрать» / «yo'q bo'lsa — olib tashlash»; `orderEditRemoved` «{name} — убрали из заказа» / «{name} — buyurtmadan olib tashlandi»; `orderEditRestored` «{name} снова в заказе» / «{name} yana buyurtmada»; `orderEditLineSpoken` «{name}, {quantity}, {sum}» (both); `orderEditLineNewSpoken` «{name}, новый товар по текущей цене, {quantity}, {sum}» / «{name}, joriy narxdagi yangi mahsulot, {quantity}, {sum}»; `orderEditTotalSpoken` «{what}. Итого {amount}» / «{what}. Jami {amount}».
  - Sums: `orderEditWasSame` «Было {amount} · доставка и сбор те же» / «Avval {amount} edi · yetkazish va xizmat haqi o'zgarmadi»; `orderEditWas` «Было {amount}» / «Avval {amount} edi»; `orderEditFeesIncluded` «Доставка {delivery} и сбор {fee} включены» / «Yetkazish {delivery} va xizmat haqi {fee} kiritilgan»; `orderEditMinimum` «До минимальной суммы {minimum} не хватает {shortfall}» / «{minimum} minimal summagacha {shortfall} yetmayapti»; `orderEditAdd` «Добавить» / «Qo'shish»; `orderEditGone` «{names}: нет в продаже — уберите, чтобы сохранить» / «{names}: sotuvda yo'q — saqlash uchun olib tashlang»; `orderEditRemoveShort` «Убрать» / «Olib tashlash».
  - Button: `orderEditNoChanges` «Нет изменений» / «O'zgarish yo'q»; `orderEditSaveChanges` «Сохранить изменения ({count})» / «O'zgarishlarni saqlash ({count})»; `orderEditSavingBusy` «Сохраняем…» / «Saqlanmoqda…»; `orderEditSaved` «Сохранено» / «Saqlandi»; `orderEditShortfall` «Не хватает {amount}» / «{amount} yetmayapti»; `orderEditRemoveFirst` «Сначала уберите: {name}» / «Avval olib tashlang: {name}»; `orderEditRemoveFirstMore` «Сначала уберите: {name} и ещё {count}» / «Avval olib tashlang: {name} va yana {count} ta»; `orderEditKeepOne` «Оставьте хотя бы один товар» / «Kamida bitta mahsulot qoldiring».
  - After saving: `orderEditedTitle` «Заказ изменён» / «Buyurtma o'zgartirildi»; `orderEditedTotal` «Итого {amount}» / «Jami {amount}»; `orderEditedSpoken` «Заказ изменён. Итого {amount}» / «Buyurtma o'zgartirildi. Jami {amount}»; `orderEditNotSaved` «Не сохранено. {what}» / «Saqlanmadi. {what}».
  - Leaving: `orderEditLeaveTitle` «Выйти без сохранения?» / «Saqlamasdan chiqasizmi?»; `orderEditLeaveCount` plural «Не сохранится {count} изменение:» / «Не сохранятся {count} изменения:» / «Не сохранятся {count} изменений:» / «{count} ta o'zgarish saqlanmaydi:»; `orderEditKeepEditing` «Продолжить изменять» / «O'zgartirishni davom ettirish»; `orderEditLeave` «Выйти без сохранения» / «Saqlamasdan chiqish».
  - Changes: `orderChangeAdded` «+ {name}, {quantity}»; `orderChangeRemoved` «− {name}»; `orderChangeQuantity` «{name}: {from} → {to}» (these three both); `orderChangeNote` «{name}: комментарий «{note}»» / «{name}: izoh «{note}»»; `orderChangeNoNote` «{name}: без комментария» / «{name}: izohsiz»; `orderChangeRule` «{name}: {rule}» (both; the rule's `OrderLabels.substitution` text with a lower-case first letter); `orderChangeWish` «Пожелание к доставке: «{wish}»» / «Yetkazish istagi: «{wish}»»; `orderChangeNoWish` «Пожелание к доставке убрано» / «Yetkazish istagi olib tashlandi».
  - Lock: `orderEditLockedTitle` «Сборщик уже начал покупать» / «Yig'uvchi xarid qilishni boshladi»; `orderEditLockedCancelled` «Заказ отменён» / «Buyurtma bekor qilindi»; `orderEditLockedText` «Изменения не сохранились — заказ остался прежним. Если что-то важно, позвоните в поддержку.» / «O'zgarishlar saqlanmadi — buyurtma avvalgidek qoldi. Muhim narsa bo'lsa, qo'llab-quvvatlash xizmatiga qo'ng'iroq qiling.»; `orderEditLockedTextNoPhone` «Изменения не сохранились — заказ остался прежним.» / «O'zgarishlar saqlanmadi — buyurtma avvalgidek qoldi.»; `orderEditLost` «Что не сохранилось» / «Nima saqlanmadi»; `orderCallSupport` «Позвонить в поддержку» / «Qo'llab-quvvatlashga qo'ng'iroq qilish»; `orderEditLockedSpoken` «Не сохранено: {title}. Не сохранилось изменений: {count}» / «Saqlanmadi: {title}. Saqlanmagan o'zgarishlar: {count}».
  - Picker: `orderPickAllSections` «Все разделы» / «Barcha bo'limlar»; `orderPickSection` «{name}, раздел» / «{name}, bo'lim»; `orderPickAlreadyIn` «Уже в заказе» / «Buyurtmada bor»; `orderPickAddedNow` «Добавлен сейчас» / «Hozir qo'shildi»; `orderPickAdd` «Добавить: {name}» / «Qo'shish: {name}»; `orderPickRowSpoken` «{name}, {price} за {unit}» / «{name}, {unit} uchun {price}»; `orderPickInOrderSpoken` «{name}, в заказе {quantity}» / «{name}, buyurtmada {quantity}»; `orderPickAdded` plural «Добавлено: {count} товар / товара / товаров» / «Qo'shildi: {count} ta mahsulot»; `orderPickAddedSpoken` «Добавили: {name}, {quantity}. Добавлено товаров: {count}» / «Qo'shildi: {name}, {quantity}. Qo'shilgan mahsulotlar: {count}».
  - Reused: `orderEditKitTitle`, `orderEditInfo`, `orderEditNew`, `orderEditRecount` (now the line shown when the sums cannot be had before saving), `orderEditRemoveLine`, `orderEditKeepLine`, `orderEditClosed`, `orderAddProduct`, `orderAddTitle`, `orderAddFull`, `orderOpen`, `cartGoods`, `cartDelivery`, `cartServiceFee`, `cartTotal`, `cartLineEstimate`, `cartStepMinus`, `cartStepPlus`, `cartLineUnavailable`, `cancelButton`, `doneButton`, `checkoutWishLabel`, `catalogSearchHint`, `catalogSearchClear`, `catalogPerUnit`, `catalogNoProducts`, `callFailed`, `OrderLabels.substitution`, `CatalogLabels.unit`. Removed when no longer used: `orderAddAlreadyIn`, `orderPickInOrder`, `orderEditAtLeastOne`, `orderEditSaving`.
- New colour token `KitColors.buttonOff = Color(0xFFE3E6E4)` (the page's grey button; its text `muted`).
- Motion, from the page (none of it with reduced motion, `MediaQuery.disableAnimationsOf`, unless said): a removed line's height goes to its compact row and back in 260 ms `Cubic(0.2, 0.8, 0.2, 1)` (`AnimatedSize`) — with reduced motion the new row fades from 0.35 in 220 ms `Curves.easeOut`; an added line dropped folds by `FoldingColumn` as built (260 ms); arriving lines unfold by `FoldingColumn` as built (300 ms, together — the page's 70 ms stagger is dropped, `DL-132` (6)) after a scroll that brings the first to a third of the view in 300 ms `Curves.easeInOut` (a jump with reduced motion), and `LineFlash` green as built (1400 ms); a sum rolls from the old to the new amount in 320 ms, ease-out cubic, the steps rounded to 100 and the last exact (at once with reduced motion); the picker's plus grows into its stepper from 44 to 124 wide in 260 ms `Cubic(0.2, 0.8, 0.2, 1)`, its contents fading in over 200 ms after 80 (a 180 ms fade with reduced motion); the picker's bar rises 16 px with a fade in 280 ms `Cubic(0.2, 0.8, 0.2, 1)` (a 200 ms fade with reduced motion); the save button's colours change over 250 ms `Curves.easeOut`; ✓ «Сохранено» stands 650 ms, then the editor returns; the order page's banner comes down from above in 420 ms `Cubic(0.2, 0.8, 0.2, 1)`, stays 4 s and goes up with a fade in 300 ms `Curves.easeIn` (fades 250 ms with reduced motion). Haptics (`HapticFeedback.lightImpact`) on a line's removal, a pick that adds and the save's success; they and announcements stay with reduced motion.
- Drawing, from the page. Info box: radius 14, padding 12, 13 px line 1.4 `ink2`; green: `primaryWash`, `Icons.info_outline` 18 `primaryDark`; amber: `warningWash`, `Icons.schedule` 18 `warningDark`. Line: 14 above and below, a bottom border `line`; picture box 56 radius 14 `card` with a 44 picture; name 14 w600, two lines; «Новый» 11 w600 `primaryDark` on `primaryWash`, radius 8, padding 2/8; price per unit 12 `muted`, one line; options row at least 44 high, 6 above, its start 68 in (0 at large text, where its text wraps), `Icons.edit_note` 18 and the text 13 w600 `primaryDark` with an ellipsis, `Icons.chevron_right` `muted` at the end; the sum 15 w700 `ink` beside the 132 × 44 stepper, 10 above. Compact removed row: at least 44 high, a 36 picture box radius 10 with a 28 grey picture at opacity 0.4, 10, the words 13 line 1.35 `muted` with the name w600 `ink2`, «Вернуть» 44 high, padding 0 16, radius 22, `primaryWash` ground, 14 w700 `primaryDark`. Marked line: a 1.5 px `danger` frame of radius 16 reaching 10 into the side padding, 4 above and below, 14/10 inside; in it, under the name, `Icons.error` 20 `danger`, the words 13 w600 `danger`, «Убрать» filled `danger` 44 high radius 12 14 w700. Totals in the list: a top border, 12 above; rows 14 `ink2` with the value w600 `ink`, 3 apart; «Итого» 16 w700 under a border, 6 above. Footer strips: radius 12, padding 6/6/6/12, 10 apart inside, 10 under; icon 20, words 13 line 1.35 `ink2`, the button white, at least 44 high, padding 0 14, radius 10, 14 w700; amber on `warningWash` with `Icons.info_outline` `warningDark`, red on `dangerWash` with `Icons.error` `danger`. Footer total: «Итого» 12 `muted` over the amount 19 w700 `ink`; the change pill padding 4/10 radius 10, 13 w700, `chip` ground and `ink` text when up, `primaryWash` and `primaryDark` when down; the «Было …» line 12 `muted`, 10 under. Button: at least 54, radius 14, 15 w600, `primary` / white; off: `buttonOff` / `muted`; busy: an 18 white spinner and the words, 10 apart; saved: `Icons.check` 20 and the words. Sheets: the title 18 w700 centred; the count line 14 `ink2` centred, 6/12; the list box `page` ground, radius 14, padding 10/14, items 14 `ink2` line 1.4, 4 apart; 18; the filled button 54; the red text button 48, 15 w600. Lock view: a 72 circle `warningWash` with `Icons.shopping_basket` 36 `warningDark`; the title 20 w700, 16 above; the words 14 `ink2` line 1.45, 8 above; «Что не сохранилось» 13 w700 `ink`, 22 above, 6 under, at the start; the list box as in the sheets; the footer's outlined «Позвонить в поддержку» (`Icons.call` 20, 1.5 px `primary`, `primaryDark` text) over the filled «Открыть заказ», 10 apart. Banner: 12 from the sides, 8 under the app bar, `primaryDark`, radius 16, padding 12/14, the kit shadow, `Icons.check_circle` 24, the title 15 w700 and the total 13 at alpha 0.92, white. Picker: the crumb row padding 0/20/6/10 — «‹ Все разделы» at least 44, `Icons.chevron_left` 22, 14 w600 `primaryDark` — then the section's name 16 w700 `ink` with an ellipsis; tiles in a grid of two, 12 apart, padding 8/20, each at least 118 high, padding 14, radius 18, `chip` ground, the name 14 w600 `ink` at the top start, the picture (`CategoryPictureWell` 60) at the bottom end; rows at least 76 high, padding 10/20, 12 apart, the picture box as the editor's, the price 14 w700 `ink`, «за кг» 12 `muted`, the tag «Уже в заказе» / «Добавлен сейчас» as «Новый», the row on `primaryWash` while the product is in the order; the plus a 44 circle `primary` with a white 22 icon; the stepper 124 × 44, radius 22, `primary` fill, two 44 white buttons (20 icons), the quantity 13 w700 white; the bar: a top border, padding 12/20/16, «Добавлено: 2 товара» 15 w700 `ink` over «≈ 20 000 сум» 13 `muted`, «Готово» filled 48 high, padding 0 22, radius 14.
- Large text: a layout rule reads `textScaleAt(scaler, fontSize)` at the size of the text it holds (`DL-126`). A line's sum stands over its stepper when `textWidth(sum) + 8 + 132` exceeds the line's width, the stepper then `min(180, width)` wide, as the cart's (`DL-119` (4)); above 1.3 at 13 px the options row starts at 0 and wraps; the picker's price wraps instead of shrinking, and above 1.3 at 13 px its stepper takes the row's width under it from 68; above 1.3 at 14 px the tiles stand in one column; above 1.3 at 13 px a strip's button goes under its words at the end. No `FittedBox` is left in the editor or the picker. Tests at large text use `NonlinearTextScaler(2)` on a 360 dp screen.
- Every state this stage draws — the editor with a new line, a removed line, a marked line, both strips, each button state; the line sheet; the exit sheet; the lock view; the picker's sections, a section, a search with plus and stepper rows, the bar; the order page with its banner — passes `meetsGuideline(iOSTapTargetGuideline)` at 100 % and at `NonlinearTextScaler(2)` (batch rule).
- Amounts are the server's (`AGENTS.md` §5): the order's sums (goods, delivery, fee, total, the change, the minimum and its shortfall) come only from the preview or the order; a line's sum stays the editor's own `EstimatePreview`, with «≈» for an estimate price, as before (`DL-52` (2)).
- Tests that pinned the old drawing (the struck-through removed line and its 40 px «Вернуть», the snack bar «уже в заказе», the picker closing on a pick, the ListTile sections and the category chip, the sheet's «Сохранить», the spinner without words, the silent success, the red refusal lines, the `FittedBox` sums) are rewritten to the new rule, each named in the task's report; no other test is deleted or weakened.
- Backend commands run as `docker compose -f docker/compose.yaml exec app …` from the repo root; never a destructive artisan command (`migrate:fresh`, `db:wipe`, `--env=testing` on the dev database). Flutter runs from PowerShell with `$env:TEMP='G:\tools\tmp'; $env:TMP='G:\tools\tmp'` and `G:\tools\flutter\bin\flutter.bat`; a full suite uses `--concurrency=2`. PHPUnit warnings fail CI: run the backend tests with `--fail-on-warning`.
- Comments read like the surrounding code: short `///` docs in plain English that name `DL-132`. A test's first run is red, and the report quotes the red line.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- `/security-review` once before the pull request: the branch adds a Customer endpoint over the Customer's own order.

## Review Focus

1. Quick taps: five steps within two seconds send one preview after the last pause (plus at most the one already in flight), and an answer for an older draft that lands after a newer one never shows. Task 3 tests `'one preview at a time, the latest draft wins'`, `'an older answer landing late is dropped'`.
2. Offline in the editor: the preview fails, the sums say «Доставку, сбор и итог пересчитаем после сохранения», no grey button is left standing on an old shortfall, and «Сохранить изменения (N)» still sends — the server judges. Task 3 test `'a failed preview clears the shortfall block'`; Task 5 test `'offline the footer says the totals come after saving and the save still goes'`.
3. A save whose answer was lost (`DL-52` (4)): the order loads again with what the server made; the count on the button, the exit sheet and the lock view compare the draft with that order, so an added product the server did add is no longer a change. Task 3 test `'changes compare with the order as last loaded'`.
4. Shopping starts while the Customer is in the picker: the preview answers `order_editing_locked`, the picker closes by itself, and the editor's place shows the lock view with everything that did not save. Task 7 test `'a lock found while the picker is open shows the lock view'`.
5. 200 % text on a 360 dp phone: stacked lines, the wrapping options row, both strips, the footer total with its change and «Было …», the exit sheet, the lock view, the picker's one-column tiles and full-width steppers: nothing overflows or shrinks, every target is 44. Tasks 4–7 large-text tests.

---

### Before the tasks (the lead)

- [x] **The test page.** Read 2026-11-05 from the local copy; this plan follows it.
- [ ] **Reproduce `edit-3`, `edit-9`, `edit-11`, `edit-12`.** The Owner dropped the emulator walks for stages 8–12 (2026-11-05); as in stages 11 and 12, the first red runs of the named tests on main's editor are the reproduction — Task 4 `'at large text a line keeps its sum whole over the stepper'` (`edit-11`) and `'a removed line reads as removed and offers Вернуть'` (`edit-12`), Task 6 `'with changes × asks before leaving'`, `'system back asks too'` (`edit-3`) and `'a refusal because shopping started shows what did not save'` (`edit-9`) — and `DL-132` (15) says so.

### Task 1: Server — the edit preview; the decision record

**Files:**
- Modify: `backend/app/Modules/Orders/Actions/EditOrderItems.php` (the plan made one private method both paths use; `preview()`), `backend/app/Modules/Orders/Http/Controllers/CustomerOrderController.php` (`previewItems`), `backend/routes/api/v1/orders.php`
- Create: `backend/app/Modules/Orders/EditPreview.php`, `backend/app/Modules/Orders/Http/Requests/PreviewOrderItemsRequest.php`, `backend/app/Modules/Orders/Http/Resources/EditPreviewResource.php`
- Modify: `docs/09-api-contracts.md` §21 and §53, `docs/DECISIONS.md` (new `DL-132`), `tasks/APPLE_BATCH.md` (stage 12's row «Merged (PR #134)», a Risks line)
- Test: create `backend/tests/Feature/Orders/EditOrderPreviewApiTest.php`; `EditAndCancelOrderApiTest.php` stays green unchanged

**Interfaces:**
- Produces: `POST /customer/orders/{order}/items/preview` with `{"items":[…]}` — the edit's `items` rules exactly (`PreviewOrderItemsRequest` shares them with `EditOrderItemsRequest`, without `delivery_time_note`, which the strict shape then refuses) — answering `200` `{"data":{"merchandise_subtotal_uzs","service_fee_uzs","delivery_fee_uzs","total_uzs","total_kind","total_before_uzs","total_change_uzs","minimum_order_uzs","minimum_order_shortfall_uzs"}}`: the plan's merchandise (lines kept at their snapshots, products added at the current price and markup), the service fee by the order's snapshotted rule on it (`OrderTotals::serviceFeeOn`), the delivery fee snapshot, their sum; `total_kind` `estimate` when any kept line's snapshot or any added product is an estimate, else `final`; `total_before_uzs` the order's total now (`OrderTotals::of`), `total_change_uzs` the difference (signed); `minimum_order_uzs` the current setting or `null`; `minimum_order_shortfall_uzs` `minimum − merchandise` exactly when the edit would be refused for it (the plan lowers the merchandise below the minimum), else `0`. Same scope-safe `404`, `409 order_editing_locked`, `409 product_unavailable` (`details.product_ids`), `422` as the edit, in the same order; never `minimum_order_not_reached`. Nothing is locked or written. Throttle `throttle:120,1,order-edit-preview`.
- `final readonly class EditPreview` (the fields above as `int`/`?int`/`string`); `EditOrderItems::preview(User $customer, string $orderId, array $items): EditPreview`.

- [ ] **Step 1: Write the failing tests** in `EditOrderPreviewApiTest`:
  - `test_the_preview_prices_the_list_without_writing`: a `shopping_assigned` order (not started) with tomatoes 2.5 kg at 14 000 and bread 3 at 3 000 (fixed fee 5 000, delivery 15 000), a product added at a market price that gives 8 000 now; the preview of tomatoes 3, bread dropped, the new product 1 → merchandise 50 000, fee 5 000, delivery 15 000, total 70 000, `total_before_uzs` 64 000, `total_change_uzs` 6 000; the items, the history and the order's `updated_at` unchanged.
  - `test_a_percent_service_fee_follows_the_previewed_goods`: a 5 % fee snapshot → the fee on the previewed merchandise, rounded as `ServiceFeeCalculator` rounds.
  - `test_the_shortfall_is_answered_only_for_an_edit_that_lowers_the_goods`: minimum raised after placement to above the order → an unchanged or raised list answers shortfall 0; a lowered list below it answers `minimum − merchandise`; minimum unset → `minimum_order_uzs` null and shortfall 0.
  - `test_an_estimate_line_makes_the_preview_an_estimate`: all fixed → `final`; an added estimate product → `estimate`.
  - `test_the_preview_is_refused_as_the_edit_is`: shopping started → `409 order_editing_locked`; a hidden added product → `409 product_unavailable` naming it; another Customer's order → `404`; a kg quantity with four decimals → `422` on `items.0.quantity`; `delivery_time_note` sent → `422`; a guest → `401`.
  - `test_the_preview_has_its_own_throttle`: 30 previews then an edit → the edit answers `200`; the 121st preview in a minute → `429 rate_limited`.
- [ ] **Step 2: Run them red:** `docker compose -f docker/compose.yaml exec app php artisan test --filter=EditOrderPreviewApiTest --fail-on-warning` — `404` on the missing route.
- [ ] **Step 3: Implement.** Move the plan of `edit()` (products to add, kept, added, removed, changed, before, after) into one private method returning its parts, so `edit()` keeps its exact behaviour; `preview()` finds the order with `ScopedLookup::firstOrNotFound` (no transaction, no lock), checks `OrderPermissions::canChange`, plans, prices. The route sits next to the edit's. Give the edit and the rating their own buckets too (`throttle:30,1,order-edit`, `throttle:30,1,order-rating`): Laravel keys a numeric throttle by the user alone, so today they share one, and the preview's would join it (`DL-132` (1)).
- [ ] **Step 4: Run green** (the filter above, then the whole `Orders` folder) and `vendor/bin/pint --test`, `vendor/bin/phpstan analyse`.
- [ ] **Step 5: Docs.** `docs/09` §21 gains the preview after the edit, with its body, answer, codes and throttle and `DL-132` (1)–(2); §53 unchanged (no new code). `tasks/APPLE_BATCH.md`: stage 12's row «Merged (PR #134)»; a Risks line — an editor of this build against an older server finds no preview (`404`) and shows «Доставку, сбор и итог пересчитаем после сохранения», so deploy the backend first. `DL-132` — «The Apple batch, stage 13: order editing (2026-11-05, agent)» — records, numbered:
  1. The edit preview as above: the edit's own plan and refusals, priced with no lock and no write; its own throttle bucket of 120 a minute, and the edit and the rating their own too, since Laravel's numeric throttles key by the user alone and so shared one bucket.
  2. The minimum comes with the preview, not on the order (`edit-2`): the order does not snapshot it and the rule depends on the edit (`DL-43` (3)), so the server answers the shortfall exactly when it would refuse.
  3. The editor's order sums (goods, delivery, fee, total, the change, «Было …») are the preview's, or the order's own while the lines are what the order holds; a line's sum stays the editor's `EstimatePreview` (`DL-52` (2)). The preview is asked 400 ms after the lines change, one at a time, the latest draft winning; while a newer draft waits, the last sums stand dimmed. A preview that fails, or a draft it cannot price (a quantity to set anew, no line kept, more than 100), shows «Доставку, сбор и итог пересчитаем после сохранения»; a shortfall greys the button only until the next answer, and a failure lifts it — the save still goes and the server judges.
  4. The draft moves from the editor's state into `orderDraftProvider(orderId)`, shared by the editor and the picker; the picker opened by its address alone goes to the editor (supersedes `DL-52` (1), last sentence).
  5. The picker stays open (`edit-4`, supersedes `DL-52` (1) "a pick closes" and (3) "told it is already there"): a pick adds the product and its plus becomes a stepper; a product already in the order shows its stepper and «Уже в заказе»; at the minimum the stepper's bin takes the line out (an added one is dropped).
  6. Lines added in the picker are held out of the editor's list until it shows again; then the first scrolls to a third of the view and they unfold together and flash green — the page's 70 ms stagger is dropped.
  7. The Russian words are gender-free («— убрали из заказа», «Добавили: …», «нет в продаже»): a product's grammatical gender is not known.
  8. `order_editing_locked` from a save or a preview shows the lock view with what did not save — titled «Заказ отменён» when the reloaded order is cancelled, else «Сборщик уже начал покупать»; «Позвонить в поддержку» only with a `support_phone`; without unsaved changes the plain «Этот заказ уже нельзя изменить» stays.
  9. The amber note stands while the order is `shopping_assigned`; a `new` order keeps the green one (`edit-9`).
  10. `product_unavailable` marks exactly the products the latest answer names (a preview's or a save's) and an accepted preview clears them (supersedes `DL-52` (6)'s "only when another edit is sent"); a save's refusal also scrolls to the first and flashes it red.
  11. A change is said when its preview answers, with the new total («Помидоры, 3 кг. Итого ≈ 98 000 сум»); of quick changes only the last is said; a failed preview says the change alone.
  12. Haptics: `lightImpact` on a removal, a pick that adds and the save's success.
  13. The picker's sections are the page's own tiles (name over picture, two to a row, one above 1.3 at 14 px), not the home's tile grid.
  14. At large text a line stacks as the cart's line does (`DL-119` (4)).
  15. How `edit-3`, `edit-9`, `edit-11`, `edit-12` were reproduced (filled in by the lead).
  16. The banner «Заказ изменён · Итого …» shows on the order page the editor was opened over; an editor opened by its address alone goes to the order without it.
- [ ] **Step 6: Commit** `feat(orders): the server previews an order edit's sums and the minimum's shortfall (DL-132)`.

### Task 2: Client data — the preview

**Files:**
- Modify: `frontend/lib/features/orders/domain/customer_orders.dart`, `frontend/lib/features/orders/data/customer_orders_api.dart` (API and repository), `frontend/test/support/fake_customer_orders_repository.dart`
- Test: `frontend/test/features/orders/data/customer_orders_api_test.dart`

**Interfaces:**
- Produces:
```dart
final class OrderEditPreview {
  const OrderEditPreview({required this.merchandiseSubtotalUzs, required this.serviceFeeUzs, required this.deliveryFeeUzs, required this.totalUzs, required this.totalKind, required this.totalBeforeUzs, required this.totalChangeUzs, required this.minimumOrderUzs, required this.minimumShortfallUzs});
  /// The order's own sums, as a preview of the lines it holds: no change, no shortfall.
  factory OrderEditPreview.ofOrder(CustomerOrder order);
  final int merchandiseSubtotalUzs, serviceFeeUzs, deliveryFeeUzs, totalUzs, totalBeforeUzs, totalChangeUzs, minimumShortfallUzs;
  final TotalKind totalKind;   // final or estimate
  final int? minimumOrderUzs;
}
// CustomerOrdersRepository
Future<OrderEditPreview> previewEdit(String id, List<OrderEditLine> lines);
```
- Fake: `previews` — a function `(String id, List<OrderEditLine> lines) → Map<String, Object?>` answering the preview's json (default: the order row's own totals with change 0 and shortfall 0), `previewFailure` (the next preview fails once), `holdPreview` (a `Completer<void>?`), and `previewCalls` recording each `(id, lines)`; `editPreviewJson({…})` builds the answer.

- [ ] **Step 1: Failing tests:** `'an edit preview sends the lines and reads its sums'` (a `POST` to `/customer/orders/<id>/items/preview` whose body has `items` only; every field read); `FormatException` for: a missing key; `total_kind` `none`; a negative shortfall; `total_uzs` not the sum of its three parts; `total_change_uzs` not `total_uzs − total_before_uzs`; a shortfall above 0 with `minimum_order_uzs` null. `OrderEditPreview.ofOrder` copies the order's totals with change 0.
- [ ] **Step 2: Run red:** `flutter test test/features/orders/data/customer_orders_api_test.dart`.
- [ ] **Step 3: Implement** the type, the strict parse (`JsonFields`), the API call (`options: _customer`, through `guardApiCall` in the repository), the fake's members.
- [ ] **Step 4: Run green**, then `test/features/orders/` whole.
- [ ] **Step 5: Commit** `feat(orders): read the order edit's preview (DL-132)`.

### Task 3: Client state — the shared draft and its preview

**Files:**
- Create: `frontend/lib/features/orders/application/order_draft.dart`, `frontend/lib/features/orders/application/order_edit_summary.dart`
- Modify: `frontend/lib/features/orders/presentation/order_line_sheet.dart` (imports `OrderLineChoice` from `order_draft.dart`, where the typedef moves)
- Test: create `frontend/test/features/orders/application/order_draft_test.dart`, `frontend/test/features/orders/application/order_edit_summary_test.dart`

**Interfaces:**
- Consumes: `OrderEditPreview`, `previewEdit` (Task 2).
- Produces:
```dart
typedef OrderLineChoice = ({String quantity, String? note, SubstitutionPolicy policy});

@immutable
final class DraftLine {            // what _LineDraft was, immutable
  final CustomerOrderLine? line;   // as the editor found it
  final CatalogProduct? product;   // a product this edit adds
  final String productId; final UnitCode unit;
  final String quantity;           // as the API takes it, '' when the unit no longer takes the line's own
  final String? note; final SubstitutionPolicy policy;
  final bool removed;              // an ordered line taken out (an added one is dropped instead)
  final bool unavailable;          // named by the latest product_unavailable
  String get key;                  // line?.id ?? 'added-$productId'
  bool get added;                  // line == null
  String name(AppLanguage language); String? get imageUrl; int get unitPriceUzs; PriceMode get priceMode;
  bool get quantityValid; int? get previewUzs;
  bool adds(CustomerOrder order);  // as before (DL-52 (4))
  OrderEditLine toEdit();
}

@immutable
final class OrderDraft {
  final List<DraftLine> lines;     // in order: the order's lines, then the products added
  final Set<String> arriving;      // keys added in the picker, held out of the editor's list
  final int version;               // bumps on every change of what the lines would send; marks and arrivals do not bump it
  List<DraftLine> get kept;        // not removed
  List<DraftLine> get marked;      // kept and unavailable
}

class OrderDraftController extends Notifier<OrderDraft> {
  OrderDraftController(this.orderId);
  // build(): seeded once from ref.read(customerOrderProvider(orderId)).value!.openLines; a reload never reseeds it
  void step(String key, {required bool up});            // CardQuantity next/previous; the minus at the minimum removes
  void setQuantity(String key, String quantity);
  void setOptions(String key, OrderLineChoice choice);
  void remove(String key);                              // ordered: removed; added: dropped (and out of arriving)
  void restore(String key);
  DraftLine add(CatalogProduct product, {bool arriving = false}); // a new line (1, no note, similar), or the product's line kept again; answers it
  void setUnavailable(Set<String> productIds);           // lower case; replaces the marks
  void removeMarked();                                   // the strip's «Убрать»
  List<String> settleArrivals();                         // the arriving keys still kept, in order; clears the set
}
final NotifierProviderFamily<OrderDraftController, OrderDraft, String> orderDraftProvider; // autoDispose

enum DraftChangeKind { added, removed, quantity, note, rule, wish }
typedef DraftChange = ({DraftChangeKind kind, String nameUz, String nameRu, UnitCode? unit, String? from, String? to, SubstitutionPolicy? rule});
List<DraftChange> draftChanges(OrderDraft draft, CustomerOrder order, String? wish); // wish trimmed like the server, null when empty
bool linesChange(OrderDraft draft, CustomerOrder order);

@immutable
final class EditSummary {
  final OrderEditPreview shown;    // the last answer, or OrderEditPreview.ofOrder while the lines are the order's
  final bool waiting;              // the lines changed since `shown`
  final bool failed;               // the last preview failed, or the draft cannot be priced
  final bool locked;               // the server answered order_editing_locked
  int get shortfallUzs;            // failed ? 0 : shown.minimumShortfallUzs
}
class OrderEditSummaryController extends Notifier<EditSummary> {
  OrderEditSummaryController(this.orderId);
  void refusedMinimum({required int minimumUzs, required int shortfallUzs}); // a save's minimum_order_not_reached
}
final NotifierProviderFamily<OrderEditSummaryController, EditSummary, String> orderEditSummaryProvider; // autoDispose
```
- `draftChanges` compares the kept lines with the order's open lines by lower-case product id, in the draft's order, then any open line the draft no longer keeps: kept and not open → `added` (quantity in `to`); open and not kept → `removed`; both → `quantity` (from the open line's normalised quantity to the draft's, skipped while the draft's is ''), `note` (`to` null when cleared), `rule`; then the wish when it differs from the order's (`to` null when cleared). Names are the line's snapshots, or the product's for an added one.
- The summary listens to `orderDraftProvider(orderId).select((d) => d.version)`. On a change: `waiting` at once; 400 ms after the last change: lines that are the order's → `shown` = `ofOrder(order as last loaded)`, nothing sent; a draft that cannot be priced → `failed`; else `previewEdit(orderId, kept.toEdit())` — one at a time, a change meanwhile sends the latest draft when the answer comes, and only the answer to the latest draft sent is shown; an answer after the account changed is dropped. `product_unavailable` → `setUnavailable(ids)` and `failed`; an accepted answer → `setUnavailable({})`; `order_editing_locked` → `locked` and the order and both order lists are invalidated; any other failure → `failed` (keeping `shown`).

- [ ] **Step 1: Failing tests.** Draft: `'a step, a removal and a restore change the lines and bump the version'`; `'the minus at the minimum removes an ordered line and drops an added one'`; `'adding a product already in the order keeps its line'` (a removed one comes back); `'lines added while arriving are held until settled'`; `'marks follow the latest answer and do not bump the version'`; `'changes list added, removed, quantity, note, rule and wish in order'` (the page's three: «+ Морковь», «− Лепёшка», «Помидоры: 2,5 кг → 3 кг» as typed records); `'changes compare with the order as last loaded'` (an added product the reloaded order holds is no change; its drop is). Summary: `'nothing changed sends nothing and shows the order\'s sums'`; `'a change waits 400 ms, then one preview'`; `'one preview at a time, the latest draft wins'` (five steps, a held answer: two calls in all, the shown one the last); `'an older answer landing late is dropped'`; `'a failed preview clears the shortfall block'`; `'product_unavailable marks the products and an accepted answer clears them'`; `'order_editing_locked locks and reloads the order'`; `'a draft with a quantity to set anew is not priced'`; `'a save\'s minimum refusal shows its shortfall until the next answer'`.
- [ ] **Step 2: Run red.**
- [ ] **Step 3: Implement.** Timers are cancelled on dispose; the generation is the draft's `version`.
- [ ] **Step 4: Run green**, then `flutter analyze`.
- [ ] **Step 5: Commit** `feat(orders): the editor's draft is shared state, previewed by the server as it changes (DL-132)`.

### Task 4: The editor's lines — rolling sums, the options row, the removed row, large text, the reader

**Files:**
- Create: `frontend/lib/core/widgets/rolling_amount.dart`, `frontend/lib/features/orders/presentation/order_edit_line.dart` (`_EditLine` out of the screen, public), `frontend/lib/features/orders/presentation/order_edit_words.dart` (`changeText`, `ruleShort`, the lines' spoken words)
- Modify: `order_edit_screen.dart` (on `orderDraftProvider`; `_LineDraft` goes; the picker's pop result goes through `add` until Task 7), `order_line_sheet.dart` (header ×, «Готово»), `line_flash.dart` (`color`), the ARB files
- Test: create `frontend/test/core/widgets/rolling_amount_test.dart` and `frontend/test/features/orders/presentation/order_edit_screen_test.dart` (the editor's tests of `orders_screens_test.dart` move here, rewritten where they pinned the old drawing); `line_flash_test.dart`

**Interfaces:**
- Consumes: `orderDraftProvider`, `DraftLine`, `DraftChange` (Task 3).
- Produces:
```dart
class RollingAmount extends StatefulWidget {
  const RollingAmount({required this.amountUzs, required this.format, this.style, this.waiting = false, this.textKey, super.key});
  final int amountUzs; final String Function(int amountUzs) format; final TextStyle? style;
  final bool waiting;              // dims to 0.45 over 200 ms, as SoftChange
  final Key? textKey;              // on the Text, which holds the final words once settled
}
class OrderEditLine extends StatelessWidget {
  const OrderEditLine({required this.draft, required this.adds, required this.busy, required this.onStep, required this.onQuantity, required this.onOptions, required this.onRemove, required this.onRestore, super.key});
}
String changeText(AppLocalizations l10n, AppLanguage language, DraftChange change);
String ruleShort(AppLocalizations l10n, SubstitutionPolicy rule);
LineFlash({required int flash, Color color = KitColors.lineFlash, required Widget child})
```
- Keys kept: `edit-line-<key>`, `edit-sum-<key>`, `edit-adds-<key>`, `edit-remove-<key>` (the sheet's «Убрать из заказа»), `line-minus-<key>`/`line-plus-<key>` (the stepper's); new: `edit-options-<key>` (the row), `edit-removed-<key>` (the compact row), `edit-restore-<key>` («Вернуть»). The rule and note info rows under the name go (the options row says them). The top of a line takes no tap; the options row and the stepper's quantity do (the quantity opens `showQuantitySheet` as before).
- Spoken: a kept line is one container labelled `orderEditLineSpoken` (or `orderEditLineNewSpoken` for an added one) with the stepper's buttons and the options row (`orderEditOptionsSpoken`) as its own actions; a removed row reads `orderEditRemoved` with «Вернуть» as its action; × reads `orderEditCloseSpoken`. Removal and restore announce `orderEditRemoved` / `orderEditRestored` through Task 5's queue (in this task: at once).

- [ ] **Step 1: Failing tests** (`edit-11`, `edit-12` red on main's editor first): rolling — `'a new amount rolls in 320 ms in steps of 100 and ends exact'`; `'with reduced motion the amount changes at once'`; `'a screen reader hears only the final amount'`. Lines — `'a removed line folds to its compact row with Вернуть'` (height mid-way at 130 ms; the row 44 high; «Вернуть» 44); `'a removed line reads as removed and offers Вернуть'`; `'Вернуть brings the line back at its price'`; `'a removal buzzes lightly'`; `'each line has a Комментарий · замена похожим row that opens its sheet'` (with a note: «"Твёрдые, для салата" · замена похожим»); `'the line sheet has × Отмена and Готово'` (× changes nothing; «Готово» applies); `'at large text a line keeps its sum whole over the stepper'` (no `FittedBox`, the sum at its full size, the stepper under it); `'at large text the options row wraps from the start'`; `'a kept line reads its name, quantity and sum and names its actions'`; the guideline at 100 % and 200 % with a new, a removed and a stepped line.
- [ ] **Step 2: Run red.**
- [ ] **Step 3: Implement.** The lines column is a `FoldingColumn` keyed by `DraftLine.key` over the draft's lines minus `arriving`; each line in a `LineFlash` (Task 5 and 7 drive it) and an `AnimatedSize`.
- [ ] **Step 4: Run green** with `test/features/orders/` and `test/core/`.
- [ ] **Step 5: Commit** `feat(orders): editor lines fold, roll and say what they hold, with a visible options row (DL-132)`.

### Task 5: The editor's sums, the minimum, the save and its banner

**Files:**
- Create: `frontend/lib/features/orders/presentation/order_edit_footer.dart` (`OrderEditTotals` for the list, `OrderEditFooter` with the strips, the total and the button), `frontend/lib/features/orders/presentation/order_edited_banner.dart`
- Modify: `order_edit_screen.dart`, `orders_screens.dart` (`OrderScreen` awaits the editor and shows the banner), `kit_colors.dart` (`buttonOff`), the ARB files
- Test: `order_edit_screen_test.dart`, `orders_screens_test.dart`

**Interfaces:**
- Consumes: `orderEditSummaryProvider`, `EditSummary`, `draftChanges` (Task 3), `RollingAmount` (Task 4).
- Produces: `OrderEditFooter({required order, required draft, required summary, required changes, required saving, required onSave, required onAdd, required onRemoveMarked})`; `OrderEditedBanner({required order})` (keyed `edit-banner`); the editor pops with the saved `CustomerOrder`; `OrderScreen`'s edit button does `context.push<CustomerOrder>(…)` and on an answer shows the banner. `enum SaveFace { saving, saved, keepOne, tooMany, removeFirst, shortfall, noChanges, save }` decides the button, in that order of precedence: busy, the ✓ moment, no line kept, more than `orderMaxLines`, marked lines, a shortfall, no changes, else «Сохранить изменения (N)» with N = `draftChanges(...).length`. Keys: `edit-goods`, `edit-delivery`, `edit-fee`, `edit-total` (list), `edit-footer-total`, `edit-change`, `edit-was`, `edit-minimum` (strip) with `edit-minimum-add`, `edit-save`, `edit-recount`.
- Sums: the list's rows `cartGoods(kept)` · delivery · fee · «Итого» (`total_kind` decides «≈»), and the footer's «Итого» over the total with the change pill (`+`/`−` and the amount, hidden at 0) and the «Было …» line: `orderEditWasSame` when the preview's delivery and fee equal the order's, `orderEditWas` otherwise, `orderEditFeesIncluded` when nothing changed — all `RollingAmount`s from `summary.shown`, `waiting` while `summary.waiting`; when `summary.failed`, the list's values are «—» and the footer shows `orderEditRecount` in place of the total. The strip shows while `summary.shortfallUzs > 0`; its «Добавить» opens the picker.
- Save: «Сохраняем…» with the spinner while sending; on success `HapticFeedback.lightImpact`, ✓ «Сохранено», `orderEditedSpoken` with the answer's total, then the pop 650 ms later; a minimum refusal → `refusedMinimum` from its `details` and `orderEditNotSaved` with the strip's words; any other failure → `FailureMessage` over the button, which comes back. Announcements of Task 4's changes wait for the next summary that is not `waiting` and add `orderEditTotalSpoken`'s total (the change alone after a failure); a later change replaces one still waiting.
- Banner: `orderEditedTitle` over `orderEditedTotal`, under the app bar, 4 s; it does not announce (the editor did).

- [ ] **Step 1: Failing tests:** `'the list and the footer show the order\'s sums before any change'`; `'a change shows the previewed delivery, fee and total, the change and Было'` (the page's order, tomatoes 2.5 → 3 kg: «Итого ≈ 98 000 сум», «+7 000 сум», «Было ≈ 91 000 сум · доставка и сбор те же»); `'while a newer preview waits the sums stay dimmed'`; `'sums roll to the new answer'`; `'offline the footer says the totals come after saving and the save still goes'`; `'a shortfall shows the strip and greys the button with the sum'` («До минимальной суммы 50 000 сум не хватает 41 000 сум», «Не хватает 41 000 сум»; «Добавить» opens the picker); `'a save refused for the minimum shows the strip from its details'`; `'the button says Нет изменений, then Сохранить изменения (3)'`; `'saving says Сохраняем…, then ✓ Сохранено, buzzes and returns with the order'`; `'the order page shows Заказ изменён with the total for 4 s'` (gone at 4.3 s; fades only with reduced motion); `'a step is announced with the new total once its preview answers'` («Помидоры, 3 кг. Итого ≈ 98 000 сум»); `'of quick steps only the last is announced'`; `'with no line kept the button says Оставьте хотя бы один товар'`; the guideline at 100 % and 200 % for each button state and both strips; at 200 % on 360 dp the footer total, its pill and «Было …» do not overflow.
- [ ] **Step 2: Run red.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run green** with `test/features/orders/`.
- [ ] **Step 5: Commit** `feat(orders): the editor shows the previewed total and the minimum before saving, and says the save's result (DL-132)`.

### Task 6: Leaving and refusals — the exit sheet, the amber note, the lock view, products no longer sold

**Files:**
- Create: `frontend/lib/features/orders/presentation/order_edit_sheets.dart` (`showLeaveSheet`), `frontend/lib/features/orders/presentation/order_edit_locked.dart` (`OrderEditLocked`)
- Modify: `order_edit_screen.dart` (stateful screen keeping the lost changes; `PopScope`), `order_edit_line.dart` (the marked frame), `order_edit_footer.dart` (the red strip), `order_sections.dart` (`_dial` made public as `dialOrSay`), the ARB files
- Test: `order_edit_screen_test.dart`

**Interfaces:**
- Consumes: `draftChanges`, `EditSummary.locked`, `OrderDraft.marked`, `removeMarked` (Task 3); `changeText` (Task 4); `OrderEditFooter` (Task 5).
- Produces: `Future<bool> showLeaveSheet(BuildContext context, {required List<String> changes})` — `true` to leave; a tap outside, the system back and «Продолжить изменять» keep editing. `OrderEditLocked({required CustomerOrder order, required List<String> lost})` (keyed `edit-locked`). `Future<void> dialOrSay(BuildContext context, WidgetRef ref, String phone)`. Keys: `edit-leave-sheet`, `edit-leave`, `edit-keep-editing`, `edit-info` (now amber or green), `edit-gone` (strip) with `edit-gone-remove`, `edit-marked-<key>` (the frame) with `edit-marked-remove-<key>`, `edit-call-support`, `edit-back-to-order`.
- Leaving: with changes, × and the system back (a `PopScope` with `canPop` false while there are changes and no save runs) open the sheet; leaving pops without saving; without changes × leaves at once.
- Lock: when the summary or a save answers `order_editing_locked`, the editor hands its change texts to the screen, which shows `OrderEditLocked` once the order has loaded again and cannot be changed (the plain `_Closed` when nothing was lost) and announces `orderEditLockedSpoken`.
- Marked: a marked line is framed red with its words and «Убрать»; the footer's red strip names the marked products (`orderEditGone`, names joined with «, ») with «Убрать» (`removeMarked`); the button says `orderEditRemoveFirst`/`…More`. A save refused with `product_unavailable` marks them, scrolls the first to a third of the view, flashes it with `KitColors.dangerWash` and announces `orderEditNotSaved` with the strip's words.

- [ ] **Step 1: Failing tests** (`edit-3`, `edit-9` red on main's editor first): `'with changes × asks before leaving'` (the sheet lists «− Лепёшка» and «Помидоры: 2,5 кг → 3 кг», «Не сохранятся 2 изменения:»); `'Продолжить изменять keeps the edits, Выйти без сохранения leaves'`; `'system back asks too'`; `'without changes × leaves at once'`; `'a Shopper assigned shows the amber note, a new order the green one'`; `'a refusal because shopping started shows what did not save'` (title «Сборщик уже начал покупать», the list, «Позвонить в поддержку» dialling the support phone, «Открыть заказ» back); `'without a support phone the lock view offers only Открыть заказ'`; `'a cancelled order\'s lock view says Заказ отменён'`; `'a preview that finds the order locked shows the lock view'`; `'a product no longer sold is framed red with Убрать, and the footer strip too'`; `'a save refused for it scrolls to the line and flashes it red'`; `'Убрать in the strip removes every marked product and the button comes back'`; the guideline at 100 % and 200 % for the sheet, the lock view and a marked line.
- [ ] **Step 2: Run red.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run green** with `test/features/orders/`.
- [ ] **Step 5: Commit** `feat(orders): the editor asks before losing changes and says what a refusal did not save (DL-132)`.

### Task 7: The picker — stays open, steppers, its bar, photo tiles, arrivals

**Files:**
- Modify: `frontend/lib/features/orders/presentation/order_product_picker.dart` (rewritten: `_PickCategories` as tiles with a `switch` over the categories' state — the stage 6 re-review's dead `when` branch goes —, `_PickRow` with plus and stepper, the crumb, the bar), `orders_routes.dart` (the picker's `redirect`), `order_edit_screen.dart` (`_add` pushes the picker and settles the arrivals on return), the ARB files
- Test: `frontend/test/features/orders/presentation/order_add_test.dart` (rewritten to the new picker), `test/app/route_pages_test.dart` (unchanged table, still green)

**Interfaces:**
- Consumes: `orderDraftProvider` (`add(…, arriving: true)`, `step`, `remove`, `settleArrivals`), `customerOrderProvider` (Task 3); `LineFlash` (Task 4).
- Produces: `OrderProductPickerScreen({required String orderId})` (`productIds` goes); `final class OrderPickerOpening { const OrderPickerOpening(); }` — the editor pushes the picker with it as `extra`; the route's `redirect` sends a picker opened without it to the order's editor. Keys: `pick-search`, `pick-search-clear` (kept), `pick-tiles`, `pick-section-<id>`, `pick-all-sections`, `product-<id>` (the row), `pick-<id>` (the plus), `pick-minus-<id>`, `pick-plus-<id>`, `pick-bar`, `pick-done`.
- Rules: a row's tap or its plus adds the product (`arriving`), the plus growing into the stepper, `HapticFeedback.lightImpact`, `orderPickAddedSpoken`; a product in the order shows its stepper and «Уже в заказе» (one added in this visit «Добавлен сейчас»); the stepper steps the draft's line, its bin at the minimum takes it out; with 100 lines kept the plus is off and the bar says `orderAddFull`. The bar shows while this visit added a kept line: `orderPickAdded(n)` over the sum of their `previewUzs` with «≈», «Готово» returning. Back from a section returns to the tiles; back again and «Готово» return to the editor. When the order loads as no longer editable, the picker closes itself. On return the editor settles the arrivals: scroll, unfold, flash green, and announces the first's line words with the total (Task 5's queue).
- Spoken: a tile `orderPickSection(name)`; a row `orderPickRowSpoken` with the plus `orderPickAdd(name)`, or `orderPickInOrderSpoken` with the stepper's buttons.

- [ ] **Step 1: Failing tests:** `'a pick keeps the picker open and turns the plus into a stepper'` (the morph mid-way at 130 ms; one light haptic; «Добавили: Морковь, 1 кг. Добавлено товаров: 1»); `'the bar counts what this visit added and Готово returns'` («Добавлено: 2 товара», «≈ 20 000 сум»); `'a product already in the order shows its stepper and Уже в заказе'`; `'the stepper\'s bin takes the product out again'`; `'back from a section returns to the tiles, then to the editor'`; `'sections are photo tiles, and a section shows Все разделы and its name'`; `'at large text the tiles stand in one column and the price wraps'`; `'at large text the stepper takes the row\'s width'`; `'lines added in the picker arrive in the editor, scrolled to and flashed'`; `'a picker opened by its address alone opens the editor'` (rewritten from the old test); `'a lock found while the picker is open shows the lock view'`; `'an order holds at most 100 lines'` (rewritten); `'a search in the picker looks through the whole catalog'` (kept); the guideline at 100 % and 200 % for the tiles, a section with plus and stepper rows, and the bar.
- [ ] **Step 2: Run red.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run green** with `test/features/orders/`, `test/app/route_pages_test.dart`, then `flutter analyze` and `dart format --set-exit-if-changed lib test`.
- [ ] **Step 5: Commit** `feat(orders): the picker stays open with steppers, a bar and photo sections (DL-132)`.

### After the tasks (the lead)

- [ ] `DL-132` (15) filled in; `docs/03-features.md` §11 checked against the new editor (the picker staying open, the preview's total) and amended in the branch; `tasks/APPLE_BATCH.md` residual findings parked with rulings, and the stage 6 re-review's picker finding marked fixed.
- [ ] Full suites (`test-runner`): frontend `flutter test --concurrency=2`, backend `php artisan test --fail-on-warning`; `pint --test`, `phpstan analyse`, `flutter analyze`, `git diff --check`.
- [ ] Final review (`branch-reviewer`, opus) → one fix wave → scoped re-review; `/security-review`; PR, both checks green, merge.
