import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/features/orders/presentation/order_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_cart_repository.dart';
import '../../../support/fake_customer_orders_repository.dart';
import '../../../support/fake_shopper_orders_repository.dart';
import '../../../support/in_memory_stores.dart';

const String _orderTwo = '0192f0a0-0000-7000-8000-00000000c002';

/// The Customer's orders list as cards (drawings 27, 27a, 28) through the real
/// router and screens, with the repositories faked.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCustomerOrdersRepository orders;
  late FakePhoneCalls phone;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  BuildContext anywhere(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).last);

  String location(WidgetTester tester) =>
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
    phone = FakePhoneCalls();
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
        phoneCalls: phone,
        device: device,
        clock: () => DateTime.utc(2026, 9, 28, 8),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(anywhere(tester)).push(AppPaths.customerOrders);
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  AppLocalizations ru() => lookupAppLocalizations(const Locale('ru'));

  Color? segment(WidgetTester tester, int index) {
    final DecoratedBox box = tester.widget<DecoratedBox>(
      byKey('progress-segment-$index'),
    );
    return (box.decoration as BoxDecoration).color;
  }

  test('the progress fills by stage for all nine statuses', () {
    expect(
      <OrderStatus, int>{
        for (final OrderStatus status in OrderStatus.values)
          status: orderStage(status),
      },
      <OrderStatus, int>{
        OrderStatus.newOrder: 1,
        OrderStatus.shoppingAssigned: 1,
        OrderStatus.shopping: 2,
        OrderStatus.finalPaymentPending: 2,
        OrderStatus.readyForDelivery: 2,
        OrderStatus.deliveryAssigned: 2,
        OrderStatus.onTheWay: 3,
        OrderStatus.completed: 4,
        OrderStatus.cancelled: 0,
      },
    );
  });

  testWidgets(
    'the progress bar paints the first segments in the brand colour',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: OrderProgressBar(stage: 3))),
      );

      expect(
        <Color?>[for (int i = 0; i < 4; i++) segment(tester, i)],
        <Color>[
          KitColors.primary,
          KitColors.primary,
          KitColors.primary,
          KitColors.line,
        ],
      );
    },
  );

  testWidgets('the chip colours follow the status', (
    WidgetTester tester,
  ) async {
    Future<void> show(OrderStatus status) => tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: OrderStatusChip(status: status)),
      ),
    );
    Color? wash() =>
        (tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: find.byType(OrderStatusChip),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration)
            .color;
    Color? ink() => tester.widget<Text>(find.byType(Text)).style?.color;

    await show(OrderStatus.shopping);
    expect((wash(), ink()), (KitColors.warningWash, KitColors.warning));
    await show(OrderStatus.finalPaymentPending);
    expect((wash(), ink()), (KitColors.warningWash, KitColors.warning));
    await show(OrderStatus.completed);
    expect((wash(), ink()), (KitColors.field, KitColors.muted));
    await show(OrderStatus.cancelled);
    expect(ink(), KitColors.danger);
    await show(OrderStatus.onTheWay);
    expect((wash(), ink()), (KitColors.primaryWash, KitColors.primaryDark));
  });

  testWidgets(
    'the current card shows number, address, count, status, date and total',
    (WidgetTester tester) async {
      orders.summaries = <Map<String, Object?>>[
        orderSummaryJson(
          number: 1044,
          status: 'shopping',
          itemCount: 4,
          street: 'Чиланзар, 9-й квартал',
          house: '14',
          totalUzs: 96000,
          createdAt: '2026-09-28T07:40:00Z',
        ),
      ];
      await open(tester);

      expect(find.text('Заказ № 1044'), findsOneWidget);
      expect(find.text('Чиланзар, 9-й квартал, 14'), findsOneWidget);
      expect(find.text('4 товара'), findsOneWidget);
      expect(find.text('Собирается'), findsOneWidget);
      expect(find.text('Сегодня, 12:40'), findsOneWidget);
      expect(
        find.text(
          ru().cartLineEstimate(MoneyFormat.uzs(96000, AppLanguage.ru)),
        ),
        findsOneWidget,
      );
      expect(byKey('order-waiting-$orderOne'), findsNothing);
      await tapAndSettle(tester, byKey('order-$orderOne'));
      expect(location(tester), AppPaths.customerOrder(orderOne));
    },
  );

  testWidgets('a waiting question shows the strip', (
    WidgetTester tester,
  ) async {
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(status: 'shopping', waiting: 1),
      orderSummaryJson(id: _orderTwo, status: 'shopping'),
    ];
    await open(tester);

    expect(byKey('order-waiting-$orderOne'), findsOneWidget);
    expect(byKey('order-waiting-$_orderTwo'), findsNothing);
    expect(find.text('Сборщик спрашивает про 1 товар'), findsOneWidget);
    await tapAndSettle(
      tester,
      find.descendant(
        of: byKey('order-waiting-$orderOne'),
        matching: find.text(ru().questionAnswer),
      ),
    );
    expect(location(tester), AppPaths.customerOrder(orderOne));
  });

  testWidgets('the courier button follows courier_phone', (
    WidgetTester tester,
  ) async {
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(status: 'on_the_way', courierPhone: '+998901112233'),
      orderSummaryJson(id: _orderTwo, status: 'shopping'),
    ];
    await open(tester);

    expect(byKey('order-call-courier-$_orderTwo'), findsNothing);
    expect(find.text('Позвонить курьеру'), findsOneWidget);
    await tapAndSettle(tester, byKey('order-call-courier-$orderOne'));
    expect(phone.calls, <String>['+998901112233']);
    expect(find.byType(SnackBar), findsNothing);

    phone.opens = false;
    await tapAndSettle(tester, byKey('order-call-courier-$orderOne'));
    expect(
      find.textContaining('+998 90 111 22 33'),
      findsOneWidget,
      reason: 'a failed dial shows the number',
    );
  });

  testWidgets('the past card offers stars only while it can be rated', (
    WidgetTester tester,
  ) async {
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(status: 'completed', canRate: true),
      orderSummaryJson(id: _orderTwo, status: 'completed', ratingStars: 4),
      orderSummaryJson(
        id: '0192f0a0-0000-7000-8000-00000000c003',
        status: 'cancelled',
      ),
    ];
    await open(tester);
    await tapAndSettle(tester, byKey('orders-tab-past'));

    for (int stars = 1; stars <= 5; stars++) {
      expect(byKey('order-rate-$orderOne-$stars'), findsOneWidget);
      expect(find.text('$stars★'), findsOneWidget);
      expect(byKey('order-rate-$_orderTwo-$stars'), findsNothing);
    }
    final Finder stars = find.descendant(
      of: byKey('order-stars-$_orderTwo'),
      matching: find.byIcon(Icons.star),
    );
    expect(
      <Color?>[
        for (final Element star in stars.evaluate())
          (star.widget as Icon).color,
      ],
      <Color>[
        KitColors.warning,
        KitColors.warning,
        KitColors.warning,
        KitColors.warning,
        KitColors.line,
      ],
    );
    expect(byKey('order-stars-$orderOne'), findsNothing);
    expect(
      find.byKey(
        const ValueKey<String>(
          'order-stars-0192f0a0-0000-7000-8000-00000000c003',
        ),
      ),
      findsNothing,
    );
    expect(byKey('order-repeat-$orderOne'), findsOneWidget);
    expect(byKey('order-progress-$orderOne'), findsNothing);

    orders.rows = <Map<String, Object?>>[
      customerOrderJson(status: 'completed', canRate: true),
    ];
    await tapAndSettle(tester, byKey('order-rate-$orderOne-3'));
    expect(
      location(tester),
      AppPaths.customerOrderRatePattern.replaceAll(':order', orderOne),
    );
  });

  testWidgets('the tabs ask for their state', (WidgetTester tester) async {
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(status: 'shopping'),
      orderSummaryJson(id: _orderTwo, status: 'completed'),
    ];
    await open(tester);
    expect(orders.loads, contains('orders:current:1'));
    expect(byKey('order-$orderOne'), findsOneWidget);
    expect(byKey('order-$_orderTwo'), findsNothing);

    await tapAndSettle(tester, byKey('orders-tab-past'));
    expect(orders.loads.last, 'orders:past:1');
    expect(byKey('order-$_orderTwo'), findsOneWidget);
    expect(byKey('order-$orderOne'), findsNothing);

    await tapAndSettle(tester, byKey('orders-tab-current'));
    expect(orders.loads.last, 'orders:current:1');
    expect(byKey('order-$orderOne'), findsOneWidget);
  });

  testWidgets('an empty current tab leads to shopping', (
    WidgetTester tester,
  ) async {
    orders.summaries = <Map<String, Object?>>[];
    await open(tester);

    expect(byKey('orders-empty'), findsOneWidget);
    expect(find.text(ru().myOrdersEmpty), findsOneWidget);
    expect(find.text(ru().ordersEmptyHint), findsOneWidget);
    await tapAndSettle(tester, byKey('orders-empty-shop'));
    expect(location(tester), AppPaths.customer);
  });

  testWidgets('an empty past tab says what will be there', (
    WidgetTester tester,
  ) async {
    orders.summaries = <Map<String, Object?>>[];
    await open(tester);
    await tapAndSettle(tester, byKey('orders-tab-past'));

    expect(byKey('orders-empty'), findsOneWidget);
    expect(find.text(ru().ordersPastEmpty), findsOneWidget);
    expect(byKey('orders-empty-shop'), findsNothing);
  });

  testWidgets('the current tab loads again every 30 seconds', (
    WidgetTester tester,
  ) async {
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(status: 'shopping'),
    ];
    await open(tester);
    int current() =>
        orders.loads.where((String load) => load == 'orders:current:1').length;
    final int before = current();

    await tester.pump(const Duration(seconds: 29));
    expect(current(), before);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(current(), before + 1);
  });

  testWidgets('the past tab is not refreshed on a timer', (
    WidgetTester tester,
  ) async {
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(status: 'completed'),
    ];
    await open(tester);
    await tapAndSettle(tester, byKey('orders-tab-past'));
    final int before = orders.loads.length;

    await tester.pump(const Duration(seconds: 90));
    await tester.pumpAndSettle();
    expect(orders.loads.length, before);
  });

  testWidgets('the cards fit a 375-wide phone at normal text', (
    WidgetTester tester,
  ) async {
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(
        status: 'on_the_way',
        waiting: 1,
        courierPhone: '+998901112233',
      ),
      orderSummaryJson(id: _orderTwo, status: 'completed', canRate: true),
    ];
    await open(tester, size: const Size(375, 812));
    expect(tester.takeException(), isNull);

    await tester.tap(byKey('orders-tab-past'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'both tabs hold the extremes on a phone with large text (${device.languageCode})',
      (WidgetTester tester) async {
        orders.summaries = <Map<String, Object?>>[
          orderSummaryJson(
            status: 'on_the_way',
            waiting: 3,
            courierPhone: '+998901112233',
            street: 'Ш' * 60,
            house: '1234',
            totalUzs: 99999999,
            itemCount: 120,
          ),
          orderSummaryJson(
            id: _orderTwo,
            status: 'completed',
            canRate: true,
            street: 'Ш' * 60,
            house: '1234',
            totalUzs: 99999999,
          ),
        ];
        await open(
          tester,
          size: const Size(320, 640),
          textScale: 2,
          device: device,
        );
        expect(tester.takeException(), isNull);
        expect(byKey('order-call-courier-$orderOne'), findsOneWidget);

        await tester.tap(byKey('orders-tab-past'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(byKey('order-rate-$_orderTwo-5'), findsOneWidget);
      },
    );
  }
}
