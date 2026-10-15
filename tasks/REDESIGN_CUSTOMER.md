# Kit stages

The app moves to the screen kit stage by stage (`DL-76`). Design 4a (`DL-74`) is no longer the target. Plan per stage in `docs/superpowers/plans/`.

| Stage | What | Status |
|---|---|---|
| 1 | Вход: splash, phone, code, name, staff password (`DL-77`) | Merged (PR #88) |
| 2 | Главная | In Progress (2a server and panel, 2b screens) |
| 3 | Каталог | Planned |
| 4 | Корзина | Planned |
| 5 | Оформление | Planned |
| 6 | Заказы | Planned |
| 7 | Профиль | Planned |

## Risks

- White text on the primary `#5AC268` has a contrast of 2.4:1, below WCAG AA. Kept as the kit's look.
- Real Telegram delivery arrives in Wave 4. Until then only the configured test phones can sign in, staff included.
- A blocked Customer account would also stop that person's staff sign-in on the phone (verify refuses before the step). Latent: no API blocks a Customer today.
- Wave 3 walkthrough compiled, not run, after the staff sign-in change - run it before Wave 4 closes.
- The list screens' header search icon arrives with stage 3 (search). Known gap.
- The kit home's header (mode bar, address and cart, search) scrolls inside 60% of the screen height above the keyboard; with two sessions at 320×640 and text ×2 it takes about that much and the sections below get a strip of about 150 px (they scroll). Only at that extreme size.

## Part 1 history (design 4a, `DL-74`, `DL-75`)

| Part | What | Status |
|---|---|---|
| 1 | Header: search, cart, delivery address; floating bar; theme and font (`DL-75`) | Merged (PR #87) |
| 2 | Category circles on the header's arc | Planned |
| 3 | Product grid with the in-cart stepper | Planned |

### Part 1 risks

- Addresses with the same street and house (different apartments) read the same in the delivery address sheet, which shows the label or `street, house` only. Seen on the walk with the local data. A later part can add the apartment to the line.

## Review findings not acted on

- Stage 2b, re-review of the final fix wave, P3: `FavoriteOverrides.toggle` (`frontend/lib/features/favorites/application/favorites_controllers.dart`) is now called only by `favorites_controllers_test.dart`; the card uses `change()`. Not removed in 2b because the review loop allows one fix wave; stage 3 deletes `toggle` and moves its tests to `change()` (AGENTS.md §8).
