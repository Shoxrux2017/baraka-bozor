# Apple Stage 1 — Kit Colours and Sizes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every role's screens use the approved colours (button fills `#3A9E46`, green text `#2D7D38`, secondary text `#676D68`, red `#C0362C`, amber text `#94600A`, stars with an edge), and every control is at least 44 × 44 to tap, compact cards drawing 32 inside a 44 square.

**Architecture:** The colours are tokens in `KitColors`, so most of the change is their values. The real work is the split of roles: `primary` stays the fill, icon and border green, and every piece of green *text* moves to `primaryDark`; amber text moves from `warning` to `warningDark`; the two reds become one. A source scan keeps fill colours out of text from now on, and a token test pins every contrast ratio. Sizes change in the shared controls (cart stepper, product card, product bar) and, on the staff screens, wherever Flutter's `iOSTapTargetGuideline` finds a smaller target. The Customer screens get that guideline check in the later stages that rewrite them.

**Tech Stack:** Flutter 3.47.5, flutter_riverpod 3.4.3, go_router 18, flutter_test (`meetsGuideline(iOSTapTargetGuideline)`).

**Spec:** `tasks/APPLE_BATCH.md` stage 1 (items `cart-1`, `cart-2`, `cart-3`, `cart-6`, `catpage-5`, `order-1`, `rate-1`); the live tests «Тест корзины - Apple», «Тест заказа - Apple», «Тест категории - Apple», «Тест оценки заказа - Apple» in the Claude Design project "BarakaBozor — стиль покупателя"; `frontend/AGENTS.md` section 12.

## Global Constraints

- Only `frontend/`, `docs/` and `tasks/` change. No package, no `pubspec.lock` change, no generated file edited (the `.arb` files do not change in this stage).
- Exact colours: `primary` `0xFF3A9E46`, `primaryDark` `0xFF2D7D38`, `muted` `0xFF676D68`, `danger` `0xFFC0362C`, `warningDark` `0xFF94600A`, new `starEdge` `0xFF94600A`. `primarySoft`, `primaryWash`, `ink`, `ink2`, `line`, `field`, `page`, `card`, `dangerWash`, `warning`, `warningWash`, `warningSoft`, `shadow` and `star` keep their values.
- Text glyphs are never `KitColors.primary` or `KitColors.warning`; the one exception is the 34 px wordmark (`core/widgets/brand_wordmark.dart`), a logo in large text. Icons, fills and borders keep `primary` and `warning`.
- A control's hit area is at least 44 × 44. Only steppers change their drawn size (to 44); every other control keeps its drawing and grows its hit area. Compact product cards draw 32 inside a 44 square.
- Every role changes: Customer, Shopper, Courier and the panel (the Owner's "везде", 2026-10-24).
- Flutter runs from PowerShell with `$env:TEMP='G:\tools\tmp'; $env:TMP='G:\tools\tmp'` and `G:\tools\flutter\bin\flutter.bat`; a full suite run uses `--concurrency=2`.
- A test that pins an old colour or size is updated to the new value; no test is deleted or weakened otherwise.
- Comments read like the surrounding code: short `///` docs in plain English that name the `DL-` they follow (`DL-117`).
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. Green or amber text the scan cannot see: a colour handed through a parameter or variable (`final Color tone = KitColors.primary;` later used in a `TextStyle`), a `TextStyle.copyWith(color: KitColors.primary)`, or a `DefaultTextStyle`. Task 2 makes the implementer read every remaining `KitColors.primary` and `KitColors.warning` line, not only the scan's hits.
2. A narrow phone with large text, where the 44 px stepper squeezes a cart line's name or sum into an overflow (Task 4 test: a cart line at 320 × 640 with text × 1.3).
3. A tap in the 6 px a compact card's button reaches into the card's padding opening the product instead of stepping (Task 4 test).
4. The panel at 1 366 px wide growing taller rows or a sideways scroll once its controls have 44 px hit areas (Task 5: the existing board and table width tests stay green, and the pager still draws 32).
5. Material widgets coloured by the theme (the addresses list's `ListTile`s, `AlertDialog`s, plain `TextButton`s) keeping the old green or drawing text in the fill green (Task 1 theme tests).

---

### Task 1: Tokens, theme and contrast

**Files:**
- Modify: `frontend/lib/core/theme/kit_colors.dart`
- Modify: `frontend/lib/core/theme/app_theme.dart`
- Modify: every file using `KitColors.dangerDark` (it is removed): `features/admin/presentation/staff_widgets.dart`, `customers_screen.dart`, `core/widgets/failure_message.dart`, `features/operations/presentation/order_actions.dart`, `order_detail_screen.dart`, `order_staff.dart`, `order_path.dart`, `board_widgets.dart`, `order_lines.dart`, `core/widgets/kit/kit_dialog.dart` (confirm with `grep -rn "dangerDark" frontend/lib`)
- Modify: `frontend/lib/features/cart/presentation/cart_summary_bar.dart:62` (`Color(0x595AC268)` becomes `KitColors.primary.withValues(alpha: 0.35)`)
- Test: `frontend/test/core/theme/kit_colors_test.dart`, `frontend/test/core/theme/app_theme_test.dart`

**Interfaces:**
- Produces: `KitColors.primary` (fills, icons, borders), `KitColors.primaryDark` (green text and links, pressed fills), `KitColors.danger` (all red: text, icons, red buttons), `KitColors.warningDark` (amber text), `KitColors.starEdge` (the edge of a filled star). `KitColors.dangerDark` no longer exists.
- Produces: the theme's `textButtonTheme` and `outlinedButtonTheme` with `foregroundColor` `KitColors.primaryDark`.

- [ ] **Step 1: Write the failing tests.** In `kit_colors_test.dart` add a local `double _contrast(Color a, Color b)` (WCAG: `(lighter + 0.05) / (darker + 0.05)` from `computeLuminance()`) and:
  - `'keeps the Owner's palette (DL-117)'`: the six exact values of the Global Constraints.
  - `'text colours read at 4.5:1 on white'`: `primaryDark`, `muted`, `danger`, `warningDark` against `Colors.white`, each `greaterThanOrEqualTo(4.5)`.
  - `'text colours read at 4.5:1 on their washes and on a disabled button'`: `primaryDark` on `primaryWash`, `danger` on `dangerWash`, `warningDark` on `warningWash`, `muted` on `field`, `muted` on `line`, each `>= 4.5`.
  - `'white on a green button is the Owner's 3.4:1'`: `_contrast(Colors.white, KitColors.primary)` `>= 3.4`; white on `primaryDark` and on `danger` `>= 4.5`.
  - `'icons and star edges stand out at 3:1'`: `primary`, `starEdge`, `muted` on white, each `>= 3`.
  In `app_theme_test.dart`: line 42 expects `Color(0xFF3A9E46)`; add `'draws text buttons in the text green'`: `buildAppTheme(Brightness.light).textButtonTheme.style!.foregroundColor!.resolve(<WidgetState>{})` equals `KitColors.primaryDark`, and the same for `outlinedButtonTheme`.

- [ ] **Step 2: Run them and see them fail**
  Run: `flutter.bat test test/core/theme/`
  Expected: FAIL (`starEdge` is not defined, old values).

- [ ] **Step 3: Change `kit_colors.dart`.** New values; `starEdge` added after `star`; `dangerDark` removed and its uses replaced by `KitColors.danger`. The docs say what each token is for: `primary` "Brand green for fills, icons and borders; white on it is 3.4:1, the Owner's choice (`DL-117`). Never text."; `primaryDark` "Green text and links, and the pressed fill."; `danger` "Red: errors, destructive actions, their text and icons."; `warning` "Amber icons, borders and fills. Never text."; `warningDark` "Amber text.".

- [ ] **Step 4: Change `app_theme.dart`.** Add `textButtonTheme` and `outlinedButtonTheme` setting only `foregroundColor: KitColors.primaryDark`; the seed and the pinned `primary` stay `KitColors.primary`.

- [ ] **Step 5: Run the theme tests and `flutter.bat analyze`.** Expected: theme tests PASS; analyze reports no issues.

- [ ] **Step 6: Commit**
```bash
git add frontend/lib frontend/test/core/theme
git commit -m "feat(kit): the approved palette and one red (DL-117)"
```

### Task 2: Text never in the fill colours

**Files:**
- Create: `frontend/test/core/theme/kit_text_colours_test.dart`
- Modify: the text sites found by the scan and by reading; known today: `features/legal/presentation/consent_line.dart:41`, `features/orders/presentation/order_sections.dart:840`, `features/catalog/presentation/search_screen.dart:300` and `:487`, `features/catalog/presentation/product_screen.dart:885`, `features/admin/presentation/product_edit_screen.dart:104`, `features/auth/presentation/auth_scaffold.dart:182-183`, `features/orders/presentation/order_questions.dart:132` (amber)

**Interfaces:**
- Consumes: Task 1's tokens.
- Produces: `List<String> kitTextColourViolations(String path, String source)` in the test file (top level, so its own cases can call it).

- [ ] **Step 1: Write the failing test.** `kitTextColourViolations` returns `'$path: $match'` for each hit of:
  - inside each `TextStyle(` call, matched as `TextStyle\((?:[^()]|\([^()]*\))*\)`, the pattern `\bcolor:[^,)]*KitColors\.(primary|warning)(?![A-Za-z])`;
  - anywhere, `\b(foregroundColor|foreground):\s*KitColors\.(primary|warning)(?![A-Za-z])`.
  Tests:
  - `'finds fill colours in text'`: `"TextStyle(fontSize: 12, color: KitColors.primary)"` gives one hit; `"TextStyle(color: on ? KitColors.warning : KitColors.muted)"` gives one; `"kitOutlined(foreground: KitColors.primary)"` gives one.
  - `'leaves text colours, icons and fills alone'`: `"TextStyle(color: KitColors.primaryDark)"`, `"Icon(Icons.add, color: KitColors.primary)"`, `"BoxDecoration(color: KitColors.primary)"`, `"TextStyle(color: KitColors.warningDark)"` give none.
  - `'no text is drawn in the fill green or the icon amber'`: every `*.dart` under `lib/` except `lib/core/widgets/brand_wordmark.dart` and `lib/core/localization/generated/`, joined violations `isEmpty`.

- [ ] **Step 2: Run it and see the last test fail** listing the known sites.
  Run: `flutter.bat test test/core/theme/kit_text_colours_test.dart`

- [ ] **Step 3: Fix every hit**, green text to `KitColors.primaryDark` and amber text to `KitColors.warningDark`. Then read every remaining `KitColors.primary` and `KitColors.warning` line (`grep -rn "KitColors\.primary\b\|KitColors\.warning\b" lib`) and move any that still colours text through a variable, a parameter, `copyWith` or `DefaultTextStyle`. Report the count of sites moved and any judgement call.

- [ ] **Step 4: Run the scan test and the tests of every changed feature.** Expected: PASS. A test that pinned the old text colour is updated to the new one.

- [ ] **Step 5: Commit**
```bash
git add frontend/lib frontend/test
git commit -m "feat(kit): green and amber text in their text colours (DL-117)"
```

### Task 3: Stars with an edge

**Files:**
- Create: `frontend/lib/core/widgets/kit/kit_star.dart`
- Modify: `features/orders/presentation/rate_order_screen.dart:223-233`, `order_rating_card.dart:81-84` and `:138-141`, `order_cards.dart:555-558`, `features/operations/presentation/order_actions.dart:1070-1074`
- Test: `frontend/test/core/widgets/kit/kit_star_test.dart` (new) and the existing tests of the changed screens

**Interfaces:**
- Produces: `class KitStar extends StatelessWidget` with `const KitStar({required bool filled, required double size, super.key})`. Filled: `Icons.star` in `KitColors.star` under `Icons.star_border` in `KitColors.starEdge`, both `size`; empty: `Icons.star_border` in `KitColors.muted`. It adds no semantics of its own (each site keeps its label).

- [ ] **Step 1: Write the failing test** `kit_star_test.dart`: `'a filled star is amber with an edge'` finds two `Icon`s with colours `KitColors.star` and `KitColors.starEdge` and the given size; `'an empty star is a grey outline'` finds one `Icon(Icons.star_border)` in `KitColors.muted`; `'adds no semantics node'`.
- [ ] **Step 2: Run it and see it fail** (`KitStar` is not defined).
- [ ] **Step 3: Implement `KitStar`** and use it at the five sites, keeping each site's size, layout, keys and semantics. `catalog_widgets.dart:255` and `board_attention.dart:178` are not ratings and stay.
- [ ] **Step 4: Run `kit_star_test.dart` and the tests of the five sites.** Expected: PASS; tests that looked for `Icons.star` with the old colour are updated.
- [ ] **Step 5: Commit**
```bash
git add frontend/lib frontend/test
git commit -m "feat(kit): rating stars with an edge (DL-117)"
```

### Task 4: The Customer's shared controls at 44

**Files:**
- Modify: `frontend/lib/features/cart/presentation/cart_line_stepper.dart` (`height` 36 → 44, `width` 116 → 132)
- Modify: `frontend/lib/features/catalog/presentation/kit_product_card.dart` (`buttonSide`, `bottomRowHeight`, the heart's tap box, the compact button's hit square)
- Modify: `frontend/lib/features/catalog/presentation/product_bar.dart:197` (buttons 38 → 44)
- Modify: `frontend/lib/features/addresses/presentation/delivery_address_widgets.dart:203` (the close button's hit area 44, drawing 28 kept)
- Test: `frontend/test/features/cart/presentation/cart_line_stepper_test.dart` (new), `frontend/test/features/cart/presentation/cart_screens_test.dart` (the 320 px case, which needs the cart harness), `frontend/test/features/catalog/kit_product_card_test.dart`, `kit_card_fixes_test.dart:334-347`, `category_screens_test.dart:236`

**Interfaces:**
- Produces: `KitCardType.buttonSide(KitCardSize)` returns 32 for compact and 44 for regular (the drawn side); new `static const double KitCardType.tapSide = 44`; `bottomRowHeight` becomes 44. `kitCardExtent` keeps adding its parts, so every card grows by 4 px.

- [ ] **Step 1: Write the failing tests.**
  - `cart_line_stepper_test.dart`: `'its buttons are 44 square'` (`tester.getSize` of the minus and plus keys equals `Size(44, 44)`); `cart_screens_test.dart`: `'a cart line fits a 320 px phone with text × 1.3'` pumps the cart with one line (`CartLineTile`) at `Size(320, 640)` with `textScaler: TextScaler.linear(1.3)` and expects no exception.
  - `kit_product_card_test.dart`: `'a regular card draws its add button and stepper 44'`; `'a compact card draws 32 inside a 44 hit square'` (the drawn face is 32 × 32, the button's `InkWell`/`GestureDetector` box is 44 × 44); `'a tap 3 px inside a compact card's edge steps, not opens'` (tap at the card's left edge + 3 px on the bottom row with the product in the cart: the minus is called, no route pushed); `'every card target meets iOSTapTargetGuideline'` for a regular and a compact card (`tester.ensureSemantics()`, `await expectLater(tester, meetsGuideline(iOSTapTargetGuideline))`).
  - Update `kit_card_fixes_test.dart:334-347` and `category_screens_test.dart:236` to the extents that are 4 px taller.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.** In compact cards the bottom row spans the card's full width, ignoring the 8 px side padding there, and each 44 hit square holds the 32 face at its centre, so the face sits 6 px from the card's edge, as the test page draws it (`.kbtn.sm { margin: 0 -6px }`). The heart keeps its 32 drawing in a 44 tap box. The product bar's stepper buttons are 44.
- [ ] **Step 4: Run the catalog, cart, product, home, category, search, favourites and order-editing tests** (`flutter.bat test test/features/catalog test/features/cart test/features/favorites test/features/orders`). Expected: PASS.
- [ ] **Step 5: Commit**
```bash
git add frontend/lib frontend/test
git commit -m "feat(kit): steppers and card buttons at 44, compact 32 in 44 (DL-117)"
```

### Task 5: Staff and panel targets at 44

**Files:**
- Modify: whatever the guideline finds; known today: `core/widgets/panel/panel_pager.dart:96-97` (32 × 32), `core/widgets/panel/panel_segmented.dart` (34 high), `features/shopper/presentation/shopper_line_actions.dart:543` (option rows at least 40)
- Test: the existing screen tests of `test/features/shopper/`, `test/features/courier/`, `test/features/operations/`, `test/features/admin/` and `test/core/widgets/panel/`

- [ ] **Step 1: Write the failing tests.** In each of these screen tests add one `'every target meets iOSTapTargetGuideline'` test that pumps the screen in its usual data state at its usual size and runs `meetsGuideline(iOSTapTargetGuideline)`: Shopper's list and order screens, Courier's list and order screens, the panel board, the panel order page, the panel products list, the panel people (staff) list. Add the same check to `panel_pager_test.dart` and `panel_segmented_test.dart`.
- [ ] **Step 2: Run them and record every failing target** (the guideline names each rect) in the task report.
- [ ] **Step 3: Fix each one by growing its hit area to 44 × 44 and keeping its drawing**: a `SizedBox`/`ConstrainedBox` hit box around the drawn piece, `MaterialTapTargetSize.padded`, or a row's minimum height 44. The pager still draws 32 × 32 (`panel_pager_test.dart:72` measures the drawn box); the segmented control still draws its 34 px track, with each segment's hit area 44 high. A link inside running text is not this stage's: list it in the report, and the lead records it in `tasks/APPLE_BATCH.md` risks.
- [ ] **Step 4: Run all four feature folders and `test/core/widgets/panel/`.** Expected: PASS, including the board's width and no-overflow tests at 1 366 px.
- [ ] **Step 5: Commit**
```bash
git add frontend/lib frontend/test
git commit -m "feat(kit): staff and panel targets at 44 (DL-117)"
```

### Task 6: Decisions and the batch file

**Files:**
- Modify: `docs/DECISIONS.md` (append `DL-117`)
- Modify: `tasks/APPLE_BATCH.md` (stage 1 status; risks from Task 5)
- Modify: `tasks/REDESIGN_CUSTOMER.md:17` (the 2.4:1 risk row says it is resolved by `DL-117`)

- [ ] **Step 1: Append `DL-117 — The Apple batch, and its kit colours and sizes (2026-10-29, agent; items 1, 3 and 4 Owner)`**, numbered:
  1. **Owner** (2026-10-24, cart test item 1, "везде"): button fills `#3A9E46`, green text and links `#2D7D38`, on every role's screens. White on a green button is 3.4:1, the Owner's choice over the old 2.4:1 (supersedes `DL-77` (6)'s colour and (7)'s known risk).
  2. Secondary text `#676D68` and one red `#C0362C` for text, icons and red buttons (cart test items 2 and 3); `dangerDark` is gone.
  3. **Owner** (2026-10-25, order test item 1): amber text `#94600A`; the amber `#E8A317` stays for icons, borders and fills.
  4. **Owner** (2026-10-25, category test item 5): every control is at least 44 × 44 to tap; steppers draw 44; compact cards draw 32 inside a 44 square that reaches 6 px into the card's padding.
  5. Roles: `primary` fills, icons and borders; `primaryDark` text; `warning` icons; `warningDark` text. A source scan (`kit_text_colours_test.dart`) refuses fill colours in text; the 34 px wordmark is the one exception. The theme's text and outlined buttons use `primaryDark`.
  6. Stars: `KitStar`, amber `#FFB020` with a `#94600A` edge, empty a `#676D68` outline (rating test item 1).
  7. Staff and panel controls keep their drawings and grow their hit areas; Flutter's `iOSTapTargetGuideline` is the check. Each later stage of the batch adds the same check for the Customer screens it rewrites.
  8. The 220 approved items are coded in 22 stages (`tasks/APPLE_BATCH.md`), one pull request each.
- [ ] **Step 2: Update the two task files** and run `git diff --check`.
- [ ] **Step 3: Commit**
```bash
git add docs/DECISIONS.md tasks/APPLE_BATCH.md tasks/REDESIGN_CUSTOMER.md
git commit -m "docs: DL-117, the Apple batch's kit colours and sizes"
```

### Task 7 (lead): Drawings, suite and walk

- [ ] **Step 1:** In Claude Design, set the same values in `kit/kit.css` (`--pri #3A9E46`, `--pri-d #2D7D38`, `--mut #676D68`, `--danger #C0362C`, new `--warn-t #94600A` and `--star-edge #94600A`) and the matching variables of `kit/panel.css`, so new drawings start from them.
- [ ] **Step 2:** Full frontend suite through `test-runner` (`flutter.bat test --concurrency=2`), `flutter.bat analyze`, `dart format --set-exit-if-changed lib test`.
- [ ] **Step 3:** `branch-reviewer` on the whole branch, one fix dispatch, scoped re-review.
- [ ] **Step 4:** Walk on the `barakabozor` emulator and the panel in Chrome: cart, a category with compact cards, an order with a question, the rating screen, a Shopper order, the panel board. Four or five screenshots for the Owner.
