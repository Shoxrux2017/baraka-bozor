import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/orders/application/customer_orders_controllers.dart';
import 'package:baraka_bozor/features/orders/application/rate_draft.dart';
import 'package:baraka_bozor/features/orders/presentation/rate_order_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_cart_repository.dart';
import '../../../support/fake_customer_orders_repository.dart';
import '../../../support/in_memory_stores.dart';
import '../../../support/nonlinear_text_scaler.dart';

const Map<String, Object?> _ratedTwo = <String, Object?>{
  'stars': 2,
  'reasons': <Object?>['not_fresh'],
  'comment': 'мятые',
  'created_at': '2026-09-29T08:00:00Z',
  'reviewed_at': null,
};

/// The order page's rating cards, the draft strip, the rated card with its
/// note, and the outcome the page plays when the rating screen returns
/// (`DL-134`), through the real router and screens with the repositories
/// faked. The test clock stands at 14:00 Tashkent on 2026-09-28.
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

  /// The rating screen's address, query included; `null` while it is not
  /// open.
  String? screenAt(WidgetTester tester) {
    final Finder screen = find.byType(RateOrderScreen);
    return screen.evaluate().isEmpty
        ? null
        : GoRouterState.of(tester.element(screen)).uri.toString();
  }

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
    TextScaler? textScaler,
    double textScale = 1,
    Locale device = const Locale('ru'),
    bool list = false,
  }) async {
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
        textScaler: textScaler,
        device: device,
        clock: () => DateTime.utc(2026, 9, 28, 9),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(
      anywhere(tester),
    ).push(list ? AppPaths.customerOrders : AppPaths.customerOrder(orderOne));
    await tester.pumpAndSettle();
    if (rate != null) {
      unawaited(GoRouter.of(anywhere(tester)).push<RateExit>(rate));
      await tester.pumpAndSettle();
    }
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(anywhere(tester));

  void keepDraft(WidgetTester tester) =>
      container(tester)
          .read(rateDraftsProvider.notifier)
          .keep(
            orderOne,
            const RateDraft(
              stars: 2,
              reasons: <RatingReason>{RatingReason.notFresh},
              comment: 'мятые',
            ),
          );

  /// The platform calls the test hears, for the haptics.
  List<MethodCall> hearPlatform(WidgetTester tester) {
    final List<MethodCall> calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return calls;
  }

  int lightImpacts(List<MethodCall> calls) => calls
      .where(
        (MethodCall c) =>
            c.method == 'HapticFeedback.vibrate' &&
            c.arguments == 'HapticFeedbackType.lightImpact',
      )
      .length;

  Map<String, Object?> ratedRow(
    int stars, {
    String? reviewedAt,
    String createdAt = '2026-09-28T08:13:00Z',
  }) => customerOrderJson(
    status: 'completed',
    rating: <String, Object?>{
      'stars': stars,
      'reasons': stars <= 3 ? <Object?>['not_fresh'] : <Object?>[],
      'comment': null,
      'created_at': createdAt,
      'reviewed_at': reviewedAt,
    },
  );

  /// Whether the card's star [star] is drawn filled.
  bool filled(WidgetTester tester, String key) => find
      .descendant(of: byKey(key), matching: find.byIcon(Icons.star))
      .evaluate()
      .isNotEmpty;

  List<bool> lit(WidgetTester tester) => <bool>[
    for (int k = 1; k <= 5; k++) filled(tester, 'order-rate-$k'),
  ];

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Scrolls the order page until [finder] is built and in view.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .descendant(of: byKey('order'), matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
  }

  /// The rated card's ground colour right now.
  Color? ground(WidgetTester tester) =>
      (tester.widget<DecoratedBox>(byKey('order-rated')).decoration
              as BoxDecoration)
          .color;

  /// Sends the rating on the screen and lets the check stand, then steps
  /// 40 ms at a time until [stop] holds, for at most a second.
  Future<void> sendUntil(WidgetTester tester, bool Function() stop) async {
    await tester.tap(byKey('rate-send'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 700));
    for (int i = 0; i < 25 && !stop(); i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
  }

  testWidgets("the card's stars light to the tap and the screen rises", (
    WidgetTester tester,
  ) async {
    final List<MethodCall> calls = hearPlatform(tester);
    await open(tester);
    await tester.ensureVisible(byKey('order-rate-3'));
    await tester.pumpAndSettle();
    for (int k = 1; k <= 5; k++) {
      expect(tester.getSize(byKey('order-rate-$k')), const Size(44, 44));
    }
    expect(lit(tester), <bool>[false, false, false, false, false]);

    await tester.tap(byKey('order-rate-3'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(lit(tester), <bool>[true, true, true, false, false]);
    expect(lightImpacts(calls), 1);
    expect(screenAt(tester), isNull);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(screenAt(tester), AppPaths.customerOrderRate(orderOne, stars: 3));
    expect(lightImpacts(calls), 1);

    await tapAndSettle(tester, byKey('rate-close'));
    expect(screenAt(tester), isNull);
    expect(location(tester), AppPaths.customerOrder(orderOne));
    expect(lit(tester), <bool>[false, false, false, false, false]);
  });

  testWidgets('with reduced motion the screen rises after 120 ms', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await open(tester);
    await tester.tap(byKey('order-rate-4'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(screenAt(tester), isNull);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpAndSettle();
    expect(screenAt(tester), AppPaths.customerOrderRate(orderOne, stars: 4));
  });

  testWidgets('a second tap while the screen is on its way is ignored', (
    WidgetTester tester,
  ) async {
    final List<MethodCall> calls = hearPlatform(tester);
    await open(tester);
    await tester.tap(byKey('order-rate-3'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(byKey('order-rate-5'));
    await tester.pumpAndSettle();
    expect(screenAt(tester), AppPaths.customerOrderRate(orderOne, stars: 3));
    // The stars stand disabled during the wait: no second haptic.
    expect(lightImpacts(calls), 1);
  });

  testWidgets('the card does not open the screen once another page covers it', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.tap(byKey('order-rate-3'));
    await tester.pump(const Duration(milliseconds: 100));
    unawaited(
      GoRouter.of(anywhere(tester)).push<void>(AppPaths.customerNewAddress),
    );
    await tester.pumpAndSettle();

    expect(screenAt(tester), isNull);
    expect(location(tester), AppPaths.customerNewAddress);
    GoRouter.of(anywhere(tester)).pop();
    await tester.pumpAndSettle();
    expect(lit(tester), <bool>[false, false, false, false, false]);
  });

  testWidgets('the draft strip reads as its words and one button', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await open(tester);
    keepDraft(tester);
    await tester.pumpAndSettle();

    final Finder strip = find.bySemanticsLabel(
      'Оценка не отправлена. Продолжить',
    );
    expect(strip, findsOneWidget);
    final SemanticsData data = tester.getSemantics(strip).getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(find.bySemanticsLabel('Оценка не отправлена'), findsNothing);
    expect(find.bySemanticsLabel('Продолжить'), findsNothing);

    tester.semantics.tap(
      find.semantics.byLabel('Оценка не отправлена. Продолжить'),
    );
    await tester.pumpAndSettle();
    expect(screenAt(tester), AppPaths.customerOrderRate(orderOne));
    handle.dispose();
  });

  testWidgets('the rated card is one reader node with the whole phrase', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    orders.rows = <Map<String, Object?>>[
      customerOrderJson(
        status: 'completed',
        rating: <String, Object?>{
          'stars': 2,
          'reasons': <Object?>['not_fresh', 'late'],
          'comment': 'мятые',
          'created_at': '2026-09-28T08:13:00Z',
          'reviewed_at': null,
        },
      ),
    ];
    await open(tester);

    final Finder card = find.bySemanticsLabel(
      'Ваша оценка, сегодня в 13:13. Оценка: 2 из 5. Несвежее, Опоздал. '
      '«мятые». Оператор свяжется с вами, чтобы разобраться',
    );
    expect(card, findsOneWidget);
    expect(find.bySemanticsLabel('Ваша оценка'), findsNothing);
    expect(find.bySemanticsLabel('Оценка: 2 из 5'), findsNothing);
    expect(find.bySemanticsLabel('Несвежее'), findsNothing);
    handle.dispose();
  });

  testWidgets('a draft shows on the card and continues', (
    WidgetTester tester,
  ) async {
    await open(tester);
    expect(find.text('Оценка не отправлена'), findsNothing);
    keepDraft(tester);
    await tester.pumpAndSettle();

    expect(find.text('Оценка не отправлена'), findsOneWidget);
    expect(find.text('Продолжить'), findsOneWidget);
    expect(find.byIcon(Icons.edit_note), findsOneWidget);

    await tapAndSettle(tester, find.text('Продолжить'));
    expect(screenAt(tester), AppPaths.customerOrderRate(orderOne));
    expect(filled(tester, 'rate-star-2'), isTrue);
    expect(filled(tester, 'rate-star-3'), isFalse);
    expect(
      find.descendant(
        of: byKey('rate-reason-not_fresh'),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(byKey('rate-comment')).controller!.text,
      'мятые',
    );

    await tapAndSettle(tester, byKey('rate-close'));
    expect(find.text('Оценка не отправлена'), findsOneWidget);

    orders.rows = <Map<String, Object?>>[customerOrderJson(status: 'shopping')];
    container(tester).invalidate(customerOrderProvider(orderOne));
    await tester.pumpAndSettle();
    expect(find.text('Оценка не отправлена'), findsNothing);
    expect(byKey('order-rate'), findsNothing);
  });

  testWidgets('a sent rating flashes the rated card', (
    WidgetTester tester,
  ) async {
    await open(tester, size: const Size(360, 560));
    double top() => tester
        .state<ScrollableState>(
          find
              .descendant(of: byKey('order'), matching: find.byType(Scrollable))
              .first,
        )
        .position
        .pixels;
    await scrollTo(tester, byKey('order-rate-5'));
    expect(top(), greaterThan(0));
    await tester.tap(byKey('order-rate-5'));
    await tester.pumpAndSettle();
    expect(screenAt(tester), AppPaths.customerOrderRate(orderOne, stars: 5));
    orders.rows = <Map<String, Object?>>[ratedRow(5)];
    await sendUntil(tester, () => byKey('order-rated').evaluate().isNotEmpty);
    // The screen sinks, then the card says the rating and flashes.
    for (int i = 0; i < 25 && ground(tester) == Colors.white; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }

    expect(location(tester), AppPaths.customerOrder(orderOne));
    expect(ground(tester), isNot(Colors.white));
    final BoxDecoration start =
        tester.widget<DecoratedBox>(byKey('order-rated')).decoration
            as BoxDecoration;
    expect(start.boxShadow!.first.spreadRadius, greaterThan(1));

    // The page brings its top into view in 300 ms.
    await tester.pump(const Duration(milliseconds: 350));
    expect(top(), 0);

    await tester.pump(const Duration(milliseconds: 1600));
    expect(ground(tester), Colors.white);
    final BoxDecoration end =
        tester.widget<DecoratedBox>(byKey('order-rated')).decoration
            as BoxDecoration;
    expect(end.boxShadow!.single.spreadRadius, 0);
    await tester.pumpAndSettle();
  });

  testWidgets('already rated shows the banner with the stored stars', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await open(tester);
    await tester.tap(byKey('order-rate-2'));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, byKey('rate-reason-late'));
    orders.rateFailure = const ApiRefusal(
      ApiError(status: 409, code: 'order_already_rated'),
    );
    orders.rows = <Map<String, Object?>>[ratedRow(4)];
    tester.takeAnnouncements();
    await tester.tap(byKey('rate-send'));
    for (
      int i = 0;
      i < 40 && byKey('rated-already-banner').evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 40));
    }

    expect(byKey('rated-already-banner'), findsOneWidget);
    expect(find.text('Этот заказ уже оценили: 4 из 5'), findsOneWidget);
    expect(
      find.text('Оценку отправили раньше — изменить её нельзя'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.info), findsOneWidget);
    expect(
      tester
          .takeAnnouncements()
          .map((CapturedAccessibilityAnnouncement a) => a.message)
          .any(
            (String m) =>
                m.contains('Этот заказ уже оценили: 4 из 5') &&
                m.contains('Оценку отправили раньше — изменить её нельзя'),
          ),
      isTrue,
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(byKey('rated-already-banner'), findsNothing);
    handle.dispose();
  });

  testWidgets('the rated card says when and what next', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    orders.rows = <Map<String, Object?>>[ratedRow(2)];
    await open(tester);
    expect(find.text('сегодня в 13:13'), findsOneWidget);
    expect(
      find.text('Оператор свяжется с вами, чтобы разобраться'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: byKey('order-rated'),
        matching: find.byIcon(Icons.support_agent),
      ),
      findsOneWidget,
    );

    orders.rows = <Map<String, Object?>>[
      ratedRow(2, reviewedAt: '2026-09-28T10:40:00Z'),
    ];
    await open(tester);
    expect(
      find.text('Оператор связался с вами сегодня в 15:40'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: byKey('order-rated'),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Ваша оценка, сегодня в 13:13. Оценка: 2 из 5. Несвежее. '
        'Оператор связался с вами сегодня в 15:40',
      ),
      findsOneWidget,
    );

    orders.rows = <Map<String, Object?>>[
      ratedRow(5, reviewedAt: '2026-09-28T10:40:00Z'),
    ];
    await open(tester);
    expect(find.text('Спасибо за оценку!'), findsOneWidget);
    expect(find.textContaining('Оператор'), findsNothing);
    expect(
      find.descendant(
        of: byKey('order-rated'),
        matching: find.byIcon(Icons.support_agent),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: byKey('order-rated'),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('rating from the list returns to the list', (
    WidgetTester tester,
  ) async {
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(status: 'completed', canRate: true),
    ];
    await open(tester, list: true);
    await tapAndSettle(tester, byKey('orders-tab-past'));
    await tapAndSettle(tester, byKey('order-rate-$orderOne-5'));
    expect(screenAt(tester), AppPaths.customerOrderRate(orderOne, stars: 5));

    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(status: 'completed', ratingStars: 5),
    ];
    orders.rows = <Map<String, Object?>>[ratedRow(5)];
    await sendUntil(tester, () => screenAt(tester) == null);
    await tester.pumpAndSettle();

    expect(location(tester), AppPaths.customerOrders);
    expect(byKey('rated-already-banner'), findsNothing);
    expect(byKey('order-rated'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: byKey('order-stars-$orderOne'),
        matching: find.byType(Icon),
      ),
      findsNWidgets(10),
    );
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
              'reviewed_at': null,
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

  group('at large text', () {
    const Size phone = Size(360, 640);
    const NonlinearTextScaler big = NonlinearTextScaler(2);

    Future<void> checkTargets(WidgetTester tester) async {
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    }

    testWidgets('the rate card with its draft strip holds', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await open(tester, size: phone, textScaler: big);
      await scrollTo(tester, byKey('order-rate'));
      await checkTargets(tester);

      keepDraft(tester);
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Продолжить'));
      await checkTargets(tester);
      handle.dispose();
    });

    testWidgets('the rate card with its draft strip holds at 100 %', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await open(tester, size: phone);
      await scrollTo(tester, byKey('order-rate'));
      keepDraft(tester);
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Продолжить'));
      await checkTargets(tester);
      handle.dispose();
    });

    testWidgets('the rated card holds with a reviewed note', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      orders.rows = <Map<String, Object?>>[
        ratedRow(1, reviewedAt: '2026-09-28T10:40:00Z'),
      ];
      await open(tester, size: phone, textScaler: big);
      await scrollTo(tester, byKey('order-rated'));
      await checkTargets(tester);
      handle.dispose();
    });

    testWidgets('the banner holds', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await open(tester, size: phone, textScaler: big);
      await scrollTo(tester, byKey('order-rate-2'));
      await tester.tap(byKey('order-rate-2'));
      await tester.pumpAndSettle();
      orders.rateFailure = const ApiRefusal(
        ApiError(status: 409, code: 'order_already_rated'),
      );
      orders.rows = <Map<String, Object?>>[ratedRow(4)];
      await tester.ensureVisible(byKey('rate-send'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('rate-send'));
      for (
        int i = 0;
        i < 40 && byKey('rated-already-banner').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pump(const Duration(milliseconds: 500));

      expect(byKey('rated-already-banner'), findsOneWidget);
      await checkTargets(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      handle.dispose();
    });
  });
}
