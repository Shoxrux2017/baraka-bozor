import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/operations/data/operations_api.dart';
import 'package:baraka_bozor/features/operations/domain/board.dart';
import 'package:flutter/material.dart';
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
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        surface: Surface.web,
        operations: operations,
      ),
    );
    await tester.pumpAndSettle();
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
    expect(byKey('attention-$orderA'), findsOneWidget);
    expect(lastQuery(), const BoardQuery());
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

      await tapAndSettle(tester, byKey('board-self-orders'));
      expect(lastQuery().selfOrdersOnly, isTrue);

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
            totalUzs: row.totalUzs,
            totalKind: row.totalKind,
            shopper: row.shopper,
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
}
