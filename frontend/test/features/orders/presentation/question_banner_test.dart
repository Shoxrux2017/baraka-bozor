import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/catalog/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_cart_repository.dart';
import '../../../support/fake_customer_orders_repository.dart';
import '../../../support/in_memory_stores.dart';

const String _orderTwo = '0192f0a0-0000-7000-8000-00000000c002';
const String _approvalTwo = '0192f0a0-0000-7000-8000-00000000c032';

Map<String, Object?> _pending(
  String orderId,
  int number,
  String expiresAt, {
  String approval = approvalOne,
}) => <String, Object?>{
  'id': approval,
  'order_id': orderId,
  'order_number': number,
  'expires_at': expiresAt,
};

/// The home's question banner (`DL-92` item 2) through the real router and
/// screens, with the repositories faked.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCustomerOrdersRepository orders;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  BuildContext anywhere(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).last);

  String top(WidgetTester tester) =>
      GoRouter.of(anywhere(tester))
          .routerDelegate
          .currentConfiguration
          .last
          .matchedLocation;

  int pendingLoads() =>
      orders.loads.where((String load) => load == 'pending').length;

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.customer] = 'c';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.customer] = user(id: 'c');
    orders = FakeCustomerOrdersRepository(
      orders: <Map<String, Object?>>[
        customerOrderJson(),
        customerOrderJson(
          id: _orderTwo,
          status: 'shopping',
          changeable: false,
          lines: <Object?>[questionLineJson('price_over_tolerance')],
        ),
      ],
    );
  });

  Future<void> open(
    WidgetTester tester, {
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
        cart: FakeCartRepository(),
        device: device,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the banner names the order and the time to answer', (
    WidgetTester tester,
  ) async {
    orders.pendingRows = <Map<String, Object?>>[
      _pending(orderOne, 1001, '2026-10-19T09:00:00Z'),
      _pending(_orderTwo, 1044, '2026-10-19T07:55:00Z', approval: _approvalTwo),
    ];
    await open(tester);

    expect(find.byType(CatalogHomeScreen), findsOneWidget);
    expect(byKey('question-banner'), findsOneWidget);
    expect(find.text('Сборщик ждёт вашего ответа'), findsOneWidget);
    expect(find.text('Заказ № 1044 · ответьте до 12:55'), findsOneWidget);

    await tester.tap(byKey('question-banner-answer'));
    await tester.pumpAndSettle();

    expect(top(tester), AppPaths.customerOrder(_orderTwo));
  });

  testWidgets('the whole card opens the order too', (
    WidgetTester tester,
  ) async {
    orders.pendingRows = <Map<String, Object?>>[
      _pending(_orderTwo, 1044, '2026-10-19T07:55:00Z'),
    ];
    await open(tester);

    await tester.tap(find.text('Сборщик ждёт вашего ответа'));
    await tester.pumpAndSettle();

    expect(top(tester), AppPaths.customerOrder(_orderTwo));
  });

  testWidgets('no question, no banner', (WidgetTester tester) async {
    await open(tester);

    expect(byKey('question-banner'), findsNothing);
    expect(find.text('Сборщик ждёт вашего ответа'), findsNothing);
  });

  testWidgets('a failed load shows nothing', (WidgetTester tester) async {
    orders.pendingRows = <Map<String, Object?>>[
      _pending(_orderTwo, 1044, '2026-10-19T07:55:00Z'),
    ];
    orders.pendingFailure = const NetworkFailure();
    await open(tester);

    expect(pendingLoads(), 1);
    expect(byKey('question-banner'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an answer hides the banner without waiting', (
    WidgetTester tester,
  ) async {
    orders.pendingRows = <Map<String, Object?>>[
      _pending(_orderTwo, 1044, '2026-10-19T07:55:00Z'),
    ];
    await open(tester);
    expect(byKey('question-banner'), findsOneWidget);

    await tester.tap(byKey('question-banner-answer'));
    await tester.pumpAndSettle();
    orders.pendingRows = <Map<String, Object?>>[];
    orders.afterDecision = customerOrderJson(
      id: _orderTwo,
      status: 'shopping',
      changeable: false,
      lines: <Object?>[orderLineJson()],
    );
    await tester.ensureVisible(byKey('approve-$approvalOne'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('approve-$approvalOne'));
    await tester.pumpAndSettle();

    GoRouter.of(anywhere(tester)).pop();
    await tester.pumpAndSettle();

    expect(find.byType(CatalogHomeScreen), findsOneWidget);
    expect(byKey('question-banner'), findsNothing);
  });

  testWidgets('the banner loads again every 30 seconds', (
    WidgetTester tester,
  ) async {
    await open(tester);
    expect(pendingLoads(), 1);

    await tester.pump(const Duration(seconds: 29));
    expect(pendingLoads(), 1);

    orders.pendingRows = <Map<String, Object?>>[
      _pending(_orderTwo, 1044, '2026-10-19T07:55:00Z'),
    ];
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(pendingLoads(), 2);
    expect(byKey('question-banner'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(pendingLoads(), 3);
  });

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets('the home holds at 320 wide with the text doubled '
        '(${device.languageCode})', (WidgetTester tester) async {
      orders.pendingRows = <Map<String, Object?>>[
        _pending(_orderTwo, 1044, '2026-10-19T07:55:00Z'),
      ];
      await open(
        tester,
        size: const Size(320, 640),
        textScale: 2,
        device: device,
      );

      expect(byKey('question-banner'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
