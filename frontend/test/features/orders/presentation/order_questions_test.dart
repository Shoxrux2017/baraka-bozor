import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/deadline_chip.dart';
import 'package:baraka_bozor/features/orders/application/customer_orders_controllers.dart';
import 'package:flutter/material.dart';
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
    expect(find.byIcon(Icons.check), findsOneWidget);
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
