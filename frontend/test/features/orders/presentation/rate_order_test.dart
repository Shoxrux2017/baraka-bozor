import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_cart_repository.dart';
import '../../../support/fake_customer_orders_repository.dart';
import '../../../support/in_memory_stores.dart';

const Map<String, Object?> _ratedTwo = <String, Object?>{
  'stars': 2,
  'reasons': <Object?>['not_fresh'],
  'comment': 'мятые',
  'created_at': '2026-09-29T08:00:00Z',
};

/// Rating a delivered order (drawings 29ж, 30, 30а, 30б) through the real
/// router and screens, with the repositories faked.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCustomerOrdersRepository orders;

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
    orders = FakeCustomerOrdersRepository()
      ..rows = <Map<String, Object?>>[
        customerOrderJson(status: 'completed', canRate: true),
      ];
  });

  /// Opens the order's page, and over it the rating screen at [rate] when
  /// one is given.
  Future<void> open(
    WidgetTester tester, {
    String? rate,
    Size size = const Size(800, 2400),
    double textScale = 1,
    Locale device = const Locale('ru'),
  }) async {
    // A fresh app each time, so a test may show several orders.
    await tester.pumpWidget(const SizedBox());
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
        clock: () => DateTime.utc(2026, 9, 28, 9),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(anywhere(tester)).push(AppPaths.customerOrder(orderOne));
    await tester.pumpAndSettle();
    if (rate != null) {
      GoRouter.of(anywhere(tester)).push(rate);
      await tester.pumpAndSettle();
    }
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Whether the star at [key] is drawn filled.
  bool filled(WidgetTester tester, String key) =>
      tester
          .widget<Icon>(
            find.descendant(of: byKey(key), matching: find.byType(Icon)),
          )
          .icon ==
      Icons.star;

  /// The one rating sent: the stars, the reason codes, the comment.
  void expectSent(int stars, List<String> reasons, String? comment) {
    expect(orders.ratings, hasLength(1));
    final (String, int, List<String>, String?) sent = orders.ratings.single;
    expect(sent.$1, orderOne);
    expect(sent.$2, stars);
    expect(sent.$3, reasons);
    expect(sent.$4, comment);
  }

  bool sendActive(WidgetTester tester) =>
      tester.widget<FilledButton>(byKey('rate-send')).onPressed != null;

  testWidgets('a box on the past card opens the screen with its stars', (
    WidgetTester tester,
  ) async {
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(status: 'completed', canRate: true),
    ];
    await open(tester);
    GoRouter.of(anywhere(tester)).go(AppPaths.customerOrders);
    await tester.pumpAndSettle();
    await tapAndSettle(tester, byKey('orders-tab-past'));
    await tapAndSettle(tester, byKey('order-rate-$orderOne-2'));

    expect(
      location(tester),
      AppPaths.customerOrderRatePattern.replaceAll(':order', orderOne),
    );
    expect(filled(tester, 'rate-star-2'), isTrue);
    expect(filled(tester, 'rate-star-3'), isFalse);
    expect(find.text('Плохо'), findsOneWidget);
    for (final String reason in <String>[
      'not_fresh',
      'wrong_weight',
      'late',
      'rude',
    ]) {
      expect(byKey('rate-reason-$reason'), findsOneWidget);
    }
    expect(sendActive(tester), isTrue);
  });

  testWidgets('the stars on the order open the screen with them chosen', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tapAndSettle(tester, byKey('order-rate-5'));

    expect(filled(tester, 'rate-star-5'), isTrue);
    expect(find.text('Отлично!'), findsOneWidget);
    expect(byKey('rate-reason-late'), findsNothing);
    expect(find.text('Как вам заказ № 1001?'), findsOneWidget);
  });

  testWidgets('a stars value out of range is ignored', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: '${AppPaths.customerOrderRate(orderOne)}?stars=9');

    expect(filled(tester, 'rate-star-5'), isFalse);
    expect(sendActive(tester), isFalse);
    expect(byKey('rate-reason-late'), findsNothing);
  });

  testWidgets('the customer rates 2 with a reason and a comment', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 2));
    orders.rows = <Map<String, Object?>>[
      customerOrderJson(status: 'completed', rating: _ratedTwo),
    ];

    await tapAndSettle(tester, byKey('rate-reason-not_fresh'));
    await tester.enterText(byKey('rate-comment'), '  мятые  ');
    await tester.pump();
    expect(find.text('5 / 500'), findsOneWidget);
    await tapAndSettle(tester, byKey('rate-send'));

    expectSent(2, <String>['not_fresh'], 'мятые');
    expect(location(tester), AppPaths.customerOrder(orderOne));
    expect(byKey('order-rated'), findsOneWidget);
    expect(byKey('order-rate'), findsNothing);
    expect(find.text('Несвежее'), findsOneWidget);
    expect(find.text('«мятые»'), findsOneWidget);
    expect(
      find.text('Спасибо! Оператор свяжется с вами, чтобы разобраться.'),
      findsOneWidget,
    );
  });

  testWidgets('a good rating says thanks and sends no reasons', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 5));
    orders.rows = <Map<String, Object?>>[
      customerOrderJson(
        status: 'completed',
        rating: <String, Object?>{
          'stars': 5,
          'reasons': <Object?>[],
          'comment': null,
          'created_at': '2026-09-29T08:00:00Z',
        },
      ),
    ];
    await tapAndSettle(tester, byKey('rate-send'));

    expectSent(5, <String>[], null);
    expect(find.text('Спасибо за оценку!'), findsOneWidget);
  });

  testWidgets('raising to 4 drops the reasons', (WidgetTester tester) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 2));

    await tapAndSettle(tester, byKey('rate-reason-late'));
    await tapAndSettle(tester, byKey('rate-star-4'));
    expect(byKey('rate-reason-late'), findsNothing);
    await tapAndSettle(tester, byKey('rate-star-2'));
    expect(
      tester.widget<FilterChip>(byKey('rate-reason-late')).selected,
      isFalse,
    );
    await tapAndSettle(tester, byKey('rate-star-4'));
    await tapAndSettle(tester, byKey('rate-send'));

    expectSent(4, <String>[], null);
  });

  testWidgets('two quick taps rate once', (WidgetTester tester) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 3));
    orders.hold = Completer<void>();

    await tester.tap(byKey('rate-send'));
    await tester.pump();
    await tester.tap(byKey('rate-send'), warnIfMissed: false);
    await tester.pump();
    expect(find.text('Отправляем оценку'), findsOneWidget);
    orders.hold!.complete();
    await tester.pumpAndSettle();

    expect(orders.ratings, hasLength(1));
  });

  testWidgets('a closed window says so and keeps the screen', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 3));
    orders.rateFailure = const ApiRefusal(
      ApiError(status: 409, code: 'rating_window_closed'),
    );
    await tapAndSettle(tester, byKey('rate-send'));

    expect(byKey('rate-send'), findsOneWidget);
    expect(
      find.text(
        'Оценить заказ можно в течение 7 дней после доставки — это время прошло.',
      ),
      findsOneWidget,
    );
    expect(sendActive(tester), isFalse);
    expect(
      tester
          .widget<Text>(
            find.text(
              'Оценить заказ можно в течение 7 дней после доставки — это время прошло.',
            ),
          )
          .style
          ?.color,
      KitColors.danger,
    );
  });

  testWidgets('another failure is said above the button', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 3));
    orders.rateFailure = const ApiRefusal(
      ApiError(status: 500, code: 'server_error'),
    );
    await tapAndSettle(tester, byKey('rate-send'));

    expect(byKey('failure-message'), findsOneWidget);
    expect(sendActive(tester), isTrue);
  });

  for (final String code in <String>[
    'order_already_rated',
    'order_not_rateable',
  ]) {
    testWidgets('$code returns to the order', (WidgetTester tester) async {
      await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 3));
      orders.rateFailure = ApiRefusal(ApiError(status: 409, code: code));
      orders.rows = <Map<String, Object?>>[
        customerOrderJson(status: 'completed', rating: _ratedTwo),
      ];
      await tapAndSettle(tester, byKey('rate-send'));

      expect(location(tester), AppPaths.customerOrder(orderOne));
      expect(byKey('order-rated'), findsOneWidget);
    });
  }

  testWidgets('a comment over 500 is refused before sending', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 3));
    await tester.enterText(byKey('rate-comment'), 'я' * 501);
    await tester.pump();

    expect(find.text('501 / 500'), findsOneWidget);
    await tester.tap(byKey('rate-send'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(orders.ratings, isEmpty);
    expect(sendActive(tester), isFalse);
  });

  testWidgets('the screen leaves at once for an order that cannot be rated', (
    WidgetTester tester,
  ) async {
    orders.rows = <Map<String, Object?>>[
      customerOrderJson(status: 'completed'),
    ];
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 3));

    expect(location(tester), AppPaths.customerOrder(orderOne));
    expect(byKey('rate-send'), findsNothing);
  });

  testWidgets('the page offers stars only while it can be rated', (
    WidgetTester tester,
  ) async {
    await open(tester);
    expect(byKey('order-rate'), findsOneWidget);
    expect(byKey('order-rated'), findsNothing);
    for (int stars = 1; stars <= 5; stars++) {
      expect(byKey('order-rate-$stars'), findsOneWidget);
    }
    expect(find.text('Как вам заказ?'), findsOneWidget);

    orders.rows = <Map<String, Object?>>[
      customerOrderJson(status: 'completed', rating: _ratedTwo),
    ];
    await open(tester);
    expect(byKey('order-rate'), findsNothing);
    expect(byKey('order-rated'), findsOneWidget);

    orders.rows = <Map<String, Object?>>[customerOrderJson(status: 'shopping')];
    await open(tester);
    expect(byKey('order-rate'), findsNothing);
    expect(byKey('order-rated'), findsNothing);
  });

  for (final Locale locale in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'the screen holds at 2 stars with text x2 (${locale.languageCode})',
      (WidgetTester tester) async {
        await open(
          tester,
          rate: AppPaths.customerOrderRate(orderOne, stars: 2),
          size: const Size(320, 640),
          textScale: 2,
          device: locale,
        );
        await tapAndSettle(tester, byKey('rate-reason-not_fresh'));
        await tester.enterText(byKey('rate-comment'), 'мятые ' * 30);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'the page holds the rated card with text x2 (${locale.languageCode})',
      (WidgetTester tester) async {
        orders.rows = <Map<String, Object?>>[
          customerOrderJson(
            status: 'completed',
            rating: <String, Object?>{
              'stars': 1,
              'reasons': <Object?>['not_fresh', 'wrong_weight', 'late', 'rude'],
              'comment': 'мятые ' * 40,
              'created_at': '2026-09-29T08:00:00Z',
            },
          ),
        ];
        await open(
          tester,
          size: const Size(320, 640),
          textScale: 2,
          device: locale,
        );

        await tester.scrollUntilVisible(
          byKey('order-rated'),
          200,
          scrollable: find
              .descendant(of: byKey('order'), matching: find.byType(Scrollable))
              .first,
        );
        expect(byKey('order-rated'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'the page holds the stars block with text x2 (${locale.languageCode})',
      (WidgetTester tester) async {
        await open(
          tester,
          size: const Size(320, 640),
          textScale: 2,
          device: locale,
        );

        await tester.scrollUntilVisible(
          byKey('order-rate'),
          200,
          scrollable: find
              .descendant(of: byKey('order'), matching: find.byType(Scrollable))
              .first,
        );
        expect(byKey('order-rate'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
