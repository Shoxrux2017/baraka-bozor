import 'dart:async';

import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
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

/// Assigning and replacing an order's Shopper from its page (`docs/09`
/// section 39, `DL-45`), through the real router, controllers and screen.
void main() {
  const String secondAssignment = '0192f0a0-0000-7000-8000-0000000000a2';

  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeOperationsRepository operations;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  BuildContext anywhere(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).first);

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(anywhere(tester));

  /// A `new` order no Shopper has been assigned to.
  BoardOrder unassigned() => OperationsApi.parseOrder(
    orderJson(
      id: orderB,
      status: 'new',
      assignments: <Object?>[],
      history: <Object?>[],
    ),
  );

  /// Order A after its Shopper was replaced by the other Shopper.
  BoardOrder reassigned() => OperationsApi.parseOrder(
    orderJson(
      assignments: <Object?>[
        assignmentJson(
          endedAt: '2026-09-27T07:10:00Z',
          endedReason: 'reassigned',
        ),
        <String, Object?>{
          ...assignmentJson(id: secondAssignment, shopper: otherShopperId),
          'shopper': <String, Object?>{
            'id': otherShopperId,
            'full_name': 'Dilnoza Karimova',
            'phone': '+998901234567',
          },
        },
      ],
    ),
  );

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.staff] = 's';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.staff] = user(role: UserRole.operator);
    operations = FakeOperationsRepository(
      shopperList: <StaffChoice>[
        OperationsApi.parseStaff(shopperJson()),
        OperationsApi.parseStaff(
          shopperJson(id: otherShopperId, fullName: 'Dilnoza Karimova'),
        ),
      ],
    );
    operations.details[orderB] = unassigned();
  });

  Future<void> openOrder(WidgetTester tester, String id) async {
    tester.view.physicalSize = const Size(1400, 2400);
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
    GoRouter.of(anywhere(tester)).go('/operations/orders/$id');
    await tester.pumpAndSettle();
  }

  /// The height of the dialog's surface, not of the layer that centres it.
  double dialogHeight(WidgetTester tester) => tester
      .getSize(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Material),
            )
            .first,
      )
      .height;

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('a new order gets its first Shopper from the picker', (
    WidgetTester tester,
  ) async {
    operations.afterAssignment[orderB] = OperationsApi.parseOrder(
      orderJson(id: orderB, history: <Object?>[]),
    );
    await openOrder(tester, orderB);
    expect(find.text(l10n(tester).assignmentsNone), findsOneWidget);
    expect(byKey('reassign-shopper'), findsNothing);

    await tapAndSettle(tester, byKey('assign-shopper'));
    expect(find.text(l10n(tester).pickShopperTitle), findsOneWidget);
    expect(
      find.textContaining(l10n(tester).shopperOrdersNow(1)),
      findsNWidgets(2),
    );
    await tapAndSettle(tester, byKey('pick-shopper-$shopperId'));

    expect(operations.changes, <String>['assign:$orderB:$shopperId']);
    expect(byKey('assignment-$assignmentId'), findsOneWidget);
    expect(byKey('assign-shopper'), findsNothing);
    expect(byKey('reassign-shopper'), findsOneWidget);
    expect(byKey('failure-message'), findsNothing);
  });

  testWidgets(
    'a Shopper who has not started is replaced, naming the assignment the Operator saw',
    (WidgetTester tester) async {
      operations.afterAssignment[orderA] = reassigned();
      await openOrder(tester, orderA);

      await tapAndSettle(tester, byKey('reassign-shopper'));
      // The current Shopper is shown and cannot be chosen again.
      expect(
        tester.widget<ListTile>(byKey('pick-shopper-$shopperId')).enabled,
        isFalse,
      );
      await tapAndSettle(tester, byKey('pick-shopper-$otherShopperId'));

      expect(operations.changes, <String>[
        'reassign:$orderA:$otherShopperId:$assignmentId',
      ]);
      expect(byKey('assignment-$secondAssignment'), findsOneWidget);
    },
  );

  testWidgets(
    'an order that changed meanwhile is reloaded and the Operator told why',
    (WidgetTester tester) async {
      await openOrder(tester, orderB);
      operations
        ..assignmentFailure = const ApiRefusal(
          ApiError(status: 409, code: 'order_state_conflict'),
        )
        ..loads.clear();
      // Another Operator assigned the order meanwhile.
      operations.details[orderB] = OperationsApi.parseOrder(
        orderJson(id: orderB, history: <Object?>[]),
      );

      await tapAndSettle(tester, byKey('assign-shopper'));
      await tapAndSettle(tester, byKey('pick-shopper-$otherShopperId'));

      expect(find.text(l10n(tester).errorOrderStateConflict), findsOneWidget);
      expect(operations.loads, contains('order:$orderB'));
      expect(
        byKey('assignment-$assignmentId'),
        findsOneWidget,
        reason: 'the order as it is now',
      );
      expect(byKey('reassign-shopper'), findsOneWidget);
    },
  );

  testWidgets('a blocked Shopper is refused with its own words', (
    WidgetTester tester,
  ) async {
    await openOrder(tester, orderB);
    operations.assignmentFailure = const ApiRefusal(
      ApiError(status: 409, code: 'staff_not_active'),
    );

    await tapAndSettle(tester, byKey('assign-shopper'));
    await tapAndSettle(tester, byKey('pick-shopper-$shopperId'));

    expect(find.text(l10n(tester).errorStaffNotActive), findsOneWidget);
    expect(byKey('assign-shopper'), findsOneWidget);
  });

  testWidgets(
    'one assignment at a time, and closing the picker sends nothing',
    (WidgetTester tester) async {
      operations.afterAssignment[orderB] = OperationsApi.parseOrder(
        orderJson(id: orderB, history: <Object?>[]),
      );
      await openOrder(tester, orderB);

      await tapAndSettle(tester, byKey('assign-shopper'));
      await tapAndSettle(tester, byKey('pick-shopper-cancel'));
      expect(operations.changes, isEmpty);

      await tapAndSettle(tester, byKey('assign-shopper'));
      // Held once the picker has its Shoppers, so only the assignment waits.
      final Completer<void> hold = Completer<void>();
      operations.hold = hold;
      await tester.tap(byKey('pick-shopper-$shopperId'));
      await tester.pump();
      await tester.pump();

      expect(
        tester.widget<FilledButton>(byKey('assign-shopper')).onPressed,
        isNull,
        reason: 'busy while the first is in flight',
      );
      operations.hold = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(operations.changes, hasLength(1));
    },
  );

  testWidgets(
    'no assignment is offered once shopping started or the order ended',
    (WidgetTester tester) async {
      operations.details[orderA] = OperationsApi.parseOrder(
        orderJson(
          status: 'shopping',
          assignments: <Object?>[
            <String, Object?>{
              ...assignmentJson(),
              'accepted_at': '2026-09-27T07:06:00Z',
              'started_at': '2026-09-27T07:07:00Z',
            },
          ],
        ),
      );
      await openOrder(tester, orderA);
      expect(byKey('assign-shopper'), findsNothing);
      expect(byKey('reassign-shopper'), findsNothing);

      GoRouter.of(anywhere(tester)).go('/operations/orders/$orderB');
      operations.details[orderB] = OperationsApi.parseOrder(
        orderJson(
          id: orderB,
          status: 'cancelled',
          assignments: <Object?>[],
          history: <Object?>[],
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
        ),
      );
      await tester.pumpAndSettle();
      expect(byKey('assign-shopper'), findsNothing);
      expect(byKey('reassign-shopper'), findsNothing);
    },
  );

  testWidgets('the picker fits a phone-wide window with large text', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(360, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        surface: Surface.web,
        operations: operations,
        device: const Locale('ru'),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(anywhere(tester)).go('/operations/orders/$orderB');
    await tester.pumpAndSettle();

    await tapAndSettle(tester, byKey('assign-shopper'));

    expect(byKey('pick-shopper-$otherShopperId'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a change loads the order again, and the picker asks for fresh counts',
    (WidgetTester tester) async {
      int shopperLoads() =>
          operations.loads.where((String load) => load == 'shoppers').length;
      operations.afterAssignment[orderB] = OperationsApi.parseOrder(
        orderJson(id: orderB, history: <Object?>[]),
      );
      await openOrder(tester, orderB);
      await tapAndSettle(tester, byKey('assign-shopper'));
      operations.loads.clear();

      await tapAndSettle(tester, byKey('pick-shopper-$shopperId'));
      expect(operations.loads, contains('order:$orderB'));

      final int before = shopperLoads();
      await tapAndSettle(tester, byKey('reassign-shopper'));
      expect(shopperLoads(), greaterThan(before));
    },
  );

  testWidgets('an order opened by an id in capitals reloads after a change', (
    WidgetTester tester,
  ) async {
    operations.afterAssignment[orderB] = OperationsApi.parseOrder(
      orderJson(id: orderB, history: <Object?>[]),
    );
    await openOrder(tester, orderB.toUpperCase());
    operations.loads.clear();

    await tapAndSettle(tester, byKey('assign-shopper'));
    await tapAndSettle(tester, byKey('pick-shopper-$shopperId'));

    expect(operations.loads, contains('order:$orderB'));
    expect(byKey('reassign-shopper'), findsOneWidget);
  });

  testWidgets('the buttons wait for the order a change reloads', (
    WidgetTester tester,
  ) async {
    operations.afterAssignment[orderB] = OperationsApi.parseOrder(
      orderJson(id: orderB, history: <Object?>[]),
    );
    await openOrder(tester, orderB);
    await tapAndSettle(tester, byKey('assign-shopper'));
    final Completer<void> reload = Completer<void>();
    operations.holdOrder = reload;

    await tester.tap(byKey('pick-shopper-$shopperId'));
    await tester.pump();
    await tester.pump();

    expect(operations.changes, hasLength(1), reason: 'the change answered');
    expect(
      tester.widget<FilledButton>(byKey('assign-shopper')).onPressed,
      isNull,
      reason: 'the order the change reloads has not arrived',
    );

    operations.holdOrder = null;
    reload.complete();
    await tester.pumpAndSettle();
    expect(byKey('reassign-shopper'), findsOneWidget);
  });

  testWidgets(
    'the picker says when there is nobody to choose, and when the list failed',
    (WidgetTester tester) async {
      operations.shopperList = <StaffChoice>[];
      await openOrder(tester, orderB);

      await tapAndSettle(tester, byKey('assign-shopper'));
      expect(find.text(l10n(tester).pickShopperEmpty), findsOneWidget);
      await tapAndSettle(tester, byKey('pick-shopper-cancel'));

      operations.shoppersFailure = const NetworkFailure();
      await tapAndSettle(tester, byKey('assign-shopper'));
      expect(find.text(l10n(tester).errorNetwork), findsOneWidget);
      expect(
        dialogHeight(tester),
        lessThan(600),
        reason: 'the dialog is as small as what it shows',
      );

      operations
        ..shoppersFailure = null
        ..shopperList = <StaffChoice>[OperationsApi.parseStaff(shopperJson())];
      await tapAndSettle(tester, byKey('retry-load'));
      expect(byKey('pick-shopper-$shopperId'), findsOneWidget);
      expect(operations.changes, isEmpty);
    },
  );

  testWidgets('the picker stays small while it loads', (
    WidgetTester tester,
  ) async {
    await openOrder(tester, orderB);
    final Completer<void> hold = Completer<void>();
    operations.hold = hold;

    await tester.tap(byKey('assign-shopper'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(dialogHeight(tester), lessThan(600));

    operations.hold = null;
    hold.complete();
    await tester.pumpAndSettle();
  });
}
