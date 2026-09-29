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

/// Assigning and replacing an order's Courier from its page (`docs/09`
/// section 39, `DL-54` (10), `DL-67`), with the rules of the Shopper's
/// (`DL-48`), through the real router, controllers and screen.
void main() {
  const String secondAssignment = '0192f0a0-0000-7000-8000-0000000000a8';

  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeOperationsRepository operations;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  BuildContext anywhere(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).first);

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(anywhere(tester));

  BoardOrder order(String status, List<Object?> couriers) =>
      OperationsApi.parseOrder(
        orderJson(
          status: status,
          assignments: <Object?>[
            assignmentJson(
              endedAt: '2026-09-27T08:00:00Z',
              endedReason: 'completed',
            ),
          ],
          courierAssignments: couriers,
          history: <Object?>[],
        ),
      );

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.staff] = 's';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.staff] = user(role: UserRole.operator);
    operations = FakeOperationsRepository(
      courierList: <StaffChoice>[
        OperationsApi.parseStaff(courierChoiceJson()),
        OperationsApi.parseStaff(
          courierChoiceJson(id: otherCourierId, fullName: 'Botir Aliyev'),
        ),
      ],
    );
  });

  Future<void> openOrder(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 2600);
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
    GoRouter.of(anywhere(tester)).go('/operations/orders/$orderA');
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('a ready order gets its Courier from the picker', (
    WidgetTester tester,
  ) async {
    operations.details[orderA] = order('ready_for_delivery', <Object?>[]);
    operations.afterAssignment[orderA] = order('delivery_assigned', <Object?>[
      courierAssignmentJson(),
    ]);
    await openOrder(tester);
    expect(find.text(l10n(tester).courierAssignmentsNone), findsOneWidget);
    expect(byKey('reassign-courier'), findsNothing);

    await tapAndSettle(tester, byKey('assign-courier'));
    expect(find.text(l10n(tester).pickCourierTitle), findsOneWidget);
    expect(
      find.textContaining(l10n(tester).shopperOrdersNow(2)),
      findsNWidgets(2),
    );
    await tapAndSettle(tester, byKey('pick-courier-$courierId'));

    expect(operations.changes, <String>['assign-courier:$orderA:$courierId']);
    expect(byKey('courier-assignment-$courierAssignmentId'), findsOneWidget);
    expect(byKey('assign-courier'), findsNothing);
    expect(byKey('reassign-courier'), findsOneWidget);
    expect(byKey('failure-message'), findsNothing);
    expect(operations.loads, contains('couriers'));
  });

  testWidgets(
    'a Courier who has not set off is replaced, naming the assignment replaced',
    (WidgetTester tester) async {
      operations.details[orderA] = order('delivery_assigned', <Object?>[
        courierAssignmentJson(acceptedAt: '2026-09-27T09:05:00Z'),
      ]);
      operations.afterAssignment[orderA] = order('delivery_assigned', <Object?>[
        courierAssignmentJson(
          endedAt: '2026-09-27T09:20:00Z',
          endedReason: 'reassigned',
        ),
        courierAssignmentJson(id: secondAssignment, courier: otherCourierId),
      ]);
      await openOrder(tester);

      await tapAndSettle(tester, byKey('reassign-courier'));
      // The current Courier is shown, not offered.
      final ListTile current = tester.widget<ListTile>(
        byKey('pick-courier-$courierId'),
      );
      expect(current.enabled, isFalse);
      await tapAndSettle(tester, byKey('pick-courier-$otherCourierId'));

      expect(operations.changes, <String>[
        'reassign-courier:$orderA:$otherCourierId:$courierAssignmentId',
      ]);
      expect(
        find.textContaining(l10n(tester).courierEndReassigned),
        findsOneWidget,
      );
    },
  );

  testWidgets('no Courier is assigned before readiness or after setting off', (
    WidgetTester tester,
  ) async {
    operations.details[orderA] = order('on_the_way', <Object?>[
      courierAssignmentJson(
        acceptedAt: '2026-09-27T09:05:00Z',
        startedAt: '2026-09-27T09:30:00Z',
      ),
    ]);
    await openOrder(tester);

    expect(byKey('assign-courier'), findsNothing);
    expect(byKey('reassign-courier'), findsNothing);
    expect(
      find.textContaining(l10n(tester).courierStarted('')),
      findsOneWidget,
    );
  });

  testWidgets(
    'a Courier who has set off keeps the order even before it shows on the way',
    (WidgetTester tester) async {
      operations.details[orderA] = order('delivery_assigned', <Object?>[
        courierAssignmentJson(
          acceptedAt: '2026-09-27T09:05:00Z',
          startedAt: '2026-09-27T09:30:00Z',
        ),
      ]);
      await openOrder(tester);

      expect(byKey('reassign-courier'), findsNothing);
      expect(byKey('assign-courier'), findsNothing);
    },
  );

  testWidgets(
    'a failed delivery shows its reason and note, and a new Courier',
    (WidgetTester tester) async {
      operations.details[orderA] = order('ready_for_delivery', <Object?>[
        courierAssignmentJson(
          acceptedAt: '2026-09-27T09:05:00Z',
          startedAt: '2026-09-27T09:30:00Z',
          endedAt: '2026-09-27T10:00:00Z',
          endedReason: 'delivery_failed',
          failedReason: 'other',
          failedNote: 'Podyezd yopiq',
        ),
      ]);
      await openOrder(tester);

      expect(
        tester.widget<Text>(byKey('courier-failure-$courierAssignmentId')).data,
        '${l10n(tester).deliveryFailureOther}: Podyezd yopiq',
      );
      expect(
        find.textContaining(l10n(tester).courierEndDeliveryFailed),
        findsOneWidget,
      );
      expect(byKey('assign-courier'), findsOneWidget);
    },
  );

  testWidgets('a refusal is said and the order loaded again', (
    WidgetTester tester,
  ) async {
    operations.details[orderA] = order('ready_for_delivery', <Object?>[]);
    operations.assignmentFailure = const ApiRefusal(
      ApiError(status: 409, code: 'staff_not_active'),
    );
    await openOrder(tester);
    final int loadsBefore = operations.loads
        .where((String load) => load == 'order:$orderA')
        .length;

    await tapAndSettle(tester, byKey('assign-courier'));
    await tapAndSettle(tester, byKey('pick-courier-$courierId'));

    expect(find.text(l10n(tester).errorStaffNotActive), findsOneWidget);
    expect(
      operations.loads.where((String load) => load == 'order:$orderA').length,
      greaterThan(loadsBefore),
    );
  });
}
