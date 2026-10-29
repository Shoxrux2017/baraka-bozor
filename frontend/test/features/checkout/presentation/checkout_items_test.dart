import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/widgets/fold.dart';
import 'package:baraka_bozor/core/widgets/product_image.dart';
import 'package:baraka_bozor/core/widgets/skeleton_bar.dart';
import 'package:baraka_bozor/features/cart/domain/cart.dart';
import 'package:baraka_bozor/features/checkout/data/checkout_api.dart';
import 'package:baraka_bozor/features/checkout/domain/checkout.dart';
import 'package:baraka_bozor/features/checkout/presentation/checkout_items.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_cart_repository.dart';
import '../../../support/fake_checkout_repository.dart';

Finder byKey(String key) => find.byKey(ValueKey<String>(key));

CheckoutPreview previewOf({int lines = 1}) => CheckoutApi.parsePreview(
  previewJson(
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

Widget host(Widget child) =>
    app(Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  final AppLocalizations ru = lookupAppLocalizations(const Locale('ru'));
  String estimate(int amount) =>
      ru.cartLineEstimate(MoneyFormat.uzs(amount, AppLanguage.ru));

  Widget items({int lines = 12, bool withSums = true, bool pending = false}) {
    final List<CheckoutItem> list = checkoutItemsOf(
      preview: previewOf(lines: lines),
    );
    return host(
      CheckoutItems(
        items: withSums
            ? list
            : <CheckoutItem>[
                for (final CheckoutItem item in list)
                  CheckoutItem(
                    id: item.id,
                    nameUz: item.nameUz,
                    nameRu: item.nameRu,
                    unit: item.unit,
                    quantity: item.quantity,
                    priceMode: item.priceMode,
                    imageUrl: item.imageUrl,
                    lineTotalUzs: null,
                  ),
              ],
        pending: pending,
        onChange: () {},
      ),
    );
  }

  double listHeight(WidgetTester tester) =>
      tester.getSize(find.byType(Fold)).height;

  String rowKey(int i) =>
      'checkout-item-0192f0a0-0000-7000-8000-0000000cc${i.toString().padLeft(3, '0')}';

  testWidgets('the strip shows four pictures and +8 for twelve lines', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(items());
    expect(find.byType(ProductImage), findsNWidgets(4));
    expect(find.text('+8'), findsOneWidget);
  });

  testWidgets('each picture is named for a screen reader', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(items(lines: 2));
    expect(find.bySemanticsLabel('Помидоры, 1,5 кг'), findsNWidgets(2));
    handle.dispose();
  });

  Widget oneLine({int? total = 1250000, Locale locale = const Locale('ru')}) =>
      app(
        Scaffold(
          body: SingleChildScrollView(
            child: CheckoutItems(
              items: <CheckoutItem>[
                CheckoutItem(
                  id: 'one',
                  nameUz: 'Pomidor navbahor',
                  nameRu: 'Помидоры черри',
                  unit: UnitCode.kg,
                  quantity: '1.500',
                  priceMode: PriceMode.estimate,
                  imageUrl: null,
                  lineTotalUzs: total,
                ),
              ],
              pending: false,
              onChange: () {},
            ),
          ),
        ),
        locale: locale,
      );

  Future<void> openOneLine(
    WidgetTester tester,
    Widget widget, {
    required Size size,
    required double textScale,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(widget);
    await tester.tap(byKey('checkout-items-toggle'));
    await tester.pumpAndSettle();
  }

  for (final Locale locale in const <Locale>[Locale('ru'), Locale('uz')]) {
    testWidgets('at large text a long sum goes under the quantity ($locale)', (
      WidgetTester tester,
    ) async {
      await openOneLine(
        tester,
        oneLine(locale: locale),
        size: const Size(320, 640),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      final Finder name = find.descendant(
        of: byKey('checkout-item-one'),
        matching: find.text(
          locale.languageCode == 'ru' ? 'Помидоры черри' : 'Pomidor navbahor',
        ),
      );
      final Finder quantity = find.descendant(
        of: byKey('checkout-item-one'),
        matching: find.textContaining(RegExp(r'1,5')),
      );
      final Rect sum = tester.getRect(byKey('checkout-item-one-sum'));
      expect(sum.top, greaterThanOrEqualTo(tester.getRect(quantity).bottom));
      final String word = locale.languageCode == 'ru' ? 'Помидоры' : 'Pomidor';
      final TextPainter painter = TextPainter(
        text: TextSpan(text: word, style: const TextStyle(fontSize: 28)),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(
        tester.getSize(name).width,
        greaterThanOrEqualTo(painter.width - 8),
      );
    });
  }

  testWidgets('beside the name when it fits', (WidgetTester tester) async {
    await openOneLine(
      tester,
      oneLine(),
      size: const Size(800, 640),
      textScale: 1,
    );
    final Rect sum = tester.getRect(byKey('checkout-item-one-sum'));
    final Rect name = tester.getRect(
      find.descendant(
        of: byKey('checkout-item-one'),
        matching: find.text('Помидоры черри'),
      ),
    );
    expect(sum.top, lessThan(name.bottom));
    expect(sum.left, greaterThan(name.right));
  });

  testWidgets('a seven-digit sum scales down rather than overflow', (
    WidgetTester tester,
  ) async {
    await openOneLine(
      tester,
      oneLine(total: 99999999),
      size: const Size(320, 640),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Показать состав lists every name, quantity and server sum', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(items());
    expect(listHeight(tester), 0, reason: 'closed');
    expect(find.text(ru.checkoutItemsShow), findsOneWidget);

    await tester.tap(byKey('checkout-items-toggle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    for (int i = 0; i < 12; i++) {
      expect(byKey(rowKey(i)), findsOneWidget);
      expect(
        tester.widget<Text>(byKey('${rowKey(i)}-sum')).data,
        estimate(27600),
      );
    }
    for (int i = 0; i < 12; i++) {
      for (final String text in <String>['Помидоры', '1,5 кг']) {
        expect(
          find.descendant(of: byKey(rowKey(i)), matching: find.text(text)),
          findsOneWidget,
        );
      }
    }
    expect(find.text(ru.checkoutItemsHide), findsOneWidget);
    expect(
      tester.getSemantics(byKey('checkout-items-toggle')),
      matchesSemantics(
        isButton: true,
        hasTapAction: true,
        hasFocusAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasExpandedState: true,
        isExpanded: true,
        label: ru.checkoutItemsHide,
      ),
    );
    handle.dispose();
  });

  testWidgets('the list folds back in 0.26 s', (WidgetTester tester) async {
    await tester.pumpWidget(items(lines: 3));
    await tester.tap(byKey('checkout-items-toggle'));
    await tester.pumpAndSettle();
    final double open = listHeight(tester);
    expect(open, greaterThan(0));

    await tester.tap(byKey('checkout-items-toggle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    expect(listHeight(tester), inExclusiveRange(0, open), reason: 'folding');
    await tester.pump(const Duration(milliseconds: 131));
    expect(listHeight(tester), 0);
    expect(find.text(ru.checkoutItemsShow), findsOneWidget);
  });

  testWidgets('without a preview the sums are bars', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(items(lines: 2, withSums: false, pending: true));
    await tester.tap(byKey('checkout-items-toggle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(byKey('${rowKey(0)}-sum'), findsNothing);
    expect(byKey('${rowKey(0)}-pending'), findsOneWidget);
    expect(byKey('${rowKey(1)}-pending'), findsOneWidget);
    final SkeletonBar bar = tester.widget<SkeletonBar>(
      byKey('${rowKey(0)}-pending'),
    );
    expect(bar.width, 64);
    expect(bar.pulsing, isTrue);
  });

  testWidgets('the toggle meets iOSTapTargetGuideline', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(items(lines: 2));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    expect(tester.getSize(byKey('checkout-items-toggle')).height, 44);
    handle.dispose();
  });

  group('checkoutItemsOf', () {
    final Cart cart = cartOf(<Map<String, Object?>>[
      cartLineJson(),
      cartLineJson(
        id: breadLine,
        productId: breadProduct,
        unit: 'piece',
        quantity: '2',
      ),
    ]);

    test('is empty with neither a preview nor a cart', () {
      expect(checkoutItemsOf(), isEmpty);
    });

    test('takes the preview first, with the cart picture by id', () {
      final List<CheckoutItem> got = checkoutItemsOf(
        preview: CheckoutApi.parsePreview(previewJson()),
        cart: cart,
      );
      expect(got, hasLength(1));
      expect(got.single.id, tomatoLine);
      expect(got.single.lineTotalUzs, 27600);
      expect(got.single.imageUrl, cart.lines.first.imageUrl);
    });

    test('without a preview takes the cart lines with no sums', () {
      final List<CheckoutItem> got = checkoutItemsOf(cart: cart);
      expect(got.map((CheckoutItem i) => i.id), <String>[
        tomatoLine,
        breadLine,
      ]);
      expect(got.every((CheckoutItem i) => i.lineTotalUzs == null), isTrue);
    });
  });
}
