import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_cart_repository.dart';
import '../../../support/fake_customer_orders_repository.dart';
import '../../../support/in_memory_stores.dart';

const String approvalTwo = '0192f0a0-0000-7000-8000-00000000c032';
const String approvalThree = '0192f0a0-0000-7000-8000-00000000c033';

/// The Shopper's question cards in the kit look (drawings 29a and 29b)
/// through the real router and screens, with the repositories faked.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCustomerOrdersRepository orders;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  BuildContext anywhere(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).last);

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.customer] = 'c';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.customer] = user(id: 'c');
    orders = FakeCustomerOrdersRepository();
  });

  /// The tomato line asking [type], answering until 12:55 Tashkent time.
  Map<String, Object?> asking(
    String type, {
    String quantity = '1.500',
    String? note = 'Остальные мятые, эти свежие',
    String id = lineTomato,
    String approval = approvalOne,
  }) {
    final Map<String, Object?> line = questionLineJson(type);
    final Map<String, Object?> pending = <String, Object?>{
      ...line['pending_approval']! as Map<String, Object?>,
      'id': approval,
      'request_note': note,
      'expires_at': '2026-09-28T07:55:00Z',
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
        clock: () => DateTime.utc(2026, 9, 28, 9),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(anywhere(tester)).push(AppPaths.customerOrder(orderOne));
    await tester.pumpAndSettle();
  }

  testWidgets('a price question reads the price today and the price ordered', (
    WidgetTester tester,
  ) async {
    await show(tester, <Object?>[asking('price_over_tolerance')]);

    expect(find.text('Вопрос от сборщика'), findsOneWidget);
    expect(find.text('Ответьте до 12:55'), findsOneWidget);
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
