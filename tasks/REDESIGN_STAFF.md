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
