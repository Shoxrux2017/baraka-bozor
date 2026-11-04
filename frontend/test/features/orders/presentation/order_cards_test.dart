import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/localization/order_labels.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/platform/clock.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/kit/kit_star.dart';
import 'package:baraka_bozor/features/orders/data/customer_orders_api.dart';
import 'package:baraka_bozor/features/orders/presentation/order_cards.dart';
import 'package:baraka_bozor/features/orders/presentation/order_stage_bar.dart';
import 'package:baraka_bozor/features/orders/presentation/rate_order_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_cart_repository.dart';
import '../../../support/fake_customer_orders_repository.dart';
import '../../../support/fake_shopper_orders_repository.dart';
import '../../../support/in_memory_stores.dart';
import '../../../support/nonlinear_text_scaler.dart';
import '../../../support/paragraphs.dart';

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
    TextScaler? scaler,
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
        textScaler: scaler,
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

  testWidgets('the stage segments change colour softly', (
    WidgetTester tester,
  ) async {
    Color? segment(int i) =>
        (tester
                    .widget<DecoratedBox>(
                      find.byKey(ValueKey<String>('order-stage-$i')),
                    )
                    .decoration
                as BoxDecoration)
            .color;
    Future<void> show(int stage, {bool still = false}) => tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: MaterialApp(
          home: Scaffold(
            body: OrderStageBar(
              stage: stage,
              labels: const <String>['a', 'b', 'c', 'd'],
            ),
          ),
        ),
      ),
    );
    final Color ahead = KitColors.primary.withValues(alpha: 0.22);

    await show(1);
    expect(segment(1), ahead);
    await show(2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final Color? mid = segment(1);
    expect(mid, isNot(ahead));
    expect(mid, isNot(KitColors.primary));
    await tester.pump(const Duration(milliseconds: 300));
    expect(segment(1), KitColors.primary);

    await show(3, still: true);
    await tester.pump();
    expect(segment(2), KitColors.primary, reason: 'at once, reduced motion');
  });

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
    expect((wash(), ink()), (KitColors.warningWash, KitColors.warningDark));
    await show(OrderStatus.finalPaymentPending);
    expect((wash(), ink()), (KitColors.warningWash, KitColors.warningDark));
    await show(OrderStatus.completed);
    expect((wash(), ink()), (KitColors.field, KitColors.muted));
    await show(OrderStatus.cancelled);
    expect(ink(), KitColors.danger);
    await show(OrderStatus.onTheWay);
    expect((wash(), ink()), (KitColors.primaryWash, KitColors.primaryDark));
  });

  testWidgets('the card heads with the status and says the number small', (
    WidgetTester tester,
  ) async {
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(
        number: 1044,
        status: 'shopping',
        itemCount: 8,
        street: 'Чиланзар, 9-й квартал',
        house: '14',
        totalUzs: 96000,
        createdAt: '2026-09-28T07:40:00Z',
      ),
    ];
    await open(tester);

    final Finder headline = byKey('order-status-$orderOne');
    expect(tester.widget<Text>(headline).data, 'Собирается');
    final TextStyle style = tester.widget<Text>(headline).style!;
    expect((style.fontSize, style.fontWeight), (16, FontWeight.w700));
    final Finder number = find.text('Заказ № 1044 · 8 товаров');
    expect(number, findsOneWidget);
    expect(
      tester.getTopLeft(number).dy,
      greaterThan(tester.getBottomLeft(headline).dy),
    );
    expect(tester.widget<Text>(number).style!.fontSize, 12);
    expect(find.text('Чиланзар, 9-й квартал, 14'), findsOneWidget);
    expect(find.text('Сегодня, 12:40'), findsOneWidget);
    expect(
      find.text(ru().cartLineEstimate(MoneyFormat.uzs(96000, AppLanguage.ru))),
      findsOneWidget,
    );
    expect(byKey('order-waiting-$orderOne'), findsNothing);
    await tapAndSettle(tester, byKey('order-$orderOne'));
    expect(location(tester), AppPaths.customerOrder(orderOne));
  });

  testWidgets(
    'the stages read Принят Сборка В пути Доставлен, a check on those passed, the current bold',
    (WidgetTester tester) async {
      orders.summaries = <Map<String, Object?>>[
        orderSummaryJson(status: 'on_the_way'),
      ];
      await open(tester);

      expect(
        <String?>[
          for (int i = 0; i < 4; i++)
            tester.widget<Text>(byKey('order-stage-label-$i')).data,
        ],
        <String>['Принят', 'Сборка', 'В пути', 'Доставлен'],
      );
      expect(
        find.descendant(
          of: byKey('order-$orderOne'),
          matching: find.byIcon(Icons.check),
        ),
        findsNWidgets(2),
      );
      expect(
        <FontWeight?>[
          for (int i = 0; i < 4; i++)
            tester
                .widget<Text>(byKey('order-stage-label-$i'))
                .style!
                .fontWeight,
        ],
        <FontWeight>[
          FontWeight.w500,
          FontWeight.w500,
          FontWeight.w700,
          FontWeight.w500,
        ],
      );
      expect(byKey('order-progress-$orderOne'), findsNothing);
    },
  );

  testWidgets(
    'at large text the stages stand as a list and the sum takes its own line',
    (WidgetTester tester) async {
      orders.summaries = <Map<String, Object?>>[
        orderSummaryJson(status: 'shopping', totalUzs: 27600),
      ];
      await open(
        tester,
        size: const Size(360, 2400),
        scaler: const NonlinearTextScaler(2),
      );

      expect(byKey('order-stages-list'), findsOneWidget);
      expect(byKey('order-stage-0'), findsNothing);
      expect(
        tester.widget<Text>(byKey('order-stage-label-1')).data,
        'Сборка',
        reason: 'the list keeps its own words',
      );
      final Finder date = find.textContaining('Сегодня');
      final Finder sum = find.text(
        ru().cartLineEstimate(MoneyFormat.uzs(27600, AppLanguage.ru)),
      );
      expect(
        tester.getTopLeft(sum).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(date).dy),
      );
      expect(tester.widget<Text>(sum).style!.fontSize, 15);
      expect(
        find.descendant(
          of: byKey('order-$orderOne'),
          matching: find.byType(FittedBox),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the question strip sits under the status with the minutes left, red at three',
    (WidgetTester tester) async {
      orders.summaries = <Map<String, Object?>>[
        orderSummaryJson(
          status: 'shopping',
          waiting: 1,
          deadlines: <String>['2026-09-28T08:09:00Z'],
        ),
        orderSummaryJson(
          id: _orderTwo,
          status: 'shopping',
          waiting: 1,
          deadlines: <String>['2026-09-28T08:03:00Z'],
        ),
      ];
      await open(tester);

      final Finder strip = byKey('order-waiting-$orderOne');
      expect(
        tester.getTopLeft(strip).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(byKey('order-status-$orderOne')).dy,
        ),
      );
      expect(
        tester.getBottomLeft(strip).dy,
        lessThanOrEqualTo(
          tester
              .getTopLeft(
                find.descendant(
                  of: byKey('order-$orderOne'),
                  matching: byKey('order-stage-0'),
                ),
              )
              .dy,
        ),
      );
      final Finder calm = find.descendant(
        of: strip,
        matching: find.text('Осталось 9 мин'),
      );
      expect(calm, findsOneWidget);
      expect(tester.widget<Text>(calm).style!.color, KitColors.warningDark);
      final Finder hot = find.descendant(
        of: byKey('order-waiting-$_orderTwo'),
        matching: find.text('Осталось 3 мин'),
      );
      expect(tester.widget<Text>(hot).style!.color, KitColors.danger);
      final Rect button = tester.getRect(byKey('order-answer-$orderOne'));
      expect(button.height, greaterThanOrEqualTo(44));
    },
  );

  testWidgets("at large text the strip's Ответить takes the whole width", (
    WidgetTester tester,
  ) async {
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(
        status: 'shopping',
        waiting: 1,
        deadlines: <String>['2026-09-28T08:09:00Z'],
      ),
    ];
    await open(
      tester,
      size: const Size(360, 2400),
      scaler: const NonlinearTextScaler(2),
    );

    final Rect strip = tester.getRect(byKey('order-waiting-$orderOne'));
    final Rect button = tester.getRect(byKey('order-answer-$orderOne'));
    final Finder text = find.text('Сборщик спрашивает про 1 товар');
    expect(button.left, greaterThanOrEqualTo(strip.left));
    expect(button.width, greaterThan(strip.width - 30));
    expect(button.top, greaterThanOrEqualTo(tester.getBottomLeft(text).dy));
    expect(button.height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the card reads status first with its stage and Примерно', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(
        number: 1044,
        status: 'shopping',
        itemCount: 8,
        waiting: 1,
        totalUzs: 86000,
        createdAt: '2026-09-28T07:40:00Z',
        deadlines: <String>['2026-09-28T08:08:30Z'],
      ),
    ];
    await open(tester);

    final String amount = MoneyFormat.uzs(86000, AppLanguage.ru);
    expect(
      tester.getSemantics(byKey('order-$orderOne')).label,
      'Заказ № 1044. Собирается, этап 2 из 4. '
      'Сборщик спрашивает про 1 товар, осталось 9 минут. '
      'Примерно $amount. Сегодня в 12:40, 8 товаров',
    );
    handle.dispose();
  });

  testWidgets('Ответить and Позвонить курьеру name their order', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(
        number: 1044,
        status: 'on_the_way',
        waiting: 1,
        courierPhone: '+998901112233',
      ),
    ];
    await open(tester);

    expect(
      tester.getSemantics(byKey('order-answer-$orderOne')).label,
      'Ответить на вопрос по заказу № 1044',
    );
    expect(
      tester.getSemantics(byKey('order-call-courier-$orderOne')).label,
      'Позвонить курьеру заказа № 1044',
    );
    handle.dispose();
  });

  for (final (String name, TextScaler? scaler) in <(String, TextScaler?)>[
    ('100 %', null),
    ('200 %', NonlinearTextScaler(2)),
  ]) {
    testWidgets('the current card meets the tap target guideline at $name', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      orders.summaries = <Map<String, Object?>>[
        orderSummaryJson(
          status: 'on_the_way',
          waiting: 1,
          courierPhone: '+998901112233',
          deadlines: <String>['2026-09-28T08:09:00Z'],
        ),
      ];
      await open(tester, size: const Size(360, 2400), scaler: scaler);

      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });
  }

  testWidgets('a card with no lines left shows no item count', (
    WidgetTester tester,
  ) async {
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(status: 'cancelled', itemCount: 0),
    ];
    await open(tester);
    await tapAndSettle(tester, byKey('orders-tab-past'));

    expect(find.textContaining('Заказ № 1001 · '), findsOneWidget);
    expect(find.textContaining('товар'), findsNothing);
  });

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
      expect(byKey('order-rate-$_orderTwo-$stars'), findsNothing);
    }
    final Finder stars = find.descendant(
      of: byKey('order-stars-$_orderTwo'),
      matching: find.byType(KitStar),
    );
    expect(
      <bool>[
        for (final Element star in stars.evaluate())
          (star.widget as KitStar).filled,
      ],
      <bool>[true, true, true, true, false],
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
  });

  testWidgets('a rateable order says Оцените заказ with five outline stars', (
    WidgetTester tester,
  ) async {
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(status: 'completed', canRate: true),
    ];
    await open(tester);
    await tapAndSettle(tester, byKey('orders-tab-past'));

    expect(find.text('Оцените заказ'), findsOneWidget);
    final Finder stars = find.descendant(
      of: byKey('order-$orderOne'),
      matching: find.byType(KitStar),
    );
    expect(stars, findsNWidgets(5));
    for (final Element star in stars.evaluate()) {
      expect((star.widget as KitStar).filled, isFalse);
      expect((star.widget as KitStar).size, 28);
    }
    for (int k = 1; k <= 5; k++) {
      final Rect button = tester.getRect(byKey('order-rate-$orderOne-$k'));
      expect(button.size, const Size(44, 44), reason: '$k');
    }
  });

  group('rating from the card', () {
    late List<MethodCall> platformCalls;

    setUp(() {
      platformCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall call,
          ) async {
            platformCalls.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      orders.summaries = <Map<String, Object?>>[
        orderSummaryJson(status: 'completed', canRate: true),
      ];
      orders.rows = <Map<String, Object?>>[
        customerOrderJson(status: 'completed', canRate: true),
      ];
    });

    /// The rating screen's address, query included; `null` while it is not
    /// open.
    String? fullLocation(WidgetTester tester) {
      final Finder screen = find.byType(RateOrderScreen);
      return screen.evaluate().isEmpty
          ? null
          : GoRouterState.of(tester.element(screen)).uri.toString();
    }

    List<bool> lit(WidgetTester tester) => <bool>[
      for (int k = 1; k <= 5; k++)
        tester
            .widget<KitStar>(
              find.descendant(
                of: byKey('order-rate-$orderOne-$k'),
                matching: find.byType(KitStar),
              ),
            )
            .filled,
    ];

    Future<void> past(WidgetTester tester) async {
      await open(tester);
      await tapAndSettle(tester, byKey('orders-tab-past'));
      await tester.ensureVisible(byKey('order-rate-$orderOne-3'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'a tap lights the stars up to it, buzzes, then opens the rating screen with them',
      (WidgetTester tester) async {
        await past(tester);

        await tester.tap(byKey('order-rate-$orderOne-3'));
        await tester.pump(const Duration(milliseconds: 429));
        expect(lit(tester), <bool>[true, true, true, false, false]);
        expect(location(tester), AppPaths.customerOrders);
        expect(
          platformCalls
              .where(
                (MethodCall c) =>
                    c.method == 'HapticFeedback.vibrate' &&
                    c.arguments == 'HapticFeedbackType.lightImpact',
              )
              .length,
          1,
        );

        await tester.pump(const Duration(milliseconds: 1));
        await tester.pumpAndSettle();
        expect(
          fullLocation(tester),
          AppPaths.customerOrderRate(orderOne, stars: 3),
        );
      },
    );

    testWidgets('a second tap meanwhile is ignored and back unlights them', (
      WidgetTester tester,
    ) async {
      await past(tester);

      await tester.tap(byKey('order-rate-$orderOne-3'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(byKey('order-rate-$orderOne-5'));
      await tester.pumpAndSettle();
      expect(
        fullLocation(tester),
        AppPaths.customerOrderRate(orderOne, stars: 3),
      );

      GoRouter.of(anywhere(tester)).pop();
      await tester.pumpAndSettle();
      expect(lit(tester), <bool>[false, false, false, false, false]);
    });

    testWidgets('with reduced motion the rating screen opens at once', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await past(tester);

      await tester.tap(byKey('order-rate-$orderOne-4'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(
        fullLocation(tester),
        AppPaths.customerOrderRate(orderOne, stars: 4),
      );
    });
  });

  testWidgets('a rated order says Ваша оценка with its stars', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(id: _orderTwo, status: 'completed', ratingStars: 4),
    ];
    await open(tester);
    await tapAndSettle(tester, byKey('orders-tab-past'));

    expect(find.text('Ваша оценка'), findsOneWidget);
    expect(find.text('Оцените заказ'), findsNothing);
    final Finder stars = find.descendant(
      of: byKey('order-stars-$_orderTwo'),
      matching: find.byType(KitStar),
    );
    expect(stars, findsNWidgets(5));
    for (final Element star in stars.evaluate()) {
      expect((star.widget as KitStar).size, 22);
    }
    expect(
      tester.getSemantics(byKey('order-stars-$_orderTwo')).label,
      'Ваша оценка: 4 из 5',
    );
    handle.dispose();
  });

  testWidgets('Повторить is 44 high and names its order', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(status: 'completed', number: 1042),
    ];
    await open(tester);
    await tapAndSettle(tester, byKey('orders-tab-past'));

    expect(tester.getSize(byKey('order-repeat-$orderOne')).height, 44);
    expect(find.bySemanticsLabel('Повторить заказ № 1042'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('ten lines show three pictures and +7', (
    WidgetTester tester,
  ) async {
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(status: 'completed', itemCount: 10),
    ];
    await open(tester);
    await tapAndSettle(tester, byKey('orders-tab-past'));

    expect(
      find.descendant(
        of: byKey('order-$orderOne'),
        matching: byKey('order-picture'),
      ),
      findsNWidgets(3),
    );
    expect(
      find.descendant(of: byKey('order-$orderOne'), matching: find.text('+7')),
      findsOneWidget,
    );
  });

  testWidgets('four lines show four pictures, one shows one', (
    WidgetTester tester,
  ) async {
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(status: 'completed', itemCount: 4),
      orderSummaryJson(id: _orderTwo, status: 'completed', itemCount: 1),
    ];
    await open(tester);
    await tapAndSettle(tester, byKey('orders-tab-past'));

    Finder tiles(String id) => find.descendant(
      of: byKey('order-$id'),
      matching: byKey('order-picture'),
    );
    expect(tiles(orderOne), findsNWidgets(4));
    expect(tiles(_orderTwo), findsOneWidget);
    expect(
      find.descendant(
        of: byKey('order-$orderOne'),
        matching: byKey('order-picture-more'),
      ),
      findsNothing,
    );
  });

  testWidgets('the names read Помидоры, Молоко домашнее и ещё 8', (
    WidgetTester tester,
  ) async {
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(status: 'completed', itemCount: 10),
      orderSummaryJson(id: _orderTwo, status: 'completed', itemCount: 2),
      orderSummaryJson(
        id: '0192f0a0-0000-7000-8000-00000000c003',
        status: 'completed',
        itemCount: 1,
      ),
    ];
    await open(tester);
    await tapAndSettle(tester, byKey('orders-tab-past'));

    expect(find.text('Помидоры, Молоко домашнее и ещё 8'), findsOneWidget);
    expect(find.text('Помидоры, Молоко домашнее'), findsOneWidget);
    expect(find.text('Помидоры'), findsOneWidget);
  });

  testWidgets("the names are the interface language's", (
    WidgetTester tester,
  ) async {
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(status: 'completed', itemCount: 10),
    ];
    await open(tester, device: const Locale('uz'));
    await tapAndSettle(tester, byKey('orders-tab-past'));

    expect(find.text("Pomidor, Sut va yana 8 ta"), findsOneWidget);
  });

  testWidgets(
    'the past card reads Заказ № 1042, доставлен. Помидоры, Молоко домашнее и ещё 8. Вчера, 19:45. 86 000 сум',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      orders.summaries = <Map<String, Object?>>[
        orderSummaryJson(
          status: 'completed',
          number: 1042,
          itemCount: 10,
          totalUzs: 86000,
          totalKind: 'final',
          createdAt: '2026-09-27T14:45:00Z',
        ),
      ];
      await open(tester);
      await tapAndSettle(tester, byKey('orders-tab-past'));

      expect(
        tester.getSemantics(byKey('order-$orderOne')).label,
        contains(
          'Заказ № 1042, доставлен. Помидоры, Молоко домашнее и ещё 8. '
          'Вчера, 19:45. ${MoneyFormat.uzs(86000, AppLanguage.ru)}',
        ),
      );
      handle.dispose();
    },
  );

  testWidgets('a cancelled order says К оплате нет', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(status: 'cancelled', number: 1042),
    ];
    await open(tester);
    await tapAndSettle(tester, byKey('orders-tab-past'));

    expect(find.text('К оплате нет'), findsOneWidget);
    final String label = tester.getSemantics(byKey('order-$orderOne')).label;
    expect(label, contains('Заказ № 1042, отменён.'));
    expect(label, endsWith('К оплате нет'));
    handle.dispose();
  });

  group('the last-order card', () {
    Future<void> show(WidgetTester tester, {TextScaler? scaler}) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final GoRouter router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) => Scaffold(
              body: LastOrderCard(
                order: CustomerOrdersApi.parseSummary(
                  orderSummaryJson(
                    status: 'completed',
                    number: 1042,
                    itemCount: 10,
                    totalUzs: 86000,
                    totalKind: 'final',
                    createdAt: '2026-09-27T14:45:00Z',
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: AppPaths.customerOrderPattern,
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(body: Text('the order')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clockProvider.overrideWithValue(() => DateTime.utc(2026, 9, 28, 8)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: scaler ?? TextScaler.noScaling),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the last-order card has an outlined Повторить', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await show(tester);

      expect(byKey('order-last-$orderOne'), findsOneWidget);
      expect(find.text('Помидоры, Молоко домашнее и ещё 8'), findsOneWidget);
      expect(
        find.text('Вчера, 19:45 · ${MoneyFormat.uzs(86000, AppLanguage.ru)}'),
        findsOneWidget,
      );
      expect(find.text('+7'), findsOneWidget);
      final Finder repeat = byKey('order-repeat-$orderOne');
      expect(tester.widget(repeat), isA<OutlinedButton>());
      expect(tester.getSize(repeat).height, 44);
      expect(
        tester.getSemantics(byKey('order-last-$orderOne')).label,
        contains('Заказ № 1042, доставлен.'),
      );
      await tester.tap(byKey('order-last-$orderOne'));
      await tester.pumpAndSettle();
      expect(find.text('the order'), findsOneWidget);
      handle.dispose();
    });

    for (final (String, TextScaler) scale in <(String, TextScaler)>[
      ('100 %', TextScaler.noScaling),
      ('200 %', const NonlinearTextScaler(2)),
    ]) {
      testWidgets('meets the tap guideline at ${scale.$1}', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await show(tester, scaler: scale.$2);

        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        expect(tester.takeException(), isNull);
        handle.dispose();
      });
    }
  });

  for (final (String, TextScaler) scale in <(String, TextScaler)>[
    ('100 %', TextScaler.noScaling),
    ('200 %', const NonlinearTextScaler(2)),
  ]) {
    testWidgets(
      'the past cards (rateable, rated, cancelled) meet the tap guideline at ${scale.$1}',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        orders.summaries = <Map<String, Object?>>[
          orderSummaryJson(status: 'completed', canRate: true, itemCount: 10),
          orderSummaryJson(id: _orderTwo, status: 'completed', ratingStars: 4),
          orderSummaryJson(
            id: '0192f0a0-0000-7000-8000-00000000c003',
            status: 'cancelled',
          ),
        ];
        await open(tester, size: const Size(360, 2400), scaler: scale.$2);
        await tapAndSettle(tester, byKey('orders-tab-past'));

        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );
  }

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

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'every status reads whole on one line at 375, as a headline or as a chip (${device.languageCode})',
      (WidgetTester tester) async {
        await loadMontserrat();
        orders.summaries = <Map<String, Object?>>[
          for (final OrderStatus status in OrderStatus.values)
            orderSummaryJson(
              id: '0192f0a0-0000-7000-8000-00000000d0${status.index.toString().padLeft(2, '0')}',
              status: status.code,
            ),
        ];
        await open(tester, size: const Size(375, 3000), device: device);
        final AppLocalizations words = lookupAppLocalizations(device);
        final Set<String> seen = <String>{};

        void check() {
          final Finder chips = find.byType(OrderStatusChip);
          for (int i = 0; i < chips.evaluate().length; i++) {
            final Finder chip = chips.at(i);
            final OrderStatus status = tester
                .widget<OrderStatusChip>(chip)
                .status;
            final List<RenderParagraph> text = paragraphsIn(tester, chip);
            expect(cutParagraphs(tester, chip), isEmpty);
            expect(linesOf(text.single), 1, reason: status.name);
            seen.add(OrderLabels.customerStatus(words, status));
          }
          final Finder headlines = find.byWidgetPredicate(
            (Widget widget) =>
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'order-status-',
                ),
          );
          for (int i = 0; i < headlines.evaluate().length; i++) {
            final Finder headline = headlines.at(i);
            final List<RenderParagraph> text = paragraphsIn(tester, headline);
            expect(cutParagraphs(tester, headline), isEmpty);
            expect(linesOf(text.single), 1);
            seen.add(tester.widget<Text>(headline).data!);
          }
        }

        check();
        await tapAndSettle(tester, byKey('orders-tab-past'));
        check();
        expect(seen, hasLength(OrderStatus.values.length));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (Size size, double scale) in <(Size, double)>[
    (const Size(320, 640), 2),
    (const Size(360, 800), 1.3),
  ]) {
    testWidgets('the card total stays one whole line at $size x$scale', (
      WidgetTester tester,
    ) async {
      await loadMontserrat();
      orders.summaries = <Map<String, Object?>>[
        orderSummaryJson(totalUzs: 27600, status: 'shopping'),
        orderSummaryJson(
          id: _orderTwo,
          status: 'completed',
          totalUzs: 28463,
          totalKind: 'final',
        ),
      ];
      await open(tester, size: size, textScale: scale);
      final AppLocalizations words = ru();

      Future<void> expectWhole(String text, String card) async {
        final Finder amount = find.text(text);
        expect(amount, findsOneWidget);
        expect(cutParagraphs(tester, amount), isEmpty);
        expect(linesOf(paragraphsIn(tester, amount).single), 1);
        final Rect inside = tester.getRect(byKey(card));
        final Rect rect = tester.getRect(amount);
        expect(rect.left, greaterThanOrEqualTo(inside.left));
        expect(rect.right, lessThanOrEqualTo(inside.right));
      }

      await expectWhole(
        words.cartLineEstimate(MoneyFormat.uzs(27600, AppLanguage.ru)),
        'order-$orderOne',
      );
      await tapAndSettle(tester, byKey('orders-tab-past'));
      await expectWhole(
        MoneyFormat.uzs(28463, AppLanguage.ru),
        'order-$_orderTwo',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shown stars read as a rating, not as an action', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(id: _orderTwo, status: 'completed', ratingStars: 4),
    ];
    await open(tester);
    await tapAndSettle(tester, byKey('orders-tab-past'));

    final SemanticsNode stars = tester.getSemantics(
      byKey('order-stars-$_orderTwo'),
    );
    expect(stars.label, ru().orderRatedSpoken(4));
    expect(stars.label, isNot(contains(ru().orderRateStarsSpoken(1001, 4))));
    handle.dispose();
  });

  testWidgets(
    'on a narrow phone the stars keep their 44 and Повторить goes under them',
    (WidgetTester tester) async {
      await loadMontserrat();
      orders.summaries = <Map<String, Object?>>[
        orderSummaryJson(status: 'completed', canRate: true),
      ];
      await open(tester, size: const Size(320, 640));
      await tapAndSettle(tester, byKey('orders-tab-past'));

      double bottom = 0;
      for (int stars = 1; stars <= 5; stars++) {
        final Rect box = tester.getRect(byKey('order-rate-$orderOne-$stars'));
        expect(box.width, greaterThanOrEqualTo(44), reason: '$stars wide');
        expect(box.height, greaterThanOrEqualTo(44), reason: '$stars high');
        bottom = box.bottom;
      }
      final Rect repeat = tester.getRect(byKey('order-repeat-$orderOne'));
      expect(repeat.top, greaterThanOrEqualTo(bottom));
      expect(tester.takeException(), isNull);
    },
  );
}
