# Customer Redesign

Design 4a (`DL-74`), built part by part on the Customer's home first. Plan per part in `docs/superpowers/plans/`.

| Part | What | Status |
|---|---|---|
| 1 | Header: search, cart, delivery address; floating bar; theme and font (`DL-75`) | In Progress |
| 2 | Category circles on the header's arc | Planned |
| 3 | Product grid with the in-cart stepper | Planned |

## Risks

- At 320×640 with text ×2 the fixed header and the floating bar leave a small list viewport (the header scrolls inside 45% of the screen). Part 2, which puts the category circles on the header's arc, should consider letting the header scroll away with the content.
- Addresses with the same street and house (different apartments) read the same in the delivery address sheet, which shows the label or `street, house` only. Seen on the walk with the local data. A later part can add the apartment to the line.

## Review findings not acted on

- Part 1, re-review of the final fix wave, P3: with two sessions, text ×2 on a 320×640 phone, the header gives the search and the address its room first, so the active-mode bar is only partly visible (in Uzbek its label is cut in half) and its "back to staff" button needs a scroll inside the header. `docs/02` section 10 asks for the mode to be always visible. Not fixed in part 1 because it occurs only at that extreme size and part 2 reshapes the header (the risk above); part 2 must keep the mode label whole at that size and assert it in its large-text test.
