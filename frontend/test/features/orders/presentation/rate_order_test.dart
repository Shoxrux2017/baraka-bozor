import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/fold.dart';
import 'package:baraka_bozor/core/widgets/product_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

const String _lineEggs = '0192f0a0-0000-7000-8000-00000000c014';

/// A delivered order of [lines] named lines with pictures; [at] says whether
/// it has its delivery time, 13:05 Tashkent on the test clock's day.
Map<String, Object?> _boughtRow({int lines = 4, bool at = true}) {
  const List<(String, String, String, String)> all =
      <(String, String, String, String)>[
        (lineTomato, 'Pomidor', 'Помидоры', 'kg'),
        (lineBread, 'Non', 'Лепёшка', 'piece'),
        (lineMilk, 'Sut', 'Молоко домашнее', 'piece'),
        (_lineEggs, 'Tuxum', 'Яйца домашние', 'piece'),
      ];
  return customerOrderJson(
    status: 'completed',
    canRate: true,
    lines: <Object?>[
      for (final (String, String, String, String) line in all.take(lines))
        orderLineJson(
          id: line.$1,
          unit: line.$4,
          patch: <String, Object?>{
            'name_uz': line.$2,
            'name_ru': line.$3,
            'image_url': 'https://cdn.example/${line.$1}.webp',
          },
        ),
    ],
    timestamps: at
        ? <String, Object?>{'completed_at': '2026-09-28T08:05:00Z'}
        : null,
  );
}

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
    TextScaler? textScaler,
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
        textScaler: textScaler,
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
  bool filled(WidgetTester tester, String key) => find
      .descendant(of: byKey(key), matching: find.byIcon(Icons.star))
      .evaluate()
      .isNotEmpty;

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

  List<String> announced(WidgetTester tester) => tester
      .takeAnnouncements()
      .map((CapturedAccessibilityAnnouncement a) => a.message)
      .toList();

  bool shown(WidgetTester tester, String key) => tester
      .widget<Fold>(
        find.descendant(of: byKey(key), matching: find.byType(Fold)),
      )
      .shown;

  String hint(WidgetTester tester) =>
      tester.widget<TextField>(byKey('rate-comment')).decoration!.hintText!;

  testWidgets('a reader meets one adjustable rating on the screen', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 2));

    final Finder node = find.bySemanticsLabel('Оценка');
    expect(node, findsOneWidget);
    final SemanticsNode semantics = tester.getSemantics(node);
    expect(semantics.value, '2 из 5, Плохо');
    expect(
      semantics.getSemanticsData().hasAction(SemanticsAction.increase),
      isTrue,
    );
    expect(find.bySemanticsLabel(RegExp('Оценить на')), findsNothing);
    handle.dispose();
  });

  testWidgets('the header names what was bought', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    orders.rows = <Map<String, Object?>>[_boughtRow()];
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 5));

    final Finder header = byKey('rate-header');
    expect(
      find.descendant(of: header, matching: find.byType(ProductImage)),
      findsNWidgets(3),
    );
    expect(
      find.descendant(of: header, matching: find.text('+1')),
      findsOneWidget,
    );
    expect(
      find.text('Помидоры, Лепёшка и ещё 2 · доставлен сегодня в 13:05'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Как вам заказ? Заказ № 1001, доставлен сегодня в 13:05: '
        'Помидоры, Лепёшка и ещё 2',
      ),
      findsOneWidget,
    );

    orders.rows = <Map<String, Object?>>[_boughtRow(lines: 1)];
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 5));
    expect(find.text('Помидоры · доставлен сегодня в 13:05'), findsOneWidget);
    expect(
      find.descendant(
        of: byKey('rate-header'),
        matching: find.byType(ProductImage),
      ),
      findsOneWidget,
    );

    orders.rows = <Map<String, Object?>>[_boughtRow(lines: 2, at: false)];
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 5));
    expect(find.text('Помидоры, Лепёшка'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('photos and hint fold at 1 to 3', (WidgetTester tester) async {
    orders.rows = <Map<String, Object?>>[_boughtRow()];
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 5));

    expect(shown(tester, 'rate-photos'), isTrue);
    expect(shown(tester, 'rate-hint'), isTrue);
    expect(shown(tester, 'rate-reasons'), isFalse);
    expect(find.text('Оцените всё: свежесть, вес и доставку'), findsOneWidget);

    await tapAndSettle(tester, byKey('rate-star-2'));

    expect(shown(tester, 'rate-photos'), isFalse);
    expect(shown(tester, 'rate-hint'), isFalse);
    expect(shown(tester, 'rate-reasons'), isTrue);
    expect(find.text('Что пошло не так?'), findsOneWidget);
    expect(find.text('Можно выбрать несколько'), findsOneWidget);
  });

  testWidgets('reasons fold at 4 and come back at 2', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 2));
    await tapAndSettle(tester, byKey('rate-reason-not_fresh'));
    tester.takeAnnouncements();

    await tapAndSettle(tester, byKey('rate-star-4'));
    expect(shown(tester, 'rate-reasons'), isFalse);
    expect(announced(tester), <String>[
      '4 из 5, Хорошо. Причины скрыты — они не отправятся.',
    ]);

    await tapAndSettle(tester, byKey('rate-star-2'));
    expect(shown(tester, 'rate-reasons'), isTrue);
    expect(
      find.descendant(
        of: byKey('rate-reason-not_fresh'),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(announced(tester), <String>[
      '2 из 5, Плохо. Появился вопрос: что пошло не так?',
    ]);
  });

  testWidgets('a reader hears only what the value does not say', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 3));
    await tapAndSettle(tester, byKey('rate-reason-late'));
    tester.takeAnnouncements();

    tester.semantics.performAction(
      find.semantics.byLabel('Оценка'),
      SemanticsAction.increase,
    );
    await tester.pumpAndSettle();
    expect(announced(tester), <String>['Причины скрыты — они не отправятся.']);

    tester.semantics.performAction(
      find.semantics.byLabel('Оценка'),
      SemanticsAction.increase,
    );
    await tester.pumpAndSettle();
    expect(announced(tester), isEmpty);

    for (int i = 0; i < 2; i++) {
      tester.semantics.performAction(
        find.semantics.byLabel('Оценка'),
        SemanticsAction.decrease,
      );
      await tester.pumpAndSettle();
    }
    expect(announced(tester), <String>['Появился вопрос: что пошло не так?']);
    handle.dispose();
  });

  testWidgets('the example follows the reasons', (WidgetTester tester) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 2));
    expect(hint(tester), 'Что случилось?');

    await tapAndSettle(tester, byKey('rate-reason-not_fresh'));
    expect(hint(tester), 'Какой товар был несвежим?');
    await tapAndSettle(tester, byKey('rate-reason-not_fresh'));
    await tapAndSettle(tester, byKey('rate-reason-wrong_weight'));
    expect(hint(tester), 'Какой товар и насколько не тот вес?');
    await tapAndSettle(tester, byKey('rate-reason-wrong_weight'));
    await tapAndSettle(tester, byKey('rate-reason-late'));
    expect(hint(tester), 'На сколько опоздал курьер?');
    await tapAndSettle(tester, byKey('rate-reason-late'));
    await tapAndSettle(tester, byKey('rate-reason-rude'));
    expect(hint(tester), 'Что случилось? Мы разберёмся');

    await tapAndSettle(tester, byKey('rate-reason-late'));
    expect(hint(tester), 'Расскажите, что случилось');

    await tapAndSettle(tester, byKey('rate-star-5'));
    expect(hint(tester), 'Что понравилось?');
  });

  testWidgets('the counter shows from 450 and says how far over', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 3));
    Color edge() =>
        (tester.widget<DecoratedBox>(byKey('rate-field')).decoration
                as BoxDecoration)
            .border!
            .top
            .color;

    await tester.enterText(byKey('rate-comment'), 'я' * 449);
    await tester.pump();
    expect(byKey('rate-counter'), findsNothing);

    await tester.enterText(byKey('rate-comment'), 'я' * 450);
    await tester.pump();
    expect(find.text('Осталось 50 знаков'), findsOneWidget);
    expect(
      tester.widget<Text>(byKey('rate-counter')).style!.color,
      KitColors.muted,
    );
    expect(edge(), isNot(KitColors.danger));

    await tester.enterText(byKey('rate-comment'), 'я' * 520);
    await tester.pump();
    expect(find.text('На 20 знаков больше, чем можно'), findsOneWidget);
    expect(
      tester.widget<Text>(byKey('rate-counter')).style!.color,
      KitColors.danger,
    );
    expect(edge(), KitColors.danger);
  });

  testWidgets('a reason is announced chosen and not chosen', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 2));
    tester.takeAnnouncements();

    await tapAndSettle(tester, byKey('rate-reason-not_fresh'));
    expect(announced(tester), <String>['Несвежее, выбрано']);
    await tapAndSettle(tester, byKey('rate-reason-not_fresh'));
    expect(announced(tester), <String>['Несвежее, не выбрано']);
  });

  testWidgets('the word changes with the stars', (WidgetTester tester) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne));
    String word() => tester.widget<Text>(byKey('rate-word')).data!;

    expect(word(), '');
    await tapAndSettle(tester, byKey('rate-star-1'));
    expect(word(), 'Очень плохо');
    await tapAndSettle(tester, byKey('rate-star-5'));
    expect(word(), 'Отлично!');
  });

  testWidgets('a reader hears the field by its name', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 2));

    expect(
      tester.getSemantics(byKey('rate-comment')).label,
      contains('Комментарий, необязательно'),
    );
    expect(find.bySemanticsLabel('Комментарий (необязательно)'), findsNothing);
    handle.dispose();
  });

  testWidgets('at 200 % on 360 dp the form fits and every target is 44', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    orders.rows = <Map<String, Object?>>[_boughtRow()];
    await open(
      tester,
      rate: AppPaths.customerOrderRate(orderOne, stars: 2),
      size: const Size(360, 640),
      textScaler: const NonlinearTextScaler(2),
    );
    await tapAndSettle(tester, byKey('rate-reason-not_fresh'));
    await tapAndSettle(tester, byKey('rate-reason-late'));

    expect(tester.takeException(), isNull);
    for (final String key in <String>[
      'rate-reason-not_fresh',
      'rate-reason-wrong_weight',
      'rate-reason-late',
      'rate-reason-rude',
    ]) {
      await tester.ensureVisible(byKey(key));
      expect(tester.getSize(byKey(key)).height, greaterThanOrEqualTo(44));
    }
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });

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
    expect(shown(tester, 'rate-reasons'), isFalse);
    expect(
      find.descendant(
        of: byKey('rate-header'),
        matching: find.text('Как вам заказ?'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a stars value out of range is ignored', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: '${AppPaths.customerOrderRate(orderOne)}?stars=9');

    expect(filled(tester, 'rate-star-5'), isFalse);
    expect(sendActive(tester), isFalse);
    expect(shown(tester, 'rate-reasons'), isFalse);
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
    expect(byKey('rate-counter'), findsNothing);
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
          'reviewed_at': null,
        },
      ),
    ];
    await tapAndSettle(tester, byKey('rate-send'));

    expectSent(5, <String>[], null);
    expect(find.text('Спасибо за оценку!'), findsOneWidget);
  });

  testWidgets('a chosen reason shows a check mark, an unchosen one none', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 2));
    Finder check(String key) =>
        find.descendant(of: byKey(key), matching: find.byIcon(Icons.check));

    expect(check('rate-reason-not_fresh'), findsNothing);
    await tapAndSettle(tester, byKey('rate-reason-not_fresh'));

    expect(check('rate-reason-not_fresh'), findsOneWidget);
    expect(check('rate-reason-late'), findsNothing);
    expect(
      tester.widget<Icon>(check('rate-reason-not_fresh')).color,
      KitColors.primaryDark,
    );
  });

  testWidgets(
    'raising to 4 hides the reasons, sends none, 2 brings them back',
    (WidgetTester tester) async {
      await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 2));

      await tapAndSettle(tester, byKey('rate-reason-late'));
      await tapAndSettle(tester, byKey('rate-star-4'));
      expect(shown(tester, 'rate-reasons'), isFalse);
      await tapAndSettle(tester, byKey('rate-star-2'));
      expect(shown(tester, 'rate-reasons'), isTrue);
      expect(
        find.descendant(
          of: byKey('rate-reason-late'),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      await tapAndSettle(tester, byKey('rate-star-4'));
      await tapAndSettle(tester, byKey('rate-send'));

      expectSent(4, <String>[], null);
    },
  );

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

    expect(find.text('На 1 знак больше, чем можно'), findsOneWidget);
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
}
