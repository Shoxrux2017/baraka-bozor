import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/orders/application/customer_orders_controllers.dart';
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

const String pillText = 'Сборщик спрашивает';
const String arrived = 'Новый вопрос от сборщика: замена для «Помидоры»';

/// News arriving while the order is open: a new Shopper question and a line
/// bought meanwhile (`DL-130`), through the real router and screens.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCustomerOrdersRepository orders;
  late List<MethodCall> platformCalls;
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
      .where((MethodCall c) => c.method == 'HapticFeedback.vibrate')
      .length;

  /// The tomato line asking [type] until 12:55 Tashkent time.
  Map<String, Object?> asking(String type) {
    final Map<String, Object?> line = questionLineJson(type);
    return <String, Object?>{
      ...line,
      'pending_approval': <String, Object?>{
        ...line['pending_approval']! as Map<String, Object?>,
        'expires_at': '2026-09-28T07:55:00Z',
      },
    };
  }

  String breadId(int i) =>
      '0192f0a0-0000-7000-8000-00000000d0${i.toString().padLeft(2, '0')}';

  /// Bread lines with ids of their own, for an order that scrolls.
  List<Object?> breads(int count, {String status = 'pending'}) => <Object?>[
    for (int i = 0; i < count; i++)
      orderLineJson(
        id: breadId(i),
        productId: productBread,
        unit: 'piece',
        quantity: '2',
        status: status,
      ),
  ];

  Map<String, Object?> order(List<Object?> lines) =>
      customerOrderJson(status: 'shopping', changeable: false, lines: lines);

  Future<void> show(
    WidgetTester tester,
    List<Object?> lines, {
    Size size = const Size(800, 700),
    TextScaler? scaler,
  }) async {
    orders.rows = <Map<String, Object?>>[order(lines)];
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        orders: orders,
        cart: FakeCartRepository(),
        device: const Locale('ru'),
        textScaler: scaler,
        clock: () => now,
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(anywhere(tester)).push(AppPaths.customerOrder(orderOne));
    await tester.pumpAndSettle();
    tester.takeAnnouncements();
  }

  /// The order loads again with [lines], as the periodic refresh does.
  Future<void> reload(WidgetTester tester, List<Object?> lines) async {
    orders.rows = <Map<String, Object?>>[order(lines)];
    ProviderScope.containerOf(anywhere(tester))
        .invalidate(customerOrderProvider(orderOne));
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  List<String> announced(WidgetTester tester) => tester
      .takeAnnouncements()
      .map((CapturedAccessibilityAnnouncement a) => a.message)
      .toList();

  double flashAlpha(WidgetTester tester, String id) {
    final DecoratedBox box = tester.widget<DecoratedBox>(
      find.descendant(
        of: byKey('order-line-$id'),
        matching: byKey('line-flash'),
      ),
    );
    return (box.decoration as BoxDecoration).color!.a;
  }

  Offset lineAt(WidgetTester tester, String id) =>
      tester.getTopLeft(byKey('order-line-$id'));

  double pixels(WidgetTester tester) => tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .pixels;

  Finder pill() => find.text(pillText);

  /// Fourteen lines, the last a tomato one.
  List<Object?> baseLines() => <Object?>[
    ...breads(13),
    orderLineJson(id: breadId(13)),
  ];

  /// The order read well down its lines, the tomato line asking nothing yet.
  Future<void> readDown(
    WidgetTester tester, {
    Size size = const Size(800, 700),
    TextScaler? scaler,
  }) async {
    await show(tester, baseLines(), size: size, scaler: scaler);
    await tester.drag(byKey('order'), const Offset(0, -900));
    await tester.pumpAndSettle();
  }

  /// The same lines, the last one asking: the card comes in above what is
  /// read, and the row that changes is below it.
  List<Object?> asked() => <Object?>[
    ...baseLines().take(13),
    <String, Object?>{...asking('substitution'), 'id': breadId(13)},
  ];

  testWidgets(
    'a new question unfolds where it is seen, the line flashes and it is said',
    (WidgetTester tester) async {
      await show(tester, <Object?>[orderLineJson(), ...breads(1)]);

      await reload(tester, <Object?>[asking('substitution'), ...breads(1)]);
      await tester.pump(const Duration(milliseconds: 100));

      expect(byKey('question-$approvalOne'), findsOneWidget);
      expect(flashAlpha(tester, lineTomato), greaterThan(0));
      expect(announced(tester), <String>[arrived]);
      expect(haptics(), 0);
      expect(pill(), findsNothing);

      await tester.pumpAndSettle();
      expect(
        tester.getSize(byKey('question-$approvalOne')).height,
        greaterThan(100),
      );
      expect(haptics(), 0);
    },
  );

  testWidgets(
    'a question above what is read keeps it in place and shows the pill',
    (WidgetTester tester) async {
      await readDown(tester);
      final Offset before = lineAt(tester, breadId(11));
      expect(before.dy, inInclusiveRange(0, 700));

      await reload(tester, asked());
      await tester.pump(const Duration(milliseconds: 50));
      expect(lineAt(tester, breadId(11)), before);
      await tester.pumpAndSettle();

      expect(lineAt(tester, breadId(11)), before);
      expect(pill(), findsOneWidget);
      expect(find.bySemanticsLabel('Показать вопрос сборщика'), findsOneWidget);
      expect(announced(tester), <String>[arrived]);
      expect(haptics(), 0);
    },
  );

  testWidgets('during a fling the reading stays in place', (
    WidgetTester tester,
  ) async {
    /// A fling up the page, a question arriving [news] into it; where the
    /// line read stands once everything has stopped.
    Future<double> flingTo({required bool news}) async {
      await readDown(tester);
      await tester.fling(byKey('order'), const Offset(0, 300), 1500);
      await tester.pump(const Duration(milliseconds: 100));
      if (news) {
        await reload(tester, asked());
      }
      await tester.pumpAndSettle();
      return lineAt(tester, breadId(11)).dy;
    }

    final double control = await flingTo(news: false);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    final double moved = await flingTo(news: true);

    expect(moved, closeTo(control, 1));
  });

  testWidgets('the pill scrolls to the top and goes', (
    WidgetTester tester,
  ) async {
    await readDown(tester);
    await reload(tester, asked());
    await tester.pumpAndSettle();
    expect(pill(), findsOneWidget);

    await tester.tap(pill());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(pixels(tester), greaterThan(0));
    await tester.pumpAndSettle();

    expect(pixels(tester), 0);
    expect(pill(), findsNothing);
    expect(byKey('question-$approvalOne'), findsOneWidget);
  });

  testWidgets('the pill goes when the card is scrolled into view', (
    WidgetTester tester,
  ) async {
    await readDown(tester);
    await reload(tester, asked());
    await tester.pumpAndSettle();
    expect(pill(), findsOneWidget);

    await tester.drag(byKey('order'), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(pill(), findsOneWidget);

    await tester.drag(byKey('order'), const Offset(0, 1500));
    await tester.pumpAndSettle();
    expect(pill(), findsNothing);
  });

  testWidgets('the pill goes when its question leaves the order', (
    WidgetTester tester,
  ) async {
    await readDown(tester);
    await reload(tester, asked());
    await tester.pumpAndSettle();
    expect(pill(), findsOneWidget);

    await reload(tester, baseLines());
    await tester.pumpAndSettle();

    expect(pill(), findsNothing);
  });

  group('a line bought meanwhile', () {
    testWidgets('flashes and is said', (WidgetTester tester) async {
      await show(tester, <Object?>[orderLineJson(), ...breads(1)]);

      await reload(tester, <Object?>[
        orderLineJson(status: 'purchased'),
        ...breads(1),
      ]);
      await tester.pump(const Duration(milliseconds: 100));

      expect(flashAlpha(tester, lineTomato), greaterThan(0));
      expect(flashAlpha(tester, breadId(0)), 0);
      expect(announced(tester), <String>[
        'Сборщик купил: Помидоры, ${MoneyFormat.uzs(28463, AppLanguage.ru)}',
      ]);
      expect(haptics(), 0);
    });

    testWidgets('two lines are said as a count', (WidgetTester tester) async {
      await show(tester, <Object?>[orderLineJson(), ...breads(1)]);

      await reload(tester, <Object?>[
        orderLineJson(status: 'purchased'),
        ...breads(1, status: 'purchased'),
      ]);
      await tester.pump(const Duration(milliseconds: 100));

      expect(flashAlpha(tester, lineTomato), greaterThan(0));
      expect(flashAlpha(tester, breadId(0)), greaterThan(0));
      expect(announced(tester), <String>['Сборщик купил товаров: 2']);
    });
  });

  testWidgets('the first load is not news', (WidgetTester tester) async {
    await show(tester, <Object?>[
      asking('substitution'),
      ...breads(1, status: 'purchased'),
    ]);
    await tester.pump(const Duration(milliseconds: 100));

    expect(announced(tester), isEmpty);
    expect(pill(), findsNothing);
    expect(flashAlpha(tester, lineTomato), 0);
    expect(flashAlpha(tester, breadId(0)), 0);
    expect(haptics(), 0);
  });

  testWidgets(
    'with reduced motion the card shows at once and the reading still stays',
    (WidgetTester tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await readDown(tester);
      final Offset before = lineAt(tester, breadId(11));

      await reload(tester, asked());
      await tester.pump();

      expect(lineAt(tester, breadId(11)), before);
      expect(pill(), findsOneWidget);
      // Above the view, so not on the stage.
      expect(
        find.byKey(
          const ValueKey<String>('question-$approvalOne'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(flashAlpha(tester, breadId(13)), 0);
      expect(announced(tester), <String>[arrived]);
    },
  );

  group('every tap target is 44 px with the pill showing', () {
    for (final (String name, TextScaler? scaler) in <(String, TextScaler?)>[
      ('100 %', null),
      ('200 %', NonlinearTextScaler(2)),
    ]) {
      testWidgets(name, (WidgetTester tester) async {
        await readDown(tester, size: const Size(360, 700), scaler: scaler);
        await tester.drag(byKey('order'), const Offset(0, -900));
        await tester.pumpAndSettle();
        await reload(tester, asked());
        await tester.pumpAndSettle();

        expect(pill(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      });
    }
  });
}
