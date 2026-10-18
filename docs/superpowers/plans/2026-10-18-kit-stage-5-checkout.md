# Kit Stage 5 — Checkout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Customer's checkout looks and works like the approved drawings 25, 25а, 25б, 25в and 26 of `kit/05-oplata.dc.html`: one screen that shows the server's figures as soon as it opens, one "Заказать" button, and a "Заказ № N оформлен" window.

**Architecture:** Client only; the API (`docs/09` §18, §19) does not change. The application layer (`checkout_controllers.dart`: prepared checkout, preview, placement, the `DL-50` lock) stays as it is. The domain gains request equality and a "same offer" comparison. The screen is rebuilt from focused kit widgets in `features/checkout/presentation/checkout_sections.dart`, orchestrated by `CheckoutScreen`. The placed window gets its own file.

**Tech Stack:** Flutter 3.47.5, Riverpod 3, go_router, `flutter gen-l10n` (template `app_uz.arb`), Montserrat, `KitColors`.

**Spec:** `kit/05-oplata.dc.html` in the Claude Design project "BarakaBozor — стиль покупателя", approved by the Owner on 2026-10-18 ("да"). Screens:
- 25 Оформление
- 25а Мы закрыты
- 25б Товар закончился
- 25в Сумма обновилась
- 26 Заказ оформлен

Removed from the kit with the drawing: promo codes, the discount, the in-app card form and "Оплата прошла". Promotions are post-MVP (`docs/01` §20); online payment is Wave 5 (`docs/06` §2, `DL-37` (3)). No Owner decision is needed. The engineering rules are `DL-89` (agent), written in Task 4.

## Global Constraints

- Branch `task/kit-5-checkout` from `main` `13cdf43`. Never commit to `main`.
- **Flutter.** Use `G:/tools/flutter/bin/flutter` with `TEMP`/`TMP` = `G:\tools\tmp`, run from `frontend/`. Run `flutter analyze` and `dart format --set-exit-if-changed lib test`.
- **No server change.** Nothing under `backend/` changes; `pubspec.lock` stays unchanged; no new package.
- **Kit look.** Colours only from `KitColors`; Montserrat; sizes follow the drawing on a 375-wide screen: side padding 20, cards radius 16 with the cart's shadow (`0x14000000`, blur 12, offset 0/2), icon wells 44×44 radius 12 on `primaryWash`, buttons 54 high radius 14, section headings 16 / w700.
- **Money.** Every amount is the preview's. The client never adds or computes money. Estimate amounts use `cartLineEstimate` ("≈ {amount}"); a `final` total is shown without "≈".
- **Placement safety.** The `DL-50` rules stay: a confirmation whose outcome is unknown locks the address and the wish and only the same confirmation may go again. A token is placed only when its request equals the current inputs.
- **Large text.** Every new or rebuilt state has a widget test at 320×640 with `textScaleFactorTestValue = 2`, in `uz` and `ru`, without an exception (pattern: the existing last test of `checkout_screen_test.dart`).
- **Localization.** Edit `app_uz.arb` and `app_ru.arb` only, then `flutter gen-l10n`; generated files are never hand-edited. Texts exactly as Task 1 lists them.
- **Tests.** Never delete, skip or weaken a test. A test whose flow changed is rewritten to assert the new flow; Task 3 gives the mapping.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **The wish typed after the figures came.** "Заказать" previews again with the new wish and never places the token made for the old one. Task 3 test: "a wish typed after the preview is previewed before it is placed".
2. **The chosen address removed meanwhile.** The checkout never moves to another address by itself: the card says the address is gone, the figures go and "Заказать" is inactive until the Customer picks one. Task 3 test: "a held address that disappears is not replaced".
3. **Two quick taps on "Заказать", or a tap while figures are coming.** One placement is sent. Task 3 test: "two quick taps place once".
4. **The first preview fails (no network).** The footer shows the failure with "Заказать" active; the tap previews again and shows the figures. It does not place figures the Customer has not seen. Task 3 test: "after a failed first preview the tap only shows the figures".
5. **A long cart at the extremes.** Twelve lines, a 60-character address and a total of 99 999 999 сум hold at 320×640 with text ×2: the strip shows four pictures and "+8", and nothing overflows. Task 2 test: "the sections hold at the extremes".

---

### Task 1: Request equality, the same-offer rule and the texts

**Files:**
- Modify: `frontend/lib/features/checkout/domain/checkout.dart`
- Modify: `frontend/lib/core/localization/l10n/app_uz.arb`, `frontend/lib/core/localization/l10n/app_ru.arb` (then `flutter gen-l10n`)
- Test: `frontend/test/features/checkout/domain/checkout_test.dart` (create)

**Interfaces:**
- Produces:
  - `CheckoutRequest` gets `operator ==` and `hashCode` over `addressId`, `paymentMethod`, `deliveryTimeNote`.
  - `bool CheckoutPreview.sameOfferAs(CheckoutPreview other)`: true when the two previews promise the same order. It compares the lines pairwise, in order, by `cartItemId`, `quantity` and `lineTotalUzs`, plus the line count. It also compares `merchandiseSubtotalUzs`, `serviceFeeUzs`, `deliveryFeeUzs`, `totalUzs`, `totalKind`, `outsideWorkingHours` and `opensAt`. It ignores `token`, `tokenExpiresAt` and `deliveryTimeNote`.
  - The l10n getters listed in Step 3.

- [ ] **Step 1: Write the failing tests** in `test/features/checkout/domain/checkout_test.dart`. Build previews with `CheckoutApi.parsePreview(previewJson(...))` from `test/support/fake_checkout_repository.dart`.
  - `'requests with the same address, method and wish are equal'`: equal and the same `hashCode`; a different wish (`null` vs `'после 18:00'`) is not equal; a different address is not equal.
  - `'a new token and expiry is the same offer'`: `previewJson(token: 'token-1')` vs `previewJson(token: 'token-2')` → `isTrue`.
  - `'a different line total, fee, total, kind, hours or opening time is another offer'`: one case per field → `isFalse`.
  - `'a different line set is another offer'`: an extra line, and a changed quantity → `isFalse`.

  To build these, `previewJson` gains optional parameters `int lineTotal = 27600`, `int total = 47600`, `int deliveryFee = 15000` and `List<Map<String, Object?>>? lines`. The defaults keep today's JSON byte for byte.

  Run `flutter test test/features/checkout/domain`. Expected: FAIL (`sameOfferAs` not defined).

- [ ] **Step 2: Implement** the equality and `sameOfferAs` in `checkout.dart`. Run the same command. Expected: PASS.

- [ ] **Step 3: Texts.** Add to both ARB files; `uz` is the template, so its entries carry the `@` metadata with placeholders, as the file does today.

  | Key | uz | ru |
  |---|---|---|
  | `checkoutWhere` | Qayerga yetkazamiz | Куда привезти |
  | `checkoutWishLabel` | Yetkazib berish bo'yicha istak | Пожелание к доставке |
  | `checkoutWishHint` | Masalan: 18:00 dan keyin, oldindan qo'ng'iroq qiling | Например: после 18:00, позвонить заранее |
  | `paymentCashTitle` | Kuryerga naqd pul | Наличными курьеру |
  | `paymentCashHint` | Qabul qilganda, aniq summani yig'ishdan keyin ko'rsatamiz | При получении, точную сумму покажем после сборки |
  | `paymentOnlineTitle` | Onlayn: Payme yoki Click | Онлайн: Payme или Click |
  | `checkoutSoon` | Tez orada | Скоро |
  | `checkoutItems` `{count}` | Mahsulotlar · {count} | Товары · {count} |
  | `checkoutOrder` | Buyurtma berish | Заказать |
  | `checkoutClosedBanner` `{time}` | Hozir biz yopiqmiz. Buyurtmani hozir qabul qilamiz, yig'ib, soat {time} da ochilgandan keyin yetkazib beramiz. | Сейчас мы закрыты. Заказ примем сейчас, а соберём и привезём после открытия — в {time}. |
  | `checkoutRecounted` | Rasmiylashtirayotganingizda buyurtma qayta hisoblandi. Summani tekshiring va «Buyurtma berish»ni yana bosing. | Пока вы оформляли, заказ пересчитали. Проверьте итог и нажмите «Заказать» ещё раз. |
  | `checkoutGoneTitle` `{count}` plural | `{count, plural, one{Mahsulot tugadi} other{Mahsulotlar tugadi}}` | `{count, plural, one{Товар закончился} few{Товары закончились} many{Товары закончились} other{Товары закончились}}` |
  | `checkoutGoneText` `{count}` plural | `{count, plural, one{Rasmiylashtirayotganingizda bozorda mahsulot tugadi:} other{Rasmiylashtirayotganingizda bozorda mahsulotlar tugadi:}}` | `{count, plural, one{Пока вы оформляли, на рынке закончился товар:} few{Пока вы оформляли, на рынке закончились товары:} many{Пока вы оформляли, на рынке закончились товары:} other{Пока вы оформляли, на рынке закончились товары:}}` |
  | `checkoutGoneHint` `{count}` plural | `{count, plural, one{Uni savatdan olib tashlang — qolganini odatdagidek rasmiylashtiramiz.} other{Ularni savatdan olib tashlang — qolganini odatdagidek rasmiylashtiramiz.}}` | `{count, plural, one{Уберите его в корзине — остальное оформим как обычно.} few{Уберите их в корзине — остальное оформим как обычно.} many{Уберите их в корзине — остальное оформим как обычно.} other{Уберите их в корзине — остальное оформим как обычно.}}` |
  | `checkoutGoneAction` | Savatga | В корзину |
  | `checkoutPlacedCash` | Yig'uvchi hammasini bozordan sotib oladi. Aniq summani yig'ishdan keyin buyurtmada ko'rsatamiz — uni kuryerga naqd berasiz. | Сборщик купит всё на рынке. Точную сумму покажем в заказе после сборки — её вы отдадите курьеру наличными. |
  | `checkoutPlacedCashFinal` `{amount}` | Yig'uvchi hammasini bozordan sotib oladi. Kuryerga naqd to'lanadi: {amount}. | Сборщик купит всё на рынке. К оплате курьеру наличными: {amount}. |
  | `checkoutPlacedOpensAt` `{time}` | Ochilgandan keyin — soat {time} da yig'ishni boshlaymiz. | Начнём собирать после открытия — в {time}. |
  | `checkoutOrderStatus` | Buyurtma holati | Статус заказа |
  | `checkoutToHome` | Bosh sahifaga | На главную |

  Change these values:

  | Key | uz | ru |
  |---|---|---|
  | `checkoutTitle` | Rasmiylashtirish | Оформление |
  | `checkoutPlaced` | Buyurtma № {number} rasmiylashtirildi | Заказ № {number} оформлен |
  | `checkoutUnconfirmed` | Buyurtma qabul qilingani aniqlanmadi. «Buyurtma berish»ni yana bosing — u ikki marta qabul qilinmaydi | Не удалось узнать, принят ли заказ. Нажмите «Заказать» ещё раз — дважды он не оформится |

  Run `flutter gen-l10n`, then `flutter analyze`. Expected: no issues.

- [ ] **Step 4: Commit**

```bash
git add frontend/lib/features/checkout/domain/checkout.dart frontend/lib/core/localization frontend/test/features/checkout/domain frontend/test/support/fake_checkout_repository.dart
git commit -m "feat(checkout): request equality, the same-offer rule and the kit texts"
```

---

### Task 2: The kit sections of the checkout

**Files:**
- Create: `frontend/lib/features/checkout/presentation/checkout_sections.dart`
- Modify: `frontend/lib/features/cart/presentation/cart_summary.dart` (make `_AmountRow` public as `SummaryAmountRow` and extract the note row as public `EstimateNote`; `CartSummary` uses both, its output unchanged)
- Test: `frontend/test/features/checkout/presentation/checkout_sections_test.dart` (create)

**Interfaces:**
- Consumes: Task 1 texts; `ProductImage` (`core/widgets/product_image.dart`); `formatPhone` (`core/formatting/phone_format.dart`); `addressFullLine` / `addressApartmentPart` (`core/formatting/address_format.dart`); `KitColors`.
- Produces (all `StatelessWidget`s in `checkout_sections.dart`; callbacks are `null` when inactive):
  - `CheckoutClosedBanner({required String opensAt})` — drawing 25а, key `checkout-closed`, `warningWash` with a `schedule` icon in `warning`, text `checkoutClosedBanner(opensAt)`, `liveRegion`.
  - `CheckoutDeliveryCard({required Address? address, required bool gone, required CustomerProfile? recipient, required VoidCallback? onChange})`. This is drawing 25's "Куда привезти" card, key `checkout-address`.
    - First row: a home icon well, the label (or `streetLine` when unlabelled) in w700, the full line under it (`addressFullLine`, max 2 lines), and the text button "Изменить" (`editButton`, key `checkout-address-change`).
    - When `address == null`: the title is `deliveryAddressAdd` with `deliveryAddressEmptyHint` under it. When `gone`: the title is `errorAddressGone` in `danger`.
    - Second row, only when `recipient?.fullName` is not null (key `checkout-recipient`): a person icon well, the name in w700, `formatPhone(phone)` under it.
  - `CheckoutWishField({required TextEditingController controller, required bool enabled, required ValueChanged<String> onChanged})`. This is the "Пожелание к доставке" field, key `checkout-delivery-wish`.
    - The label `checkoutWishLabel` sits above the field; the hint is `checkoutWishHint`; it has 1–3 lines on a `field` fill with radius 14 and no border.
    - The counter reads `'$n / 160'`, where `n = trimLikeServer(text).runes.length`.
    - The validator answers `fieldTooLong(160)` above 160, as today.
  - `CheckoutPaymentCards()` — `RadioGroup<PaymentMethod>` with cash selected. Each card is a kit `DecoratedBox` (radius 16, the card shadow) around a `RadioListTile<PaymentMethod>` with the icon as `secondary` and the radio at the end. Two cards:
    - Key `pay-cash`: `paymentCashTitle` and `paymentCashHint`, a `payments_outlined` icon, a 1.5 px `primary` outline.
    - Key `pay-online`: `enabled: false`, `paymentOnlineTitle` and `checkoutOnlineUnavailable`, a `credit_card` icon at opacity 0.5, and the chip `checkoutSoon`.
  - `CheckoutItemsStrip({required List<PreviewLine> lines, required Map<String, String?> imageByCartItem, required VoidCallback onChange})`.
    - The heading reads `checkoutItems(lines.length)`, with "Изменить" (`editButton`, key `checkout-items-change`) on the right.
    - Below it: 64×64 tiles on `card` with radius 14 holding `ProductImage`. Under each tile, `QuantityRules.display(quantity)` and the unit label in 11 / w600.
    - The strip shows at most four tiles. When there are more lines, a fifth tile reads `'+${lines.length - 4}'`, key `checkout-items-more`.
  - `CheckoutAmounts({required CheckoutPreview preview, int? replacedTotalUzs})`.
    - Rows in the cart's order and style: `cartGoods(lines.length)`, `cartDelivery`, `cartServiceFee`, a divider, then `cartTotal` (keys `checkout-subtotal`, `checkout-delivery`, `checkout-service-fee`, `checkout-total`). Then `EstimateNote`.
    - When `replacedTotalUzs != null`, the `checkoutRecounted` notice (key `checkout-refreshed`, `primaryWash`, a `sync` icon, `liveRegion`) sits above the rows. The total row shows the old total struck through in `muted` 13 / w500 before the new one.
    - Estimate amounts go through `cartLineEstimate`. A `final` total shows the plain amount.
  - `CheckoutFooter({required int? totalUzs, required bool estimate, required bool busy, required String busyLabel, required VoidCallback? onOrder, Widget? message})`.
    - A white bar with the cart footer's shadow. `message` (a refusal or a note) sits above the button.
    - The button (key `checkout-confirm`) is `FilledButton` 54 high, radius 14, `primary`. It reads `≈ total | checkoutOrder`, or only `checkoutOrder` when `totalUzs == null`, inside a `FittedBox(scaleDown)`.
    - While `busy`, it shows an 18 px `CircularProgressIndicator` with `semanticsLabel: busyLabel` in place of the text.
  - `Future<void> showCheckoutGoneSheet(BuildContext context, {required List<CartLine> lines, required VoidCallback onToCart})`. This is drawing 25б.
    - A kit modal sheet (white, top radius 28, drag handle) titled `checkoutGoneTitle(n)`, with a close button.
    - Then `checkoutGoneText(n)`, then one `field` row per line: a greyed `ProductImage` (`ColorFiltered` greyscale, opacity 0.4), the name, and `catalogUnavailable` in `danger`.
    - Then `checkoutGoneHint(n)` and the primary button `checkoutGoneAction` (key `checkout-gone-to-cart`), which closes the sheet and calls `onToCart`.

- [ ] **Step 1: Write the failing widget tests** in `checkout_sections_test.dart`. Each pumps the section inside `MaterialApp` with `AppLocalizations` delegates, `locale: Locale('ru')`.
  - `'the delivery card shows the address, the recipient and "Изменить"'`:
    - `find.text('Дом')`, the full line, `'Азиз Каримов'` and `'+998 90 123 45 67'`.
    - Tapping `checkout-address-change` calls `onChange` once.
  - `'the delivery card without an address offers to add one, a gone one says so'`: `deliveryAddressAdd` is found; with `gone: true`, `errorAddressGone` is found.
  - `'the recipient row hides without a name'`: `checkout-recipient` finds nothing.
  - `'online is shown, inactive, with "Скоро"'`:
    - `tester.widget<RadioListTile<PaymentMethod>>(find.byKey(const ValueKey<String>('pay-online'))).enabled` is `false`.
    - `find.text('Скоро')` is found.
  - `'the strip shows four pictures and +8 for twelve lines'`: four `ProductImage`s and `'+8'`.
  - `'the amounts are the preview's, with ≈ on an estimate'`: `checkout-total` reads `'≈ 47 600 сум'` (`cartLineEstimate(MoneyFormat.uzs(47600, AppLanguage.ru))`). For a final total, the text has no `≈`.
  - `'a recount shows the notice and the struck old total'`: `checkout-refreshed` is found; the text `cartLineEstimate(MoneyFormat.uzs(47600, AppLanguage.ru))` for `replacedTotalUzs: 47600` (with a preview total of 48 600) has `TextDecoration.lineThrough`.
  - `'the footer reads total | Заказать and is inactive while busy'`. `busy: true` shows a `CircularProgressIndicator` with the label. With `onOrder: null`, `tester.widget<FilledButton>(...).onPressed` is `null`.
  - `'the gone sheet names each product and leads to the cart'`: two cart lines → `'Товары закончились'` and both names; tapping `checkout-gone-to-cart` closes the sheet and calls `onToCart` once.
  - `'the wish counter counts what the server keeps'`: entering `'  после 18:00  '` shows `'11 / 160'`.
  - `'the sections hold at the extremes'`: at 320×640 with text ×2, in `uz` and `ru`, all sections in a `ListView` plus the footer. The inputs are twelve lines, a 60-character street, the recipient, `total 99 999 999`, a recount and the closed banner. Expect `tester.takeException()` to be `null`.

  Run `flutter test test/features/checkout/presentation/checkout_sections_test.dart`. Expected: FAIL (file not found).

- [ ] **Step 2: Implement** `checkout_sections.dart` and the `cart_summary.dart` extraction. Run that test plus `flutter test test/features/cart`. Expected: PASS (the cart tests prove `CartSummary` is unchanged).

- [ ] **Step 3: Run** `flutter analyze` and the format check. Expected: clean.

- [ ] **Step 4: Commit**

```bash
git add frontend/lib/features/checkout/presentation/checkout_sections.dart frontend/lib/features/cart/presentation/cart_summary.dart frontend/test/features/checkout/presentation/checkout_sections_test.dart
git commit -m "feat(checkout): the kit sections of drawings 25-25в"
```

---

### Task 3: The checkout screen

**Files:**
- Modify (rewrite the presentation; keep `CheckoutRefusal`'s mapping): `frontend/lib/features/checkout/presentation/checkout_screen.dart`
- Modify: `frontend/test/features/checkout/presentation/checkout_screen_test.dart`
- Modify: `frontend/test/support/app_harness.dart` (an optional `FakeProfileRepository? profile` that overrides `profileRepositoryProvider` only when given)

**Interfaces:**
- Consumes: Task 1 (`==`, `sameOfferAs`), Task 2 (all sections), the unchanged `preparedCheckoutProvider`, `checkoutPreviewProvider`, `placeOrderProvider`, `deliveryAddressProvider`, `deliveryAddressChoiceProvider`, `addressesProvider`, `currentCartProvider`, `profileControllerProvider`, `showDeliveryAddressSheet`, `addDeliveryAddress`, `kitAppBar`.
- Produces: `CheckoutScreen` (same route `/customer/checkout`). It calls `CheckoutPlacedView` from Task 4. Until Task 4 exists, it keeps the current `_Placed` view.

**Behaviour** (`DL-89` items 1–5, written in Task 4):

1. **Layout** (drawing 25). `Scaffold(backgroundColor: white, appBar: kitAppBar(title: checkoutTitle))`. The body is a `SafeArea` with `ActiveModeBar` and then a `ListView` keyed `checkout`. The list holds, in order:
   - the closed banner, when the shown preview is outside the hours with an `opensAt`;
   - the heading `checkoutWhere`, the delivery card and the wish field;
   - the heading `checkoutPayment`, `CheckoutPaymentCards`;
   - with a shown preview: the items strip and `CheckoutAmounts`.

   `CheckoutFooter` is the Scaffold's `bottomNavigationBar` inside `SafeArea(top: false)`, as the cart does. Its `message` holds the refusal (`CheckoutRefusal`, restyled to 12–13 px `danger` with its action) or the `checkoutUnconfirmed` note (key `checkout-unconfirmed`).
2. **The held address.**
   - `_addressId` starts from the sent confirmation's request. Otherwise it starts from `deliveryAddressProvider`, once, as `_adoptDeliveryAddress` does today.
   - After that it changes only when the Customer acts. A listener on `deliveryAddressChoiceProvider(account)` adopts a new non-null choice while nothing is sent: a pick in the sheet, or a new address. "Изменить" on the card opens `showDeliveryAddressSheet(context)`, or `addDeliveryAddress` when there is no address.
   - When the held id is no longer among the loaded addresses, the card is `gone`, the shown figures are dropped, the prepared checkout is cleared and "Заказать" is inactive.
3. **Figures.**
   - The screen previews post-frame on open (unless a confirmation is sent) and after every adopted address change. It asks for `CheckoutRequest(addressId, cash, trimmed wish or null)`.
   - `_shown` holds the preview on screen. It is set from every new prepared checkout and kept while the next preview runs. It is dropped on an address change.
   - Typing in the wish does not clear the prepared checkout or the figures.
4. **"Заказать"** (`_order`). The button is active when an address is held and nothing runs, or when a confirmation is sent. The form must validate.
   - When the prepared checkout is sent, or its `request ==` the current request: place it.
   - Otherwise, remember `shown = _shown` and preview the current request.
     - If the new preview `sameOfferAs(shown)`: place the new prepared checkout at once.
     - If it differs and `shown != null`: set `_replacedTotal = shown.totalUzs` (drawing 25в), and do not place.
     - If `shown == null`: just show it.
   - A placement answered `checkout_snapshot_stale` previews the same request again, once. Same offer → place it at once. Another offer → `_replacedTotal` and wait for the tap.
   - `_replacedTotal` clears on the next tap, an address change and a wish change.
5. **Refusals.**
   - `product_unavailable`, from a preview or a placement, opens `showCheckoutGoneSheet` once per refusal. Its lines are the current cart's lines whose `productId` is in `details.product_ids`. When none match, the footer shows the refusal text instead.
   - `onToCart` pops back to the cart.
   - Every other refusal shows in the footer's message, as `CheckoutRefusal` maps it today.
6. **Items strip.** It shows `_shown.lines`. The pictures come from the current cart's lines by `cartItemId`. "Изменить" pops back to the cart.
7. **Locks.** While a confirmation is sent: the card's "Изменить" and the wish are inactive, and the footer note is `checkoutUnconfirmed`.

**Test mapping** (rewrite, never drop). Old "calculate" steps disappear: the preview comes on open.

| Old test | New assertion |
|---|---|
| an address, cash, the wish, the preview, then the order | open → `checkout.previews` has one request (a-1, cash, null) → type the wish → "Заказать" → a second preview with the wish, the same offer → one placement with token-2 |
| the placed order opens over the catalog | unchanged through `checkout-open-order` (Task 3 keeps `_Placed`) |
| what a preview was asked for cannot change while it runs | with `previewHold`, the wish field and `checkout-address-change` are inactive while the preview runs |
| a retry of an unknown outcome reuses its key | unchanged, through `checkout-confirm` |
| unknown outcome waits in the cart after leaving | unchanged |
| a refused confirmation frees the checkout, new preview new key | refusal → the next tap previews (new key) |
| a stale confirmation previews again by itself and says so | stale + the same offer → placed without a second tap; stale + another total (`previewJson(total: 48600)` queued) → `checkout-refreshed`, the struck old total, no placement until the tap |
| a refused recalculation leaves no old total to confirm | a refused re-preview after a changed wish → no placement; the footer shows the refusal |
| checkout opens with the home's address / the newest | the card shows that address; the first preview's `addressId` matches |
| another address picked becomes the delivery address | pick a-2 in the sheet → `checkout.previews.last.addressId == 'a-2'`, and the card shows "Ish" |
| an address added at checkout becomes the selected one | through the sheet's "add" → the new id is previewed |
| unknown outcome keeps its address | the card's change is inactive and placements reuse the token |
| the preselected address is held: when it disappears nothing … | remove a-1 → the card is gone, no preview for a-2, `checkout-confirm` inactive |
| a chosen address since removed is not preselected / an address gone is no longer chosen | the same assertions on the card |
| each refusal has its own words | unchanged texts, now inside the footer |
| a product that cannot be ordered, with the way back | the gone sheet names "Помидоры"; `checkout-gone-to-cart` pops to `/customer/cart` |
| without an address it says so and offers to add one | the card shows `deliveryAddressAdd`; no preview is sent |
| a wish longer than 160 | no request is sent; the field shows `fieldTooLong(160)` |
| one confirmation at a time | two quick taps → `placements.length == 1` |
| a preview never sent is not kept | unchanged |
| a replay cancelled meanwhile | unchanged (`_Placed`) |
| leaving while a stale confirmation previews again | unchanged |
| a server error on confirming asks for the cart | unchanged |
| large text | rebuilt: the screen with figures, the gone sheet, a footer refusal |

New tests (Review Focus):
- `'a wish typed after the preview is previewed before it is placed'`: `placements.single.$1 == 'token-2'` and `previews.last.deliveryTimeNote == 'после 18:00'`.
- `'a held address that disappears is not replaced'`.
- `'two quick taps place once'`.
- `'after a failed first preview the tap only shows the figures'`: `previewFailure = NetworkFailure` on open → tap → `placements` is empty and `checkout-total` is found.
- `'the closed banner shows the opening time'`: `outsideHours = true` → `checkout-closed` reads `checkoutClosedBanner('08:00')`.

The fake gains `List<Map<String, Object?>> queuedPreviews`. When it is non-empty, the next preview answers its first entry (with that call's token) instead of the default.

- [ ] **Step 1: Rewrite the tests** per the mapping, and add the new ones. Run `flutter test test/features/checkout`. Expected: FAIL.
- [ ] **Step 2: Implement** the screen. Run `flutter test test/features/checkout test/features/cart test/features/addresses`. Expected: PASS.
- [ ] **Step 3: Run** `flutter analyze` and the format check. Expected: clean.
- [ ] **Step 4: Commit**

```bash
git add frontend/lib/features/checkout frontend/test/features/checkout frontend/test/support
git commit -m "feat(checkout): one kit screen that previews on open and places on one tap"
```

---

### Task 4: "Заказ оформлен", the decision and the docs

**Files:**
- Create: `frontend/lib/features/checkout/presentation/checkout_placed_view.dart`
- Modify: `frontend/lib/features/checkout/presentation/checkout_screen.dart` (use it; delete `_Placed`)
- Modify: `frontend/lib/core/localization/l10n/app_uz.arb`, `app_ru.arb` (delete keys no file uses any more, then `flutter gen-l10n`)
- Modify: `docs/DECISIONS.md` (`DL-89`), `docs/04-user-flows.md` §7
- Test: `frontend/test/features/checkout/presentation/checkout_screen_test.dart`

**Interfaces:**
- Consumes: `PlacedOrder`; the placing prepared checkout's `preview.outsideWorkingHours` and `preview.opensAt`.
- Produces: `CheckoutPlacedView({required PlacedOrder order, required String? opensAt})`. `opensAt` is non-null only when the placed preview was outside the hours.

**Behaviour** (drawing 26):
- When placed, the screen returns a `Scaffold` (no app bar, background `Color(0xFFEBEDEC)`) wrapped in `PopScope(canPop: false)`. A pop goes to `AppPaths.customer`.
- Centred, 20 from the sides, is a white card (radius 24, padding 28/20/20) holding, top to bottom:
  - a 130 circle on `primaryWash` around a 90 circle on `primary` with a white `shopping_bag_outlined` 44;
  - the title `checkoutPlaced(number)` (21 / w700, centred);
  - the body text.
  - the buttons: `checkoutOrderStatus` (primary, key `checkout-open-order`; `go(AppPaths.customer)`, then `push(customerOrder(id))` as today) and `checkoutToHome` (outlined, key `checkout-to-home`; `go(AppPaths.customer)`).
- The body text:
  - for an estimate: `checkoutPlacedCash`;
  - for a final total: `checkoutPlacedCashFinal(MoneyFormat.uzs(total))`;
  - plus `checkoutPlacedOpensAt(opensAt)` as a second paragraph when given;
  - for a replay cancelled meanwhile: the title is `checkoutPlacedCancelled(number)` and the body `totalNothingDue`.
- The card scrolls inside a `SingleChildScrollView` for large text.

**`DL-89 — The checkout, kit stage 5 (2026-10-18, agent)`**, one item each:
1. The checkout previews when it opens and after the Customer changes the address. The address is the Customer's explicit choice; a removed address is never replaced by another.
2. A wish typed after a preview is previewed before placing; a token is placed only when its request equals the current inputs.
3. Same offer means the same lines (cart item, quantity, line total), amounts, total kind, hours flag and opening time. An unchanged re-preview, after a wish change or a stale token, is placed without a second tap. A changed one shows "заказ пересчитали" with the old total struck through and waits for the tap.
4. Refusals show above the button. `product_unavailable` opens a sheet naming the products from the cart, with the way back.
5. "Заказ оформлен" replaces the screen; back goes home.
6. Online stays visible and inactive with "Скоро" until Wave 5 (`docs/06` §2, `DL-37` (3)). Promo codes, discounts and an in-app card form are not drawn (promotions post-MVP, `docs/01` §20); a saved-card question goes to the Owner with Wave 5.

**`docs/04` §7.** Step 1 says the preview is asked for when checkout opens and after an address change. Step 5 says confirming re-previews a changed wish or a stale token and places an unchanged offer without asking again (`DL-89`).

- [ ] **Step 1: Write the failing tests.**
  - `'the placed window names the order and says how to pay'`: `find.text('Заказ № 1001 оформлен')` (ru) and `checkoutPlacedCash`.
  - `'outside the hours it says when collecting starts'`: `outsideHours = true` → `checkoutPlacedOpensAt('08:00')`.
  - `'back from the placed window goes home'`: `tester.binding.handlePopRoute()` → `top(tester) == AppPaths.customer`.
  - `'"На главную" goes home'`.

  Adapt the cancelled-replay and large-text tests to the new view. Run `flutter test test/features/checkout`. Expected: FAIL.
- [ ] **Step 2: Implement** the view and use it. Then delete the ARB keys no Dart file uses any more. Check each candidate with `grep -rn "l10n\.<key>\b" lib` before deleting it: `checkoutCalculate`, `checkoutConfirm`, `checkoutAddAddress`, `checkoutNoAddress`, `checkoutClosedUntil`, `checkoutBackToCatalog`, `errorCheckoutStale`, `errorCheckoutProductsUnavailable` (only if the footer no longer uses it). `checkoutAddress`, `checkoutEstimateExplain` and `orderOpen` are used by the order screens and stay. Run `flutter gen-l10n`.
- [ ] **Step 3: Run** `flutter test`, the whole frontend suite. Expected: PASS. Then `flutter analyze` and the format check. Expected: clean.
- [ ] **Step 4: Write** `DL-89` and the `docs/04` §7 lines.
- [ ] **Step 5: Commit**

```bash
git add frontend/lib frontend/test docs/DECISIONS.md docs/04-user-flows.md
git commit -m "feat(checkout): the placed window, DL-89 and the checkout flow in docs"
```

---

## After the tasks (controller)

- `branch-reviewer` (opus) on `13cdf43..HEAD` with this plan and its Review Focus; one fix wave; a scoped re-review.
- No `/security-review`: no access, roles or server data change. The Customer's own name and phone are shown only to that Customer, from `GET /customer/profile`.
- PR. When it is open, set stage 5 in `tasks/REDESIGN_CUSTOMER.md` to "Merged (PR #N)" in the same branch before the merge. Wait for both required checks, then merge.
- Walk on the emulator: open, wish, "Заказать", the placed window, closed hours (set the working hours in the panel), and a product archived during checkout. Take 4–5 screenshots for the Owner.
