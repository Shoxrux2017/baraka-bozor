import 'dart:async';

import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
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

/// The order page's Wave 3 parts and actions (`docs/09` sections 38, 40,
/// 41 and 45, `DL-68`) through the real router, controllers and screen:
/// what a line bought, the questions to the Customer, the cancellation
/// requests, the payment, and the actions the rules allow.
void main() {
  const String secondApproval = '0192f0a0-0000-7000-8000-0000000000b4';

  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeOperationsRepository operations;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  BuildContext anywhere(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).first);

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(anywhere(tester));

  String money(int amount) => MoneyFormat.uzs(amount, AppLanguage.uz);

  BoardOrder order({
    String status = 'shopping',
    List<Object?>? items,
    List<Object?>? approvals,
    List<Object?>? requests,
    List<Object?>? couriers,
    Map<String, Object?>? payment,
    Map<String, Object?>? totals,
    String paymentMethod = 'cash',
    List<Object?>? history,
  }) => OperationsApi.parseOrder(
    orderJson(
      status: status,
      items: items,
      approvals: approvals,
      cancellationRequests: requests,
      courierAssignments: couriers,
      payment: payment,
      totals: totals,
      paymentMethod: paymentMethod,
      history: history ?? <Object?>[],
    ),
  );

  Map<String, Object?> bought({
    String priceMode = 'estimate',
    bool replaced = false,
  }) => itemJson(status: 'purchased', priceMode: priceMode, replaced: replaced);

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.staff] = 's';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.staff] = user(role: UserRole.operator);
    operations = FakeOperationsRepository();
  });

  Future<void> openOrder(
    WidgetTester tester, {
    Size size = const Size(1400, 3200),
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
    GoRouter.of(anywhere(tester)).go('/operations/orders/$orderA');
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(byKey(key)).data!;

  group('what the page shows', () {
    testWidgets('a bought line: what was bought, the price paid and billed', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        status: 'ready_for_delivery',
        items: <Object?>[bought(replaced: true)],
      );
      await openOrder(tester);
      final AppLocalizations words = l10n(tester);

      expect(text(tester, 'order-item-bought-$itemId'), contains('3.000'));
      expect(
        text(tester, 'order-item-paid-$itemId'),
        words.itemPricePaid(money(16000)),
      );
      expect(find.text(words.itemBilledPrice(money(18400))), findsOneWidget);
      expect(
        text(tester, 'order-item-replacement-$itemId'),
        '${words.itemReplacedWith('Olcha pomidor')}, '
        '${words.replacementAutomatic}',
      );
    });

    testWidgets(
      'the questions, newest first, with their proposal, timers and end',
      (WidgetTester tester) async {
        operations.details[orderA] = order(
          approvals: <Object?>[
            approvalJson(
              status: 'approved',
              resolution: 'approved',
              resolved: true,
            ),
            approvalJson(id: secondApproval, type: 'reduced_quantity'),
          ],
        );
        await openOrder(tester);
        final AppLocalizations words = l10n(tester);

        expect(
          tester.getTopLeft(byKey('approval-$secondApproval')).dy,
          lessThan(tester.getTopLeft(byKey('approval-$approvalId')).dy),
        );
        expect(
          text(tester, 'approval-status-$approvalId'),
          words.approvalStatusApproved,
        );
        expect(
          text(tester, 'approval-proposal-$approvalId'),
          words.approvalProposedPrice(money(25300), money(22000)),
        );
        expect(
          text(tester, 'approval-status-$secondApproval'),
          words.approvalStatusPending,
        );
        expect(
          text(tester, 'approval-proposal-$secondApproval'),
          startsWith(words.approvalProposedQuantity('2.000')),
        );
        expect(
          text(tester, 'approval-timers-$approvalId'),
          words.approvalTimers('27.09.2026 12:40', '27.09.2026 13:00'),
        );
        expect(
          find.textContaining(words.approvalResolvedBy('Olim', '')),
          findsOneWidget,
        );
        expect(byKey('remove-expired-$approvalId'), findsNothing);
        expect(byKey('remove-expired-$secondApproval'), findsNothing);
      },
    );

    testWidgets('the payment, and a page with nothing of the wave yet', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        status: 'completed',
        items: <Object?>[bought()],
        payment: paymentJson(),
      );
      await openOrder(tester);
      final AppLocalizations words = l10n(tester);

      expect(find.text(words.paymentAmount(money(75200))), findsOneWidget);
      expect(
        find.text(words.paymentPaidAt('27.09.2026 16:00')),
        findsOneWidget,
      );
      expect(
        find.text(words.paymentRecordedBy('Kamol Karimov')),
        findsOneWidget,
      );

      operations.details[orderA] = order(status: 'new');
      await tapAndSettle(tester, byKey('order-refresh'));
      expect(text(tester, 'payment'), words.paymentNone);
      expect(find.text(words.approvalsNone), findsOneWidget);
      expect(find.text(words.cancellationRequestsNone), findsOneWidget);
    });

    testWidgets('the history says what a price correction changed', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        status: 'ready_for_delivery',
        items: <Object?>[bought()],
        history: <Object?>[
          <String, Object?>{
            ...historyJson(
              event: 'price_corrected',
              details: <String, Object?>{
                'item_id': itemId,
                'correction_id': '0192f0a0-0000-7000-8000-0000000000b8',
                'old_actual_market_price_uzs': 16000,
                'new_actual_market_price_uzs': 17000,
                'old_billable_unit_price_uzs': 18400,
                'new_billable_unit_price_uzs': 19550,
                'line_total_uzs': 58650,
              },
            ),
            'note': 'Chek bo\'yicha',
          },
        ],
      );
      await openOrder(tester);

      expect(
        find.text(
          l10n(tester).historyPriceCorrectedDetails(
            'Pomidor',
            money(16000),
            money(17000),
            money(18400),
            money(19550),
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Chek bo\'yicha'), findsOneWidget);
    });
  });

  group('removing the line of an expired question', () {
    testWidgets('is confirmed first, and sends the note when there is one', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        approvals: <Object?>[approvalJson(status: 'expired')],
      );
      operations.afterAction[orderA] = order(
        status: 'cancelled',
        items: <Object?>[
          itemJson(status: 'removed', removedReason: 'approval_expired'),
        ],
        totals: _none,
        approvals: <Object?>[
          approvalJson(
            status: 'expired',
            resolution: 'remove_item',
            resolved: true,
          ),
        ],
      );
      await openOrder(tester);

      await tapAndSettle(tester, byKey('remove-expired-$approvalId'));
      expect(
        find.text(l10n(tester).removeExpiredTitle('Pomidor')),
        findsOneWidget,
      );
      await tapAndSettle(tester, byKey('action-cancel'));
      expect(operations.actions, isEmpty);

      await tapAndSettle(tester, byKey('remove-expired-$approvalId'));
      await tester.enterText(byKey('action-note'), '  Javob kelmadi  ');
      await tapAndSettle(tester, byKey('action-confirm'));

      expect(operations.actions, <String>[
        'remove-expired:$orderA:$approvalId:Javob kelmadi',
      ]);
      expect(find.byType(AlertDialog), findsNothing);
      expect(byKey('remove-expired-$approvalId'), findsNothing);
      expect(find.text(l10n(tester).approvalLineRemoved), findsOneWidget);
    });

    testWidgets('is not offered once resolved, or on an order not shopped', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        approvals: <Object?>[
          approvalJson(
            status: 'expired',
            resolution: 'remove_item',
            resolved: true,
          ),
        ],
      );
      await openOrder(tester);
      expect(byKey('remove-expired-$approvalId'), findsNothing);

      operations.details[orderA] = order(
        status: 'cancelled',
        items: <Object?>[
          itemJson(status: 'removed', removedReason: 'order_cancelled'),
        ],
        totals: _none,
        approvals: <Object?>[approvalJson(status: 'expired')],
      );
      await tapAndSettle(tester, byKey('order-refresh'));
      expect(byKey('approval-$approvalId'), findsOneWidget);
      expect(byKey('remove-expired-$approvalId'), findsNothing);
    });
  });

  group('a cancellation request', () {
    testWidgets('is approved after a confirmation, and then shows its end', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        requests: <Object?>[cancellationRequestJson()],
      );
      operations.afterAction[orderA] = order(
        status: 'cancelled',
        items: <Object?>[
          itemJson(status: 'removed', removedReason: 'order_cancelled'),
        ],
        totals: _none,
        requests: <Object?>[
          cancellationRequestJson(
            status: 'approved',
            note: 'Qo\'ng\'iroq qildi',
          ),
        ],
      );
      await openOrder(tester);
      final AppLocalizations words = l10n(tester);
      expect(
        text(tester, 'request-status-$requestId'),
        words.requestStatusPending,
      );

      await tapAndSettle(tester, byKey('approve-request-$requestId'));
      expect(find.text(words.approveRequestExplained), findsOneWidget);
      await tester.enterText(byKey('action-note'), 'Qo\'ng\'iroq qildi');
      await tapAndSettle(tester, byKey('action-confirm'));

      expect(operations.actions, <String>[
        'decide:$orderA:$requestId:approve:Qo\'ng\'iroq qildi',
      ]);
      expect(
        text(tester, 'request-status-$requestId'),
        words.requestStatusApproved,
      );
      expect(byKey('approve-request-$requestId'), findsNothing);
      expect(byKey('reject-request-$requestId'), findsNothing);
      expect(
        find.textContaining(words.requestDecidedBy('Olim', '')),
        findsOneWidget,
      );
    });

    testWidgets('is rejected without a note', (WidgetTester tester) async {
      operations.details[orderA] = order(
        requests: <Object?>[cancellationRequestJson()],
      );
      operations.afterAction[orderA] = order(
        requests: <Object?>[cancellationRequestJson(status: 'rejected')],
      );
      await openOrder(tester);

      await tapAndSettle(tester, byKey('reject-request-$requestId'));
      expect(find.text(l10n(tester).rejectRequestExplained), findsOneWidget);
      await tapAndSettle(tester, byKey('action-confirm'));

      expect(operations.actions, <String>[
        'decide:$orderA:$requestId:reject:null',
      ]);
      expect(
        text(tester, 'request-status-$requestId'),
        l10n(tester).requestStatusRejected,
      );
    });

    testWidgets(
      'a refusal is said in the dialog, which stays, and the order reloads',
      (WidgetTester tester) async {
        operations.details[orderA] = order(
          requests: <Object?>[cancellationRequestJson()],
        );
        await openOrder(tester);
        operations
          ..actionFailure = const ApiRefusal(
            ApiError(status: 409, code: 'cancellation_request_already_decided'),
          )
          ..loads.clear();

        await tapAndSettle(tester, byKey('approve-request-$requestId'));
        await tapAndSettle(tester, byKey('action-confirm'));

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(l10n(tester).errorRequestAlreadyDecided),
          ),
          findsOneWidget,
        );
        expect(operations.loads, contains('order:$orderA'));
      },
    );

    testWidgets('the dialog cannot be left while its action runs, and sends '
        'once', (WidgetTester tester) async {
      operations.details[orderA] = order(
        requests: <Object?>[cancellationRequestJson()],
      );
      operations.afterAction[orderA] = order(
        requests: <Object?>[cancellationRequestJson(status: 'rejected')],
      );
      await openOrder(tester);
      await tapAndSettle(tester, byKey('reject-request-$requestId'));
      final Completer<void> hold = Completer<void>();
      operations.hold = hold;

      await tester.tap(byKey('action-confirm'));
      await tester.pump();

      expect(
        tester.widget<FilledButton>(byKey('action-confirm')).onPressed,
        isNull,
      );
      expect(
        tester.widget<TextButton>(byKey('action-cancel')).onPressed,
        isNull,
      );
      await tester.tapAt(const Offset(4, 4));
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);

      operations.hold = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(operations.actions, hasLength(1));
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a note over 300 characters is refused before sending', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        requests: <Object?>[cancellationRequestJson()],
      );
      await openOrder(tester);

      await tapAndSettle(tester, byKey('reject-request-$requestId'));
      await tester.enterText(byKey('action-note'), 'a' * 301);
      await tapAndSettle(tester, byKey('action-confirm'));

      expect(find.text(l10n(tester).fieldTooLong(300)), findsOneWidget);
      expect(operations.actions, isEmpty);
    });

    testWidgets('while the order loads again, its buttons wait', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        requests: <Object?>[cancellationRequestJson()],
      );
      await openOrder(tester);
      final Completer<void> reload = Completer<void>();
      operations.holdOrder = reload;

      await tester.tap(byKey('order-refresh'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(byKey('approve-request-$requestId'))
            .onPressed,
        isNull,
      );

      operations.holdOrder = null;
      reload.complete();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(byKey('approve-request-$requestId'))
            .onPressed,
        isNotNull,
      );
    });
  });

  group('cancelling after a failed delivery', () {
    Map<String, Object?> failed() => courierAssignmentJson(
      acceptedAt: '2026-09-27T09:05:00Z',
      startedAt: '2026-09-27T09:30:00Z',
      endedAt: '2026-09-27T10:00:00Z',
      endedReason: 'delivery_failed',
      failedReason: 'no_answer',
    );

    testWidgets('is offered while the order is back, and confirmed first', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        status: 'ready_for_delivery',
        items: <Object?>[bought()],
        couriers: <Object?>[failed()],
      );
      operations.afterAction[orderA] = order(
        status: 'cancelled',
        items: <Object?>[bought()],
        totals: _none,
        couriers: <Object?>[failed()],
      );
      await openOrder(tester);

      await tapAndSettle(tester, byKey('cancel-failed-delivery'));
      expect(
        find.text(l10n(tester).cancelFailedDeliveryExplained),
        findsOneWidget,
      );
      await tapAndSettle(tester, byKey('action-confirm'));

      expect(operations.actions, <String>['cancel-failed:$orderA:null']);
      expect(byKey('cancel-failed-delivery'), findsNothing);
    });

    testWidgets('is not offered while a request is pending, or once a new '
        'Courier has it', (WidgetTester tester) async {
      operations.details[orderA] = order(
        status: 'ready_for_delivery',
        items: <Object?>[bought()],
        couriers: <Object?>[failed()],
        requests: <Object?>[cancellationRequestJson()],
      );
      await openOrder(tester);
      expect(byKey('cancel-failed-delivery'), findsNothing);
      expect(byKey('approve-request-$requestId'), findsOneWidget);

      operations.details[orderA] = order(
        status: 'delivery_assigned',
        items: <Object?>[bought()],
        couriers: <Object?>[
          failed(),
          courierAssignmentJson(id: '0192f0a0-0000-7000-8000-0000000000a8'),
        ],
      );
      await tapAndSettle(tester, byKey('order-refresh'));
      expect(byKey('cancel-failed-delivery'), findsNothing);
    });
  });

  group('the Admin\'s price correction', () {
    setUp(() {
      auth.identities[SessionSlot.staff] = user(role: UserRole.admin);
    });

    testWidgets('sends the new price and the reason, both required', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        status: 'ready_for_delivery',
        items: <Object?>[bought()],
      );
      operations.afterAction[orderA] = order(
        status: 'ready_for_delivery',
        items: <Object?>[
          itemJson(
            status: 'purchased',
            purchase: <String, Object?>{
              'actual_market_price_uzs': 17000,
              'billable_unit_price_uzs': 19550,
            },
          ),
        ],
      );
      await openOrder(tester);
      final AppLocalizations words = l10n(tester);

      await tapAndSettle(tester, byKey('correct-price-$itemId'));
      expect(find.text(words.correctPriceTitle('Pomidor')), findsOneWidget);
      await tapAndSettle(tester, byKey('correction-save'));
      expect(find.text(words.fieldRequired), findsNWidgets(2));
      expect(operations.actions, isEmpty);

      await tester.enterText(byKey('correction-price'), '17 000');
      await tester.enterText(byKey('correction-reason'), ' Chek bo\'yicha ');
      await tapAndSettle(tester, byKey('correction-save'));

      expect(operations.actions, <String>[
        'correct:$orderA:$itemId:17000:Chek bo\'yicha',
      ]);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        text(tester, 'order-item-paid-$itemId'),
        words.itemPricePaid(money(17000)),
      );
    });

    testWidgets('a price above the bound is refused with the bound, in the '
        'dialog', (WidgetTester tester) async {
      operations
        ..details[orderA] = order(
          status: 'ready_for_delivery',
          items: <Object?>[bought()],
        )
        ..actionFailure = const ApiRefusal(
          ApiError(
            status: 409,
            code: 'price_correction_above_ceiling',
            details: <String, Object?>{
              'ceiling_customer_unit_price_uzs': 20000,
              'proposed_customer_unit_price_uzs': 23000,
            },
          ),
        );
      await openOrder(tester);

      await tapAndSettle(tester, byKey('correct-price-$itemId'));
      await tester.enterText(byKey('correction-price'), '20000');
      await tester.enterText(byKey('correction-reason'), 'Chek');
      await tapAndSettle(tester, byKey('correction-save'));

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        text(tester, 'failure-message'),
        l10n(tester).errorPriceAboveCeiling(money(20000)),
      );
    });

    testWidgets('is offered only on a line billed from the price paid, while '
        'the rules allow', (WidgetTester tester) async {
      operations.details[orderA] = order(
        status: 'ready_for_delivery',
        items: <Object?>[bought(priceMode: 'fixed')],
      );
      await openOrder(tester);
      expect(byKey('correct-price-$itemId'), findsNothing);

      final List<BoardOrder> closed = <BoardOrder>[
        order(status: 'on_the_way', items: <Object?>[bought()]),
        order(
          status: 'ready_for_delivery',
          items: <Object?>[bought()],
          paymentMethod: 'online',
        ),
        order(items: <Object?>[itemJson()]),
      ];
      for (final BoardOrder shown in closed) {
        operations.details[orderA] = shown;
        await tapAndSettle(tester, byKey('order-refresh'));
        expect(byKey('correct-price-$itemId'), findsNothing);
      }

      // A fixed line bought as a replacement is billed from the price paid.
      operations.details[orderA] = order(
        status: 'ready_for_delivery',
        items: <Object?>[bought(priceMode: 'fixed', replaced: true)],
      );
      await tapAndSettle(tester, byKey('order-refresh'));
      expect(byKey('correct-price-$itemId'), findsOneWidget);
    });
  });

  testWidgets('the Operator is not offered the price correction', (
    WidgetTester tester,
  ) async {
    operations.details[orderA] = order(
      status: 'ready_for_delivery',
      items: <Object?>[bought()],
    );
    await openOrder(tester);

    expect(byKey('order-item-paid-$itemId'), findsOneWidget);
    expect(byKey('correct-price-$itemId'), findsNothing);
  });

  testWidgets('a phone-wide window with large text fits the page and its '
      'dialogs, in both languages', (WidgetTester tester) async {
    auth.identities[SessionSlot.staff] = user(role: UserRole.admin);
    operations.details[orderA] = order(
      status: 'ready_for_delivery',
      items: <Object?>[bought(replaced: true)],
      approvals: <Object?>[
        approvalJson(
          status: 'approved',
          resolution: 'approved',
          resolved: true,
        ),
      ],
      requests: <Object?>[cancellationRequestJson()],
      payment: paymentJson(),
    );
    for (final Locale language in const <Locale>[Locale('uz'), Locale('ru')]) {
      await openOrder(
        tester,
        size: const Size(360, 2400),
        textScale: 2,
        device: language,
      );
      expect(tester.takeException(), isNull);

      await tapAndSettle(tester, byKey('approve-request-$requestId'));
      expect(tester.takeException(), isNull);
      await tapAndSettle(tester, byKey('action-cancel'));

      await tapAndSettle(tester, byKey('correct-price-$itemId'));
      expect(tester.takeException(), isNull);
      await tapAndSettle(tester, byKey('action-cancel'));
    }
  });
}

const Map<String, Object?> _none = <String, Object?>{
  'merchandise_subtotal_uzs': null,
  'service_fee_uzs': null,
  'delivery_fee_uzs': null,
  'total_uzs': null,
  'total_kind': 'none',
};
