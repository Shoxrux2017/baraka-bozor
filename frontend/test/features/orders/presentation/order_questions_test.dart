import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/deadline_chip.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/features/orders/application/customer_orders_controllers.dart';
import 'package:baraka_bozor/features/orders/data/customer_orders_api.dart';
import 'package:baraka_bozor/features/orders/domain/customer_orders.dart';
import 'package:baraka_bozor/features/orders/presentation/order_sections.dart';
import 'package:flutter/material.dart';
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

const String approvalTwo = '0192f0a0-0000-7000-8000-00000000c032';
const String approvalThree = '0192f0a0-0000-7000-8000-00000000c033';

/// The Shopper's question cards in the kit look (drawings 29a and 29b)
/// through the real router and screens, with the repositories faked.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCustomerOrdersRepository orders;

  /// The phone's clock: nine minutes before the question's 12:55 (Tashkent).
  late DateTime now;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  BuildContext anywhere(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).last);

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.customer] = 'c';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.customer] = user(id: 'c');
    orders = FakeCustomerOrdersRepository();
    now = DateTime.utc(2026, 9, 28, 7, 46);
  });

  /// The tomato line asking [type], answering until 12:55 Tashkent time.
  Map<String, Object?> asking(
    String type, {
    String quantity = '1.500',
    String? note = 'Остальные мятые, эти свежие',
    String id = lineTomato,
    String approval = approvalOne,
    Map<String, Object?>? question,
  }) {
    final Map<String, Object?> line = questionLineJson(type);
    final Map<String, Object?> pending = <String, Object?>{
      ...line['pending_approval']! as Map<String, Object?>,
      'id': approval,
      'request_note': note,
      'expires_at': '2026-09-28T07:55:00Z',
      ...?question,
    };
    return <String, Object?>{
      ...line,
      'id': id,
      'quantity': quantity,
      'pending_approval': pending,
    };
  }

  Future<void> show(
    WidgetTester tester,
    List<Object?> lines, {
    Size size = const Size(800, 2400),
    double textScale = 1,
    Locale device = const Locale('ru'),
    TextScaler? scaler,
  }) async {
    orders.rows = <Map<String, Object?>>[
      customerOrderJson(status: 'shopping', changeable: false, lines: lines),
    ];
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
        textScaler: scaler,
        clock: () => now,
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(anywhere(tester)).push(AppPaths.customerOrder(orderOne));
    await tester.pumpAndSettle();
  }

  /// The rich text whose plain text starts with [start].
  Finder richStarting(String start) => find.byWidgetPredicate(
    (Widget w) => w is RichText && w.text.toPlainText().startsWith(start),
  );

  /// The text spans of [finder]'s rich text, flattened.
  List<TextSpan> spansOf(WidgetTester tester, Finder finder) {
    final List<TextSpan> out = <TextSpan>[];
    tester.widget<RichText>(finder).text.visitChildren((InlineSpan span) {
      if (span is TextSpan) {
        out.add(span);
      }
      return true;
    });
    return out;
  }

  const String nbsp = '\u00A0';

  bool bold(TextStyle? style) => style?.fontWeight == FontWeight.w700;

  testWidgets('a price question reads the price today and the price ordered', (
    WidgetTester tester,
  ) async {
    await show(tester, <Object?>[asking('price_over_tolerance')]);

    expect(find.text('Вопрос от сборщика'), findsOneWidget);
    String perKg(int uzs) => '${MoneyFormat.uzs(uzs, AppLanguage.ru)} / кг';
    expect(
      find.text(
        'Цена сегодня ${perKg(21850)}, при заказе была ${perKg(18400)}. '
        'Согласны на эту цену?',
      ),
      findsOneWidget,
    );
    expect(find.text('Сборщик: «Остальные мятые, эти свежие»'), findsOneWidget);
    expect(byKey('approve-$approvalOne'), findsOneWidget);
    expect(byKey('reject-$approvalOne'), findsOneWidget);
  });

  testWidgets('a substitution shows both products', (
    WidgetTester tester,
  ) async {
    await show(tester, <Object?>[asking('substitution', quantity: '2.000')]);

    expect(find.text('Замена'), findsOneWidget);
    expect(find.text('Помидоры черри'), findsOneWidget);
    expect(find.text('вместо «Помидоры», 2 кг'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
  });

  testWidgets('a smaller quantity reads both quantities', (
    WidgetTester tester,
  ) async {
    await show(tester, <Object?>[asking('reduced_quantity')]);

    expect(find.text('Меньше, чем заказали'), findsOneWidget);
    expect(
      find.text('Есть только 1 кг, вы заказали 1,5 кг. Согласны на меньшее?'),
      findsOneWidget,
    );
  });

  testWidgets('a price question says what each answer does to the bill', (
    WidgetTester tester,
  ) async {
    await show(tester, <Object?>[
      asking('price_over_tolerance', quantity: '2.000'),
    ]);

    final String estimate = '≈$nbsp${MoneyFormat.uzs(25300, AppLanguage.ru)}';
    final String change = MoneyFormat.signed(5300);
    final Finder yes = richStarting('Согласитесь: 2 кг — ');
    expect(yes, findsOneWidget);
    expect(
      tester.widget<RichText>(yes).text.toPlainText(),
      endsWith(' ($change)'),
    );
    // The amount is bold, and its words hold their spaces non-breaking.
    expect(
      spansOf(
        tester,
        yes,
      ).where((TextSpan span) => span.text == estimate && bold(span.style)),
      hasLength(1),
    );
    expect(estimate, contains(nbsp));

    final String loss = MoneyFormat.signedUzs(-20000, AppLanguage.ru);
    final Finder no = richStarting('Откажетесь: «Помидоры» уберут из заказа, ');
    expect(no, findsOneWidget);
    expect(
      tester.widget<RichText>(no).text.toPlainText(),
      'Откажетесь: «Помидоры» уберут из заказа, $loss',
    );
    expect(
      spansOf(
        tester,
        no,
      ).where((TextSpan span) => span.text == loss && bold(span.style)),
      hasLength(1),
    );
    // The question's own yes line; the stages above carry their 13 px checks.
    expect(
      find.byWidgetPredicate(
        (Widget w) => w is Icon && w.icon == Icons.check && w.size == 17,
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.close), findsOneWidget);
    // Nothing is said under the buttons any more.
    expect(
      find.text('Если откажетесь, этот товар уберут из заказа.'),
      findsNothing,
    );
    expect(
      tester.getBottomLeft(byKey('approve-$approvalOne')).dy,
      lessThan(tester.getBottomLeft(byKey('question-$approvalOne')).dy - 15),
    );
  });

  testWidgets(
    'a substitution says the replacement in its yes line and shows its photo',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await show(tester, <Object?>[asking('substitution', quantity: '2.000')]);

      expect(
        richStarting('Согласитесь: Помидоры черри, 2 кг — '),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Замена: Помидоры черри'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (Widget w) =>
              w is Image &&
              w.image is NetworkImage &&
              (w.image as NetworkImage).url ==
                  'https://cdn.example/cherry.webp',
        ),
        findsOneWidget,
      );
      // No caption under either picture.
      expect(find.text('Замена: Помидоры черри'), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets('a reduced quantity says the proposed quantity in its yes line', (
    WidgetTester tester,
  ) async {
    await show(tester, <Object?>[asking('reduced_quantity')]);

    expect(richStarting('Согласитесь: 1 кг — '), findsOneWidget);
  });

  testWidgets('a change of zero leaves the bracket out', (
    WidgetTester tester,
  ) async {
    await show(tester, <Object?>[
      asking(
        'price_over_tolerance',
        question: <String, Object?>{
          'estimate_if_approved_uzs': 27600,
          'change_if_approved_uzs': 0,
        },
      ),
    ]);

    final Finder yes = richStarting('Согласитесь: ');
    expect(
      tester.widget<RichText>(yes).text.toPlainText(),
      isNot(contains('(')),
    );
  });

  Color? washOf(WidgetTester tester) =>
      (tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(DeadlineChip),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration)
          .color;

  testWidgets('minutes left count down and turn red at three', (
    WidgetTester tester,
  ) async {
    await show(tester, <Object?>[asking('price_over_tolerance')]);

    final Finder nine = find.text('Осталось 9 мин · до 12:55');
    expect(nine, findsOneWidget);
    expect(washOf(tester), KitColors.warningWash);
    expect(tester.widget<Text>(nine).style!.color, KitColors.warningDark);

    now = DateTime.utc(2026, 9, 28, 7, 52);
    await tester.pump(const Duration(minutes: 6));
    final Finder three = find.text('Осталось 3 мин · до 12:55');
    expect(three, findsOneWidget);
    expect(washOf(tester), KitColors.dangerWash);
    expect(tester.widget<Text>(three).style!.color, KitColors.danger);
  });

  testWidgets('the header reads as one node: the title and the minutes left', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await show(tester, <Object?>[asking('price_over_tolerance')]);

    expect(
      find.bySemanticsLabel('Вопрос от сборщика, осталось 9 минут'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets(
    'at its deadline the card turns expired at once and the order loads again',
    (WidgetTester tester) async {
      await show(tester, <Object?>[asking('price_over_tolerance')]);

      // The order polls every 15 s; count the load the deadline adds.
      await tester.pump(const Duration(minutes: 8, seconds: 59));
      expect(byKey('question-$approvalOne'), findsOneWidget);
      final int loaded = orders.loads.length;
      tester.takeAnnouncements();

      now = DateTime.utc(2026, 9, 28, 7, 55);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(byKey('question-expired-$lineTomato'), findsOneWidget);
      expect(byKey('approve-$approvalOne'), findsNothing);
      expect(byKey('reject-$approvalOne'), findsNothing);
      await tester.pumpAndSettle();
      expect(orders.loads.length, loaded + 1);
      expect(
        tester.takeAnnouncements().map(
          (CapturedAccessibilityAnnouncement a) => a.message,
        ),
        <String>['Время ответа истекло: Помидоры уберут из заказа'],
      );
    },
  );

  testWidgets(
    'a question past its deadline on the phone stays expired after a reload',
    (WidgetTester tester) async {
      now = DateTime.utc(2026, 9, 28, 7, 56);
      await show(tester, <Object?>[asking('price_over_tolerance')]);

      // The server still sends the question; the phone's clock says it is
      // over.
      expect(byKey('question-expired-$lineTomato'), findsOneWidget);
      expect(byKey('approve-$approvalOne'), findsNothing);

      ProviderScope.containerOf(anywhere(tester))
          .invalidate(customerOrderProvider(orderOne));
      await tester.pumpAndSettle();
      expect(byKey('question-expired-$lineTomato'), findsOneWidget);
      expect(byKey('approve-$approvalOne'), findsNothing);
    },
  );

  group('the question card meets the tap-target guideline', () {
    for (final String type in const <String>[
      'price_over_tolerance',
      'substitution',
      'reduced_quantity',
    ]) {
      for (final (String, TextScaler) scale in const <(String, TextScaler)>[
        ('100 %', TextScaler.noScaling),
        ('200 %', NonlinearTextScaler(2)),
      ]) {
        testWidgets('$type at ${scale.$1}', (WidgetTester tester) async {
          final SemanticsHandle semantics = tester.ensureSemantics();
          await show(
            tester,
            <Object?>[asking(type)],
            size: const Size(360, 2400),
            scaler: scale.$2,
          );

          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          semantics.dispose();
        });
      }
    }
  });

  testWidgets('an expired question says the product goes', (
    WidgetTester tester,
  ) async {
    await show(tester, <Object?>[orderLineJson(status: 'awaiting_customer')]);

    expect(byKey('question-expired-$lineTomato'), findsOneWidget);
    expect(find.text('Время ответа истекло'), findsOneWidget);
    expect(find.text('Этот товар уберут из заказа'), findsOneWidget);
    expect(find.text('Помидоры'), findsWidgets);
  });

  group('an answered question folds into its line (DL-130)', () {
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
    });

    int haptics() => platformCalls
        .where(
          (MethodCall c) =>
              c.method == 'HapticFeedback.vibrate' &&
              c.arguments == 'HapticFeedbackType.lightImpact',
        )
        .length;

    List<String> announced(WidgetTester tester) => tester
        .takeAnnouncements()
        .map((CapturedAccessibilityAnnouncement a) => a.message)
        .toList();

    Map<String, Object?> after(List<Object?> lines) =>
        customerOrderJson(status: 'shopping', changeable: false, lines: lines);

    Finder agreedLine(String id) => byKey('order-line-agreed-$id');

    Finder flash(String id) => find.descendant(
      of: byKey('order-line-$id'),
      matching: byKey('line-flash'),
    );

    double flashAlpha(WidgetTester tester, String id) =>
        ((tester.widget<DecoratedBox>(flash(id)).decoration) as BoxDecoration)
            .color!
            .a;

    String perKg(int uzs) => '${MoneyFormat.uzs(uzs, AppLanguage.ru)} за кг';

    testWidgets(
      'a yes folds the card into «Вы согласились: 16 500 сум за кг» on the line',
      (WidgetTester tester) async {
        await show(tester, <Object?>[
          asking(
            'price_over_tolerance',
            question: <String, Object?>{
              'proposed_customer_unit_price_uzs': 16500,
            },
          ),
        ]);
        orders.afterDecision = after(<Object?>[
          orderLineJson(
            patch: <String, Object?>{
              'agreed': <String, Object?>{
                'customer_unit_price_uzs': 16500,
                'quantity': null,
              },
            },
          ),
        ]);

        await tester.tap(byKey('approve-$approvalOne'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // The card goes on folding, and takes no tap.
        expect(byKey('question-$approvalOne'), findsOneWidget);
        expect(
          tester
              .widget<IgnorePointer>(
                find
                    .ancestor(
                      of: byKey('question-$approvalOne'),
                      matching: find.byType(IgnorePointer),
                    )
                    .first,
              )
              .ignoring,
          isTrue,
        );
        expect(agreedLine(lineTomato), findsOneWidget);
        expect(flashAlpha(tester, lineTomato), greaterThan(0));
        expect(haptics(), 1);
        expect(announced(tester), <String>[
          'Вы согласились: Помидоры, ${perKg(16500)}',
        ]);

        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(byKey('question-$approvalOne'), findsNothing);
        expect(
          find.descendant(
            of: agreedLine(lineTomato),
            matching: find.text('Вы согласились: ${perKg(16500)}'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: agreedLine(lineTomato),
            matching: find.byIcon(Icons.check_circle),
          ),
          findsOneWidget,
        );
        await tester.pump(const Duration(milliseconds: 1400));
        expect(flashAlpha(tester, lineTomato), 0);
        expect(haptics(), 1);
      },
    );

    testWidgets('a yes to a substitution says «Вы согласились на замену»', (
      WidgetTester tester,
    ) async {
      await show(tester, <Object?>[asking('substitution')]);
      orders.afterDecision = after(<Object?>[
        orderLineJson(
          patch: <String, Object?>{
            'replacement': <String, Object?>{
              'name_uz': 'Olcha pomidor',
              'name_ru': 'Помидоры черри',
            },
            'agreed': <String, Object?>{
              'customer_unit_price_uzs': 21850,
              'quantity': null,
            },
          },
        ),
      ]);

      await tester.tap(byKey('approve-$approvalOne'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: agreedLine(lineTomato),
          matching: find.text('Вы согласились на замену'),
        ),
        findsOneWidget,
      );
      expect(announced(tester), <String>[
        'Вы согласились на замену: Помидоры черри',
      ]);
    });

    testWidgets(
      'a no folds the card and the line moves under «Убрали из заказа»',
      (WidgetTester tester) async {
        await show(tester, <Object?>[asking('price_over_tolerance')]);
        orders.afterDecision = after(<Object?>[
          orderLineJson(status: 'removed', removedReason: 'customer_rejected'),
        ]);

        await tester.tap(byKey('reject-$approvalOne'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        // The reload has moved the line, and the card still folds: it does
        // not vanish with the line's move.
        expect(byKey('order-removed-group'), findsOneWidget);
        expect(byKey('question-$approvalOne'), findsOneWidget);
        expect(
          tester.getSize(byKey('question-$approvalOne')).height,
          greaterThan(0),
        );
        expect(haptics(), 1);
        expect(announced(tester), <String>[
          'Вы отказались: Помидоры уберут из заказа',
        ]);

        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(byKey('question-$approvalOne'), findsNothing);
        expect(find.text('Убрали из заказа · 1'), findsOneWidget);
        expect(flashAlpha(tester, lineTomato), greaterThan(0));
        expect(agreedLine(lineTomato), findsNothing);
      },
    );

    testWidgets('a sure yes whose reload fails still shows what was agreed', (
      WidgetTester tester,
    ) async {
      await show(tester, <Object?>[
        asking(
          'price_over_tolerance',
          question: <String, Object?>{
            'proposed_customer_unit_price_uzs': 16500,
          },
        ),
      ]);
      orders.loadFailure = const NetworkFailure();

      await tester.tap(byKey('approve-$approvalOne'));
      await tester.pumpAndSettle();

      expect(byKey('stale-line'), findsOneWidget);
      expect(byKey('question-$approvalOne'), findsNothing);
      expect(byKey('approve-$approvalOne'), findsNothing);
      expect(byKey('decide-again-$approvalOne'), findsNothing);
      expect(
        find.descendant(
          of: agreedLine(lineTomato),
          matching: find.text('Вы согласились: ${perKg(16500)}'),
        ),
        findsOneWidget,
      );
      expect(orders.decisions, hasLength(1));
    });

    testWidgets(
      'with reduced motion the answered card goes at once and nothing flashes',
      (WidgetTester tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await show(tester, <Object?>[asking('price_over_tolerance')]);
        orders.afterDecision = after(<Object?>[
          orderLineJson(
            patch: <String, Object?>{
              'agreed': <String, Object?>{
                'customer_unit_price_uzs': 21850,
                'quantity': null,
              },
            },
          ),
        ]);

        await tester.tap(byKey('approve-$approvalOne'));
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(byKey('question-$approvalOne'), findsNothing);
        expect(agreedLine(lineTomato), findsOneWidget);
        expect(flashAlpha(tester, lineTomato), 0);
        // The haptic and the announcement stay.
        expect(haptics(), 1);
        expect(announced(tester), hasLength(1));
      },
    );
  });

  testWidgets('the amounts fade in when they change, not on the first build', (
    WidgetTester tester,
  ) async {
    CustomerOrder withTotals(int goods, int total) =>
        CustomerOrdersApi.parseOrder(
          customerOrderJson(
            totals: <String, Object?>{
              'merchandise_subtotal_uzs': goods,
              'service_fee_uzs': 5000,
              'delivery_fee_uzs': 15000,
              'total_uzs': total,
              'total_kind': 'estimate',
            },
          ),
        );
    Future<void> pump(CustomerOrder order) => tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: OrderAmounts(order: order)),
      ),
    );
    double opacityOf(String key) => tester
        .widget<Opacity>(
          find.ancestor(of: byKey(key), matching: find.byType(Opacity)).first,
        )
        .opacity;

    await pump(withTotals(35600, 55600));
    expect(opacityOf('order-goods'), 1);
    expect(opacityOf('order-total'), 1);

    await pump(withTotals(41000, 61000));
    expect(opacityOf('order-goods'), closeTo(0.2, 0.001));
    await tester.pump(const Duration(milliseconds: 150));
    final double half = 0.2 + 0.8 * Curves.easeOut.transform(0.5);
    expect(opacityOf('order-goods'), closeTo(half, 0.01));
    expect(opacityOf('order-total'), closeTo(half, 0.01));
    await tester.pump(const Duration(milliseconds: 150));
    expect(opacityOf('order-goods'), 1);
  });

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'the question cards hold at the extremes (${device.languageCode})',
      (WidgetTester tester) async {
        const String long =
            'Juda uzun nomli mahsulot Очень длинное название продукта для проверки';
        Map<String, Object?> longNamed(Map<String, Object?> line) =>
            <String, Object?>{...line, 'name_uz': long, 'name_ru': long};
        await show(
          tester,
          <Object?>[
            longNamed(asking('price_over_tolerance', note: long * 3)),
            longNamed(
              asking(
                'substitution',
                id: '0192f0a0-0000-7000-8000-00000000c015',
                approval: approvalTwo,
              ),
            ),
            longNamed(
              asking(
                'reduced_quantity',
                id: '0192f0a0-0000-7000-8000-00000000c016',
                approval: approvalThree,
              ),
            ),
          ],
          size: const Size(320, 640),
          textScale: 2,
          device: device,
        );

        // At 200 % the stages stand as a list, so the first card is below the
        // fold of a 640 px phone.
        await tester.scrollUntilVisible(
          byKey('question-$approvalOne'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(byKey('question-$approvalOne'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          byKey('question-$approvalThree'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
