# Staff stages

The Shopper's, the Courier's and the panel's screens take the screen kit's style before Wave 4 (`DL-97`, `DL-98`). Plan per stage in `docs/superpowers/plans/`.

| Stage | What | Status |
|---|---|---|
| 1 | Сборщик (kit/08-sborshchik) | Merged (PR #103) |
| 2 | Курьер (kit/09-kurer) | Merged (PR #105) |
| 3a | Панель: заказы (kit/10–10d) | Merged (PR #106) |
| 3b | Панель: каталог (kit/11) | Merged (PR #107) |
| 3c | Панель: сотрудники, покупатели, документы, настройки (kit/12) | Coded (PR #108) |

## Risks

- Found outside the stage: `productSaved` is defined twice in both ARB files (the panel's "Товар сохранён" and the cart's "Корзина обновлена"); the later wins, so the Admin's product save says "Корзина обновлена". Fixed: the cart's text is `cartLineSaved` now, and `frontend/test/core/localization/arb_keys_test.dart` fails on any repeated top-level ARB key.

## Review findings not acted on

- Stage 1 re-review, P3: every kit sheet's header row is 48 px since its × got a 48 px tap area. Ruling: a taller header is the price of a × that can be hit with gloves at a stall; kept.
- Stage 1 re-review, P3: `KitEmptyState` in a parent of unbounded height sits at the top instead of centred (the replacement search's "nothing found"). Ruling: centring needed a fixed-height box that crashed in other parents; walked on the emulator, reads well; kept.
- Stage 1 re-review, P3: `ShopperLineCard` treats any status but `awaiting_customer` as a line to buy; its one caller passes only pending and waiting lines. Ruling: not reachable; kept.
- Stage 1 walk: a purchase without a sure answer refills its price undivided ("14000"), while a typed price is grouped ("14 000"). Ruling: only the resend case, the value is right; kept.
- Stage 1 final review, out of scope: after a proposal whose order left the Shopper, `ShopperReplaceScreen` goes to the list and then pops; an old purchase refusal can show in the "Нет товара" sheet. Both behave as on `main`. Ruling: left for a later Shopper change, with tests.
- Stage 1 final review, out of scope: the Customer's `order_line_sheet.dart` pads the keyboard inside its scroll view (the defect fixed here in the kit sheet). Ruling: the Customer's sheet is outside this stage; fix it when that screen is next touched.
- Stage 2 re-review, P3: no test pins the amount's `FittedBox` or the list's w700 amount (`courier_order_screen.dart`, `courier_list_screen.dart`). Ruling: both were seen on the emulator walk; a pixel-weight assertion adds little; kept.
- Stage 2 re-review, P3: the resend seed `_grouped` in `courier_outcome_sheets.dart` repeats the grouping loop of the kit field's private formatter. Ruling: two short loops with one rule (groups of three, plain spaces); share them when a third caller appears; kept.
- Stage 2 walk: the cash mismatch note stays under the field while the Courier corrects the amount, until the next send. Ruling: as the dialog did; the next send clears or repeats it; kept.
- Stage 3a final re-review, P3: `panel_layout.dart` is imported before `kit/kit_buttons.dart` in `board_screen.dart` and `order_detail_screen.dart`. Ruling: analyze and format are clean and no import-order lint is enabled; cosmetic; kept.
- Stage 3a walk, pre-existing: a panel dialog left open stays over the next page when the URL changes (browser back or forward); choosing in it does nothing, since the old page is gone. As on `main`. Ruling: no wrong assignment can happen; left for a later panel change.
- Stage 3a final review, P3: the "Выполнено сегодня" and "Отменено сегодня" tiles filter by status over every day, not by today. Ruling: the board's day filter is on the placing date, so it would miss orders completed today but placed earlier; named in `DL-100` item 2; kept.
- Stage 3b re-review, P3: `products_screen.dart` computes the prices' maximum width without clamping it at zero, so a product card narrower than 124 would assert in debug. Ruling: a card is never that narrow (a 320 window gives about 164); clamp it when the file is next touched. Done in 3c.
- Stage 3b final review, P3: the products and categories tables repeat their header and row scaffolding. Ruling: stage 3c adds four more tables; a shared panel table pays for itself there. Done in 3c.
- Stage 3c re-review, P3: the staff test "a role name never breaks mid-word in a narrow table" passes through the role chip's one-line ellipsis, not through the 170 role-column minimum, because the test font is wider than Montserrat. Ruling: the walk at 1440 and 820 showed "Администратор" whole in Montserrat; the ellipsis is the fallback; kept.
- Stage 3c re-review, P3: while the malformed-phone error shows under the Customer search field, the field grows and "Найти" stretches with it. Ruling: the button keeps the field's height by design (walk W2) and the error is short-lived; kept.
