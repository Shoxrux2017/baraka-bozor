import 'dart:async';

import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/localization/order_labels.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/orders/domain/customer_orders.dart';
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

    expect(find.textContaining(l10n(tester).customerStatusNew), findsOneWidget);
    await tapAndSettle(tester, byKey('order-$orderOne'));

    expect(byKey('order-status'), findsOneWidget);
    expect(find.text(l10n(tester).customerStatusNew), findsOneWidget);
    expect(
      find.text('${l10n(tester).orderSectionDeliveryWish}: Kechqurun'),
      findsOneWidget,
    );
    expect(byKey('order-edit'), findsOneWidget);
    expect(byKey('order-cancel'), findsOneWidget);
  });

  testWidgets('an empty cart leads to the orders', (WidgetTester tester) async {
    await open(tester, at: '/customer/cart');
    await tapAndSettle(tester, byKey('cart-open-orders'));
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
      expect(
        find.text(words.orderLineRemoved(words.removedUnavailable)),
        findsOneWidget,
      );
    },
  );

  testWidgets('an order past editing offers neither edit nor cancel', (
    WidgetTester tester,
  ) async {
    orders.rows = <Map<String, Object?>>[
      customerOrderJson(status: 'shopping', changeable: false),
    ];
    await open(tester, at: AppPaths.customerOrder(orderOne));

    expect(find.text(l10n(tester).customerStatusShopping), findsOneWidget);
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
      await tester.enterText(byKey('cancel-reason'), '  Kerak emas ');
      await tapAndSettle(tester, byKey('cancel-confirm'));

      expect(orders.cancels.single.$2, 'Kerak emas');
      expect(find.text(l10n(tester).customerStatusCancelled), findsOneWidget);
      expect(find.text(l10n(tester).totalNothingDue), findsOneWidget);
      expect(byKey('order-cancel'), findsNothing);
    });

    testWidgets(
      'a retry after a lost answer reuses the key; a refusal is said and the order reloaded',
      (WidgetTester tester) async {
        await open(tester, at: AppPaths.customerOrder(orderOne));

        orders.failure = const NetworkFailure();
        await tapAndSettle(tester, byKey('order-cancel'));
        await tester.enterText(byKey('cancel-reason'), 'Kerak emas');
        await tapAndSettle(tester, byKey('cancel-confirm'));
        expect(find.text(l10n(tester).errorNetwork), findsOneWidget);

        orders.failure = const ApiRefusal(
          ApiError(status: 409, code: 'order_cancellation_not_allowed'),
        );
        orders.rows = <Map<String, Object?>>[
          customerOrderJson(status: 'shopping', changeable: false),
        ];
        await tapAndSettle(tester, byKey('order-cancel'));
        // The retry is the same request: its reason is shown and kept.
        final TextField reason = tester.widget<TextField>(
          find.descendant(
            of: byKey('cancel-reason'),
            matching: find.byType(TextField),
          ),
        );
        expect(reason.controller!.text, 'Kerak emas');
        expect(reason.readOnly, isTrue);
        await tapAndSettle(tester, byKey('cancel-confirm'));

        expect(orders.cancels, hasLength(2));
        expect(orders.cancels[1].$3, orders.cancels[0].$3, reason: 'same key');
        expect(orders.cancels[1].$2, 'Kerak emas', reason: 'same reason');
        expect(
          find.text(l10n(tester).errorOrderCancellationNotAllowed),
          findsOneWidget,
        );
        expect(find.text(l10n(tester).customerStatusShopping), findsOneWidget);
      },
    );
  });

  group('editing', () {
    testWidgets(
      'sends every line the order keeps and the wish, and nothing when nothing changed',
      (WidgetTester tester) async {
        await open(tester, at: AppPaths.customerOrder(orderOne));
        await tapAndSettle(tester, byKey('order-edit'));
        expect(byKey('order-editor'), findsOneWidget);

        await tapAndSettle(tester, byKey('edit-save'));
        expect(orders.edits, isEmpty, reason: 'nothing changed');
        expect(byKey('order-editor'), findsNothing);

        await tapAndSettle(tester, byKey('order-edit'));
        await tapAndSettle(tester, byKey('edit-remove-$lineBread'));
        await tester.enterText(
          find
              .descendant(
                of: byKey('edit-line-$lineTomato'),
                matching: byKey('line-quantity'),
              )
              .first,
          '2,5',
        );
        await tester.enterText(byKey('edit-delivery-wish'), '');
        orders.answer = customerOrderJson(
          note: null,
          lines: <Object?>[
            orderLineJson(quantity: '2.500'),
            orderLineJson(
              id: lineBread,
              productId: productBread,
              unit: 'piece',
              quantity: '2',
              status: 'removed',
              removedReason: 'customer_removed',
            ),
          ],
        );
        await tapAndSettle(tester, byKey('edit-save'));

        final (String id, List<OrderEditLine> lines, String? wish) =
            orders.edits.single;
        expect(id, orderOne);
        expect(lines.single.productId, productTomato);
        expect(lines.single.quantity, '2.5');
        expect(wish, isNull);
        expect(byKey('order-editor'), findsNothing);
        expect(byKey('order-line-$lineBread'), findsNothing);
      },
    );

    testWidgets('at least one line stays', (WidgetTester tester) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));

      await tapAndSettle(tester, byKey('edit-remove-$lineTomato'));
      await tapAndSettle(tester, byKey('edit-remove-$lineBread'));
      await tapAndSettle(tester, byKey('edit-save'));

      expect(byKey('edit-none-left'), findsOneWidget);
      expect(orders.edits, isEmpty);
    });

    testWidgets(
      'an order whose shopping started is reloaded, and no longer edited',
      (WidgetTester tester) async {
        await open(tester, at: AppPaths.customerOrder(orderOne));
        await tapAndSettle(tester, byKey('order-edit'));
        orders
          ..failure = const ApiRefusal(
            ApiError(status: 409, code: 'order_editing_locked'),
          )
          ..rows = <Map<String, Object?>>[
            customerOrderJson(status: 'shopping', changeable: false),
          ];
        await tester.enterText(byKey('edit-delivery-wish'), 'Ertalab');

        await tapAndSettle(tester, byKey('edit-save'));

        expect(byKey('edit-closed'), findsOneWidget);
        expect(find.text(l10n(tester).orderEditClosed), findsOneWidget);
        expect(byKey('edit-save'), findsNothing);
        await tapAndSettle(tester, byKey('edit-back-to-order'));
        expect(find.text(l10n(tester).customerStatusShopping), findsOneWidget);
        expect(byKey('order-edit'), findsNothing);
      },
    );

    testWidgets('an order past editing opened by its address is not edited', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        customerOrderJson(status: 'cancelled', changeable: false),
      ];
      await open(tester, at: AppPaths.customerOrderEdit(orderOne), alone: true);

      expect(byKey('edit-closed'), findsOneWidget);
      expect(byKey('order-editor'), findsNothing);
      await tapAndSettle(tester, byKey('edit-back-to-order'));
      expect(
        GoRouter.of(anywhere(tester))
            .routerDelegate
            .currentConfiguration
            .last
            .matchedLocation,
        AppPaths.customerOrder(orderOne),
      );
      expect(byKey('order-status'), findsOneWidget);
    });

    testWidgets('a rule changed alone is sent', (WidgetTester tester) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));
      Finder inLine(String line, String key) => find
          .descendant(of: byKey('edit-line-$line'), matching: byKey(key))
          .first;

      await tapAndSettle(
        tester,
        inLine(lineTomato, 'substitution-contact_before_substitution'),
      );
      orders.answer = customerOrderJson();
      await tapAndSettle(tester, byKey('edit-save'));
      expect(
        orders.edits.single.$2.first.substitutionPolicy,
        SubstitutionPolicy.contactBefore,
      );
      expect(orders.edits.single.$2, hasLength(2));
    });

    testWidgets('a note changed alone is sent, trimmed', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));
      Finder inLine(String line, String key) => find
          .descendant(of: byKey('edit-line-$line'), matching: byKey(key))
          .first;

      await tester.enterText(inLine(lineBread, 'line-note'), '  Yangi  ');
      orders.answer = customerOrderJson();
      await tapAndSettle(tester, byKey('edit-save'));
      expect(orders.edits.single.$2[1].customerNote, 'Yangi');
    });

    testWidgets('a wish longer than 160 characters is refused before sending', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));
      await tester.enterText(byKey('edit-delivery-wish'), 'a' * 161);
      await tapAndSettle(tester, byKey('edit-save'));

      expect(find.text(l10n(tester).fieldTooLong(160)), findsOneWidget);
      expect(orders.edits, isEmpty);

      await tester.enterText(
        byKey('edit-delivery-wish'),
        '  ${'a' * 160}\u0085',
      );
      orders.answer = customerOrderJson(note: 'a' * 160);
      await tapAndSettle(tester, byKey('edit-save'));
      expect(
        orders.edits.single.$3,
        'a' * 160,
        reason: 'trimmed as the server',
      );
    });

    testWidgets('one save at a time', (WidgetTester tester) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));
      await tester.enterText(byKey('edit-delivery-wish'), 'Ertalab');
      final Completer<void> hold = Completer<void>();
      orders
        ..hold = hold
        ..answer = customerOrderJson(note: 'Ertalab');

      await tester.tap(byKey('edit-save'));
      await tester.pump();
      expect(tester.widget<FilledButton>(byKey('edit-save')).onPressed, isNull);
      orders.hold = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(orders.edits, hasLength(1));
    });
  });

  for (final Locale language in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'an order and its editor fit a phone with large text (${language.languageCode})',
      (WidgetTester tester) async {
        await open(
          tester,
          at: AppPaths.customerOrder(orderOne),
          size: const Size(360, 800),
          textScale: 2,
          device: language,
        );
        expect(tester.takeException(), isNull);
        await tapAndSettle(tester, byKey('order-edit'));
        expect(byKey('order-editor'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
