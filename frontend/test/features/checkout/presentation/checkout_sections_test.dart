import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/product_image.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:baraka_bozor/features/cart/domain/cart.dart';
import 'package:baraka_bozor/features/checkout/data/checkout_api.dart';
import 'package:baraka_bozor/features/checkout/domain/checkout.dart';
import 'package:baraka_bozor/features/checkout/presentation/checkout_footer.dart';
import 'package:baraka_bozor/features/checkout/presentation/checkout_sections.dart';
import 'package:baraka_bozor/features/profile/domain/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_checkout_repository.dart';

Finder byKey(String key) => find.byKey(ValueKey<String>(key));

Address address({String? label = 'Дом', String street = 'Чиланзар'}) => Address(
  id: 'a-1',
  label: label,
  point: const GeoPoint(latitude: '41.000000', longitude: '69.000000'),
  street: street,
  house: '14',
  apartment: '5',
  landmark: null,
  deliveryNote: null,
);

const CustomerProfile aziz = CustomerProfile(
  id: 'c',
  phone: '+998901234567',
  fullName: 'Азиз Каримов',
);

CheckoutPreview previewOf({
  int lines = 1,
  int total = 47600,
  String kind = 'estimate',
}) => CheckoutApi.parsePreview(
  previewJson(
    total: total,
    totalKind: kind,
    lines: <Map<String, Object?>>[
      for (int i = 0; i < lines; i++)
        <String, Object?>{
          'cart_item_id':
              '0192f0a0-0000-7000-8000-0000000cc${i.toString().padLeft(3, '0')}',
          'product_id':
              '0192f0a0-0000-7000-8000-0000000cd${i.toString().padLeft(3, '0')}',
          'name_uz': 'Pomidor',
          'name_ru': 'Помидоры',
          'unit_code': 'kg',
          'quantity': '1.500',
          'price_mode': 'estimate',
          'customer_unit_price_uzs': 18400,
          'line_total_uzs': 27600,
        },
    ],
  ),
);

CartLine goneLine(String id, String name) => CartLine(
  id: id,
  productId: 'p-$id',
  nameUz: name,
  nameRu: name,
  unit: UnitCode.kg,
  priceMode: PriceMode.estimate,
  imageUrl: null,
  quantity: '1.000',
  customerNote: null,
  substitutionPolicy: SubstitutionPolicy.allowSimilar,
  isAvailable: false,
  customerUnitPriceUzs: null,
  estimatedLineTotalUzs: null,
);

MaterialApp app(Widget home, {Locale locale = const Locale('ru')}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

Widget host(Widget child) => app(
  Scaffold(
    body: SingleChildScrollView(child: Form(child: child)),
  ),
);

void main() {
  final AppLocalizations ru = lookupAppLocalizations(const Locale('ru'));
  String estimate(int amount) =>
      ru.cartLineEstimate(MoneyFormat.uzs(amount, AppLanguage.ru));

  testWidgets(
    'the delivery card shows the address, the recipient and "Изменить"',
    (WidgetTester tester) async {
      int changed = 0;
      await tester.pumpWidget(
        host(
          CheckoutDeliveryCard(
            address: address(),
            gone: false,
            recipient: aziz,
            onChange: () => changed++,
          ),
        ),
      );
      expect(find.text('Дом'), findsOneWidget);
      expect(
        find.text('Чиланзар, 14, ${ru.addressApartmentShort('5')}'),
        findsOneWidget,
      );
      expect(find.text('Азиз Каримов'), findsOneWidget);
      expect(find.text('+998 90 123 45 67'), findsOneWidget);
      await tester.tap(byKey('checkout-address-change'));
      expect(changed, 1);
    },
  );

  testWidgets(
    'the delivery card without an address offers to add one, a gone one says so',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          CheckoutDeliveryCard(
            address: null,
            gone: false,
            recipient: aziz,
            onChange: () {},
          ),
        ),
      );
      expect(find.text(ru.deliveryAddressAdd), findsOneWidget);
      await tester.pumpWidget(
        host(
          CheckoutDeliveryCard(
            address: null,
            gone: true,
            recipient: aziz,
            onChange: () {},
          ),
        ),
      );
      expect(find.text(ru.errorAddressGone), findsOneWidget);
    },
  );

  testWidgets('the recipient row hides without a name', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        CheckoutDeliveryCard(
          address: address(),
          gone: false,
          recipient: const CustomerProfile(
            id: 'c',
            phone: '+998901234567',
            fullName: null,
          ),
          onChange: () {},
        ),
      ),
    );
    expect(byKey('checkout-recipient'), findsNothing);
  });

  testWidgets('payment is one cash row and the line about online payment', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(const CheckoutPayment()));
    expect(byKey('pay-cash'), findsOneWidget);
    expect(find.byType(RadioListTile<PaymentMethod>), findsNothing);
    expect(find.byType(Radio<PaymentMethod>), findsNothing);
    expect(find.text(ru.paymentCashTitle), findsOneWidget);
    expect(find.text(ru.paymentCashHint), findsOneWidget);
    expect(
      find.descendant(
        of: byKey('pay-online-soon'),
        matching: find.text(ru.checkoutOnlineSoon),
      ),
      findsOneWidget,
    );
    expect(byKey('pay-online'), findsNothing);
    expect(
      find.descendant(
        of: byKey('pay-cash'),
        matching: byKey('pay-online-soon'),
      ),
      findsNothing,
      reason: 'the line stands outside the card',
    );
    expect(
      tester.getRect(byKey('pay-online-soon')).top,
      closeTo(tester.getRect(byKey('pay-cash')).bottom + 10, 0.5),
    );
  });

  testWidgets('with no address the link reads Добавить', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        CheckoutDeliveryCard(
          address: null,
          gone: false,
          recipient: aziz,
          onChange: () {},
        ),
      ),
    );
    expect(
      find.descendant(
        of: byKey('checkout-address-change'),
        matching: find.text(ru.checkoutAddressAdd),
      ),
      findsOneWidget,
    );
    expect(find.text(ru.editButton), findsNothing);
  });

  testWidgets('a long address is shown whole', (WidgetTester tester) async {
    final String street = 'Улица ${'длинная ' * 15}'.trim();
    expect(street.length, greaterThanOrEqualTo(120));
    await tester.pumpWidget(
      host(
        CheckoutDeliveryCard(
          address: address(label: null, street: street),
          gone: false,
          recipient: aziz,
          onChange: () {},
        ),
      ),
    );
    final Finder title = find.byWidgetPredicate(
      (Widget w) => w is Text && (w.data ?? '').startsWith(street),
    );
    expect(title, findsOneWidget);
    expect(tester.widget<Text>(title).maxLines, isNull);
    final double lineHeight = tester.getSize(find.text('Азиз Каримов')).height;
    expect(tester.getSize(title).height, greaterThan(lineHeight * 2));
  });

  Future<void> pumpCardAt(WidgetTester tester, double scale) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      host(
        CheckoutDeliveryCard(
          address: address(),
          gone: false,
          recipient: aziz,
          onChange: () {},
        ),
      ),
    );
  }

  testWidgets('at large text the link goes under the address', (
    WidgetTester tester,
  ) async {
    await pumpCardAt(tester, 1.8);
    final Rect link = tester.getRect(byKey('checkout-address-change'));
    final Rect title = tester.getRect(find.text('Дом'));
    final Rect detail = tester.getRect(
      find.text('Чиланзар, 14, ${ru.addressApartmentShort('5')}'),
    );
    expect(link.top, greaterThanOrEqualTo(detail.bottom));
    expect(link.left, title.left);
    expect(link.width, greaterThanOrEqualTo(44));
    expect(link.height, greaterThanOrEqualTo(44));
  });

  testWidgets('at normal text the link stands beside the address', (
    WidgetTester tester,
  ) async {
    await pumpCardAt(tester, 1);
    final Rect link = tester.getRect(byKey('checkout-address-change'));
    final Rect title = tester.getRect(find.text('Дом'));
    final Rect detail = tester.getRect(
      find.text('Чиланзар, 14, ${ru.addressApartmentShort('5')}'),
    );
    expect(link.left, greaterThanOrEqualTo(title.right));
    expect(link.top, lessThan(detail.bottom));
  });

  testWidgets('the strip shows four pictures and +8 for twelve lines', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        CheckoutItemsStrip(
          lines: previewOf(lines: 12).lines,
          imageByCartItem: const <String, String?>{},
          onChange: () {},
        ),
      ),
    );
    expect(find.byType(ProductImage), findsNWidgets(4));
    expect(find.text('+8'), findsOneWidget);
  });

  testWidgets("the amounts are the preview's, with ≈ on an estimate", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(CheckoutAmounts(preview: previewOf())));
    expect(tester.widget<Text>(byKey('checkout-total')).data, estimate(47600));
    await tester.pumpWidget(
      host(CheckoutAmounts(preview: previewOf(kind: 'final'))),
    );
    expect(
      tester.widget<Text>(byKey('checkout-total')).data,
      isNot(contains('≈')),
    );
  });

  testWidgets(
    "the amounts keep the struck old total, the notice is the footer's",
    (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          CheckoutAmounts(
            preview: previewOf(total: 48600),
            replacedTotalUzs: 47600,
          ),
        ),
      );
      expect(byKey('checkout-refreshed'), findsNothing);
      expect(
        tester.widget<Text>(find.text(estimate(47600))).style?.decoration,
        TextDecoration.lineThrough,
      );
    },
  );

  testWidgets('the gone sheet names each product and leads to the cart', (
    WidgetTester tester,
  ) async {
    int toCart = 0;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => showCheckoutGoneSheet(
              context,
              lines: <CartLine>[
                goneLine('1', 'Яблоки'),
                goneLine('2', 'Груши'),
              ],
              onToCart: () => toCart++,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Товары закончились'), findsOneWidget);
    expect(find.text('Яблоки'), findsOneWidget);
    expect(find.text('Груши'), findsOneWidget);
    await tester.tap(byKey('checkout-gone-to-cart'));
    await tester.pumpAndSettle();
    expect(toCart, 1);
    expect(byKey('checkout-gone-to-cart'), findsNothing);
  });

  Future<void> pumpWish(
    WidgetTester tester,
    TextEditingController controller,
  ) async {
    final FocusNode focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      host(
        CheckoutWishField(
          controller: controller,
          focusNode: focus,
          enabled: true,
          onChanged: (String _) {},
        ),
      ),
    );
  }

  Future<void> type(WidgetTester tester, int count) async {
    await tester.enterText(
      byKey('checkout-delivery-wish'),
      '  ${'a' * count}  ',
    );
    await tester.pump();
  }

  testWidgets('the counter shows from 120 characters and turns red over 160', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpWish(tester, controller);

    await type(tester, 119);
    expect(find.text('119 / 160'), findsNothing);

    await type(tester, 120);
    final TextStyle muted = tester.widget<Text>(find.text('120 / 160')).style!;
    expect(muted.color, KitColors.muted);
    expect(muted.fontSize, 11);

    await type(tester, 161);
    final TextStyle over = tester.widget<Text>(find.text('161 / 160')).style!;
    expect(over.color, KitColors.danger);
    expect(over.fontWeight, FontWeight.w600);
  });

  testWidgets('the error shows while typing', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpWish(tester, controller);
    final String tooLong = ru.fieldTooLong(160);

    await type(tester, 161);
    expect(find.text(tooLong), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(tooLong)).style!.color,
      KitColors.danger,
    );

    await type(tester, 160);
    expect(find.text(tooLong), findsNothing);
  });

  String estimate99(Locale language, int amount) =>
      lookupAppLocalizations(language).cartLineEstimate(
        MoneyFormat.uzs(
          amount,
          language.languageCode == 'uz' ? AppLanguage.uz : AppLanguage.ru,
        ),
      );

  for (final Locale language in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'the sections hold at the extremes (${language.languageCode})',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final CheckoutPreview preview = previewOf(lines: 12, total: 99999999);
        final TextEditingController wish = TextEditingController();
        addTearDown(wish.dispose);
        final FocusNode wishFocus = FocusNode();
        addTearDown(wishFocus.dispose);

        await tester.pumpWidget(
          app(
            Scaffold(
              body: Column(
                children: <Widget>[
                  Expanded(
                    child: Form(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: <Widget>[
                            const CheckoutClosedBanner(opensAt: '08:00'),
                            CheckoutDeliveryCard(
                              address: address(street: 'x' * 60),
                              gone: false,
                              recipient: aziz,
                              onChange: () {},
                            ),
                            CheckoutWishField(
                              controller: wish,
                              focusNode: wishFocus,
                              enabled: true,
                              onChanged: (String _) {},
                            ),
                            const CheckoutPayment(),
                            CheckoutItemsStrip(
                              lines: preview.lines,
                              imageByCartItem: const <String, String?>{},
                              onChange: () {},
                            ),
                            CheckoutAmounts(
                              preview: preview,
                              replacedTotalUzs: 88888888,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  CheckoutFooter(
                    totalUzs: 99999999,
                    estimate: true,
                    busy: false,
                    busyLabel: '…',
                    onOrder: () {},
                    message: const Text('message'),
                  ),
                ],
              ),
            ),
            locale: language,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // A scrolling Column builds every section: all of them were laid out.
        expect(byKey('pay-cash'), findsOneWidget);
        expect(byKey('pay-online-soon'), findsOneWidget);
        expect(find.byType(ProductImage), findsNWidgets(4));
        expect(byKey('checkout-items-more'), findsOneWidget);
        expect(find.text('+8'), findsOneWidget);
        expect(byKey('checkout-total'), findsOneWidget);
        expect(
          find.text(estimate99(language, 88888888)),
          findsOneWidget,
          reason: 'the struck total',
        );
      },
    );
  }
}
