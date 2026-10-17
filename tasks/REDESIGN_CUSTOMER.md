# Kit stages

The app moves to the screen kit stage by stage (`DL-76`). Design 4a (`DL-74`) is no longer the target. Plan per stage in `docs/superpowers/plans/`.

| Stage | What | Status |
|---|---|---|
| 1 | Вход: splash, phone, code, name, staff password (`DL-77`) | Merged (PR #88) |
| 2 | Главная | Merged (PR #89, #90, #91, #92) |
| 3 | Поиск и товар | Merged (PR #93) |
| 4 | Корзина и адрес | In Progress (4a cart; 4b address, Google map, courier) |
| 5 | Оформление | Planned |
| 6 | Заказы | Planned |
| 7 | Профиль | Planned |

## Risks

- White text on the primary `#5AC268` has a contrast of 2.4:1, below WCAG AA. Kept as the kit's look.
- Real Telegram delivery arrives in Wave 4. Until then only the configured test phones can sign in, staff included.
- A blocked Customer account would also stop that person's staff sign-in on the phone (verify refuses before the step). Latent: no API blocks a Customer today.
- Wave 3 walkthrough compiled, not run, after the staff sign-in change - run it before Wave 4 closes.
- The kit home's header (mode bar, address and cart, search) scrolls inside 60% of the screen height above the keyboard; with two sessions at 320×640 and text ×2 it takes about that much and the sections below get a strip of about 150 px (they scroll). Only at that extreme size.
- Stage 4a: the cart's footer is the screen's bottom bar, so a snackbar rises above the button; the lines, the notice, the row, the amounts and the address scroll above it. At 320×640 with text ×2 a single large line leaves little room above the footer, and the rest scrolls.

## Part 1 history (design 4a, `DL-74`, `DL-75`)

| Part | What | Status |
|---|---|---|
| 1 | Header: search, cart, delivery address; floating bar; theme and font (`DL-75`) | Merged (PR #87) |
| 2 | Category circles on the header's arc | Planned |
| 3 | Product grid with the in-cart stepper | Planned |

### Part 1 risks

- Addresses with the same street and house (different apartments) read the same in the delivery address sheet, which shows the label or `street, house` only. Seen on the walk with the local data. A later part can add the apartment to the line.

## Review findings not acted on

- Card layout follow-up (`DL-81`), review P3: `ceilToDouble()` in `kitCardExtent` may add 1 px of slack on rare float products. Ruling: no functional effect, kept. (The TalkBack node and the picture corner were fixed in stage 3.)
- The picture may lie under the heart's 40 px tap box by a few px; the heart is on top and takes those taps. Ruling: no visible or functional effect, kept.
- Stage 3 branch review, latent: the product screen's `_form.currentState!` is reached only in the frame where the signed-in account changes, when the router removes the route anyway. Ruling: not reachable in use, kept.
- Stage 3 re-review, P3: while an add is in flight the header's heart stays tappable. Ruling: independent of the add, harmless, kept.
- Stage 3 branch review: a query typed by account A and left on screen when A signs out is remembered under A, as `DL-83` item 1 specifies; the device store is not wiped on sign-out. Ruling: by design, kept.
