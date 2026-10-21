# Staff stages

The Shopper's, the Courier's and the panel's screens take the screen kit's style before Wave 4 (`DL-97`, `DL-98`). Plan per stage in `docs/superpowers/plans/`.

| Stage | What | Status |
|---|---|---|
| 1 | Сборщик (kit/08-sborshchik) | Coded (PR #—) |
| 2 | Курьер | Planned |
| 3 | Панель | Planned |

## Risks

- Found outside the stage: `productSaved` is defined twice in both ARB files (the panel's "Товар сохранён" and the cart's "Корзина обновлена"); the later wins, so the Admin's product save says "Корзина обновлена". Fixed in a separate small PR.

## Review findings not acted on

- Stage 1 re-review, P3: every kit sheet's header row is 48 px since its × got a 48 px tap area. Ruling: a taller header is the price of a × that can be hit with gloves at a stall; kept.
- Stage 1 re-review, P3: `KitEmptyState` in a parent of unbounded height sits at the top instead of centred (the replacement search's "nothing found"). Ruling: centring needed a fixed-height box that crashed in other parents; walked on the emulator, reads well; kept.
- Stage 1 re-review, P3: `ShopperLineCard` treats any status but `awaiting_customer` as a line to buy; its one caller passes only pending and waiting lines. Ruling: not reachable; kept.
- Stage 1 walk: a purchase without a sure answer refills its price undivided ("14000"), while a typed price is grouped ("14 000"). Ruling: only the resend case, the value is right; kept.
- Stage 1 final review, out of scope: after a proposal whose order left the Shopper, `ShopperReplaceScreen` goes to the list and then pops; an old purchase refusal can show in the "Нет товара" sheet. Both behave as on `main`. Ruling: left for a later Shopper change, with tests.
- Stage 1 final review, out of scope: the Customer's `order_line_sheet.dart` pads the keyboard inside its scroll view (the defect fixed here in the kit sheet). Ruling: the Customer's sheet is outside this stage; fix it when that screen is next touched.
