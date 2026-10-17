# Kit Stage 4a — The Cart Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Customer's cart looks and works like the approved drawings 19, 19а, 19б, 19в and 20 of `kit/04-korzina-adres.dc.html`. The server tells the cart what checkout would charge and how far the minimum order is.

**Architecture:**
- **Server.** The cart answer (`docs/09` §17) gains six fields from a new `CartCharges`. It is computed from the cart view and the business settings, the way checkout computes them.
- **Client.** `Cart` parses the six fields strictly. The cart screen is rebuilt from focused widgets in `features/cart/presentation/`: the line, its stepper, the remove sheet, the amounts, the minimum notice, the address card and the footer. The home's `RecommendedRow` gains parameters so the cart can show "Добавьте к заказу".

**Tech Stack:** Laravel 13 + PostgreSQL (PHPUnit, Pint, PHPStan), all inside Docker. Flutter 3.47.5, Riverpod 3, go_router, `flutter gen-l10n` (template `app_uz.arb`), Montserrat, `KitColors`.

**Spec:** `kit/04-korzina-adres.dc.html` in the Claude Design project "BarakaBozor — стиль покупателя". The Owner approved it on 2026-10-17. Screens built here:
- 19 Корзина
- 19а Пустая корзина
- 19б Товара нет в продаже
- 19в Меньше минимальной суммы
- 20 Убрать товар

Screens 21–22в (the address sheet, the Google map, the address form and the courier's address) are stage 4b. The Owner's decisions are `DL-84`, written in Task 1.

## Global Constraints

- Branch `task/kit-4a-cart` from `main` `0c61069`. Never commit to `main`.
- **Backend.** Every command runs in the container, from the repo root: `docker compose -f docker/compose.yaml exec app php artisan test --filter=…`, `… exec app vendor/bin/pint --test`, `… exec app vendor/bin/phpstan analyse`.
- **Flutter.** Use `G:/tools/flutter/bin/flutter` with `TEMP`/`TMP` = `G:\tools\tmp`, run from `frontend/`. Run `flutter analyze` and `dart format --set-exit-if-changed lib test`.
- **Kit look.** Colours only from `KitColors`; Montserrat; the cards stay as `DL-81` built them. Sizes follow the drawing on a 375-wide screen.
- **Money.**
  - Every amount on the cart screen is a server figure. The client never adds, subtracts or multiplies money (`DL-37` (19)).
  - The minimum's bar is the only computed value: its fraction `(minimum − shortfall) / minimum`, drawn and never printed.
  - Estimate amounts carry `≈` through the existing `cartLineEstimate` ("≈ {amount}").
- **Large text.** Every new or rebuilt screen state has a widget test at 320×640 with `textScaleFactorTestValue = 2`, in `uz` and `ru`, without an exception. Pattern: `test/features/catalog/customer_home_test.dart:236-248`.
- **No new packages.** No new package on either side; `pubspec.lock` and `composer.lock` stay unchanged.
- **Localization.** Generated l10n is regenerated, never hand-edited. Texts are in Uzbek (the template) and Russian, exactly as listed in each task.
- **Decisions.** `DL-84` (Owner) and `DL-85` (agent) go into `docs/DECISIONS.md`. Each `DL-85` item is written by the task that implements it, and the affected `docs/01–09` section is updated in that same task.
- **Tests.** Never delete, skip or weaken a test. A test whose flow changed is rewritten to assert the new flow; the mapping is given in Task 3.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Two quick taps on a line's plus.** The buttons are inactive while the line's change runs, so one change is sent, not two. Task 3 test: "two quick taps send one change".
2. **A line changed or removed on another device.** A step or removal answered `404 not_found` or `409` reloads the cart and says why. Nothing crashes, and no remove sheet stays open over a line that is gone. Task 3 test: "a step on a line gone elsewhere reloads the cart".
3. **Settings not filled in yet.** The fee, the delivery or the minimum is `null`, and the screen shows only what it has. The button still opens checkout, which refuses with `checkout_configuration_incomplete` as before. Task 4 test: "unset settings hide their rows and keep checkout open".
4. **The minimum crossed by a step.** A plus that takes the subtotal past the minimum makes the notice and the reason disappear and "Оформить" active, from the server's answer alone. Task 4 test: "the answer that reaches the minimum opens checkout".
5. **Content at the extremes.** A 60-character name, a 300-character note, a quantity of 9 999,999 kg and a sum of 99 999 999 сум hold at 320×640 with text ×2: the stepper's text scales down, and nothing overflows. Task 4 test: "the cart holds at the extremes".

---

### Task 1: The server answers the charges, and the Owner's decisions

**Files:**
- Create: `backend/app/Modules/Orders/CartCharges.php`, `backend/tests/Feature/Orders/CartChargesApiTest.php`
- Modify:
  - `backend/app/Modules/Orders/Http/Resources/CartResource.php`: the constructor takes the charges, and `toArray` gets the six keys.
  - `backend/app/Modules/Orders/Http/Controllers/CartController.php:54-57`.
  - `backend/tests/Feature/Orders/CartApiTest.php:54`: the key list.
  - `docs/09-api-contracts.md` §17 (line 122), `docs/03-features.md` §8, `docs/DECISIONS.md`.

**Interfaces:**
- Produces: `final readonly class CartCharges`, built by `public static function of(CartView $view, BusinessSettings $settings): self`. Its public properties:
  - `?int $serviceFeeUzs`: the current rule (`ServiceFeeCalculator`) applied to `$view->estimatedSubtotalUzs`. `null` when the chosen mode's value is unset.
  - `?string $serviceFeeKind`: `final` for a fixed fee. For a percentage, `estimate` when any available line's product is `price_mode = estimate`, `final` otherwise. `null` exactly when the fee is `null`.
  - `?int $deliveryFeeUzs`: `delivery_fee_uzs` as set.
  - `?int $estimatedTotalUzs`: `MoneyCalculator::sum(subtotal, fee, delivery)`. `null` when the fee or the delivery is `null`.
  - `?int $minimumOrderUzs`: `minimum_order_uzs` as set.
  - `?int $minimumOrderShortfallUzs`: `max(0, minimum − subtotal)`. `null` exactly when the minimum is `null`.
- The answer's keys, in this order: `id, items, item_count, estimated_subtotal_uzs, service_fee_uzs, service_fee_kind, delivery_fee_uzs, estimated_total_uzs, minimum_order_uzs, minimum_order_shortfall_uzs`.

- [ ] **Step 1: Failing tests** in `CartChargesApiTest`.
  - Setup: 15 % markup, as in `CartApiTest`. Settings are written with `DB::table('business_settings')->where('id', BusinessSettings::SINGLETON_ID)->update([...])`. Tomatoes: market 16 000, customer 18 400.
  - `test_the_cart_answers_what_checkout_would_charge`:
    - settings: fixed fee 3 000, delivery 12 000, minimum 50 000;
    - cart: tomatoes 1.5;
    - answer: `estimated_subtotal_uzs` 27 600, `service_fee_uzs` 3 000, `service_fee_kind` `final`, `delivery_fee_uzs` 12 000, `estimated_total_uzs` 42 600, `minimum_order_uzs` 50 000, `minimum_order_shortfall_uzs` 22 400.
  - `test_a_percentage_fee_of_an_estimate_is_an_estimate`: percentage 5.00 on the same cart gives fee 1 380, kind `estimate`, total 40 980.
  - `test_the_shortfall_is_zero_once_the_minimum_is_reached`: minimum 20 000 gives shortfall 0.
  - `test_a_line_no_longer_sold_is_outside_the_charges`:
    - lines: tomatoes 1.5 and a second product, made unavailable the way `CartApiTest::test_a_line_whose_product_became_unavailable_stays_marked_and_may_only_be_removed` does;
    - percentage 10.00;
    - fee 2 760, on 27 600 only.
  - `test_unset_settings_answer_null`:
    - delivery `null` gives `delivery_fee_uzs` and `estimated_total_uzs` `null`, while the fee is still given;
    - minimum `null` gives `null` minimum and shortfall;
    - fixed mode with `service_fee_fixed_uzs` `null` gives fee and kind `null`.
  - `test_every_cart_answer_carries_the_charges`: add (201), change (200) and remove (200) each answer the six keys.
  - In `CartApiTest:54`, the asserted key list becomes the ten keys above.

  Run `docker compose -f docker/compose.yaml exec app php artisan test --filter=Cart`. Expected: FAIL.
- [ ] **Step 2: Implement** `CartCharges::of`. In `CartController::cart`, pass `CartCharges::of($view, BusinessSettings::current())` to `new CartResource($view, $charges)`.
- [ ] **Step 3: Run** the filter, `pint --test` and `phpstan analyse`. Expected: PASS.
- [ ] **Step 4: Docs.**
  - **`docs/09` §17.** After "…and the subtotal over the available lines", add: "It also answers what checkout would charge now (`DL-85` item 1): `service_fee_uzs` by the current rule on that subtotal, with `service_fee_kind` (`final`, or `estimate` for a percentage of an estimate); `delivery_fee_uzs`; `estimated_total_uzs`, the three together; `minimum_order_uzs` and `minimum_order_shortfall_uzs`, what the subtotal lacks, `0` once reached. A field is `null` while its setting is unset (`BR-SET-002`); the total is then `null` too. Checkout stays the authority." Also add the six keys to the answer's shape.
  - **`docs/03` §8.** "…and sees current customer prices" becomes "…and sees current customer prices, the service and delivery fees, the estimated total and what is missing to the minimum order".
  - **`docs/DECISIONS.md`.** Append both entries:

```markdown
## DL-84 — Cart and address, kit stage 4 (2026-10-17, Owner)

The Owner approved the drawing `kit/04-korzina-adres.dc.html`.

1. **"Добавьте к заказу" in the cart** shows the recommended products (`DL-78` item 2) not yet in the cart, and is absent when none is left. The cart has no flag of its own.
2. **Google Maps takes the Customer's address**, replacing Yandex MapKit (interview 5.2, `DL-36`). The Customer either puts the pin on the map or types the address in words. A typed address is looked up and the pin placed there for the Customer to check; when nothing is found, the Customer places the pin. The pin stays required (`BR-CHK-002`), so the service area is still checked.
3. **Couriers navigate with Yandex Navigator**, which works better in Uzbekistan and is free on their phones. The Courier's order shows the full address with "Открыть в Яндексе", a route to the pin, and "Скопировать адрес".
4. **The Google Maps key** is created by the Owner in Google Cloud. Items 2 to 4 are built in stage 4b, which updates `docs/03`, `docs/04`, `docs/06` and `docs/07`; until then those documents still name Yandex MapKit.

## DL-85 — The cart, kit stage 4a (2026-10-17, agent)

1. **The cart answers what checkout would charge now**: the service fee by the current rule on the subtotal of the available lines, marked `estimate` when it is a percentage of an estimate; the delivery fee; their total with the subtotal; the minimum order and what is missing to reach it, `0` once reached. A field is `null` while its setting is unset (`BR-SET-002`); checkout stays the authority and refuses as before. The client shows these figures and sums nothing (`DL-37` (19)); the minimum's bar is drawn from them.
```

- [ ] **Step 5: Commit**: `feat(cart): the cart answers the fees, the total and the minimum`.

---

### Task 2: The client reads the charges

**Files:**
- Modify:
  - `frontend/lib/features/cart/domain/cart.dart`: `Cart`.
  - `frontend/lib/features/cart/data/cart_api.dart`: `parseCart`.
  - `frontend/test/support/fake_cart_repository.dart`: `cartJson` and `cartOf`.
- Test: `frontend/test/features/cart/data/cart_api_test.dart`.

**Interfaces:**
- Consumes: Task 1's ten keys.
- Produces, on `Cart` (all `required` in the constructor):
  - fields `int? serviceFeeUzs`, `bool serviceFeeIsEstimate`, `int? deliveryFeeUzs`, `int? estimatedTotalUzs`, `int? minimumOrderUzs`, `int? minimumShortfallUzs`;
  - getters:
    - `int get availableCount`: the lines that are available;
    - `bool get hasUnavailable`;
    - `bool get belowMinimum`: `(minimumShortfallUzs ?? 0) > 0`;
    - `bool get canCheckout`: `lines.isNotEmpty && !hasUnavailable && !belowMinimum`.
- Produces, in the test support: `cartJson(lines, {int? subtotal, int? serviceFee, String serviceFeeKind = 'final', int? deliveryFee, int? total, int? minimum, int? shortfall})`, and `cartOf` with the same named parameters.
  - `service_fee_kind` is emitted as `null` when `serviceFee` is `null`.
  - `total` defaults to subtotal + fee + delivery when both fees are given, `null` otherwise.
  - `shortfall` defaults to `max(0, minimum − subtotal)` when `minimum` is given.
  - With no named charges, every new field is `null`, so existing tests read a cart whose settings are unset.

- [ ] **Step 1: Failing tests** in `cart_api_test.dart`.
  - It parses the six figures of Task 1's first case, and `serviceFeeIsEstimate` for `estimate`.
  - It parses all-`null` charges.
  - Each of these throws `FormatException`:
    - a kind without a fee;
    - a fee without a kind;
    - the kind `free`;
    - a total while the delivery is `null`;
    - no total while both fees are given;
    - a negative amount;
    - a shortfall without a minimum;
    - a shortfall greater than the minimum.

  Run `flutter test test/features/cart`. Expected: FAIL.
- [ ] **Step 2: Implement** the fields, the getters and the checks in `parseCart`. Update `cartJson`/`cartOf`.
- [ ] **Step 3: Run** `flutter test test/features/cart test/features/catalog test/features/checkout` and `flutter analyze`. Expected: PASS.
- [ ] **Step 4: Commit**: `feat(cart): read the cart's fees, total and minimum`.

---

### Task 3: The cart's lines, the stepper and the remove sheet

**Files:**
- Create:
  - `frontend/lib/features/cart/presentation/cart_line_tile.dart`
  - `frontend/lib/features/cart/presentation/cart_line_stepper.dart`
  - `frontend/lib/features/cart/presentation/remove_line_sheet.dart`
- Modify:
  - `frontend/lib/features/cart/presentation/cart_screen.dart`: delete `_LineTile` (:193-264) and `_LineEditor` (:266-378); drop `openLineId` and `_openAsked`; `kitAppBar(title: l10n.cartTitle)`; the empty state.
  - `cart_routes.dart`: no query parameter.
  - `cart_paths.dart`: delete `line()`.
  - `app_uz.arb`, `app_ru.arb`.
  - `docs/DECISIONS.md` (`DL-85` item 2).
- Test: `frontend/test/features/cart/presentation/cart_screens_test.dart`, the group 'the cart screen'.

**Interfaces:**
- Consumes: Task 2's `Cart`.
- Consumes from earlier stages:
  - `CardQuantity.next/previous` (`cart/application/card_quantity.dart`);
  - `showQuantitySheet(context, unit:, current:) → Future<String?>` (`catalog/presentation/quantity_sheet.dart`);
  - `cartLineProvider(lineId)` with `change(CartLinePatch)` / `remove()`;
  - `CartLinePatch.between`, `failureText(l10n, failure)`, `CatalogPaths.product(id)`, `OrderLabels.substitution`.
- Produces:
  - `class CartLineTile extends ConsumerStatefulWidget { const CartLineTile({required CartLine line}); }`
  - `class CartLineStepper extends StatelessWidget { const CartLineStepper({required String id, required String quantityText, required bool busy, required bool canStep, required VoidCallback onMinus, required VoidCallback onPlus, required VoidCallback onQuantity}); }`
  - `Future<bool> confirmRemoveLine(BuildContext context, CartLine line)`: `true` only on "Убрать".
- Keys:
  - `cart-line-<id>`: the tappable area of an available line;
  - `line-minus-<id>`, `line-plus-<id>`, `line-qty-<id>`;
  - `line-rule-<id>`, `line-note-<id>`, `line-sum-<id>`;
  - `cart-line-unavailable-<id>`, `remove-line-<id>`;
  - `remove-cancel`, `remove-confirm`;
  - `cart-empty`, `cart-to-catalog`.
- New strings (uz / ru):
  - `cartUnitPrice`: "{unit} uchun ≈ {price}" / "≈ {price} за {unit}"
  - `cartUnitPriceExact`: "{unit} uchun {price}" / "{price} за {unit}"
  - `cartRemoveTitle`: "Savatdan olib tashlansinmi?" / "Убрать из корзины?"
  - `cartRemoveConfirm`: "Olib tashlash" / "Убрать"
  - `cartEmptyTitle`: "Savat hozircha bo'sh" / "Корзина пока пуста"
  - `cartEmptyText`: "Katalogdan mahsulot qo'shing — yig'uvchi ularni bozordan oladi, kuryer olib keladi." / "Добавьте товары из каталога — сборщик купит их на рынке, курьер привезёт."
  - Reused: `cartLineEstimate`, `cartLineUnavailable`, `cartUnavailableHint`, `cancelButton`, `productGoneAction` ("В каталог"), `cartStepMinus`, `cartStepPlus`, `cartQuantity`.

- [ ] **Step 1: Failing tests.** Rewritten tests keep their intent.
  - **Rewritten:**
    - "shows the lines and the subtotal as the server computed them" → "shows the lines as the server priced them":
      - the stepper text `1,5 kg`;
      - `line-sum` "≈ 27 600 so'm";
      - the unit price via `cartUnitPrice`;
      - the unavailable line's tag and `remove-line-<bread>`;
      - no `cart-line-<bread>` tap target;
      - the subtotal assertion stays as it is: the server's 99 999, not the lines' sum.
    - "an edit sends only what changed, and nothing when nothing did" → "a step sends only the quantity": plus on tomatoes 1.5 sends one patch with `quantity '2'`, `noteChanged false` and `substitutionPolicy null`.
    - "the editor stays while its change runs" → "a line's buttons wait while its change runs": with `cart.hold` set, after a plus the three controls are inactive until the answer.
    - "a whole-unit line that kept its decimals is set anew":
      - piece `1.500`: minus and plus are inactive;
      - `line-qty` opens the sheet with an empty field;
      - typing `2` and confirming sends `quantity '2'`.
    - "a line is removed, and an empty cart says so": `remove-line-<bread>` removes at once with no sheet. After removing the last line, `cart-empty` shows `cartEmptyTitle`, and `cart-to-catalog` goes to `/customer`.
  - **New:**
    - "minus at the smallest step asks first":
      - piece `1`, minus → the sheet shows `cartRemoveTitle`;
      - `remove-cancel` → no remove call;
      - again, then `remove-confirm` → `cart.calls` ends with the remove of that line.
    - "minus above the step changes the quantity": piece `2` → patch `'1'`.
    - "the quantity opens the exact-amount sheet": kg `1.5`, `line-qty` → type `2,25` → patch `'2.25'`.
    - "an available line opens its product": tap `cart-line-<id>` → location `/customer/products/<productId>`.
    - "the rule and the note show only when set": `allowSimilar` with no note shows neither key; `contactBefore` with the note "без вмятин" shows both.
    - "two quick taps send one change" (Review Focus 1): with `hold`, two plus taps → `patches.length == 1`.
    - "a step on a line gone elsewhere reloads the cart" (Review Focus 2): `cart.failure` = an `ApiRefusal` with status 404 and code `not_found`, built as the other cart tests build refusals; plus → a snackbar with `failureText`, and the cart is asked for again (`calls` gains `cart`). The same failure on `remove-confirm` closes the sheet.

  Run `flutter test test/features/cart`. Expected: FAIL.
- [ ] **Step 2: Implement.**
  - **`CartLineTile`** draws the line as on drawing 19:
    - an 84×84 picture on `KitColors.card`, radius 16;
    - the name (14/500, at most 2 lines);
    - the unit price, muted;
    - the rule row (`Icons.call_outlined` for `contactBefore`, `Icons.block` for `removeIfUnavailable`), shown only when the rule is not `allowSimilar`;
    - the note row (`Icons.chat_bubble_outline`, «note», 2 lines);
    - the bottom row: `line-sum` (15/700) on the left, the stepper on the right.

    Lines are separated by a 1 px `KitColors.line` divider. Price and sum use the `≈` forms for `PriceMode.estimate` and the exact forms otherwise.
  - **An unavailable line** (drawing 19б):
    - the picture at 40 % opacity through a greyscale `ColorFiltered`;
    - the name in `KitColors.muted`;
    - the tag `cartLineUnavailable` in `KitColors.danger` on `KitColors.field`, radius 6;
    - the bottom row: the quantity, muted, and the outlined "Убрать" in danger.

    It is not tappable. A box with `cartUnavailableHint` and `Icons.error_outline` in danger follows the lines.
  - **Steps.**
    - Plus uses `CardQuantity.next`; when it equals the current quantity, nothing is sent.
    - Minus uses `CardQuantity.previous`; on `null` it calls `confirmRemoveLine`, then `remove()`.
    - The quantity opens `showQuantitySheet` and sends a change only when the quantity differs.
    - A line whose quantity does not fit its unit (`QuantityRules.normalize(unit, quantity) == null`) has `canStep: false`.
    - Every action goes through `cartLineProvider(line.id)`; the controls are inactive while it `isBusy`.
    - A `null` answer shows `failureText` in a snackbar, as `KitProductCard._change` does; the controller already reloads the cart.
  - **`CartLineStepper`** (drawing 19):
    - 116×36, a 1 px `KitColors.primary` border, radius 12;
    - minus and plus are 36×36 `IconButton`s with `KitColors.primary` 18 px icons and the existing tooltips;
    - the quantity text (13/600) is tappable, wrapped in `FittedBox(fit: BoxFit.scaleDown)`, with the semantics label `cartQuantity`.
  - **`confirmRemoveLine`** (drawing 20):
    - a white sheet, radius 28, with a drag handle;
    - the title `cartRemoveTitle` (17/700) over a divider;
    - the 72×72 picture, the name, and "{quantity} {unit} · ≈ {line sum}";
    - two 54-tall buttons in a row: `cancelButton` outlined and `cartRemoveConfirm` primary;
    - dismissing the sheet answers `false`.
  - **The empty state** (drawing 19а):
    - a 96 circle on `KitColors.primaryWash` with `Icons.shopping_basket_outlined` in `primaryDark`;
    - `cartEmptyTitle` (18/700) and `cartEmptyText` (13, muted, centred);
    - a primary `productGoneAction` button that goes to `AppPaths.customer`.
  - Keep the subtotal text and the "go to checkout" button as they are until Task 4 replaces them. Keep `ActiveModeBar` and the unconfirmed-order banner.
- [ ] **Step 3: Run** `flutter test test/features/cart test/features/catalog`, `flutter analyze` and the format check. Expected: PASS.
- [ ] **Step 4: Docs.** Append `DL-85` item 2:

```markdown
2. **The cart's lines follow the kit**: a line steps as the card does (`DL-80` item 2), the quantity opens the exact-amount sheet, and a minus at the smallest step asks before removing the line (drawing 20); a line no longer sold is removed with one tap, which cannot be an accident. Tapping a line opens its product, where the rule and the note are changed (`DL-83` item 5); the cart's own line editor and its `?line=` link are gone. The rule shows on the line only when it is not the default, and the note when there is one.
```

- [ ] **Step 5: Commit**: `feat(cart): kit lines with the stepper and the remove sheet`.

---

### Task 4: The amounts, the minimum, "Добавьте к заказу", the address and the footer

**Files:**
- Create in `frontend/lib/features/cart/presentation/`:
  - `cart_summary.dart`
  - `cart_minimum_notice.dart`
  - `cart_address_card.dart`
  - `cart_footer.dart`
- Modify:
  - `frontend/lib/features/catalog/presentation/recommended_row.dart`
  - `cart_screen.dart`
  - `app_uz.arb`, `app_ru.arb`: add the keys below; delete `cartSubtotal` if nothing else uses it.
  - `docs/04-user-flows.md` §6, `docs/DECISIONS.md` (`DL-85` item 3), `tasks/REDESIGN_CUSTOMER.md`.
- Test:
  - `frontend/test/features/cart/presentation/cart_screens_test.dart`;
  - `frontend/test/features/catalog/customer_home_test.dart`: the row on the home is unchanged.

**Interfaces:**
- Consumes: Task 2's `Cart` getters and Task 3's tile.
- Consumes from earlier stages: `deliveryAddressProvider`, `showDeliveryAddressSheet(context)`, `addDeliveryAddress(router:, container:)`, `addressesProvider` (`features/addresses`), `AppPaths.customerCheckout`.
- Produces:
  - `RecommendedRow({String? title, Set<String> excludedProductIds = const <String>{}, bool showAll = true, String rowKey = 'recommended-row'})`. The excluded products are dropped before the first `shown` are taken. The row is absent when nothing is left. Without "Все" when `showAll` is false.
  - `CartSummary({required Cart cart})`, `CartMinimumNotice({required Cart cart})`, `CartAddressCard()`, `CartFooter({required Cart cart})`.
- Keys:
  - `cart-subtotal`, `cart-delivery`, `cart-service-fee`, `cart-total`, `cart-estimate-note`;
  - `cart-minimum`, `cart-minimum-bar`;
  - `cart-add-more`;
  - `cart-address`, `cart-address-change`;
  - `cart-why`, `go-to-checkout`.
- New strings (uz / ru):
  - `cartGoods`: "Mahsulotlar ({count})" / "Товары ({count})"
  - `cartDelivery`: "Yetkazib berish" / "Доставка"
  - `cartServiceFee`: "Xizmat haqi" / "Сервисный сбор"
  - `cartTotal`: "Jami" / "Итого"
  - `cartEstimateNote`: "Summa taxminiy. Yakuniy summani xariddan keyin bozor narxlari bo'yicha hisoblaymiz; narx ruxsat etilganidan oshsa — sizdan so'raymiz." / "Сумма ориентировочная. Итог считаем по ценам рынка после покупки; если цена выйдет выше допустимого — спросим вас."
  - `cartMinimumShort`: "Minimal buyurtmagacha {amount} yetmayapti" / "До минимального заказа не хватает {amount}"
  - `cartMinimumRule`: "Mahsulotlarning minimal summasi — {amount}, yetkazib berish va xizmat haqisiz" / "Минимальная сумма товаров — {amount}, без доставки и сбора"
  - `cartWhyUnavailable`: "Avval sotuvda yo'q mahsulotlarni olib tashlang" / "Сначала уберите товары, которых нет в продаже"
  - `cartWhyMinimum`: "Minimal buyurtma — {amount}" / "Минимальный заказ — {amount}"
  - `cartAddMoreTitle`: "Buyurtmaga qo'shing" / "Добавьте к заказу"
  - `cartDeliveryTo`: "Yetkazish:" / "Доставка:"
  - Reused: `editButton` ("Изменить"), `deliveryAddressAdd`, `deliveryAddressEmptyHint`, `deliveryAddressRetry`, `checkoutGo`.

- [ ] **Step 1: Failing tests.**
  - **Rewritten:** in "shows the lines as the server priced them" (Task 3), the subtotal assertion now reads `cart-subtotal` as "≈ 99 999 so'm", still the server's figure and not the lines' sum.
  - **New:** "the amounts are the server's":
    - charges: subtotal 61 410, delivery 12 000, fee 3 000 `final`, total 76 410;
    - shown: "≈ 61 410 so'm" in `cart-subtotal`, "12 000 so'm" in `cart-delivery`, "3 000 so'm" in `cart-service-fee`, "≈ 76 410 so'm" in `cart-total`;
    - the footer button text contains "≈ 76 410" and `checkoutGo`;
    - with fee 1 380 `estimate`, `cart-service-fee` shows "≈ 1 380 so'm".
  - **New tests:**
    - "unset settings hide their rows and keep checkout open" (Review Focus 3): all charges `null` → only `cart-subtotal`; no `cart-total`; the button reads `checkoutGo` alone, is active, and pushes `/customer/checkout`.
    - "a short subtotal shows the minimum and closes checkout": minimum 50 000, shortfall 35 165 →
      - `cart-minimum` shows `cartMinimumShort("≈ 35 165 so'm")` and `cartMinimumRule("50 000 so'm")`;
      - `cart-minimum-bar`'s value is `(50 000 − 35 165) / 50 000`;
      - `cart-why` shows `cartWhyMinimum`;
      - `go-to-checkout` is inactive.
    - "the answer that reaches the minimum opens checkout" (Review Focus 4): from the short cart, plus answers shortfall 0 → no `cart-minimum` and no `cart-why`; the button is active.
    - "a line no longer sold closes checkout with its reason": `cart-why` shows `cartWhyUnavailable`, and the button is inactive.
    - "Добавьте к заказу leaves out what is in the cart":
      - featured products A, B and C, with A in the cart → `cart-add-more` shows the cards of B and C only;
      - "+" on B → `cart.added.single.productId == B`, and B leaves the row;
      - with A, B and C all in the cart → no `cart-add-more`.
    - "the address card shows and changes the delivery address":
      - with the address labelled "Uy" → `cart-address` shows "Uy" and its `streetLine`;
      - `cart-address-change` → `delivery-address-sheet`;
      - with no address → `deliveryAddressAdd`.
    - "the cart holds at the extremes" (Review Focus 5): at 320×640, text ×2, `uz` and `ru` →
      - a 60-character name, a 300-character note, quantity `9999.999` kg, line sum 99 999 999, total 99 999 999 → no exception;
      - also the empty, the unavailable and the short cart each hold.
  - **In `customer_home_test.dart`**: the home's row still shows "Все", with its old key and title.

  Run `flutter test test/features/cart test/features/catalog`. Expected: FAIL.
- [ ] **Step 2: Implement.**
  - **The screen's scrolling order:** lines → unavailable box → `CartMinimumNotice` → `RecommendedRow(title: l10n.cartAddMoreTitle, excludedProductIds: {the lines' product ids}, showAll: false, rowKey: 'cart-add-more')` → `CartSummary` → `CartAddressCard` → bottom padding equal to the footer's height. `CartFooter` is pinned under the list.
  - **`CartSummary`** (drawing 19):
    - a 1 px `KitColors.line` top border;
    - rows of 14 px, the label in `ink2` and the value in `ink`;
    - `cartGoods(availableCount)` with "≈ subtotal";
    - delivery and fee only when not `null`; the fee with `≈` when `serviceFeeIsEstimate`;
    - a divider, then `cartTotal` 18/700 with "≈ total" when the total is not `null`;
    - `cartEstimateNote`, 12 px muted, with `Icons.info_outline`.
  - **`CartMinimumNotice`** (drawing 19в), only when `belowMinimum`:
    - a `KitColors.primaryWash` box, radius 14;
    - `cartMinimumShort` with the amount bold;
    - a 6 px `LinearProgressIndicator` (`primary` on `primarySoft`, radius 3);
    - `cartMinimumRule`, 11 px muted.
  - **`CartAddressCard`** (drawing 19):
    - a white card, radius 16, the kit's soft shadow;
    - a 44 `primaryWash` square with `Icons.home_outlined` in `primaryDark`;
    - `cartDeliveryTo` plus the label in bold, or the `streetLine` in bold when there is no label; the `streetLine` under it, 12 px muted, only when a label exists;
    - `editButton` in `primaryDark`, which opens `showDeliveryAddressSheet`;
    - no address: `deliveryAddressAdd` with `deliveryAddressEmptyHint`, and the tap calls `addDeliveryAddress`;
    - an error: `deliveryAddressRetry`, and the tap invalidates `addressesProvider`;
    - while loading: "…".
  - **`CartFooter`** (drawing 19):
    - a white bar with the top shadow `0 -6 20 rgba(0,0,0,.06)`, padding 12/20 plus the bottom inset;
    - the optional `cart-why` line, 12 px centred: unavailable first, then the minimum;
    - the 54-tall, radius 14 button: "≈ total | Оформить →" (a 1×22 white divider, `Icons.arrow_forward`), or "Оформить →" when the total is `null`;
    - inactive (`KitColors.line` background, muted text) when `!cart.canCheckout`;
    - its tap clears the snackbars and pushes `AppPaths.customerCheckout`, as now.
  - **The old subtotal text and button** in `cart_screen.dart` go.
- [ ] **Step 3: Run** `flutter test test/features/cart test/features/catalog test/features/checkout`, `flutter analyze` and the format check. Expected: PASS.
- [ ] **Step 4: Docs.**
  - **`docs/04` §6.** Append: "The cart shows each line with its estimate and a stepper, the amounts checkout would charge, what is missing to the minimum order, the recommended products not yet in it (`DL-84`) and the delivery address; checkout opens only when every line is sold and the minimum is reached."
  - **`DL-85` item 3:**

```markdown
3. **The rest of the cart**: under the lines, the minimum's notice while the subtotal is short of it, then "Добавьте к заказу" — the home's "Рекомендуем" row without the products already in the cart, so an added product leaves the row for the lines — then the amounts, the delivery address with "Изменить", and at the bottom "≈ total | Оформить", inactive with its reason while a line is not sold or the minimum is not reached. The empty cart leads to the catalog; orders are a tab of the bottom bar.
```

  - **`tasks/REDESIGN_CUSTOMER.md`:**
    - stage 3 → "Merged (PR #93)";
    - stage 4 → "Корзина и адрес", "In Progress (4a cart; 4b address, Google map, courier)";
    - the part 1 risk about the same street and house stays until 4b;
    - add any new risk and any review finding not acted on, each with its ruling.
- [ ] **Step 5: Commit**: `feat(cart): amounts, minimum, add more, address and footer`.

---

## After the tasks

1. Run the full frontend suite through `test-runner`. Run the backend suite filtered to `Orders` and `Cart`. Then run `git diff --check`.
2. Run `branch-reviewer` (opus) with this plan, BASE `0c61069` and HEAD. Then one fix wave and a scoped re-review.
3. `/security-review`: the branch changes a backend answer.
4. Open the PR. Wait for both required checks to pass, checking by grep. Merge.
5. **Walk the real stack** on port 8001 with the emulator `barakabozor`. Before the walk, set business settings with a fixed fee, delivery and a minimum through the panel API. Then:
   1. a cart below the minimum;
   2. plus until it is reached;
   3. "Добавьте к заказу" → add;
   4. minus at 1 → the sheet → remove;
   5. archive a product in the panel → the line greys → "Убрать";
   6. the empty cart → "В каталог".

   Take 4–5 screenshots for the Owner. Restore `APP_URL=http://localhost:8000` in `backend/.env` afterwards.
