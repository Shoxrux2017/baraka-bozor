import 'dart:async';

import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/localization/order_labels.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/customer_tab_bar.dart';
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

  /// Takes a line out of the editor: its options sheet, then the remove
  /// button in it.
  Future<void> removeLine(WidgetTester tester, String key) async {
    await tapAndSettle(tester, byKey('edit-options-$key'));
    await tapAndSettle(tester, byKey('edit-remove-$key'));
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

    expect(find.text(l10n(tester).customerStatusNew), findsOneWidget);
    expect(find.text(l10n(tester).customerOrderTitle(1001)), findsOneWidget);
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
        expect(find.text(l10n(tester).orderCancelRepeating), findsOneWidget);
        await tapAndSettle(tester, byKey('cancel-confirm'));

        expect(orders.cancels, hasLength(2));
        expect(orders.cancels[1].$3, orders.cancels[0].$3, reason: 'same key');
        expect(orders.cancels[1].$2, 'Kerak emas', reason: 'same reason');
        expect(
          find.text(l10n(tester).errorOrderCancellationNotAllowed),
          findsOneWidget,
        );
        expect(find.text(l10n(tester).orderStateShopping), findsOneWidget);
      },
    );
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
        await tester.enterText(byKey('cancel-reason'), 'Kerak emas');
        await tapAndSettle(tester, byKey('cancel-confirm'));

        expect(orders.cancels.single.$2, 'Kerak emas');
        expect(byKey('order-cancellation-requested'), findsOneWidget);
        expect(find.text(l10n(tester).requestStatusPending), findsOneWidget);
        expect(find.text(l10n(tester).orderStateShopping), findsOneWidget);
        expect(byKey('failure-message'), findsNothing);
      },
    );

    testWidgets('without a reason, the Customer is told to give one', (
      WidgetTester tester,
    ) async {
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

      expect(byKey('order-cancel-needs-reason'), findsOneWidget);
      expect(
        find.text(l10n(tester).orderCancellationNeedsReason),
        findsOneWidget,
      );
      expect(find.text(l10n(tester).errorValidationFailed), findsNothing);
      expect(
        tester.widget<Text>(byKey('order-cancel-needs-reason')).style?.color,
        KitColors.danger,
      );
    });
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
        await removeLine(tester, lineBread);
        // 1,5 kg steps by half a kilo: two plus taps make 2,5.
        await tapAndSettle(tester, byKey('line-plus-$lineTomato'));
        await tapAndSettle(tester, byKey('line-plus-$lineTomato'));
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

      await removeLine(tester, lineTomato);
      await removeLine(tester, lineBread);
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
        expect(find.text(l10n(tester).orderStateShopping), findsOneWidget);
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

    testWidgets('an editor opened by its address leaves for the order', (
      WidgetTester tester,
    ) async {
      String top() =>
          GoRouter.of(anywhere(tester))
              .routerDelegate
              .currentConfiguration
              .last
              .matchedLocation;

      await open(tester, at: AppPaths.customerOrderEdit(orderOne), alone: true);
      await tapAndSettle(tester, byKey('edit-save'));
      expect(orders.edits, isEmpty, reason: 'nothing changed');
      expect(top(), AppPaths.customerOrder(orderOne));

      GoRouter.of(anywhere(tester)).go(AppPaths.customerOrderEdit(orderOne));
      await tester.pumpAndSettle();
      await tester.enterText(byKey('edit-delivery-wish'), 'Ertalab');
      orders.answer = customerOrderJson(note: 'Ertalab');
      await tapAndSettle(tester, byKey('edit-save'));
      expect(orders.edits, hasLength(1));
      expect(tester.takeException(), isNull);
      expect(top(), AppPaths.customerOrder(orderOne));
      expect(byKey('order-status'), findsOneWidget);
    });

    testWidgets('an order gone meanwhile is said so, not edited', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));
      orders
        ..failure = const ApiRefusal(
          ApiError(status: 404, code: 'resource_not_found'),
        )
        ..rows = <Map<String, Object?>>[];
      await tester.enterText(byKey('edit-delivery-wish'), 'Ertalab');

      await tapAndSettle(tester, byKey('edit-save'));

      expect(byKey('order-editor'), findsNothing);
      expect(find.text(l10n(tester).errorNotFound), findsOneWidget);
    });

    testWidgets(
      'a reload that failed is said so, and retried, never the old form',
      (WidgetTester tester) async {
        await open(tester, at: AppPaths.customerOrderEdit(orderOne));
        orders
          ..failure = const ApiRefusal(
            ApiError(status: 409, code: 'order_editing_locked'),
          )
          ..loadFailure = const NetworkFailure()
          ..rows = <Map<String, Object?>>[
            customerOrderJson(status: 'shopping', changeable: false),
          ];
        await tester.enterText(byKey('edit-delivery-wish'), 'Ertalab');

        await tapAndSettle(tester, byKey('edit-save'));
        expect(byKey('order-editor'), findsNothing);
        expect(find.text(l10n(tester).errorNetwork), findsOneWidget);

        await tester.tap(byKey('retry-load'));
        await tester.pump();
        expect(byKey('order-editor'), findsNothing, reason: 'not the old form');
        expect(byKey('retry-load'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.pumpAndSettle();
        expect(byKey('edit-closed'), findsOneWidget);
      },
    );

    testWidgets('a quantity changed alone is sent', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));
      await tapAndSettle(tester, byKey('line-qty-$lineTomato'));
      await tester.enterText(byKey('line-quantity'), '1,75');
      await tapAndSettle(tester, byKey('quantity-done'));
      expect(
        find.descendant(
          of: byKey('edit-line-$lineTomato'),
          matching: find.text('1,75 ${l10n(tester).unitKg}'),
        ),
        findsOneWidget,
      );
      orders.answer = customerOrderJson();
      await tapAndSettle(tester, byKey('edit-save'));

      expect(orders.edits.single.$2.first.quantity, '1.75');
      expect(orders.edits.single.$2, hasLength(2));
    });

    testWidgets('the plus and the minus step by the unit', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));
      await tapAndSettle(tester, byKey('line-minus-$lineTomato'));
      await tapAndSettle(tester, byKey('line-plus-$lineBread'));
      orders.answer = customerOrderJson();
      await tapAndSettle(tester, byKey('edit-save'));

      expect(
        orders.edits.single.$2.map((OrderEditLine l) => l.quantity),
        <String>['1', '3'],
      );
    });

    testWidgets('a rule changed alone is sent', (WidgetTester tester) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));

      await tapAndSettle(tester, byKey('edit-options-$lineTomato'));
      await tapAndSettle(
        tester,
        byKey('substitution-contact_before_substitution'),
      );
      await tapAndSettle(tester, byKey('edit-options-done'));
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

      await tapAndSettle(tester, byKey('edit-options-$lineBread'));
      await tester.enterText(byKey('line-note'), '  Yangi  ');
      await tapAndSettle(tester, byKey('edit-options-done'));
      orders.answer = customerOrderJson();
      await tapAndSettle(tester, byKey('edit-save'));
      expect(orders.edits.single.$2[1].customerNote, 'Yangi');
    });

    testWidgets('the options sheet applies only on "Сохранить"', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));

      await tapAndSettle(tester, byKey('edit-options-$lineBread'));
      await tester.enterText(byKey('line-note'), 'Yangi');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(byKey('edit-options-done'), findsNothing, reason: 'closed');
      expect(find.text('Yangi'), findsNothing);

      orders.answer = customerOrderJson();
      await tester.enterText(byKey('edit-delivery-wish'), 'Ertalab');
      await tapAndSettle(tester, byKey('edit-save'));
      expect(orders.edits.single.$2[1].customerNote, isNull);
    });

    testWidgets('the sheet refuses a quantity of 0 and stays open', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));

      await tapAndSettle(tester, byKey('edit-options-$lineTomato'));
      await tester.enterText(byKey('line-quantity'), '0');
      await tapAndSettle(tester, byKey('edit-options-done'));

      expect(find.text(l10n(tester).cartQuantityFraction), findsOneWidget);
      expect(byKey('edit-options-done'), findsOneWidget);
    });

    testWidgets('the sheet answers its quantity, note and rule', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));

      await tapAndSettle(tester, byKey('edit-options-$lineBread'));
      await tester.enterText(byKey('line-quantity'), '5');
      await tester.enterText(byKey('line-note'), 'Yangi');
      await tapAndSettle(tester, byKey('substitution-remove_if_unavailable'));
      await tapAndSettle(tester, byKey('edit-options-done'));
      orders.answer = customerOrderJson();
      await tapAndSettle(tester, byKey('edit-save'));

      final OrderEditLine bread = orders.edits.single.$2[1];
      expect(bread.quantity, '5');
      expect(bread.customerNote, 'Yangi');
      expect(bread.substitutionPolicy, SubstitutionPolicy.removeIfUnavailable);
    });

    testWidgets('the minus at the minimum removes the line', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        customerOrderJson(
          lines: <Object?>[
            orderLineJson(quantity: '1'),
            orderLineJson(
              id: lineBread,
              productId: productBread,
              unit: 'piece',
              quantity: '2',
            ),
          ],
        ),
      ];
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));

      Finder bin(String line) => find.descendant(
        of: byKey('line-minus-$line'),
        matching: find.byIcon(Icons.delete_outline),
      );
      expect(bin(lineTomato), findsNothing, reason: '1 kg steps down to 0,5');
      await tapAndSettle(tester, byKey('line-minus-$lineTomato'));
      expect(bin(lineTomato), findsOneWidget, reason: '0,5 kg is the minimum');
      expect(bin(lineBread), findsNothing);

      await tapAndSettle(tester, byKey('line-minus-$lineTomato'));
      expect(byKey('line-minus-$lineTomato'), findsNothing);
      expect(
        find.descendant(
          of: byKey('edit-remove-$lineTomato'),
          matching: find.text(l10n(tester).orderEditKeepLine),
        ),
        findsOneWidget,
      );
      await tapAndSettle(tester, byKey('edit-remove-$lineTomato'));
      expect(byKey('line-minus-$lineTomato'), findsOneWidget, reason: 'kept');
    });

    testWidgets('a line taken out is not sent', (WidgetTester tester) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));
      await removeLine(tester, lineTomato);

      expect(byKey('edit-options-$lineTomato'), findsOneWidget);
      expect(byKey('line-plus-$lineTomato'), findsNothing);
      orders.answer = customerOrderJson();
      await tapAndSettle(tester, byKey('edit-save'));
      expect(orders.edits.single.$2.single.productId, productBread);
    });

    testWidgets(
      'the editor shows the goods preview and no delivery, fee or total',
      (WidgetTester tester) async {
        String id(int i) => '0192f0a0-0000-7000-8000-00000000c10$i';
        orders.rows = <Map<String, Object?>>[
          customerOrderJson(
            lines: <Object?>[
              // 1,5 kg at 18 400, 2 at 4 000, 3 at 4 000 and 1 at 31 400.
              orderLineJson(),
              orderLineJson(
                id: lineBread,
                productId: productBread,
                unit: 'piece',
                quantity: '2',
              ),
              orderLineJson(
                id: id(1),
                productId: id(2),
                unit: 'piece',
                quantity: '3',
              ),
              orderLineJson(
                id: id(3),
                productId: id(4),
                unit: 'piece',
                quantity: '1',
                patch: <String, Object?>{'customer_unit_price_uzs': 31400},
              ),
            ],
          ),
        ];
        await open(
          tester,
          at: AppPaths.customerOrderEdit(orderOne),
          device: const Locale('ru'),
        );

        final AppLocalizations words = l10n(tester);
        String estimate(int amount) =>
            words.cartLineEstimate(MoneyFormat.uzs(amount, AppLanguage.ru));
        expect(find.text('Товары (4)'), findsOneWidget);
        expect(
          find.descendant(
            of: byKey('edit-line-$lineTomato'),
            matching: find.text(estimate(27600)),
          ),
          findsOneWidget,
        );
        expect(find.text(estimate(79000)), findsOneWidget);
        expect(find.text('Доставка'), findsNothing);
        expect(find.text('Сервисный сбор'), findsNothing);
        expect(find.text('Итого'), findsNothing);
        expect(
          find.text('Доставку, сбор и итог пересчитаем после сохранения'),
          findsOneWidget,
        );

        await tapAndSettle(tester, byKey('line-plus-$lineBread'));
        expect(find.text('Товары (4)'), findsOneWidget);
        expect(find.text(estimate(83000)), findsOneWidget);
        await removeLine(tester, lineBread);
        expect(find.text('Товары (3)'), findsOneWidget);
        expect(find.text(estimate(71000)), findsOneWidget);
      },
    );

    testWidgets('only an estimate price carries "≈" in the editor', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        customerOrderJson(
          lines: <Object?>[
            orderLineJson(),
            orderLineJson(
              id: lineBread,
              productId: productBread,
              unit: 'piece',
              quantity: '2',
            ),
          ],
        ),
      ];
      await open(
        tester,
        at: AppPaths.customerOrderEdit(orderOne),
        device: const Locale('ru'),
      );

      final AppLocalizations words = l10n(tester);
      String sum(int amount) => MoneyFormat.uzs(amount, AppLanguage.ru);
      Finder inLine(String id, String text) => find.descendant(
        of: byKey('edit-line-$id'),
        matching: find.text(text),
      );
      expect(
        inLine(
          lineTomato,
          words.cartLineEstimate(
            words.catalogPricePerUnit(sum(18400), words.unitKg),
          ),
        ),
        findsOneWidget,
      );
      expect(
        inLine(lineTomato, words.cartLineEstimate(sum(27600))),
        findsOneWidget,
      );
      expect(
        inLine(
          lineBread,
          words.catalogPricePerUnit(sum(4000), words.unitPiece),
        ),
        findsOneWidget,
      );
      expect(inLine(lineBread, sum(8000)), findsOneWidget);
    });

    testWidgets('a line without a quantity leaves the goods unsummed', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        customerOrderJson(
          lines: <Object?>[
            orderLineJson(),
            // A piece line holding half a piece: no quantity the unit takes.
            orderLineJson(
              id: lineBread,
              productId: productBread,
              unit: 'piece',
              quantity: '1.500',
            ),
          ],
        ),
      ];
      await open(
        tester,
        at: AppPaths.customerOrderEdit(orderOne),
        device: const Locale('ru'),
      );

      expect(tester.widget<Text>(byKey('edit-goods')).data, '—');
      expect(find.text('Товары (2)'), findsOneWidget);
    });

    testWidgets('a line shows its own price per unit and the rule and note', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        customerOrderJson(
          lines: <Object?>[
            orderLineJson(
              note: 'Pishgan',
              patch: <String, Object?>{
                'substitution_policy': 'remove_if_unavailable',
              },
            ),
          ],
        ),
      ];
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));

      final AppLocalizations words = l10n(tester);
      final Finder tomato = byKey('edit-line-$lineTomato');
      expect(
        find.descendant(
          of: tomato,
          matching: find.text(
            words.cartLineEstimate(
              words.catalogPricePerUnit(
                MoneyFormat.uzs(18400, AppLanguage.uz),
                words.unitKg,
              ),
            ),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tomato, matching: find.text('Pishgan')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tomato,
          matching: find.text(
            OrderLabels.substitution(
              words,
              SubstitutionPolicy.removeIfUnavailable,
            ),
          ),
        ),
        findsOneWidget,
      );
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
          size: const Size(320, 640),
          textScale: 2,
          device: language,
        );
        expect(tester.takeException(), isNull);
        await tapAndSettle(tester, byKey('order-edit'));
        expect(byKey('order-editor'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tapAndSettle(tester, byKey('edit-options-$lineTomato'));
        expect(byKey('edit-options-done'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
