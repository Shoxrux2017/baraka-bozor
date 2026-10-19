import 'dart:async';

import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/cart/presentation/cart_paths.dart';
import 'package:baraka_bozor/features/orders/presentation/reorder_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_cart_repository.dart';
import '../../../support/fake_customer_orders_repository.dart';
import '../../../support/in_memory_stores.dart';

const String _productApple = '0192f0a0-0000-7000-8000-00000000c024';
const String _productCheese = '0192f0a0-0000-7000-8000-00000000c025';

Map<String, Object?> _item(
  String productId,
  String nameUz,
  String nameRu, {
  String? quantity,
}) => <String, Object?>{
  'product_id': productId,
  'name_uz': nameUz,
  'name_ru': nameRu,
  'quantity': ?quantity,
};

/// "Повторить" and what it says, through the real router and screens, with
/// the repositories faked. The button is shown on its own over the home in a
/// dialog, apart from the cards and the order page that carry it.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCustomerOrdersRepository orders;
  late FakeCartRepository cart;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  BuildContext anywhere(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).last);

  String top(WidgetTester tester) =>
      GoRouter.of(anywhere(tester))
          .routerDelegate
          .currentConfiguration
          .last
          .matchedLocation;

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.customer] = 'c';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.customer] = user(id: 'c');
    orders = FakeCustomerOrdersRepository();
    cart = FakeCartRepository(
      cart: cartOf(<Map<String, Object?>>[
        cartLineJson(
          id: breadLine,
          productId: productBread,
          unit: 'piece',
          quantity: '2',
        ),
      ]),
    );
    orders.reorderAnswer = <String, Object?>{
      'added_items': <Object?>[
        for (int i = 0; i < 8; i++)
          _item(
            '0192f0a0-0000-7000-8000-0000000d00${i + 10}',
            'Mahsulot $i',
            'Товар $i',
            quantity: '1',
          ),
      ],
      'skipped_existing_items': <Object?>[
        _item(productBread, 'Lepyoshka', 'Лепёшка'),
      ],
      'unavailable_items': <Object?>[
        _item(_productApple, 'Semirenko olmasi', 'Яблоки Семиренко'),
      ],
      'cart_full_items': <Object?>[_item(_productCheese, 'Pishloq', 'Сыр')],
    };
  });

  Future<void> open(
    WidgetTester tester, {
    bool wide = false,
    Size size = const Size(800, 2400),
    double textScale = 1,
    Locale device = const Locale('ru'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        orders: orders,
        cart: cart,
        device: device,
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      showGeneralDialog<void>(
        context: anywhere(tester),
        barrierDismissible: true,
        barrierLabel: 'dialog',
        pageBuilder:
            (BuildContext context, Animation<double> a, Animation<double> b) =>
                Material(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Consumer(
                        builder:
                            (BuildContext context, WidgetRef ref, Widget? _) =>
                                RepeatOrderButton(
                                  orderId: orderOne,
                                  orderNumber: 1038,
                                  wide: wide,
                                ),
                      ),
                    ),
                  ),
                ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> repeat(WidgetTester tester) async {
    await tester.tap(byKey('order-repeat-$orderOne'));
    await tester.pumpAndSettle();
  }

  testWidgets('the sheet lists what was added, kept and not on sale', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await repeat(tester);

    expect(find.text('Добавили в корзину'), findsOneWidget);
    expect(
      find.text('8 товаров из заказа № 1038 — по сегодняшним ценам.'),
      findsOneWidget,
    );
    expect(find.text('Лепёшка'), findsOneWidget);
    expect(find.text('В корзине 2 шт.'), findsOneWidget);
    expect(find.text('Яблоки Семиренко'), findsOneWidget);
    expect(find.text('Нет в продаже'), findsOneWidget);
    expect(find.text('Сыр'), findsOneWidget);
    expect(
      find.text('Не поместились — в корзине уже 100 товаров'),
      findsOneWidget,
    );
    expect(orders.reorders, hasLength(1));
  });

  testWidgets('nothing added says so', (WidgetTester tester) async {
    orders.reorderAnswer = <String, Object?>{
      'added_items': <Object?>[],
      'skipped_existing_items': <Object?>[
        _item(productBread, 'Lepyoshka', 'Лепёшка'),
      ],
      'unavailable_items': <Object?>[],
      'cart_full_items': <Object?>[],
    };
    await open(tester);
    await repeat(tester);

    expect(find.text('Ничего не добавили'), findsOneWidget);
    expect(find.text('Добавили в корзину'), findsNothing);
    expect(find.textContaining('по сегодняшним ценам'), findsNothing);
    expect(find.text('Лепёшка'), findsOneWidget);
  });

  testWidgets('"В корзину" opens the cart', (WidgetTester tester) async {
    await open(tester);
    await repeat(tester);

    await tester.tap(byKey('reorder-to-cart'));
    await tester.pumpAndSettle();

    expect(top(tester), CartPaths.cart);
    expect(byKey('reorder-to-cart'), findsNothing);
  });

  testWidgets('"Остаться" and the cross close the sheet', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await repeat(tester);
    await tester.tap(byKey('reorder-stay'));
    await tester.pumpAndSettle();
    expect(byKey('reorder-stay'), findsNothing);
    expect(top(tester), isNot(CartPaths.cart));

    await repeat(tester);
    await tester.tap(byKey('reorder-close'));
    await tester.pumpAndSettle();
    expect(byKey('reorder-stay'), findsNothing);
  });

  testWidgets('two quick taps repeat once', (WidgetTester tester) async {
    await open(tester);
    final Completer<void> hold = Completer<void>();
    orders.hold = hold;

    await tester.tap(byKey('order-repeat-$orderOne'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(byKey('order-repeat-$orderOne'), warnIfMissed: false);
    await tester.pump();
    hold.complete();
    await tester.pumpAndSettle();

    expect(orders.reorders, hasLength(1));
  });

  testWidgets('a lost answer is retried under the same key', (
    WidgetTester tester,
  ) async {
    orders.reorderFailure = const NetworkFailure();
    await open(tester);

    await repeat(tester);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text(AppLocalizations.of(anywhere(tester)).errorNetwork),
      findsOneWidget,
    );
    expect(byKey('reorder-stay'), findsNothing);

    await repeat(tester);
    expect(byKey('reorder-stay'), findsOneWidget);
    expect(orders.reorders, hasLength(2));
    expect(orders.reorders[0].$2, orders.reorders[1].$2);
  });

  testWidgets('the page\'s wide button repeats the order too', (
    WidgetTester tester,
  ) async {
    await open(tester, wide: true);

    await tester.tap(byKey('order-repeat'));
    await tester.pumpAndSettle();

    expect(find.text('Добавили в корзину'), findsOneWidget);
    expect(orders.reorders.single.$1, orderOne);
  });

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets('the sheet holds at 320 wide with the text doubled '
        '(${device.languageCode})', (WidgetTester tester) async {
      await open(
        tester,
        size: const Size(320, 640),
        textScale: 2,
        device: device,
      );
      await repeat(tester);

      expect(byKey('reorder-to-cart'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
