import 'dart:math' as math;

import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/formatting/phone_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/operations/data/operations_api.dart';
import 'package:baraka_bozor/features/operations/domain/board.dart';
import 'package:baraka_bozor/features/operations/presentation/board_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_operations_repository.dart';
import '../../../support/in_memory_stores.dart';
import '../../../support/operations_json.dart';

/// The board of `docs/09` section 38 through the real router, shell and
/// controllers, with the operations repository faked.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeOperationsRepository operations;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  BuildContext anywhere(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).first);

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(anywhere(tester));

  String location(WidgetTester tester) =>
      GoRouter.of(anywhere(tester)).routeInformationProvider.value.uri
          .toString();

  BoardQuery lastQuery() => operations.queries.last;

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.staff] = 's';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.staff] = user(role: UserRole.operator);
    operations = FakeOperationsRepository();
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(1400, 1200),
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
        surface: Surface.web,
        operations: operations,
        device: device,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Whether the text [finder] shows is cut: laid out shorter than it needs.
  bool cut(WidgetTester tester, Finder finder) {
    final RenderParagraph paragraph = tester.renderObject(finder);
    return paragraph.size.height <
        paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.5;
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String dropdown, String item) async {
    await tapAndSettle(tester, byKey(dropdown));
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  testWidgets('the board shows the day, the orders and what needs attention', (
    WidgetTester tester,
  ) async {
    await open(tester);

    expect(
      find.text('${l10n(tester).orderStatusNew}: 2'),
      findsOneWidget,
      reason: 'the open orders by status',
    );
    expect(
      find.text('${l10n(tester).summaryCompletedToday}: 4'),
      findsOneWidget,
    );
    expect(find.byType(DataTable), findsOneWidget);
    expect(byKey('board-row-$orderA'), findsOneWidget);
    expect(byKey('board-row-$orderB'), findsOneWidget);
    expect(find.text(l10n(tester).boardNoShopper), findsOneWidget);
    expect(byKey('attention-self_order-$orderA'), findsOneWidget);
    expect(lastQuery(), const BoardQuery());
  });

  testWidgets(
    'each attention type has its words, and one order may need two things',
    (WidgetTester tester) async {
      operations.attentionAnswer = <AttentionItem>[
        OperationsApi.parseAttention(<String, Object?>{
          ...attentionJson(),
          'type': 'approval_pending',
        }),
        OperationsApi.parseAttention(attentionJson()),
        OperationsApi.parseAttention(<String, Object?>{
          ...attentionJson(order: orderB, number: 1002),
          'type': 'approval_expired',
          'shopper': null,
        }),
        OperationsApi.parseAttention(<String, Object?>{
          ...attentionJson(order: orderB, number: 1002),
          'type': 'a_later_type',
        }),
        OperationsApi.parseAttention(<String, Object?>{
          ...attentionJson(order: orderB, number: 1002),
          'type': 'another_later_type',
        }),
      ];

      for (final Locale language in const <Locale>[
        Locale('uz'),
        Locale('ru'),
      ]) {
        await open(tester, device: language);
        final AppLocalizations words = l10n(tester);

        expect(byKey('attention-approval_pending-$orderA'), findsOneWidget);
        expect(byKey('attention-self_order-$orderA'), findsOneWidget);
        expect(byKey('attention-approval_expired-$orderB'), findsOneWidget);
        expect(
          find.textContaining(words.attentionApprovalPending),
          findsOneWidget,
        );
        expect(
          find.textContaining(words.attentionApprovalExpired),
          findsOneWidget,
        );
        // Two types this client does not know are two rows, each in general
        // words.
        for (final String later in const <String>[
          'a_later_type',
          'another_later_type',
        ]) {
          expect(
            find.descendant(
              of: byKey('attention-$later-$orderB'),
              matching: find.textContaining(words.attentionOther),
            ),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'a row names its Courier and the Customer\'s open questions, in a table and a card',
    (WidgetTester tester) async {
      operations.rows = <BoardRow>[
        OperationsApi.parseRow(
          rowJson(
            status: 'delivery_assigned',
            courier: courierId,
            pendingApprovals: 2,
          ),
        ),
      ];
      for (final Size size in const <Size>[Size(1400, 1200), Size(420, 1600)]) {
        await open(tester, size: size);
        final AppLocalizations words = l10n(tester);

        expect(
          find.descendant(
            of: find.byKey(const ValueKey<String>('operations-board')),
            matching: find.text(words.boardCourierNamed('Kamol Karimov')),
          ),
          findsOneWidget,
        );
        expect(find.text(words.boardPendingQuestions(2)), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'the questions go under the status, so the table keeps its width',
    (WidgetTester tester) async {
      operations.rows = <BoardRow>[
        OperationsApi.parseRow(rowJson(pendingApprovals: 3)),
      ];
      await open(tester, size: const Size(1800, 1200));
      final Finder chip = find.descendant(
        of: find.byType(DataTable),
        matching: find.byType(OrderStatusChip),
      );
      final Finder questions = byKey('board-questions-$orderA');
      Finder header(String text) => find.descendant(
        of: find.byType(DataTable),
        matching: find.text(text),
      );
      final AppLocalizations words = l10n(tester);

      expect(
        tester.getTopLeft(questions).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(chip).dy),
      );
      expect(tester.getTopLeft(questions).dx, tester.getTopLeft(chip).dx);
      // The column is as wide as the widest of its lines, not their sum.
      final double widest = <double>[
        tester.getSize(chip).width,
        tester.getSize(questions).width,
        tester.getSize(header(words.boardColumnStatus)).width,
      ].reduce(math.max);
      expect(
        tester.getTopLeft(header(words.boardColumnPayment)).dx -
            tester.getTopLeft(chip).dx,
        lessThanOrEqualTo(widest + 24 + 0.5),
      );
    },
  );

  testWidgets(
    'the Courier\'s and the cancellation\'s attention have their words',
    (WidgetTester tester) async {
      const Map<String, String Function(AppLocalizations)> types =
          <String, String Function(AppLocalizations)>{
            'courier_delayed': _courierDelayed,
            'delivery_failed': _deliveryFailed,
            'cancellation_request': _cancellationRequest,
            'staff_blocked': _staffBlocked,
          };
      operations.attentionAnswer = <AttentionItem>[
        for (final String type in types.keys)
          OperationsApi.parseAttention(<String, Object?>{
            ...attentionJson(order: orderB, number: 1002),
            'type': type,
          }),
      ];

      for (final Locale language in const <Locale>[
        Locale('uz'),
        Locale('ru'),
      ]) {
        await open(tester, size: const Size(1800, 1600), device: language);
        final AppLocalizations words = l10n(tester);

        for (final MapEntry<String, String Function(AppLocalizations)> type
            in types.entries) {
          expect(
            find.descendant(
              of: byKey('attention-${type.key}-$orderB'),
              matching: find.textContaining(type.value(words)),
            ),
            findsOneWidget,
            reason: type.key,
          );
        }
      }
    },
  );

  testWidgets('the attention list folds past five items and unfolds on a tap', (
    WidgetTester tester,
  ) async {
    const List<String> orders = <String>[
      '0192f0a0-0000-7000-8000-0000000001a1',
      '0192f0a0-0000-7000-8000-0000000001a2',
      '0192f0a0-0000-7000-8000-0000000001a3',
      '0192f0a0-0000-7000-8000-0000000001a4',
      '0192f0a0-0000-7000-8000-0000000001a5',
      '0192f0a0-0000-7000-8000-0000000001a6',
      '0192f0a0-0000-7000-8000-0000000001a7',
    ];
    operations.attentionAnswer = <AttentionItem>[
      for (final String order in orders)
        OperationsApi.parseAttention(<String, Object?>{
          ...attentionJson(order: order),
          'type': 'courier_delayed',
          'shopper': null,
        }),
    ];
    await open(tester, size: const Size(1800, 1600));
    Finder items() => find.descendant(
      of: byKey('board-attention'),
      matching: find.byType(ListTile),
    );

    expect(items(), findsNWidgets(5));
    expect(find.text(l10n(tester).attentionShowAll(7)), findsOneWidget);
    await tapAndSettle(tester, byKey('attention-fold'));
    expect(items(), findsNWidgets(7));
    await tapAndSettle(tester, byKey('attention-fold'));
    expect(items(), findsNWidgets(5));
    expect(find.text(l10n(tester).attentionShowAll(7)), findsOneWidget);
  });

  testWidgets(
    'each filter narrows what the board asks for, and one tap clears them',
    (WidgetTester tester) async {
      await open(tester);
      final AppLocalizations words = l10n(tester);

      await choose(
        tester,
        'board-status-filter',
        words.orderStatusShoppingAssigned,
      );
      expect(lastQuery().status, OrderStatus.shoppingAssigned);

      await choose(tester, 'board-payment-filter', words.paymentCash);
      expect(lastQuery().paymentMethod, PaymentMethod.cash);

      await choose(tester, 'board-shopper-filter', 'Sardor Yusupov');
      expect(lastQuery().shopperId, shopperId);

      await choose(tester, 'board-courier-filter', 'Kamol Karimov');
      expect(lastQuery().courierId, courierId);

      await tapAndSettle(tester, byKey('board-self-orders'));
      expect(lastQuery().selfOrdersOnly, isTrue);

      await tapAndSettle(tester, byKey('board-awaiting-customer'));
      expect(lastQuery().awaitingCustomerOnly, isTrue);

      await tester.enterText(byKey('board-search'), ' 1001 ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(lastQuery().search, '1001');
      expect(lastQuery().page, 1);

      await tapAndSettle(tester, byKey('board-clear-filters'));
      expect(lastQuery(), const BoardQuery());
      expect(
        tester.widget<TextField>(byKey('board-search')).controller!.text,
        isEmpty,
      );

      // A status in the summary filters the board by it, and again clears it.
      await tapAndSettle(tester, byKey('summary-new'));
      expect(lastQuery().status, OrderStatus.newOrder);
      expect(byKey('board-row-$orderA'), findsNothing);
      await tapAndSettle(tester, byKey('summary-new'));
      expect(lastQuery().status, isNull);
    },
  );

  testWidgets(
    'an order opens on its page, and the board comes back as it was left',
    (WidgetTester tester) async {
      await open(tester);
      final AppLocalizations words = l10n(tester);
      await tapAndSettle(tester, byKey('board-self-orders'));
      operations.rows = <BoardRow>[
        ...operations.rows.map(
          (BoardRow row) => BoardRow(
            id: row.id,
            orderNumber: row.orderNumber,
            createdAt: row.createdAt,
            status: row.status,
            paymentMethod: row.paymentMethod,
            customerName: row.customerName,
            customerPhone: row.customerPhone,
            itemCount: row.itemCount,
            pendingApprovalCount: row.pendingApprovalCount,
            totalUzs: row.totalUzs,
            totalKind: row.totalKind,
            shopper: row.shopper,
            courier: row.courier,
            isSelfOrder: row.shopper != null,
          ),
        ),
      ];
      await tapAndSettle(tester, byKey('board-refresh'));

      await tapAndSettle(tester, byKey('board-row-$orderA'));

      expect(location(tester), '/operations/orders/$orderA');
      expect(find.text(words.orderTitle('1001')), findsOneWidget);
      expect(find.text('Pomidor · 3.000 ${words.unitKg}'), findsOneWidget);
      expect(find.text(words.itemMarkup('15.00')), findsOneWidget);
      expect(
        find.text(
          words.itemMarketPrice(MoneyFormat.uzs(16000, AppLanguage.uz)),
        ),
        findsOneWidget,
      );
      expect(find.text(words.assignmentCurrent), findsOneWidget);
      expect(
        find.text(
          '${words.historyEventShopperAssigned} · '
          '${words.orderStatusNew} → ${words.orderStatusShoppingAssigned}',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Olim (${words.roleOperator})'),
        findsOneWidget,
      );
      expect(
        find.text(words.historyAssignedTo('Sardor Yusupov')),
        findsOneWidget,
      );
      expect(find.text('Kechqurun'), findsOneWidget);

      await tapAndSettle(tester, byKey('order-back'));
      expect(location(tester), AppPaths.operations);
      expect(lastQuery().selfOrdersOnly, isTrue, reason: 'the filters stay');
    },
  );

  testWidgets('a cancelled order shows nothing to pay and why it ended', (
    WidgetTester tester,
  ) async {
    await open(tester);
    operations.details[orderB] = OperationsApi.parseOrder(
      orderJson(
        id: orderB,
        status: 'cancelled',
        totals: <String, Object?>{
          'merchandise_subtotal_uzs': null,
          'service_fee_uzs': null,
          'delivery_fee_uzs': null,
          'total_uzs': null,
          'total_kind': 'none',
        },
        items: <Object?>[
          itemJson(status: 'removed', removedReason: 'order_cancelled'),
        ],
        assignments: <Object?>[],
        history: <Object?>[],
        cancellationReason: 'customer_cancelled',
      ),
    );
    final AppLocalizations words = l10n(tester);

    GoRouter.of(anywhere(tester)).go('/operations/orders/$orderB');
    await tester.pumpAndSettle();

    expect(find.text(words.totalNothingDue), findsOneWidget);
    expect(find.text(words.cancelCustomerCancelled), findsOneWidget);
    expect(
      find.text(words.itemRemovedBecause(words.removedOrderCancelled)),
      findsOneWidget,
    );
    expect(find.text(words.assignmentsNone), findsOneWidget);
    expect(find.text(words.historyNone), findsOneWidget);
  });

  testWidgets('an order that does not exist says so without a retry', (
    WidgetTester tester,
  ) async {
    await open(tester);

    GoRouter.of(anywhere(tester))
        .go('/operations/orders/0192f0a0-0000-7000-8000-0000000000ff');
    await tester.pumpAndSettle();

    expect(byKey('failure-message'), findsOneWidget);
    expect(byKey('retry-load'), findsNothing);
  });

  testWidgets(
    'a board that failed to load offers a retry that shows progress',
    (WidgetTester tester) async {
      operations.pageFailure = const NetworkFailure();
      await open(tester);

      expect(byKey('retry-load'), findsOneWidget);
      expect(byKey('board-row-$orderA'), findsNothing);

      operations.pageFailure = null;
      await tapAndSettle(tester, byKey('retry-load'));

      expect(byKey('board-row-$orderA'), findsOneWidget);
    },
  );

  testWidgets(
    'refresh asks again for the page, the summary and the attention list',
    (WidgetTester tester) async {
      await open(tester);
      operations.loads.clear();

      await tapAndSettle(tester, byKey('board-refresh'));

      expect(
        operations.loads,
        containsAll(<String>['orders', 'summary', 'attention']),
      );
    },
  );

  testWidgets(
    'a phone-size window shows cards with the attention list above them',
    (WidgetTester tester) async {
      // Phone-wide, and tall enough that the list builds every row.
      await open(tester, size: const Size(400, 2400));

      expect(find.byType(DataTable), findsNothing);
      expect(byKey('board-row-$orderA'), findsOneWidget);
      expect(
        tester.getTopLeft(byKey('board-attention')).dy,
        lessThan(tester.getTopLeft(byKey('board-row-$orderA')).dy),
      );
      expect(tester.takeException(), isNull);

      await tapAndSettle(tester, byKey('board-row-$orderA'));
      expect(location(tester), '/operations/orders/$orderA');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a window narrower than the whole table shows cards, not a clipped table',
    (WidgetTester tester) async {
      await open(tester, size: const Size(1100, 2400));

      expect(find.byType(DataTable), findsNothing);
      expect(byKey('board-row-$orderA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a long name wraps in its cell rather than widening the table', (
    WidgetTester tester,
  ) async {
    operations.rows = <BoardRow>[
      for (final BoardRow row in operations.rows)
        BoardRow(
          id: row.id,
          orderNumber: row.orderNumber,
          createdAt: row.createdAt,
          status: row.status,
          paymentMethod: row.paymentMethod,
          customerName: 'Abdurakhmonova Shakhnoza Rustamovna',
          customerPhone: row.customerPhone,
          itemCount: row.itemCount,
          pendingApprovalCount: row.pendingApprovalCount,
          totalUzs: row.totalUzs,
          totalKind: row.totalKind,
          shopper: row.shopper,
          courier: row.courier,
          isSelfOrder: row.isSelfOrder,
        ),
    ];
    await open(tester, size: const Size(1800, 1600));

    expect(find.byType(DataTable), findsOneWidget);
    expect(
      tester.getSize(byKey('board-customer-$orderA')).width,
      lessThanOrEqualTo(180),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text makes a table row taller rather than cutting it', (
    WidgetTester tester,
  ) async {
    await open(tester, size: const Size(1800, 1600), textScale: 2);

    expect(find.byType(DataTable), findsOneWidget);
    final Finder customer = find.text(
      'Aziza Karimova\n${formatPhone('+998901112233')}',
    );
    expect(customer, findsNWidgets(2));
    for (final Element cell in customer.evaluate()) {
      expect(
        cut(tester, find.byElementPredicate((Element e) => e == cell)),
        isFalse,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the orders stay a table whether the attention list is above or beside them',
    (WidgetTester tester) async {
      // A laptop window keeps the whole width for the orders.
      await open(tester, size: const Size(1440, 1600));
      expect(find.byType(DataTable), findsOneWidget);
      expect(
        tester.getTopLeft(byKey('board-attention')).dy,
        lessThan(tester.getTopLeft(find.byType(DataTable)).dy),
        reason: 'above the orders below the side-by-side width',
      );

      await open(tester, size: const Size(1600, 1600));
      expect(find.byType(DataTable), findsOneWidget);
      expect(
        tester.getTopLeft(byKey('board-attention')).dx,
        greaterThan(tester.getTopLeft(find.byType(DataTable)).dx),
        reason: 'beside them from it',
      );
    },
  );

  for (final Locale language in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'the order page fits a phone with large text (${language.languageCode})',
      (WidgetTester tester) async {
        await open(
          tester,
          size: const Size(360, 3200),
          textScale: 2,
          device: language,
        );

        GoRouter.of(anywhere(tester)).go('/operations/orders/$orderA');
        await tester.pumpAndSettle();

        expect(byKey('totals'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'the history marks a self-order and says who a reassignment went from and to',
    (WidgetTester tester) async {
      const String secondAssignment = '0192f0a0-0000-7000-8000-0000000000a2';
      operations.details[orderA] = OperationsApi.parseOrder(
        orderJson(
          assignments: <Object?>[
            assignmentJson(
              endedAt: '2026-09-27T07:10:00Z',
              endedReason: 'reassigned',
            ),
            <String, Object?>{
              ...assignmentJson(
                id: secondAssignment,
                shopper: otherShopperId,
                selfOrder: true,
              ),
              'shopper': <String, Object?>{
                'id': otherShopperId,
                'full_name': 'Dilnoza Karimova',
                'phone': '+998901112233',
              },
            },
          ],
          history: <Object?>[
            historyJson(),
            <String, Object?>{
              ...historyJson(
                event: 'shopper_reassigned',
                details: <String, Object?>{
                  'assignment_id': secondAssignment,
                  'shopper_id': otherShopperId,
                  'is_self_order': true,
                  'previous_assignment_id': assignmentId,
                  'previous_shopper_id': shopperId,
                },
              ),
              'id': '0192f0a0-0000-7000-8000-0000000000b2',
              'from_status': null,
              'to_status': null,
            },
            <String, Object?>{
              ...historyJson(
                event: 'edited',
                details: <String, Object?>{
                  'added': <Object?>[],
                  'removed': <Object?>[],
                  'changed': <Object?>[],
                  'delivery_time_note': <String, Object?>{
                    'before': null,
                    'after': 'Kechqurun',
                  },
                },
              ),
              'id': '0192f0a0-0000-7000-8000-0000000000b3',
              'from_status': null,
              'to_status': null,
            },
          ],
        ),
      );
      await open(tester, size: const Size(1400, 2400));
      final AppLocalizations words = l10n(tester);

      GoRouter.of(anywhere(tester)).go('/operations/orders/$orderA');
      await tester.pumpAndSettle();

      expect(
        find.text(
          words.historyReassignedTo('Sardor Yusupov', 'Dilnoza Karimova'),
        ),
        findsOneWidget,
      );
      expect(
        find.byType(SelfOrderMark),
        findsNWidgets(2),
        reason: 'on the current assignment and on its history entry',
      );
      expect(find.text(words.historyDeliveryWishChanged), findsOneWidget);
      expect(find.textContaining(words.historyEditAdded(0)), findsNothing);
    },
  );

  testWidgets(
    'a Courier filter the options no longer hold still shows one is chosen',
    (WidgetTester tester) async {
      operations.rows = <BoardRow>[
        OperationsApi.parseRow(
          rowJson(status: 'delivery_assigned', courier: courierId),
        ),
      ];
      await open(tester);
      await choose(tester, 'board-courier-filter', 'Kamol Karimov');
      expect(lastQuery().courierId, courierId);

      // The Courier is blocked meanwhile, so the options come back without them.
      operations.courierList = <StaffChoice>[];
      await tapAndSettle(tester, byKey('board-row-$orderA'));
      await tapAndSettle(tester, byKey('order-back'));

      expect(lastQuery().courierId, courierId);
      expect(
        find.descendant(
          of: byKey('board-courier-filter'),
          matching: find.text(l10n(tester).boardFilteredCourier),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a Shopper filter the options no longer hold still shows one is chosen',
    (WidgetTester tester) async {
      await open(tester);
      await choose(tester, 'board-shopper-filter', 'Sardor Yusupov');
      expect(lastQuery().shopperId, shopperId);

      // The Shopper is blocked meanwhile, so the options come back without them.
      operations.shopperList = <StaffChoice>[];
      await tapAndSettle(tester, byKey('board-row-$orderA'));
      await tapAndSettle(tester, byKey('order-back'));

      expect(lastQuery().shopperId, shopperId);
      expect(
        find.descendant(
          of: byKey('board-shopper-filter'),
          matching: find.text(l10n(tester).boardFilteredShopper),
        ),
        findsOneWidget,
      );
    },
  );
}

String _courierDelayed(AppLocalizations l10n) => l10n.attentionCourierDelayed;

String _deliveryFailed(AppLocalizations l10n) => l10n.attentionDeliveryFailed;

String _cancellationRequest(AppLocalizations l10n) =>
    l10n.attentionCancellationRequest;

String _staffBlocked(AppLocalizations l10n) => l10n.attentionStaffBlocked;
