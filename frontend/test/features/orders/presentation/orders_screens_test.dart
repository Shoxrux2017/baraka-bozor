import 'dart:async';

import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/localization/order_labels.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/widgets/customer_tab_bar.dart';
import 'package:baraka_bozor/features/orders/data/customer_orders_api.dart';
import 'package:baraka_bozor/features/orders/presentation/order_edited_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_cart_repository.dart';
import '../../../support/fake_customer_orders_repository.dart';
import '../../../support/in_memory_stores.dart';

/// The Customer's orders of `docs/09` sections 20 to 22 through the real
/// router and screens, with the repositories faked.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCustomerOrdersRepository orders;
  late FakeCartRepository cart;

  const String otherOrder = '0192f0a0-0000-7000-8000-00000000c002';

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  BuildContext anywhere(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).last);

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(anywhere(tester));

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.customer] = 'c';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.customer] = user(id: 'c');
    orders = FakeCustomerOrdersRepository();
    cart = FakeCartRepository();
  });

  Future<void> open(
    WidgetTester tester, {
    String? at,
    bool alone = false,
    Size size = const Size(800, 2400),
    double textScale = 1,
    Locale device = const Locale('uz'),
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
        cart: cart,
        device: device,
      ),
    );
    await tester.pumpAndSettle();
    if (at != null) {
      final GoRouter router = GoRouter.of(anywhere(tester));
      alone ? router.go(at) : router.push(at);
      await tester.pumpAndSettle();
    }
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Goes back from the order's page to the list under it, by the app bar's
  /// back button.
  Future<void> backToList(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  }

  /// Opens the order reached from the list of current orders, which holds
  /// [orderOne] and a second order.
  Future<void> openFromList(WidgetTester tester) async {
    orders = FakeCustomerOrdersRepository(
      orders: <Map<String, Object?>>[
        customerOrderJson(),
        customerOrderJson(id: otherOrder),
      ],
    );
    await open(tester, at: AppPaths.customerOrders);
    await tapAndSettle(tester, byKey('order-$orderOne'));
  }

  test(
    'every status has its own words for the Customer, in both languages',
    () {
      final Map<OrderStatus, String Function(AppLocalizations)> expected =
          <OrderStatus, String Function(AppLocalizations)>{
            OrderStatus.newOrder: (AppLocalizations l) => l.customerStatusNew,
            OrderStatus.shoppingAssigned: (AppLocalizations l) =>
                l.customerStatusShoppingAssigned,
            OrderStatus.shopping: (AppLocalizations l) =>
                l.customerStatusShopping,
            OrderStatus.finalPaymentPending: (AppLocalizations l) =>
                l.customerStatusFinalPaymentPending,
            OrderStatus.readyForDelivery: (AppLocalizations l) =>
                l.customerStatusReadyForDelivery,
            OrderStatus.deliveryAssigned: (AppLocalizations l) =>
                l.customerStatusDeliveryAssigned,
            OrderStatus.onTheWay: (AppLocalizations l) =>
                l.customerStatusOnTheWay,
            OrderStatus.completed: (AppLocalizations l) =>
                l.customerStatusCompleted,
            OrderStatus.cancelled: (AppLocalizations l) =>
                l.customerStatusCancelled,
          };
      expect(expected.keys, unorderedEquals(OrderStatus.values));
      final AppLocalizations uz = lookupAppLocalizations(const Locale('uz'));
      final AppLocalizations ru = lookupAppLocalizations(const Locale('ru'));
      for (final AppLocalizations words in <AppLocalizations>[uz, ru]) {
        for (final MapEntry<OrderStatus, String Function(AppLocalizations)>
            entry
            in expected.entries) {
          expect(
            OrderLabels.customerStatus(words, entry.key),
            entry.value(words),
            reason: '${entry.key} in ${words.localeName}',
          );
        }
        expect(
          <String>{
            for (final OrderStatus status in OrderStatus.values)
              OrderLabels.customerStatus(words, status),
          },
          hasLength(OrderStatus.values.length),
          reason: 'no two states read alike in ${words.localeName}',
        );
        // Where the board speaks as the staff, the Customer reads their own
        // words (`DL-51` (2)).
        for (final OrderStatus status in const <OrderStatus>[
          OrderStatus.newOrder,
          OrderStatus.finalPaymentPending,
          OrderStatus.completed,
        ]) {
          expect(
            OrderLabels.customerStatus(words, status),
            isNot(OrderLabels.status(words, status)),
            reason: '$status in ${words.localeName}',
          );
        }
      }
      for (final OrderStatus status in OrderStatus.values) {
        expect(
          OrderLabels.customerStatus(uz, status),
          isNot(OrderLabels.customerStatus(ru, status)),
          reason: '$status must be translated, not copied',
        );
      }
    },
  );

  testWidgets('the orders open from the catalog, and an order from the list', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tapAndSettle(tester, byKey('open-orders'));

    // The status heads the card; «Принят» is also the first stage's word.
    expect(
      tester.widget<Text>(byKey('order-status-$orderOne')).data,
      l10n(tester).customerStatusNew,
    );
    expect(
      find.textContaining(l10n(tester).customerOrderTitle(1001)),
      findsOneWidget,
    );
    await tapAndSettle(tester, byKey('order-$orderOne'));

    expect(byKey('order-status'), findsOneWidget);
    expect(find.text(l10n(tester).orderStateAccepted), findsOneWidget);
    expect(find.text(l10n(tester).checkoutWishLabel), findsOneWidget);
    expect(find.text('Kechqurun'), findsOneWidget);
    expect(byKey('order-edit'), findsOneWidget);
    expect(byKey('order-cancel'), findsOneWidget);
  });

  testWidgets('the orders carry the tab bar with the orders tab current', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tapAndSettle(tester, byKey('open-orders'));

    expect(find.byType(CustomerTabBar), findsOneWidget);
    expect(
      tester.widget<CustomerTabBar>(find.byType(CustomerTabBar)).current,
      CustomerTab.orders,
    );
  });

  testWidgets('the header says «Заказы» with the cart and its count', (
    WidgetTester tester,
  ) async {
    cart = FakeCartRepository(
      cart: cartOf(<Map<String, Object?>>[
        cartLineJson(),
        cartLineJson(id: breadLine, productId: breadProduct, unit: 'piece'),
      ]),
    );
    await open(
      tester,
      at: AppPaths.customerOrders,
      alone: true,
      device: const Locale('ru'),
    );

    final Finder bar = find.byType(AppBar);
    expect(
      find.descendant(of: bar, matching: find.text('Заказы')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bar, matching: byKey('open-cart')),
      findsOneWidget,
    );
    expect(tester.widget<Text>(byKey('cart-count')).data, '2');
    expect(
      find.descendant(of: bar, matching: find.text('Мои заказы')),
      findsNothing,
    );
  });

  testWidgets('the cart bumps after «Повторить»', (WidgetTester tester) async {
    orders = FakeCustomerOrdersRepository(
      orders: <Map<String, Object?>>[customerOrderJson(status: 'completed')],
    );
    orders.reorderAnswer = <String, Object?>{
      'added_items': <Object?>[
        <String, Object?>{
          'product_id': productBread,
          'name_uz': 'Non',
          'name_ru': 'Хлеб',
          'quantity': '1',
        },
      ],
      'skipped_existing_items': <Object?>[],
      'unavailable_items': <Object?>[],
      'cart_full_items': <Object?>[],
    };
    cart = FakeCartRepository(
      cart: cartOf(<Map<String, Object?>>[cartLineJson()]),
    );
    await open(
      tester,
      at: AppPaths.customerOrders,
      alone: true,
      device: const Locale('ru'),
    );
    await tapAndSettle(tester, byKey('orders-tab-past'));
    expect(
      tester.widget<ScaleTransition>(byKey('cart-badge-bump')).scale.value,
      1,
    );

    cart.answer = cartOf(<Map<String, Object?>>[
      cartLineJson(),
      cartLineJson(id: breadLine, productId: breadProduct, unit: 'piece'),
    ]);
    await tester.tap(byKey('order-repeat-$orderOne'));
    double highest = 1;
    for (int step = 0; step < 40; step++) {
      await tester.pump(const Duration(milliseconds: 20));
      final Finder badge = byKey('cart-badge-bump');
      if (badge.evaluate().isNotEmpty) {
        highest = highest < tester.widget<ScaleTransition>(badge).scale.value
            ? tester.widget<ScaleTransition>(badge).scale.value
            : highest;
      }
    }

    expect(highest, greaterThan(1.1), reason: 'the badge was bumped');
  });

  testWidgets('every target meets iOSTapTargetGuideline', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await open(tester, at: AppPaths.customerOrders, alone: true);

    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('an empty cart leads to the catalog, and the orders are a tab', (
    WidgetTester tester,
  ) async {
    await open(tester, at: '/customer/cart');
    expect(byKey('cart-open-orders'), findsNothing);
    await tapAndSettle(tester, byKey('cart-to-catalog'));
    expect(
      GoRouter.of(anywhere(tester))
          .routerDelegate
          .currentConfiguration
          .last
          .matchedLocation,
      AppPaths.customer,
    );
    await tapAndSettle(tester, byKey('open-orders'));
    expect(byKey('orders-list'), findsOneWidget);
  });

  testWidgets(
    'the Customer does not see the lines they removed; other removals say why',
    (WidgetTester tester) async {
      orders.rows = <Map<String, Object?>>[
        customerOrderJson(
          lines: <Object?>[
            orderLineJson(),
            orderLineJson(
              id: lineBread,
              productId: productBread,
              unit: 'piece',
              quantity: '2',
              status: 'removed',
              removedReason: 'customer_removed',
            ),
            orderLineJson(
              id: lineMilk,
              productId: productMilk,
              unit: 'piece',
              quantity: '1',
              status: 'removed',
              removedReason: 'unavailable',
            ),
          ],
        ),
      ];
      await open(tester, at: AppPaths.customerOrder(orderOne));
      final AppLocalizations words = l10n(tester);

      expect(byKey('order-line-$lineTomato'), findsOneWidget);
      expect(byKey('order-line-$lineBread'), findsNothing);
      expect(find.text(words.lineTagUnavailable), findsOneWidget);
    },
  );

  testWidgets('an order past editing offers neither edit nor cancel', (
    WidgetTester tester,
  ) async {
    orders.rows = <Map<String, Object?>>[
      customerOrderJson(status: 'shopping', changeable: false),
    ];
    await open(tester, at: AppPaths.customerOrder(orderOne));

    expect(find.text(l10n(tester).orderStateShopping), findsOneWidget);
    expect(byKey('order-edit'), findsNothing);
    expect(byKey('order-cancel'), findsNothing);
  });

  group('cancelling', () {
    testWidgets('asks first, sends the reason, and shows the order cancelled', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.customerOrder(orderOne));

      await tapAndSettle(tester, byKey('order-cancel'));
      await tapAndSettle(tester, byKey('cancel-keep'));
      expect(orders.cancels, isEmpty);

      orders.answer = customerOrderJson(status: 'cancelled', changeable: false);
      await tapAndSettle(tester, byKey('order-cancel'));
      await tapAndSettle(tester, byKey('cancel-more'));
      await tester.enterText(byKey('cancel-reason'), '  Kerak emas ');
      await tapAndSettle(tester, byKey('cancel-confirm'));

      expect(orders.cancels.single.$2, 'Kerak emas');
      expect(find.text(l10n(tester).orderStateCancelled), findsOneWidget);
      expect(find.text(l10n(tester).orderNothingDue), findsOneWidget);
      expect(byKey('order-cancel'), findsNothing);
    });

    testWidgets(
      'a retry after a lost answer reuses the key; a refusal is said and the order reloaded',
      (WidgetTester tester) async {
        await open(tester, at: AppPaths.customerOrder(orderOne));

        orders.failure = const NetworkFailure();
        await tapAndSettle(tester, byKey('order-cancel'));
        await tapAndSettle(tester, byKey('cancel-more'));
        await tester.enterText(byKey('cancel-reason'), 'Kerak emas');
        await tapAndSettle(tester, byKey('cancel-confirm'));
        // The sheet itself is the retry: it stays, and says what is unknown.
        expect(find.text(l10n(tester).cancelSheetUnsureTitle), findsOneWidget);
        expect(find.text('«Kerak emas»'), findsOneWidget);

        orders.failure = const ApiRefusal(
          ApiError(status: 409, code: 'order_cancellation_not_allowed'),
        );
        orders.rows = <Map<String, Object?>>[
          customerOrderJson(status: 'shopping', changeable: false),
        ];
        await tapAndSettle(tester, byKey('cancel-confirm'));

        expect(orders.cancels, hasLength(2));
        expect(orders.cancels[1].$3, orders.cancels[0].$3, reason: 'same key');
        expect(orders.cancels[1].$2, 'Kerak emas', reason: 'same reason');
        expect(
          find.text(l10n(tester).errorOrderCancellationNotAllowed),
          findsOneWidget,
        );
        await tapAndSettle(tester, byKey('cancel-keep'));
        expect(find.text(l10n(tester).orderStateShopping), findsOneWidget);
      },
    );

    testWidgets(
      'a cancelled order leaves the current orders under it at once',
      (WidgetTester tester) async {
        await openFromList(tester);

        orders.answer = customerOrderJson(
          status: 'cancelled',
          changeable: false,
        );
        final Completer<void> listHold = orders.holdList = Completer<void>();
        await tapAndSettle(tester, byKey('order-cancel'));
        await tapAndSettle(tester, byKey('cancel-more'));
        await tester.enterText(byKey('cancel-reason'), 'Kerak emas');
        await tapAndSettle(tester, byKey('cancel-confirm'));
        await backToList(tester);

        expect(byKey('order-$orderOne'), findsNothing);
        expect(byKey('order-$otherOrder'), findsOneWidget);

        listHold.complete();
        await tester.pumpAndSettle();

        expect(byKey('order-$orderOne'), findsNothing);
        expect(byKey('order-$otherOrder'), findsOneWidget);
      },
    );

    testWidgets('a cancel without a sure answer keeps the order on the list', (
      WidgetTester tester,
    ) async {
      await openFromList(tester);

      orders.failure = const NetworkFailure();
      orders.holdList = Completer<void>();
      await tapAndSettle(tester, byKey('order-cancel'));
      await tapAndSettle(tester, byKey('cancel-more'));
      await tester.enterText(byKey('cancel-reason'), 'Kerak emas');
      await tapAndSettle(tester, byKey('cancel-confirm'));
      // The sheet stays on its retry face; the Customer leaves it by hand.
      await tapAndSettle(tester, byKey('cancel-sheet-close'));
      await backToList(tester);

      expect(byKey('order-$orderOne'), findsOneWidget);
      expect(byKey('order-$otherOrder'), findsOneWidget);
    });
  });

  group('a cancellation request', () {
    testWidgets(
      'once shopping began, a cancel files a request the order then shows',
      (WidgetTester tester) async {
        await open(tester, at: AppPaths.customerOrder(orderOne));

        orders.answer = customerOrderJson(
          status: 'shopping',
          changeable: false,
          cancellationRequest: 'pending',
        );
        await tapAndSettle(tester, byKey('order-cancel'));
        await tapAndSettle(tester, byKey('cancel-more'));
        await tester.enterText(byKey('cancel-reason'), 'Kerak emas');
        await tapAndSettle(tester, byKey('cancel-confirm'));

        expect(orders.cancels.single.$2, 'Kerak emas');
        expect(byKey('order-cancellation-requested'), findsOneWidget);
        expect(find.text(l10n(tester).requestStatusPending), findsOneWidget);
        expect(find.text(l10n(tester).orderStateShopping), findsOneWidget);
        expect(byKey('failure-message'), findsNothing);
      },
    );

    testWidgets(
      'without a reason, the sheet turns into the request that asks for one',
      (WidgetTester tester) async {
        await open(tester, at: AppPaths.customerOrder(orderOne));

        orders.failure = const ApiRefusal(
          ApiError(
            status: 422,
            code: 'validation_failed',
            errors: <String, List<String>>{
              'reason': <String>['A cancellation request needs its reason.'],
            },
          ),
        );
        await tapAndSettle(tester, byKey('order-cancel'));
        await tapAndSettle(tester, byKey('cancel-confirm'));

        expect(byKey('cancel-raced'), findsOneWidget);
        expect(find.text(l10n(tester).cancelSheetRaced), findsOneWidget);
        expect(find.text(l10n(tester).errorValidationFailed), findsNothing);
      },
    );

    testWidgets('a cancellation request keeps the order on the list', (
      WidgetTester tester,
    ) async {
      await openFromList(tester);

      orders.answer = customerOrderJson(
        status: 'shopping',
        changeable: false,
        cancellationRequest: 'pending',
      );
      orders.holdList = Completer<void>();
      await tapAndSettle(tester, byKey('order-cancel'));
      await tapAndSettle(tester, byKey('cancel-more'));
      await tester.enterText(byKey('cancel-reason'), 'Kerak emas');
      await tapAndSettle(tester, byKey('cancel-confirm'));
      await backToList(tester);

      expect(byKey('order-$orderOne'), findsOneWidget);
      expect(byKey('order-$otherOrder'), findsOneWidget);
    });
  });

  group('the edited banner', () {
    /// An edit saved from the order page: the wish changed and the editor
    /// answers. Stops when the editor has gone back to the order.
    Future<void> editAndSave(
      WidgetTester tester, {
      double textScale = 1,
    }) async {
      await open(
        tester,
        at: AppPaths.customerOrder(orderOne),
        size: const Size(360, 2400),
        textScale: textScale,
      );
      await tapAndSettle(tester, byKey('order-edit'));
      await tester.enterText(byKey('edit-delivery-wish'), 'Ertalab');
      await tester.pumpAndSettle();
      orders.answer = customerOrderJson(note: 'Ertalab');
      await tester.tap(byKey('edit-save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 650));
    }

    testWidgets('the order page shows Заказ изменён with the total for 4 s', (
      WidgetTester tester,
    ) async {
      await editAndSave(tester);
      await tester.pump(const Duration(milliseconds: 500));

      expect(byKey('order-status'), findsOneWidget);
      expect(byKey('edit-banner'), findsOneWidget);
      final AppLocalizations words = l10n(tester);
      expect(
        find.descendant(
          of: byKey('edit-banner'),
          matching: find.text(words.orderEditedTitle),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: byKey('edit-banner'),
          matching: find.text(
            words.orderEditedTotal(
              words.cartLineEstimate(MoneyFormat.uzs(55600, AppLanguage.uz)),
            ),
          ),
        ),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 3000));
      expect(byKey('edit-banner'), findsOneWidget, reason: 'still there');
      await tester.pump(const Duration(milliseconds: 1000));
      expect(byKey('edit-banner'), findsNothing, reason: 'gone after 4,3 s');
      await tester.pumpAndSettle();
    });

    testWidgets('the banner does not announce, the editor already did', (
      WidgetTester tester,
    ) async {
      await editAndSave(tester);
      tester.takeAnnouncements();
      await tester.pump(const Duration(milliseconds: 500));

      expect(byKey('edit-banner'), findsOneWidget);
      expect(tester.takeAnnouncements(), isEmpty);
      await tester.pumpAndSettle();
    });

    Widget bannerApp() => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Stack(
          children: <Widget>[
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: OrderEditedBanner(
                order: CustomerOrdersApi.parseOrder(customerOrderJson()),
              ),
            ),
          ],
        ),
      ),
    );

    Finder fade() =>
        find.ancestor(of: byKey('edit-banner'), matching: find.byType(Opacity));

    testWidgets('it comes down from above in 420 ms and goes up in 300 ms', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(bannerApp());
      final double top = tester.getTopLeft(byKey('edit-banner')).dy;
      expect(top, lessThan(0), reason: 'starts above the page');

      await tester.pump(const Duration(milliseconds: 420));
      expect(tester.getTopLeft(byKey('edit-banner')).dy, 8);
      expect(tester.widget<Opacity>(fade()).opacity, 1);

      await tester.pump(const Duration(milliseconds: 3580 + 150));
      expect(tester.getTopLeft(byKey('edit-banner')).dy, lessThan(8));
      expect(tester.widget<Opacity>(fade()).opacity, lessThan(1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(byKey('edit-banner'), findsNothing);
    });

    testWidgets('with reduced motion it only fades', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(bannerApp());
      expect(tester.getTopLeft(byKey('edit-banner')).dy, 8);
      expect(tester.widget<Opacity>(fade()).opacity, lessThan(0.1));

      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.widget<Opacity>(fade()).opacity, 1);
      await tester.pump(const Duration(milliseconds: 3750 + 125));
      expect(tester.getTopLeft(byKey('edit-banner')).dy, 8);
      expect(tester.widget<Opacity>(fade()).opacity, lessThan(1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(byKey('edit-banner'), findsNothing);
    });

    for (final (String, double) scale in <(String, double)>[
      ('100 %', 1.0),
      ('200 %', 2.0),
    ]) {
      testWidgets(
        'the order page with its banner meets the guideline at ${scale.$1}',
        (WidgetTester tester) async {
          final SemanticsHandle handle = tester.ensureSemantics();
          await editAndSave(tester, textScale: scale.$2);
          await tester.pump(const Duration(milliseconds: 500));
          expect(byKey('edit-banner'), findsOneWidget);

          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          expect(tester.takeException(), isNull);
          await tester.pumpAndSettle();
          handle.dispose();
        },
      );
    }
  });
}
