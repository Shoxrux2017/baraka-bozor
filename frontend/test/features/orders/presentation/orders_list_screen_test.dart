import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:baraka_bozor/core/formatting/order_dates.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/orders/application/customer_orders_controllers.dart';
import 'package:baraka_bozor/features/orders/domain/customer_orders.dart';
import 'package:baraka_bozor/features/orders/presentation/orders_segment.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_cart_repository.dart';
import '../../../support/fake_customer_orders_repository.dart';
import '../../../support/in_memory_stores.dart';
import '../../../support/nonlinear_text_scaler.dart';

/// The Customer's orders list (`DL-131`) through the real router and screens,
/// with the repositories faked: the two kept tabs, the months, the endless
/// loading, the stale line and the empty states.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCustomerOrdersRepository orders;

  /// What is on show; a list under another tab is not.
  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  /// Also what the other tab keeps.
  Finder kept(String key) =>
      find.byKey(ValueKey<String>(key), skipOffstage: false);

  BuildContext anywhere(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).last);

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.customer] = 'c';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.customer] = user(id: 'c');
    orders = FakeCustomerOrdersRepository();
  });

  /// Lets loads and animations run without waiting for skeletons, which
  /// pulse for ever.
  Future<void> frames(WidgetTester tester, [int count = 8]) async {
    for (int i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    TextScaler? scaler,
    Completer<void>? hold,
    bool reducedMotion = false,
  }) async {
    if (reducedMotion) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }
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
        clock: () => DateTime.utc(2026, 10, 28, 8),
      ),
    );
    await tester.pumpAndSettle();
    orders.holdList = hold;
    GoRouter.of(anywhere(tester)).push(AppPaths.customerOrders);
    await frames(tester);
  }

  String id(int index) =>
      '0192f0a0-0000-7000-8000-${(0xd000 + index).toRadixString(16).padLeft(12, '0')}';

  /// [count] past orders, newest first: 20 in October, 15 in September, the
  /// rest in August.
  List<Map<String, Object?>> past(int count) => <Map<String, Object?>>[
    for (int i = 0; i < count; i++)
      orderSummaryJson(
        id: id(i),
        number: 2000 - i,
        status: 'completed',
        createdAt:
            (i < 20
                    ? DateTime.utc(
                        2026,
                        10,
                        27,
                        12,
                      ).subtract(Duration(hours: i * 5))
                    : i < 35
                    ? DateTime.utc(
                        2026,
                        9,
                        28,
                        12,
                      ).subtract(Duration(hours: (i - 20) * 5))
                    : DateTime.utc(
                        2026,
                        8,
                        30,
                        12,
                      ).subtract(Duration(hours: (i - 35) * 5)))
                .toIso8601String(),
      ),
  ];

  /// The scroll position of the list on show; a list under another tab is
  /// not on show.
  ScrollPosition shown(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).last).position;

  /// Scrolls the list on show to its end; a list lays out lazily, so its end
  /// moves while it is reached.
  Future<void> toEnd(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      shown(tester).jumpTo(shown(tester).maxScrollExtent);
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  String segmentText(WidgetTester tester, String key) => tester
      .widgetList<Text>(
        find.descendant(of: byKey(key), matching: find.byType(Text)),
      )
      .map((Text text) => text.data ?? '')
      .join();

  SemanticsData semanticsOf(WidgetTester tester, String key) =>
      tester.getSemantics(byKey(key)).getSemanticsData();

  int loadsOf(String load) =>
      orders.loads.where((String entry) => entry == load).length;

  List<String> announced(WidgetTester tester) => tester
      .takeAnnouncements()
      .map((CapturedAccessibilityAnnouncement a) => a.message)
      .toList();

  double slideOf(WidgetTester tester, String tab) => tester
      .widget<Transform>(kept('orders-pane-slide-$tab'))
      .transform
      .getTranslation()
      .x;

  double fadeOf(WidgetTester tester, String tab) =>
      tester.widget<Opacity>(kept('orders-pane-fade-$tab')).opacity;

  testWidgets(
    'switching tabs keeps each list and its place and loads nothing again',
    (WidgetTester tester) async {
      orders.summaries = <Map<String, Object?>>[
        orderSummaryJson(status: 'shopping'),
        ...past(45),
      ];
      await open(tester);
      await tester.tap(byKey('orders-tab-past'));
      await frames(tester);
      shown(tester).jumpTo(600);
      await frames(tester);

      await tester.tap(byKey('orders-tab-current'));
      await frames(tester);
      expect(byKey('order-$orderOne'), findsOneWidget);
      await tester.tap(byKey('orders-tab-past'));
      await frames(tester);

      expect(shown(tester).pixels, 600);
      expect(loadsOf('orders:past:1'), 1);
      expect(loadsOf('orders:current:1'), 1);
    },
  );

  testWidgets('each tab shows its own orders, both asked for at the start', (
    WidgetTester tester,
  ) async {
    const String ended = '0192f0a0-0000-7000-8000-00000000c002';
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(status: 'shopping'),
      orderSummaryJson(id: ended, status: 'completed'),
    ];
    await open(tester);
    expect(
      orders.loads,
      containsAll(<String>['orders:current:1', 'orders:past:1']),
    );
    expect(byKey('order-$orderOne'), findsOneWidget);
    expect(byKey('order-$ended'), findsNothing);
    final int asked = orders.loads.length;

    await tester.tap(byKey('orders-tab-past'));
    await frames(tester);
    expect(byKey('order-$ended'), findsOneWidget);
    expect(byKey('order-$orderOne'), findsNothing);

    await tester.tap(byKey('orders-tab-current'));
    await frames(tester);
    expect(byKey('order-$orderOne'), findsOneWidget);
    expect(orders.loads, hasLength(asked));
  });

  testWidgets('the thumb slides and the list comes in from its side', (
    WidgetTester tester,
  ) async {
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(status: 'shopping'),
      ...past(3),
    ];
    await open(tester);
    final double left = tester.getTopLeft(byKey('orders-thumb')).dx;

    await tester.tap(byKey('orders-tab-past'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final double middle = tester.getTopLeft(byKey('orders-thumb')).dx;
    final double slide = slideOf(tester, 'past');
    final double fade = fadeOf(tester, 'past');
    await frames(tester);
    final double right = tester.getTopLeft(byKey('orders-thumb')).dx;

    expect(middle, greaterThan(left));
    expect(middle, lessThan(right));
    expect(slide, inExclusiveRange(0, 28), reason: 'from its own side');
    expect(fade, inExclusiveRange(0, 1));
    expect(slideOf(tester, 'past'), 0);
    expect(fadeOf(tester, 'past'), 1);

    await tester.tap(byKey('orders-tab-current'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(slideOf(tester, 'current'), inExclusiveRange(-28, 0));
  });

  testWidgets(
    'with reduced motion the thumb is there at once and the list fades',
    (WidgetTester tester) async {
      orders.summaries = <Map<String, Object?>>[
        orderSummaryJson(status: 'shopping'),
        ...past(3),
      ];
      await open(tester, reducedMotion: true);
      final double left = tester.getTopLeft(byKey('orders-thumb')).dx;

      await tester.tap(byKey('orders-tab-past'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      final double settled = tester.getTopLeft(byKey('orders-thumb')).dx;
      expect(settled, greaterThan(left));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getTopLeft(byKey('orders-thumb')).dx, settled);
      expect(slideOf(tester, 'past'), 0);
      expect(fadeOf(tester, 'past'), inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(fadeOf(tester, 'past'), 1);
    },
  );

  testWidgets('the first visit shows skeletons, not a spinner', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final Completer<void> hold = Completer<void>();
    await open(tester, hold: hold);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(byKey('orders-skeleton-current'), findsOneWidget);
    expect(
      find.descendant(
        of: byKey('orders-skeleton-current'),
        matching: byKey('orders-skeleton-card'),
      ),
      findsNWidgets(3),
    );
    expect(
      semanticsOf(tester, 'orders-skeleton-current').label,
      'Загружаем заказы',
    );

    hold.complete();
    await frames(tester);
    expect(byKey('orders-skeleton-current'), findsNothing);
    expect(byKey('order-$orderOne'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the segments count their orders and say so', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    orders.summaries = <Map<String, Object?>>[
      orderSummaryJson(status: 'shopping'),
      orderSummaryJson(
        id: '0192f0a0-0000-7000-8000-00000000c002',
        status: 'shopping',
      ),
      ...past(25),
    ];
    await open(tester);

    expect(segmentText(tester, 'orders-tab-current'), 'Текущие · 2');
    expect(segmentText(tester, 'orders-tab-past'), 'Прошлые · 25');
    final SemanticsData current = semanticsOf(tester, 'orders-tab-current');
    expect(current.label, 'Текущие, 2 заказа');
    expect(current.flagsCollection.isSelected, Tristate.isTrue);
    expect(current.role, SemanticsRole.tab);
    final SemanticsData pastTab = semanticsOf(tester, 'orders-tab-past');
    expect(pastTab.label, 'Прошлые, 25 заказов');
    expect(pastTab.flagsCollection.isSelected, Tristate.isFalse);
    handle.dispose();
  });

  testWidgets(
    'a failed refresh keeps the list under the stale line and the next tick tries again',
    (WidgetTester tester) async {
      orders.summaries = <Map<String, Object?>>[
        orderSummaryJson(status: 'shopping'),
        orderSummaryJson(
          id: '0192f0a0-0000-7000-8000-00000000c002',
          status: 'shopping',
        ),
      ];
      await open(tester);
      expect(loadsOf('orders:current:1'), 1);

      orders.listFailures[OrdersTab.current] = const NetworkFailure();
      await tester.pump(const Duration(seconds: 30));
      await frames(tester);
      expect(loadsOf('orders:current:1'), 2);
      expect(byKey('stale-line'), findsOneWidget);
      expect(
        find.textContaining('Нет связи · данные на 13:00'),
        findsOneWidget,
      );
      expect(byKey('order-$orderOne'), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
      await frames(tester);
      expect(
        loadsOf('orders:current:1'),
        3,
        reason: 'the next tick tries again',
      );
      await frames(tester);
      expect(byKey('stale-line'), findsNothing);
      expect(byKey('order-$orderOne'), findsOneWidget);
    },
  );

  testWidgets('the stale line refreshes once per tap and shows it is busy', (
    WidgetTester tester,
  ) async {
    await open(tester);
    orders.listFailures[OrdersTab.current] = const NetworkFailure();
    await tester.pump(const Duration(seconds: 30));
    await frames(tester);

    final Completer<void> hold = orders.holdList = Completer<void>();
    await tester.tap(byKey('stale-retry'));
    await tester.pump();
    expect(loadsOf('orders:current:1'), 3);
    expect(
      tester.widget<TextButton>(byKey('stale-retry')).onPressed,
      isNull,
      reason: 'busy takes no tap',
    );
    hold.complete();
    await frames(tester);
    expect(byKey('stale-line'), findsNothing);
  });

  testWidgets('refreshes never overlap', (WidgetTester tester) async {
    await open(tester);
    final Completer<void> hold = orders.holdList = Completer<void>();

    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(loadsOf('orders:current:1'), 2);
    await tester.pump(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 30));
    expect(loadsOf('orders:current:1'), 2, reason: 'one request while it runs');

    hold.complete();
    await frames(tester);
    expect(byKey('order-$orderOne'), findsOneWidget);
  });

  testWidgets('pulling refreshes and says so', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await open(tester);
    announced(tester);

    await tester.fling(kept('orders-list'), const Offset(0, 300), 1000);
    await frames(tester, 12);

    expect(loadsOf('orders:current:1'), 2);
    expect(announced(tester), <String>['Обновлено']);
    handle.dispose();
  });

  testWidgets('a pull that fails on the past list is announced with the time', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    orders.summaries = past(3);
    await open(tester);
    await tester.tap(byKey('orders-tab-past'));
    await frames(tester);
    announced(tester);

    orders.listFailures[OrdersTab.past] = const NetworkFailure();
    await tester.fling(kept('orders-past-list'), const Offset(0, 300), 1000);
    await frames(tester, 12);

    expect(announced(tester), <String>['Нет связи. Показаны данные на 13:00']);
    expect(byKey('order-${id(0)}'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a reload of a deep past list keeps the offset', (
    WidgetTester tester,
  ) async {
    orders.summaries = past(45);
    await open(tester);
    await tester.tap(byKey('orders-tab-past'));
    await frames(tester);
    shown(tester).jumpTo(shown(tester).maxScrollExtent);
    await frames(tester);
    expect(loadsOf('orders:past:2'), 1);
    shown(tester).jumpTo(2500);
    await frames(tester);

    ProviderScope.containerOf(anywhere(tester))
        .invalidate(customerOrdersProvider(OrdersTab.past));
    await tester.pump();
    expect(byKey('orders-skeleton-past'), findsNothing);
    await frames(tester);

    expect(shown(tester).pixels, 2500);
    expect(loadsOf('orders:past:1'), 2);
    expect(loadsOf('orders:past:2'), 2);
  });

  testWidgets(
    'past orders stand under month headings and load on as you scroll',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      orders.summaries = past(45);
      await open(tester);
      await tester.tap(byKey('orders-tab-past'));
      await frames(tester);

      expect(find.text('Октябрь'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.text('Октябрь'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      expect(find.text('Сентябрь'), findsNothing);
      expect(loadsOf('orders:past:2'), 0);

      final Completer<void> hold = orders.holdPast = Completer<void>();
      await toEnd(tester);
      expect(byKey('orders-more-skeleton'), findsNWidgets(2));
      expect(loadsOf('orders:past:2'), 1);
      hold.complete();
      await frames(tester);
      await tester.scrollUntilVisible(
        find.text('Сентябрь'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Сентябрь'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Август'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Август'), findsOneWidget);

      await toEnd(tester);
      expect(loadsOf('orders:past:3'), 1);
      expect(byKey('orders-more-skeleton'), findsNothing);
      expect(byKey('orders-more-retry'), findsNothing);
      expect(loadsOf('orders:past:4'), 0);
      handle.dispose();
    },
  );

  testWidgets(
    'a page that fails at the end says Нет связи · Повторить and loads on retry',
    (WidgetTester tester) async {
      orders.summaries = past(45);
      await open(tester);
      await tester.tap(byKey('orders-tab-past'));
      await frames(tester);

      orders.listFailures[OrdersTab.past] = const NetworkFailure();
      await toEnd(tester);
      await frames(tester);

      expect(byKey('orders-more-skeleton'), findsNothing);
      expect(byKey('orders-more-retry'), findsOneWidget);
      expect(find.text('Нет связи'), findsOneWidget);
      expect(tester.getSize(byKey('orders-more-row')).height, 52);
      expect(loadsOf('orders:past:2'), 1, reason: 'it does not try on its own');
      await frames(tester);
      expect(loadsOf('orders:past:2'), 1);

      await tester.tap(byKey('orders-more-retry'));
      await frames(tester);
      expect(loadsOf('orders:past:2'), 2);
      expect(byKey('orders-more-retry'), findsNothing);
    },
  );

  testWidgets('with no current orders the last one is offered', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    orders.summaries = past(25);
    await open(tester);

    expect(find.text('Сейчас заказов в работе нет'), findsOneWidget);
    expect(
      find.text(
        'Последний заказ — вчера. Его можно повторить или собрать новую корзину.',
      ),
      findsOneWidget,
    );
    expect(byKey('order-last-${id(0)}'), findsOneWidget);
    expect(find.text('Все прошлые заказы · 25'), findsOneWidget);
    expect(
      tester.getSemantics(byKey('orders-all-past')).label,
      'Все прошлые заказы, 25',
    );
    expect(byKey('orders-empty-shop'), findsOneWidget);

    await tester.tap(byKey('orders-all-past'));
    await frames(tester);
    expect(
      semanticsOf(tester, 'orders-tab-past').flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(byKey('order-${id(0)}'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the empty Текущие shows skeletons while Прошлые has no answer', (
    WidgetTester tester,
  ) async {
    orders.summaries = past(3);
    final Completer<void> hold = Completer<void>();
    orders.holdPast = hold;
    await open(tester);
    expect(byKey('orders-skeleton-current'), findsOneWidget);
    expect(find.text('Сейчас заказов в работе нет'), findsNothing);

    hold.complete();
    await frames(tester);
    expect(byKey('orders-skeleton-current'), findsNothing);
    expect(find.text('Сейчас заказов в работе нет'), findsOneWidget);
  });

  testWidgets('«За покупками» of the new empty state leads home', (
    WidgetTester tester,
  ) async {
    orders.summaries = past(3);
    await open(tester);

    await tester.tap(byKey('orders-empty-shop'));
    await tester.pumpAndSettle();
    expect(
      GoRouter.of(anywhere(tester))
          .routerDelegate
          .currentConfiguration
          .last
          .matchedLocation,
      AppPaths.customer,
    );
  });

  testWidgets('with no orders ever the screen invites to shop', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    orders.summaries = <Map<String, Object?>>[];
    await open(tester);

    expect(byKey('orders-empty'), findsOneWidget);
    expect(find.text('Заказов пока нет'), findsOneWidget);
    expect(byKey('orders-empty-shop'), findsOneWidget);
    expect(byKey('orders-all-past'), findsNothing);
    expect(segmentText(tester, 'orders-tab-current'), 'Текущие');
    expect(semanticsOf(tester, 'orders-tab-current').label, 'Текущие');

    await tester.tap(byKey('orders-tab-past'));
    await frames(tester);
    expect(
      find.text('Здесь будут доставленные и отменённые заказы'),
      findsOneWidget,
    );
    expect(byKey('orders-empty-shop'), findsNothing);
    handle.dispose();
  });

  testWidgets('a re-tap on Заказы scrolls the shown tab to the top', (
    WidgetTester tester,
  ) async {
    orders.summaries = past(45);
    await open(tester);
    await tester.tap(byKey('orders-tab-past'));
    await frames(tester);
    shown(tester).jumpTo(600);
    await frames(tester);

    await tester.tap(find.byKey(const ValueKey<String>('open-orders')).last);
    await frames(tester);
    expect(shown(tester).pixels, 0);
  });

  testWidgets('a tap on the chosen segment scrolls its list to the top', (
    WidgetTester tester,
  ) async {
    orders.summaries = past(45);
    await open(tester);
    await tester.tap(byKey('orders-tab-past'));
    await frames(tester);
    shown(tester).jumpTo(600);
    await frames(tester);

    await tester.tap(byKey('orders-tab-past'));
    await frames(tester);
    expect(shown(tester).pixels, 0);
  });

  group('the segment', () {
    Future<void> show(
      WidgetTester tester, {
      required int pastBumps,
      bool reducedMotion = false,
    }) => tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reducedMotion),
          child: child!,
        ),
        home: Scaffold(
          body: OrdersSegment(
            tab: OrdersTab.current,
            currentCount: 2,
            pastCount: 25,
            pastBumps: pastBumps,
            onTab: (OrdersTab _) {},
          ),
        ),
      ),
    );

    double scale(WidgetTester tester) =>
        tester.widget<ScaleTransition>(kept('orders-past-bump')).scale.value;

    testWidgets('each rise of the past count bumps it once', (
      WidgetTester tester,
    ) async {
      await show(tester, pastBumps: 0);
      expect(scale(tester), 1);

      await show(tester, pastBumps: 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 136));
      expect(scale(tester), closeTo(1.3, 0.02));
      await tester.pump(const Duration(milliseconds: 300));
      expect(scale(tester), 1);

      await show(tester, pastBumps: 1);
      await tester.pump(const Duration(milliseconds: 136));
      expect(scale(tester), 1, reason: 'no new rise, no bump');
    });

    testWidgets('with reduced motion the count does not move', (
      WidgetTester tester,
    ) async {
      await show(tester, pastBumps: 0, reducedMotion: true);
      await show(tester, pastBumps: 1, reducedMotion: true);
      await tester.pump(const Duration(milliseconds: 136));
      expect(scale(tester), 1);
    });
  });

  test('a month heading names the Tashkent month and adds another year', () {
    final AppLocalizations ru = lookupAppLocalizations(const Locale('ru'));
    final AppLocalizations uz = lookupAppLocalizations(const Locale('uz'));
    final DateTime now = DateTime.utc(2026, 10, 28, 8);

    expect(monthHeading(ru, DateTime.utc(2026, 9, 15), now), 'Сентябрь');
    // 20:00 UTC on 30 September is 01:00 on 1 October in Tashkent.
    expect(monthHeading(ru, DateTime.utc(2026, 9, 30, 20), now), 'Октябрь');
    expect(
      monthHeading(ru, DateTime.utc(2025, 12, 31, 12), now),
      'Декабрь 2025',
    );
    expect(monthHeading(uz, DateTime.utc(2026, 8, 1, 12), now), 'Avgust');
    expect(monthHeading(uz, DateTime.utc(2025, 1, 5, 12), now), 'Yanvar 2025');
  });

  group('the tap targets', () {
    for (final (String, TextScaler) scale in <(String, TextScaler)>[
      ('100 %', TextScaler.noScaling),
      ('200 %', const NonlinearTextScaler(2)),
    ]) {
      Future<void> meets(WidgetTester tester) async {
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        expect(tester.takeException(), isNull);
      }

      testWidgets(
        'a current list with a strip and the call button at ${scale.$1}',
        (WidgetTester tester) async {
          final SemanticsHandle handle = tester.ensureSemantics();
          orders.summaries = <Map<String, Object?>>[
            orderSummaryJson(
              status: 'on_the_way',
              waiting: 1,
              courierPhone: '+998901112233',
              deadlines: <String>['2026-10-28T08:10:00Z'],
            ),
          ];
          await open(tester, size: const Size(360, 800), scaler: scale.$2);
          await meets(tester);
          handle.dispose();
        },
      );

      testWidgets(
        'a past list with rateable, rated and cancelled orders at ${scale.$1}',
        (WidgetTester tester) async {
          final SemanticsHandle handle = tester.ensureSemantics();
          orders.summaries = <Map<String, Object?>>[
            orderSummaryJson(status: 'completed', canRate: true, itemCount: 10),
            orderSummaryJson(id: id(1), status: 'completed', ratingStars: 4),
            orderSummaryJson(id: id(2), status: 'cancelled'),
          ];
          await open(tester, size: const Size(360, 800), scaler: scale.$2);
          await tester.tap(byKey('orders-tab-past'));
          await frames(tester);
          await meets(tester);
          handle.dispose();
        },
      );

      testWidgets('the skeletons at ${scale.$1}', (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final Completer<void> hold = Completer<void>();
        await open(
          tester,
          size: const Size(360, 800),
          scaler: scale.$2,
          hold: hold,
        );
        await meets(tester);
        hold.complete();
        await frames(tester);
        handle.dispose();
      });

      testWidgets('the stale line at ${scale.$1}', (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await open(tester, size: const Size(360, 800), scaler: scale.$2);
        orders.listFailures[OrdersTab.current] = const NetworkFailure();
        await tester.pump(const Duration(seconds: 30));
        await frames(tester);
        expect(byKey('stale-line'), findsOneWidget);
        await meets(tester);
        handle.dispose();
      });

      testWidgets('the end row at ${scale.$1}', (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        orders.summaries = past(45);
        await open(tester, size: const Size(360, 800), scaler: scale.$2);
        await tester.tap(byKey('orders-tab-past'));
        await frames(tester);
        orders.listFailures[OrdersTab.past] = const NetworkFailure();
        await toEnd(tester);
        await frames(tester);
        expect(byKey('orders-more-retry'), findsOneWidget);
        await meets(tester);
        handle.dispose();
      });

      testWidgets('the empty state with the last order at ${scale.$1}', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        orders.summaries = past(25);
        await open(tester, size: const Size(360, 800), scaler: scale.$2);
        expect(byKey('orders-all-past'), findsOneWidget);
        await meets(tester);
        handle.dispose();
      });

      testWidgets('the plain empty state at ${scale.$1}', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        orders.summaries = <Map<String, Object?>>[];
        await open(tester, size: const Size(360, 800), scaler: scale.$2);
        await meets(tester);
        await tester.tap(byKey('orders-tab-past'));
        await frames(tester);
        await meets(tester);
        handle.dispose();
      });
    }

    testWidgets(
      'the segment with counts does not overflow at 200 % on 360 dp',
      (WidgetTester tester) async {
        orders.summaries = <Map<String, Object?>>[
          orderSummaryJson(status: 'shopping'),
          ...past(25),
        ];
        await open(
          tester,
          size: const Size(360, 800),
          scaler: const NonlinearTextScaler(2),
        );

        expect(tester.takeException(), isNull);
        expect(tester.getSize(byKey('orders-segment')).width, 320);
        expect(segmentText(tester, 'orders-tab-past'), 'Прошлые · 25');
      },
    );
  });
}
