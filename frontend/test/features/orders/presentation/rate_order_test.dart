import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/fold.dart';
import 'package:baraka_bozor/core/widgets/product_image.dart';
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

  /// What the rating screen returned to whoever pushed it, and whether it
  /// returned at all.
  RateExit? exit;
  bool exited = false;

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
    exit = null;
    exited = false;
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
      unawaited(
        GoRouter.of(anywhere(tester))
            .push<RateExit>(rate)
            .then((RateExit? result) {
              exit = result;
              exited = true;
            }),
      );
      await tester.pumpAndSettle();
    }
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(anywhere(tester));

  RateDraft? kept(WidgetTester tester) =>
      container(tester).read(rateDraftsProvider)[orderOne];

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

  Map<String, Object?> ratedRow(int stars) => customerOrderJson(
    status: 'completed',
    rating: <String, Object?>{
      'stars': stars,
      'reasons': stars <= 3 ? <Object?>['not_fresh'] : <Object?>[],
      'comment': null,
      'created_at': '2026-09-29T08:00:00Z',
      'reviewed_at': null,
    },
  );

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Taps send, lets the answer in and the check stand, and the screen go.
  Future<void> sendAndLand(WidgetTester tester) async {
    await tapAndSettle(tester, byKey('rate-send'));
    await tester.pump(const Duration(milliseconds: 700));
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
    await sendAndLand(tester);

    expectSent(2, <String>['not_fresh'], 'мятые');
    expect(location(tester), AppPaths.customerOrder(orderOne));
    expect(byKey('order-rated'), findsOneWidget);
    expect(byKey('order-rate'), findsNothing);
    expect(find.text('Несвежее'), findsOneWidget);
    expect(find.text('«мятые»'), findsOneWidget);
    expect(
      find.text('Оператор свяжется с вами, чтобы разобраться'),
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
    await sendAndLand(tester);

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
    expect(find.text('Отправляем…'), findsOneWidget);
    orders.hold!.complete();
    await tester.pumpAndSettle();

    expect(orders.ratings, hasLength(1));
  });

  testWidgets('sending freezes the form and ends with a check', (
    WidgetTester tester,
  ) async {
    final List<MethodCall> platform = hearPlatform(tester);
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 2));
    orders.rows = <Map<String, Object?>>[ratedRow(2)];
    orders.hold = Completer<void>();
    tester.takeAnnouncements();

    await tester.tap(byKey('rate-send'));
    await tester.pump();
    expect(find.text('Отправляем…'), findsOneWidget);
    expect(announced(tester), <String>['Отправляем оценку…']);
    await tester.tap(byKey('rate-star-5'), warnIfMissed: false);
    await tester.tap(byKey('rate-reason-late'), warnIfMissed: false);
    await tester.pump();
    expect(filled(tester, 'rate-star-5'), isFalse);
    expect(
      find.descendant(
        of: byKey('rate-reason-late'),
        matching: find.byIcon(Icons.check),
      ),
      findsNothing,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(byKey('rate-send'), findsOneWidget);

    orders.hold!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Оценка отправлена'), findsOneWidget);
    expect(announced(tester), <String>[
      'Оценка отправлена: 2 из 5. Оператор свяжется с вами.',
    ]);
    expect(
      platform
          .where(
            (MethodCall c) =>
                c.method == 'HapticFeedback.vibrate' &&
                c.arguments == 'HapticFeedbackType.lightImpact',
          )
          .length,
      1,
    );
    await tester.pump(const Duration(milliseconds: 590));
    expect(exited, isFalse);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(exited, isTrue);
    expect(exit, RateExit.sent);
    expect(kept(tester), isNull);
  });

  testWidgets('with reduced motion the check stands 500 ms', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 5));
    orders.rows = <Map<String, Object?>>[ratedRow(5)];
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();

    await tester.tap(byKey('rate-send'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 480));
    expect(exited, isFalse);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpAndSettle();
    expect(exit, RateExit.sent);
  });

  testWidgets('nothing sent shows the strip and stays editable', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 2));
    orders.rateFailure = const NetworkFailure(mayHaveArrived: false);
    tester.takeAnnouncements();
    await tapAndSettle(tester, byKey('rate-send'));

    expect(byKey('rate-strip'), findsOneWidget);
    expect(find.text('Нет связи — оценка не отправлена'), findsOneWidget);
    expect(byKey('rate-unsure'), findsNothing);
    expect(announced(tester), <String>[
      'Отправляем оценку…',
      'Оценка не отправлена: нет связи.',
    ]);
    expect(
      find.descendant(
        of: byKey('rate-strip'),
        matching: find.text('Повторить'),
      ),
      findsOneWidget,
    );

    await tapAndSettle(tester, byKey('rate-star-5'));
    expect(filled(tester, 'rate-star-5'), isTrue);
    orders.rows = <Map<String, Object?>>[ratedRow(5)];
    await tapAndSettle(tester, byKey('rate-retry'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(orders.ratings, hasLength(2));
    expect(orders.ratings.last.$2, 5);
    expect(exit, RateExit.sent);
  });

  testWidgets('a lost answer locks the form', (WidgetTester tester) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 2));
    await tapAndSettle(tester, byKey('rate-reason-not_fresh'));
    orders.rateFailure = const NetworkFailure();
    tester.takeAnnouncements();
    await tapAndSettle(tester, byKey('rate-send'));

    expect(byKey('rate-unsure'), findsOneWidget);
    expect(
      find.text(
        'Ответ не дошёл — оценка могла сохраниться. '
        'Отправьте ещё раз: дважды она не сохранится.',
      ),
      findsOneWidget,
    );
    expect(announced(tester), <String>[
      'Отправляем оценку…',
      'Ответ не дошёл. Оценка могла сохраниться. Отправьте ещё раз.',
    ]);
    await tapAndSettle(tester, byKey('rate-star-5'));
    expect(filled(tester, 'rate-star-5'), isFalse);
    expect(filled(tester, 'rate-star-2'), isTrue);
    await tapAndSettle(tester, byKey('rate-reason-late'));
    expect(
      find.descendant(
        of: byKey('rate-reason-late'),
        matching: find.byIcon(Icons.check),
      ),
      findsNothing,
    );
    expect(tester.widget<TextField>(byKey('rate-comment')).readOnly, isTrue);
    expect(
      find.descendant(
        of: byKey('rate-send'),
        matching: find.text('Отправить ещё раз'),
      ),
      findsOneWidget,
    );
    expect(sendActive(tester), isTrue);
  });

  testWidgets('a resend after a lost answer sends the same body and ends as '
      'sent', (WidgetTester tester) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 2));
    await tapAndSettle(tester, byKey('rate-reason-not_fresh'));
    await tester.enterText(byKey('rate-comment'), '  мятые  ');
    await tester.pump();
    orders.rateFailure = const NetworkFailure();
    await tapAndSettle(tester, byKey('rate-send'));
    orders.rows = <Map<String, Object?>>[
      customerOrderJson(status: 'completed', rating: _ratedTwo),
    ];

    await tester.tap(byKey('rate-send'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Оценка отправлена'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(orders.ratings, hasLength(2));
    expect(orders.ratings.first.$2, orders.ratings.last.$2);
    expect(orders.ratings.first.$3, orders.ratings.last.$3);
    expect(orders.ratings.first.$4, orders.ratings.last.$4);
    expect(orders.ratings.last.$2, 2);
    expect(orders.ratings.last.$3, <String>['not_fresh']);
    expect(orders.ratings.last.$4, 'мятые');
    expect(exit, RateExit.sent);
  });

  testWidgets('a locked resend that fails again keeps the lock', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 2));
    orders.rateFailure = const NetworkFailure();
    await tapAndSettle(tester, byKey('rate-send'));
    orders.rateFailure = const ApiRefusal(
      ApiError(status: 429, code: 'rate_limited'),
    );
    await tapAndSettle(tester, byKey('rate-send'));

    expect(byKey('rate-unsure'), findsOneWidget);
    expect(byKey('rate-failure'), findsOneWidget);
    expect(sendActive(tester), isTrue);
    expect(tester.widget<TextField>(byKey('rate-comment')).readOnly, isTrue);
  });

  testWidgets('at 5 the kept reasons are not sent', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 2));
    await tapAndSettle(tester, byKey('rate-reason-late'));
    await tapAndSettle(tester, byKey('rate-star-5'));
    orders.rows = <Map<String, Object?>>[ratedRow(5)];
    await sendAndLand(tester);

    expectSent(5, <String>[], null);
    expect(exit, RateExit.sent);
  });

  testWidgets('already rated pops with the outcome', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 2));
    await tapAndSettle(tester, byKey('rate-reason-late'));
    orders.rateFailure = const ApiRefusal(
      ApiError(status: 409, code: 'order_already_rated'),
    );
    orders.rows = <Map<String, Object?>>[ratedRow(4)];
    await tapAndSettle(tester, byKey('rate-send'));

    expect(exited, isTrue);
    expect(exit, RateExit.already);
    expect(location(tester), AppPaths.customerOrder(orderOne));
    expect(kept(tester), isNull);
    expect(byKey('order-rated'), findsOneWidget);
  });

  testWidgets('an order that cannot be rated pops with nothing', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 2));
    await tapAndSettle(tester, byKey('rate-reason-late'));
    orders.rateFailure = const ApiRefusal(
      ApiError(status: 409, code: 'order_not_rateable'),
    );
    orders.rows = <Map<String, Object?>>[ratedRow(4)];
    await tapAndSettle(tester, byKey('rate-send'));

    expect(exited, isTrue);
    expect(exit, isNull);
    expect(location(tester), AppPaths.customerOrder(orderOne));
    expect(kept(tester), isNull);
  });

  testWidgets('a closed window shows the calm face', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 2));
    await tapAndSettle(tester, byKey('rate-reason-late'));
    orders.rateFailure = const ApiRefusal(
      ApiError(status: 409, code: 'rating_window_closed'),
    );
    await tapAndSettle(tester, byKey('rate-send'));

    expect(find.text('Срок оценки прошёл'), findsOneWidget);
    expect(
      find.text('Оценить заказ можно в течение 7 дней после доставки.'),
      findsOneWidget,
    );
    expect(byKey('rate-stars'), findsNothing);
    expect(byKey('rate-comment'), findsNothing);
    expect(find.byIcon(Icons.schedule), findsOneWidget);
    expect(kept(tester), isNull);
    expect(find.text('Вернуться к заказу'), findsOneWidget);

    await tapAndSettle(tester, find.text('Вернуться к заказу'));
    expect(exited, isTrue);
    expect(exit, isNull);
    expect(location(tester), AppPaths.customerOrder(orderOne));
  });

  testWidgets('an unrated order past its window opens on the calm face', (
    WidgetTester tester,
  ) async {
    orders.rows = <Map<String, Object?>>[
      customerOrderJson(status: 'completed'),
    ];
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 3));

    expect(find.text('Срок оценки прошёл'), findsOneWidget);
    expect(byKey('rate-stars'), findsNothing);
    expect(exited, isFalse);
    await tapAndSettle(tester, find.text('Вернуться к заказу'));
    expect(exited, isTrue);
    expect(location(tester), AppPaths.customerOrder(orderOne));
  });

  testWidgets('another refusal is a red line and the form stays', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 3));
    orders.rateFailure = const ApiRefusal(
      ApiError(status: 429, code: 'rate_limited'),
    );
    await tapAndSettle(tester, byKey('rate-send'));

    expect(byKey('rate-failure'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: byKey('rate-failure'),
              matching: find.byType(Text),
            ),
          )
          .style!
          .color,
      KitColors.danger,
    );
    expect(byKey('rate-stars'), findsOneWidget);
    expect(byKey('rate-unsure'), findsNothing);
    expect(tester.widget<TextField>(byKey('rate-comment')).readOnly, isFalse);
    expect(sendActive(tester), isTrue);
    expect(exited, isFalse);
  });

  testWidgets('another failure is said above the button', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 3));
    orders.rateFailure = const ApiRefusal(
      ApiError(status: 500, code: 'server_error'),
    );
    await tapAndSettle(tester, byKey('rate-send'));

    expect(byKey('rate-unsure'), findsOneWidget);
    expect(
      tester.getRect(byKey('rate-unsure')).bottom,
      lessThanOrEqualTo(tester.getRect(byKey('rate-send')).top),
    );
    expect(sendActive(tester), isTrue);
  });

  testWidgets('the over-limit button says to shorten and is off', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 3));
    await tester.enterText(byKey('rate-comment'), 'я' * 501);
    await tester.pump();

    expect(
      find.descendant(
        of: byKey('rate-send'),
        matching: find.text('Сократите комментарий'),
      ),
      findsOneWidget,
    );
    expect(sendActive(tester), isFalse);
  });

  testWidgets('without stars the button is off and says send', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne));

    expect(
      find.descendant(
        of: byKey('rate-send'),
        matching: find.text('Отправить оценку'),
      ),
      findsOneWidget,
    );
    expect(sendActive(tester), isFalse);
  });

  testWidgets('× keeps the draft for the card', (WidgetTester tester) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 2));
    await tapAndSettle(tester, byKey('rate-reason-not_fresh'));
    await tester.enterText(byKey('rate-comment'), 'мятые');
    await tester.pump();
    await tapAndSettle(tester, byKey('rate-close'));

    expect(exited, isTrue);
    expect(exit, isNull);
    expect(kept(tester)!.stars, 2);
    expect(kept(tester)!.reasons, <RatingReason>{RatingReason.notFresh});
    expect(kept(tester)!.comment, 'мятые');

    GoRouter.of(anywhere(tester))
        .push(AppPaths.customerOrderRate(orderOne, stars: 3));
    await tester.pumpAndSettle();
    expect(filled(tester, 'rate-star-3'), isTrue);
    expect(filled(tester, 'rate-star-4'), isFalse);
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
  });

  testWidgets('back keeps the draft', (WidgetTester tester) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 2));
    await tapAndSettle(tester, byKey('rate-reason-not_fresh'));
    await tester.enterText(byKey('rate-comment'), 'мятые');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(exited, isTrue);
    expect(kept(tester)!.reasons, <RatingReason>{RatingReason.notFresh});
    expect(kept(tester)!.comment, 'мятые');

    GoRouter.of(anywhere(tester))
        .push(AppPaths.customerOrderRate(orderOne, stars: 3));
    await tester.pumpAndSettle();
    expect(filled(tester, 'rate-star-3'), isTrue);
    expect(
      find.descendant(
        of: byKey('rate-reason-not_fresh'),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
  });

  testWidgets('leaving with nothing written keeps no draft', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 5));
    await tapAndSettle(tester, byKey('rate-close'));

    expect(exited, isTrue);
    expect(kept(tester), isNull);
  });

  testWidgets('leaving the locked face keeps the draft', (
    WidgetTester tester,
  ) async {
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 2));
    await tapAndSettle(tester, byKey('rate-reason-not_fresh'));
    await tester.enterText(byKey('rate-comment'), 'мятые');
    await tester.pump();
    orders.rateFailure = const NetworkFailure();
    await tapAndSettle(tester, byKey('rate-send'));
    await tapAndSettle(tester, byKey('rate-close'));

    expect(exited, isTrue);
    expect(kept(tester)!.reasons, <RatingReason>{RatingReason.notFresh});
    expect(kept(tester)!.comment, 'мятые');
  });

  group('at large text with the keyboard up', () {
    Future<void> lock(WidgetTester tester, ApiFailure failure) async {
      await open(
        tester,
        rate: AppPaths.customerOrderRate(orderOne, stars: 2),
        size: const Size(360, 640),
        textScaler: const NonlinearTextScaler(2),
      );
      orders.rateFailure = failure;
      await tapAndSettle(tester, byKey('rate-send'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
    }

    testWidgets('the locked footer stays whole', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await lock(tester, const NetworkFailure());

      expect(tester.takeException(), isNull);
      expect(byKey('rate-unsure'), findsOneWidget);
      // The note is taller than the room above the keyboard, so it scrolls in
      // a window of its own; the button never leaves the screen.
      final Rect note = tester.getRect(byKey('rate-unsure'));
      final Rect button = tester.getRect(byKey('rate-send'));
      expect(note.top, greaterThanOrEqualTo(56));
      expect(note.top, lessThan(button.top));
      expect(button.bottom, lessThanOrEqualTo(640 - 300));
      expect(button.height, greaterThanOrEqualTo(54));
      expect(
        find.descendant(
          of: find.byType(Scaffold).last,
          matching: find.ancestor(
            of: byKey('rate-unsure'),
            matching: find.byType(SingleChildScrollView),
          ),
        ),
        findsOneWidget,
      );
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('the strip stays whole', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await lock(tester, const NetworkFailure(mayHaveArrived: false));

      expect(tester.takeException(), isNull);
      expect(byKey('rate-strip'), findsOneWidget);
      final Rect button = tester.getRect(byKey('rate-send'));
      expect(button.bottom, lessThanOrEqualTo(640 - 300));
      expect(
        tester.getSize(byKey('rate-retry')).height,
        greaterThanOrEqualTo(44),
      );
      await tester.ensureVisible(byKey('rate-retry'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(byKey('rate-retry')).bottom,
        lessThanOrEqualTo(button.top),
      );
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });
  });

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
    orders.rows = <Map<String, Object?>>[customerOrderJson(status: 'shopping')];
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 3));

    expect(exited, isTrue);
    expect(location(tester), AppPaths.customerOrder(orderOne));
    expect(byKey('rate-send'), findsNothing);
  });

  testWidgets('the screen leaves at once for an order already rated', (
    WidgetTester tester,
  ) async {
    orders.rows = <Map<String, Object?>>[ratedRow(4)];
    await open(tester, rate: AppPaths.customerOrderRate(orderOne, stars: 3));

    expect(exited, isTrue);
    expect(exit, isNull);
    expect(location(tester), AppPaths.customerOrder(orderOne));
    expect(byKey('rate-send'), findsNothing);
  });
}
