import 'dart:async';

import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/operations/application/board_controllers.dart';
import 'package:baraka_bozor/features/operations/data/operations_api.dart';
import 'package:baraka_bozor/features/operations/domain/board.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/drawn_size.dart';
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
    Map<String, Object?>? rating,
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
      rating: rating,
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
    DateTime Function()? clock,
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
        // The fixtures' day, so their times read as clock times.
        clock: clock ?? () => DateTime.utc(2026, 9, 27, 10),
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

  group('lines, questions and history in the kit style', () {
    TextStyle? styleOf(WidgetTester tester, String key, String data) => tester
        .widget<Text>(
          find.descendant(of: byKey(key), matching: find.text(data)),
        )
        .style;

    BoxDecoration decorationOf(WidgetTester tester, String key) =>
        tester.widget<DecoratedBox>(byKey(key)).decoration as BoxDecoration;

    testWidgets('each line shows its status beside its name', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        items: <Object?>[
          itemJson(id: '0192f0a0-0000-7000-8000-500000000001'),
          itemJson(
            id: '0192f0a0-0000-7000-8000-500000000002',
            status: 'purchased',
          ),
          itemJson(
            id: '0192f0a0-0000-7000-8000-500000000003',
            status: 'awaiting_customer',
          ),
          itemJson(
            id: '0192f0a0-0000-7000-8000-500000000004',
            status: 'removed',
            removedReason: 'unavailable',
          ),
        ],
      );
      await openOrder(tester, size: const Size(2200, 3200));
      final AppLocalizations words = l10n(tester);

      final TextStyle? name = styleOf(
        tester,
        'order-item-0192f0a0-0000-7000-8000-500000000001',
        'Pomidor',
      );
      expect(name?.fontSize, 13);
      expect(name?.fontWeight, FontWeight.w600);
      for (final (String id, Color ground) in <(String, Color)>[
        ('0192f0a0-0000-7000-8000-500000000001', KitColors.line),
        ('0192f0a0-0000-7000-8000-500000000002', KitColors.primaryWash),
        ('0192f0a0-0000-7000-8000-500000000003', KitColors.warningWash),
        ('0192f0a0-0000-7000-8000-500000000004', KitColors.dangerWash),
      ]) {
        expect(tester.getSize(byKey('order-item-status-$id')).height, 22);
        expect(decorationOf(tester, 'order-item-status-$id').color, ground);
      }
      expect(
        tester
            .getTopLeft(
              byKey('order-item-status-0192f0a0-0000-7000-8000-500000000001'),
            )
            .dx,
        greaterThan(
          tester
              .getTopRight(
                find.descendant(
                  of: byKey('order-item-0192f0a0-0000-7000-8000-500000000001'),
                  matching: find.text('Pomidor'),
                ),
              )
              .dx,
        ),
      );
      expect(
        find.descendant(
          of: byKey('order-item-0192f0a0-0000-7000-8000-500000000001'),
          matching: find.byIcon(Icons.swap_horiz),
        ),
        findsOneWidget,
      );
      expect(
        decorationOf(
          tester,
          'order-item-note-0192f0a0-0000-7000-8000-500000000001',
        ).color,
        KitColors.field,
      );
      expect(find.text(words.itemNote('Qizilini oling')), findsNWidgets(4));
    });

    testWidgets('a bought line shows what was bought and billed', (
      WidgetTester tester,
    ) async {
      auth.identities[SessionSlot.staff] = user(role: UserRole.admin);
      operations.details[orderA] = order(
        status: 'ready_for_delivery',
        items: <Object?>[bought()],
      );
      await openOrder(tester);
      final AppLocalizations words = l10n(tester);

      final TextStyle boughtStyle = tester
          .widget<Text>(byKey('order-item-bought-$itemId'))
          .style!;
      expect(boughtStyle.fontSize, 12);
      expect(boughtStyle.color, KitColors.muted);
      expect(
        tester.widget<Text>(byKey('order-item-paid-$itemId')).style!.color,
        KitColors.muted,
      );
      expect(
        tester
            .widget<Text>(find.text(words.itemBilledPrice(money(18400))))
            .style
            ?.fontSize,
        13,
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: byKey('order-line-$itemId'),
                matching: find.text(money(55200)),
              ),
            )
            .style
            ?.fontWeight,
        FontWeight.w700,
      );
      final TextButton fix = tester.widget<TextButton>(
        byKey('correct-price-$itemId'),
      );
      expect(
        fix.style?.foregroundColor?.resolve(<WidgetState>{}),
        KitColors.primaryDark,
      );
      expect(
        find.descendant(
          of: byKey('correct-price-$itemId'),
          matching: find.byIcon(Icons.edit),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a waiting line shows the estimate and why it is late', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        items: <Object?>[itemJson(status: 'awaiting_customer')],
        approvals: <Object?>[approvalJson(status: 'expired')],
      );
      await openOrder(tester);
      final AppLocalizations words = l10n(tester);

      expect(find.text('≈ ${money(18400)}/${words.unitKg}'), findsOneWidget);
      expect(find.text(words.itemMarketPrice(money(16000))), findsOneWidget);
      expect(find.text('≈ ${money(55200)}'), findsOneWidget);
      expect(
        decorationOf(tester, 'order-line-$itemId').color,
        KitColors.warningWash,
      );
      expect(
        tester.widget<Text>(find.text(words.itemExpiredHint)).style?.color,
        KitColors.danger,
      );

      operations.details[orderA] = order(
        items: <Object?>[itemJson(status: 'awaiting_customer')],
        approvals: <Object?>[approvalJson()],
      );
      await tapAndSettle(tester, byKey('order-refresh'));
      expect(find.text(words.itemExpiredHint), findsNothing);
    });

    testWidgets('a removed line is struck through with why', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        items: <Object?>[
          itemJson(status: 'removed', removedReason: 'unavailable'),
        ],
      );
      await openOrder(tester);
      final AppLocalizations words = l10n(tester);

      expect(
        styleOf(tester, 'order-item-$itemId', 'Pomidor')?.decoration,
        TextDecoration.lineThrough,
      );
      expect(find.textContaining(words.itemRemovedBecause('')), findsOneWidget);
      expect(
        find.descendant(
          of: byKey('order-line-$itemId'),
          matching: find.text('—'),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('the markup shows once when every line shares it', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        items: <Object?>[
          itemJson(),
          itemJson(id: '0192f0a0-0000-7000-8000-500000000005'),
        ],
      );
      await openOrder(tester);

      expect(find.text(l10n(tester).itemMarkup('15')), findsOneWidget);
    });

    testWidgets('the markup shows per line when they differ', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        items: <Object?>[
          itemJson(),
          itemJson(
            id: '0192f0a0-0000-7000-8000-500000000005',
            purchase: <String, Object?>{'markup_percent': '10.00'},
          ),
        ],
      );
      await openOrder(tester);
      final AppLocalizations words = l10n(tester);

      expect(find.text(words.itemMarkup('15')), findsOneWidget);
      expect(find.text(words.itemMarkup('10')), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(words.itemMarkup('15'))).dy,
        greaterThan(
          tester
              .getBottomLeft(find.text(words.itemColumnPrice.toUpperCase()))
              .dy,
        ),
        reason: 'it is in the table, not in the card header',
      );
    });

    testWidgets('questions take the tone of their state', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        approvals: <Object?>[
          approvalJson(
            status: 'approved',
            resolution: 'approved',
            resolved: true,
          ),
          approvalJson(id: secondApproval, status: 'expired'),
          approvalJson(id: '0192f0a0-0000-7000-8000-500000000006'),
        ],
      );
      await openOrder(tester);

      BoxDecoration box(String id) =>
          tester.widget<Container>(byKey('approval-$id')).decoration!
              as BoxDecoration;

      expect(
        box('0192f0a0-0000-7000-8000-500000000006').color,
        KitColors.warningWash,
      );
      expect(
        (box('0192f0a0-0000-7000-8000-500000000006').border! as Border)
            .top
            .color,
        KitColors.warning,
      );
      expect(
        (box('0192f0a0-0000-7000-8000-500000000006').border! as Border)
            .top
            .width,
        1.5,
      );
      expect(
        byKey('approval-timers-0192f0a0-0000-7000-8000-500000000006'),
        findsOneWidget,
      );
      expect(box(secondApproval).color, KitColors.dangerWash);
      expect(
        (box(secondApproval).border! as Border).top.color,
        KitColors.danger,
      );
      expect(
        tester.getSize(byKey('remove-expired-$secondApproval')).height,
        // Drawn 36 high, tapped from 48 (DL-117).
        48,
      );
      expect(
        drawnSize(tester, byKey('remove-expired-$secondApproval')).height,
        36,
      );
      expect(box(approvalId).color, Colors.white);
      expect(
        tester.widget<Text>(byKey('approval-status-$approvalId')).style!.color,
        KitColors.primaryDark,
      );
      expect(
        tester
            .getTopLeft(byKey('approval-0192f0a0-0000-7000-8000-500000000006'))
            .dy,
        lessThan(tester.getTopLeft(byKey('approval-$secondApproval')).dy),
        reason: 'the newest first',
      );
    });

    for (final Locale locale in const <Locale>[Locale('uz'), Locale('ru')]) {
      testWidgets('lines, questions and history hold at 820x1180 with text x2 '
          '(${locale.languageCode})', (WidgetTester tester) async {
        auth.identities[SessionSlot.staff] = user(role: UserRole.admin);
        operations.details[orderA] = order(
          items: <Object?>[
            bought(replaced: true),
            itemJson(
              id: '0192f0a0-0000-7000-8000-500000000009',
              status: 'awaiting_customer',
            ),
          ],
          approvals: <Object?>[
            approvalJson(status: 'expired'),
            approvalJson(id: secondApproval),
          ],
          history: <Object?>[
            for (int index = 0; index < 10; index++)
              <String, Object?>{
                ...historyJson(event: 'item_purchased', details: null),
                'id':
                    '0192f0a0-0000-7000-8000-7${index.toString().padLeft(11, '0')}',
              },
          ],
        );
        await openOrder(
          tester,
          size: const Size(820, 1180),
          textScale: 2,
          device: locale,
        );
        expect(tester.takeException(), isNull);
        await tapAndSettle(tester, byKey('history-fold'));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('no questions says so', (WidgetTester tester) async {
      await openOrder(tester);

      expect(find.text(l10n(tester).approvalsNone), findsOneWidget);
    });

    testWidgets('the history shows eight entries and folds the rest', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        history: <Object?>[
          for (int index = 0; index < 13; index++)
            <String, Object?>{
              ...historyJson(
                event: switch (index) {
                  12 => 'approval_expired',
                  11 => 'item_purchased',
                  _ => 'status_changed',
                },
                details: null,
              ),
              'id':
                  '0192f0a0-0000-7000-8000-7${index.toString().padLeft(11, '0')}',
            },
        ],
      );
      await openOrder(tester);
      final AppLocalizations words = l10n(tester);

      expect(
        byKey('history-0192f0a0-0000-7000-8000-700000000012'),
        findsOneWidget,
      );
      expect(
        byKey('history-0192f0a0-0000-7000-8000-700000000005'),
        findsOneWidget,
      );
      expect(
        byKey('history-0192f0a0-0000-7000-8000-700000000004'),
        findsNothing,
      );
      expect(find.text(words.historyShowAll(13)), findsOneWidget);
      // Drawn 38 high, tapped from 48 (DL-117).
      expect(tester.getSize(byKey('history-fold')).height, 48);
      expect(drawnSize(tester, byKey('history-fold')).height, 38);
      Color dot(String id) =>
          (decorationOf(tester, 'history-dot-$id').border! as Border).top.color;
      expect(dot('0192f0a0-0000-7000-8000-700000000012'), KitColors.danger);
      expect(
        dot('0192f0a0-0000-7000-8000-700000000011'),
        KitColors.primaryDark,
      );
      expect(dot('0192f0a0-0000-7000-8000-700000000010'), KitColors.muted);
      final TextStyle? time = styleOf(
        tester,
        'history-0192f0a0-0000-7000-8000-700000000012',
        '12:05',
      );
      expect(time?.fontSize, 12);
      expect(time?.fontWeight, FontWeight.w600);

      await tapAndSettle(tester, byKey('history-fold'));
      expect(
        byKey('history-0192f0a0-0000-7000-8000-700000000000'),
        findsOneWidget,
      );
      expect(find.text(words.historyShowFewer), findsOneWidget);

      await tapAndSettle(tester, byKey('history-fold'));
      expect(
        byKey('history-0192f0a0-0000-7000-8000-700000000000'),
        findsNothing,
      );
    });
  });

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

      // Quantities as a person reads them: `3.000` is `3`.
      expect(
        text(tester, 'order-item-bought-$itemId'),
        words.itemBought('3 ${words.unitKg}'),
      );
      expect(find.text(words.itemBilled('3 ${words.unitKg}')), findsOneWidget);
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
          // A quantity as a person reads it: `2.000` is `2`.
          words.approvalProposedQuantity('2 ${words.unitKg}'),
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
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith('request-'),
        ),
        findsNothing,
        reason: 'no request, no section',
      );
      expect(find.text(words.orderSectionCancellationRequests), findsNothing);
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
      expect(byKey('order-action'), findsNothing);
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

        expect(byKey('order-action'), findsOneWidget);
        expect(
          find.descendant(
            of: byKey('order-action'),
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
        tester.widget<OutlinedButton>(byKey('action-cancel')).onPressed,
        isNull,
      );
      await tester.tap(byKey('order-action-close'));
      await tester.pump();
      expect(byKey('order-action'), findsOneWidget, reason: 'the × holds');
      await tester.tapAt(const Offset(4, 4));
      await tester.pump();
      expect(byKey('order-action'), findsOneWidget, reason: 'the scrim holds');
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(byKey('order-action'), findsOneWidget, reason: 'back holds');

      operations.hold = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(operations.actions, hasLength(1));
      expect(byKey('order-action'), findsNothing);
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

      // Exactly the limit is sent.
      operations.afterAction[orderA] = order(
        requests: <Object?>[cancellationRequestJson(status: 'rejected')],
      );
      await tester.enterText(byKey('action-note'), 'a' * 300);
      await tapAndSettle(tester, byKey('action-confirm'));
      expect(operations.actions, <String>[
        'decide:$orderA:$requestId:reject:${'a' * 300}',
      ]);
    });

    testWidgets(
      'an action loads again the order and whatever shows the board',
      (WidgetTester tester) async {
        operations.details[orderA] = order(
          requests: <Object?>[cancellationRequestJson()],
        );
        operations.afterAction[orderA] = order(
          requests: <Object?>[cancellationRequestJson(status: 'rejected')],
        );
        await openOrder(tester);
        // The board is not on the order's page; something that still shows
        // it, as a wider layout might, keeps it alive here.
        final ProviderContainer container = ProviderScope.containerOf(
          anywhere(tester),
        );
        final List<ProviderSubscription<Object?>> shown =
            <ProviderSubscription<Object?>>[
              container.listen(boardPageProvider, (_, _) {}),
              container.listen(boardSummaryProvider, (_, _) {}),
              container.listen(attentionProvider, (_, _) {}),
            ];
        addTearDown(() {
          for (final ProviderSubscription<Object?> subscription in shown) {
            subscription.close();
          }
        });
        await tester.pumpAndSettle();
        operations.loads.clear();

        await tapAndSettle(tester, byKey('reject-request-$requestId'));
        await tapAndSettle(tester, byKey('action-confirm'));

        expect(
          operations.loads,
          containsAll(<String>[
            'order:$orderA',
            'orders',
            'summary',
            'attention',
          ]),
        );
      },
    );
  });

  testWidgets('while the order loads again, every action button waits', (
    WidgetTester tester,
  ) async {
    const String boughtLine = '0192f0a0-0000-7000-8000-0000000000f4';
    auth.identities[SessionSlot.staff] = user(role: UserRole.admin);
    operations.details[orderA] = order(
      items: <Object?>[
        itemJson(status: 'awaiting_customer'),
        itemJson(id: boughtLine, status: 'purchased'),
      ],
      approvals: <Object?>[approvalJson(status: 'expired')],
      requests: <Object?>[cancellationRequestJson()],
    );
    await openOrder(tester);

    VoidCallback? pressed(String key) =>
        tester.widget<ButtonStyleButton>(byKey(key)).onPressed;
    Future<void> checkWhileReloading(List<String> buttons) async {
      for (final String button in buttons) {
        expect(pressed(button), isNotNull, reason: button);
      }
      final Completer<void> reload = Completer<void>();
      operations.holdOrder = reload;
      await tester.tap(byKey('order-refresh'));
      await tester.pump();
      for (final String button in buttons) {
        expect(pressed(button), isNull, reason: button);
      }
      operations.holdOrder = null;
      reload.complete();
      await tester.pumpAndSettle();
      for (final String button in buttons) {
        expect(pressed(button), isNotNull, reason: button);
      }
    }

    await checkWhileReloading(<String>[
      'remove-expired-$approvalId',
      'approve-request-$requestId',
      'reject-request-$requestId',
      'correct-price-$boughtLine',
    ]);

    operations.details[orderA] = order(
      status: 'ready_for_delivery',
      items: <Object?>[bought()],
      couriers: <Object?>[
        courierAssignmentJson(
          acceptedAt: '2026-09-27T09:05:00Z',
          startedAt: '2026-09-27T09:30:00Z',
          endedAt: '2026-09-27T10:00:00Z',
          endedReason: 'delivery_failed',
          failedReason: 'refused',
        ),
      ],
    );
    await tapAndSettle(tester, byKey('order-refresh'));
    await checkWhileReloading(<String>['cancel-failed-delivery']);
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

  group('the Customer\'s rating', () {
    int filledStars(WidgetTester tester) => tester
        .widgetList<Icon>(
          find.descendant(
            of: byKey('rating-stars'),
            matching: find.byType(Icon),
          ),
        )
        .where((Icon icon) => icon.color == KitColors.star)
        .length;

    testWidgets('is shown with a review button until it is reviewed', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        status: 'completed',
        items: <Object?>[bought()],
        rating: ratingJson(),
      );
      operations.afterAction[orderA] = order(
        status: 'completed',
        items: <Object?>[bought()],
        rating: ratingJson(reviewed: true),
      );
      await openOrder(tester, device: const Locale('ru'));

      expect(find.text('Оценка клиента'), findsOneWidget);
      expect(filledStars(tester), 2);
      expect(find.text('Несвежее'), findsOneWidget);
      expect(find.text('Kartoshka eski edi'), findsOneWidget);
      expect(find.text('Связались с клиентом'), findsOneWidget);

      await tapAndSettle(tester, byKey('rating-review'));

      expect(operations.actions, <String>['review-rating:$orderA']);
      expect(byKey('rating-review'), findsNothing);
      expect(find.textContaining('Разобрано: Olim, '), findsOneWidget);
    });

    testWidgets('a 5-star rating nobody reviewed has no review button', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        status: 'completed',
        items: <Object?>[bought()],
        rating: ratingJson(stars: 5, reasons: const <Object?>[], comment: null),
      );
      await openOrder(tester, device: const Locale('ru'));

      expect(filledStars(tester), 5);
      expect(byKey('rating-review'), findsNothing);
      expect(byKey('rating-reviewed'), findsNothing);
    });

    testWidgets('a 3-star rating nobody reviewed has the review button', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        status: 'completed',
        items: <Object?>[bought()],
        rating: ratingJson(stars: 3),
      );
      await openOrder(tester, device: const Locale('ru'));

      expect(filledStars(tester), 3);
      expect(byKey('rating-review'), findsOneWidget);
    });

    testWidgets('a reviewed rating has no button', (WidgetTester tester) async {
      operations.details[orderA] = order(
        status: 'completed',
        items: <Object?>[bought()],
        rating: ratingJson(reviewed: true),
      );
      await openOrder(tester, device: const Locale('ru'));

      expect(byKey('rating-stars'), findsOneWidget);
      expect(byKey('rating-review'), findsNothing);
      expect(find.textContaining('Разобрано: Olim, '), findsOneWidget);
    });

    testWidgets('an order without a rating has no section', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        status: 'completed',
        items: <Object?>[bought()],
      );
      await openOrder(tester, device: const Locale('ru'));

      expect(find.text('Оценка клиента'), findsNothing);
      expect(byKey('rating-review'), findsNothing);
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
      expect(byKey('price-correction'), findsNothing);
      expect(
        text(tester, 'order-item-paid-$itemId'),
        words.itemPricePaid(money(17000)),
      );
    });

    testWidgets('the correction cannot be left while it runs, and sends once', (
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
            purchase: <String, Object?>{'actual_market_price_uzs': 17000},
          ),
        ],
      );
      await openOrder(tester);
      await tapAndSettle(tester, byKey('correct-price-$itemId'));
      await tester.enterText(byKey('correction-price'), '17000');
      await tester.enterText(byKey('correction-reason'), 'Chek');
      final Completer<void> hold = Completer<void>();
      operations.hold = hold;

      await tester.tap(byKey('correction-save'));
      await tester.pump();

      expect(
        tester.widget<FilledButton>(byKey('correction-save')).onPressed,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(byKey('action-cancel')).onPressed,
        isNull,
      );
      await tester.tap(byKey('price-correction-close'));
      await tester.pump();
      expect(byKey('price-correction'), findsOneWidget, reason: 'the × holds');
      await tester.tapAt(const Offset(4, 4));
      await tester.pump();
      expect(
        byKey('price-correction'),
        findsOneWidget,
        reason: 'the scrim holds',
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(byKey('price-correction'), findsOneWidget, reason: 'back holds');

      operations.hold = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(operations.actions, hasLength(1));
      expect(byKey('price-correction'), findsNothing);
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

      expect(byKey('price-correction'), findsOneWidget);
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

  testWidgets('an erased order says so and offers no phone and no address', (
    WidgetTester tester,
  ) async {
    operations.details[orderA] = OperationsApi.parseOrder(
      orderJson(erased: true),
    );
    await openOrder(tester, device: const Locale('ru'));

    expect(find.text('Данные покупателя удалены'), findsOneWidget);
    // The shell's user card shares the Customer's name in this fixture, so
    // the absence is checked on the order page itself.
    Finder onPage(Finder matching) => find.descendant(
      of: find.byKey(const ValueKey<String>('order-detail')),
      matching: matching,
    );
    expect(onPage(find.text('Aziza Karimova')), findsNothing);
    expect(onPage(find.textContaining('901112233')), findsNothing);
    expect(onPage(find.textContaining('Amir Temur')), findsNothing);
    expect(onPage(find.text(l10n(tester).orderSectionAddress)), findsNothing);
  });

  testWidgets('an erased request shows no reason, only that the data is gone', (
    WidgetTester tester,
  ) async {
    operations.details[orderA] = OperationsApi.parseOrder(
      orderJson(
        erased: true,
        status: 'cancelled',
        history: <Object?>[],
        cancellationRequests: <Object?>[
          cancellationRequestJson(status: 'approved', erased: true),
        ],
      ),
    );
    await openOrder(tester, device: const Locale('ru'));

    expect(byKey('request-status-$requestId'), findsOneWidget);
    expect(find.textContaining('Причина'), findsNothing);
    expect(find.text('Данные покупателя удалены'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  group('the kit\'s action windows', () {
    Color? confirmColor(WidgetTester tester, String key) => tester
        .widget<FilledButton>(byKey(key))
        .style!
        .backgroundColor!
        .resolve(<WidgetState>{});

    Color? boxColorOf(WidgetTester tester, Finder inner) {
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.ancestor(of: inner, matching: find.byType(DecoratedBox)).first,
      );
      return (box.decoration as BoxDecoration).color;
    }

    Map<String, Object?> failed() => courierAssignmentJson(
      acceptedAt: '2026-09-27T09:05:00Z',
      startedAt: '2026-09-27T09:30:00Z',
      endedAt: '2026-09-27T10:00:00Z',
      endedReason: 'delivery_failed',
      failedReason: 'no_answer',
    );

    testWidgets('a confirming window names the order', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        approvals: <Object?>[approvalJson(status: 'expired')],
      );
      await openOrder(tester);
      final AppLocalizations words = l10n(tester);

      await tapAndSettle(tester, byKey('remove-expired-$approvalId'));

      expect(byKey('order-action'), findsOneWidget);
      expect(find.text(words.removeExpiredTitle('Pomidor')), findsOneWidget);
      expect(
        find.text(words.dialogOrderLine('1001', 'Aziza Karimova')),
        findsOneWidget,
      );
      expect(find.text(words.removeExpiredExplained), findsOneWidget);
      expect(find.text(words.actionNote), findsOneWidget);
      expect(find.text('0 / 300'), findsOneWidget);
      await tester.enterText(byKey('action-note'), 'abcd');
      await tester.pump();
      expect(find.text('4 / 300'), findsOneWidget);
      expect(tester.getSize(byKey('action-cancel')).height, 48);
      expect(tester.getSize(byKey('action-confirm')).height, 48);
      expect(
        tester.widget<OutlinedButton>(byKey('action-cancel')).onPressed,
        isNotNull,
      );
      expect(confirmColor(tester, 'action-confirm'), KitColors.danger);
      expect(
        find.descendant(
          of: byKey('action-confirm'),
          matching: find.byIcon(Icons.remove_shopping_cart),
        ),
        findsOneWidget,
      );
    });

    testWidgets('an erased Customer leaves the order number alone', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = OperationsApi.parseOrder(
        orderJson(
          status: 'shopping',
          approvals: <Object?>[approvalJson(status: 'expired')],
          history: <Object?>[],
          erased: true,
        ),
      );
      await openOrder(tester);

      await tapAndSettle(tester, byKey('remove-expired-$approvalId'));

      expect(find.text(l10n(tester).orderTitle('1001')), findsWidgets);
      expect(
        find.descendant(
          of: byKey('order-action'),
          matching: find.text(l10n(tester).orderTitle('1001')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: byKey('order-action'),
          matching: find.textContaining('Aziza'),
        ),
        findsNothing,
      );
    });

    testWidgets('a cancellation decision shows the Customer\'s reason', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        requests: <Object?>[cancellationRequestJson()],
      );
      await openOrder(tester);
      final AppLocalizations words = l10n(tester);
      final String reason = words.requestCustomerReason('Rejalar o\'zgardi');

      await tapAndSettle(tester, byKey('approve-request-$requestId'));
      expect(find.text(words.approveRequestTitle), findsWidgets);
      expect(find.text(reason), findsOneWidget);
      expect(boxColorOf(tester, find.text(reason)), KitColors.field);
      expect(find.text(words.approveRequestExplained), findsOneWidget);
      expect(confirmColor(tester, 'action-confirm'), KitColors.danger);
      await tapAndSettle(tester, byKey('action-cancel'));

      await tapAndSettle(tester, byKey('reject-request-$requestId'));
      expect(find.text(words.rejectRequestTitle), findsWidgets);
      expect(find.text(reason), findsOneWidget);
      expect(confirmColor(tester, 'action-confirm'), KitColors.primary);
    });

    testWidgets('a request without a reason shows no box', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        requests: <Object?>[cancellationRequestJson(erased: true)],
      );
      await openOrder(tester);

      await tapAndSettle(tester, byKey('approve-request-$requestId'));

      expect(find.textContaining('Mijoz sababi'), findsNothing);
      expect(byKey('order-action'), findsOneWidget);
    });

    testWidgets('cancelling after a failed delivery is red', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        status: 'ready_for_delivery',
        items: <Object?>[bought()],
        couriers: <Object?>[failed()],
      );
      await openOrder(tester);

      await tapAndSettle(tester, byKey('cancel-failed-delivery'));

      expect(find.text(l10n(tester).cancelFailedDeliveryTitle), findsOneWidget);
      expect(confirmColor(tester, 'action-confirm'), KitColors.danger);
    });

    testWidgets('the correction shows the prices and refuses over the bound', (
      WidgetTester tester,
    ) async {
      auth.identities[SessionSlot.staff] = user(role: UserRole.admin);
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
            },
          ),
        );
      await openOrder(tester);
      final AppLocalizations words = l10n(tester);

      await tapAndSettle(tester, byKey('correct-price-$itemId'));

      expect(find.text(words.correctPriceTitle('Pomidor')), findsOneWidget);
      expect(
        find.descendant(
          of: byKey('price-correction'),
          matching: find.text(words.itemBilledPrice(money(18400))),
        ),
        findsOneWidget,
      );
      expect(
        boxColorOf(
          tester,
          find.descendant(
            of: byKey('price-correction'),
            matching: find.text(words.itemBilledPrice(money(18400))),
          ),
        ),
        KitColors.field,
      );
      expect(confirmColor(tester, 'correction-save'), KitColors.primary);
      expect(find.byIcon(Icons.error), findsNothing);

      await tester.enterText(byKey('correction-price'), '20000');
      await tester.enterText(byKey('correction-reason'), 'Chek');
      await tapAndSettle(tester, byKey('correction-save'));

      expect(
        tester.widget<Text>(byKey('failure-message')).style?.color,
        KitColors.danger,
      );
      expect(find.byIcon(Icons.error), findsOneWidget);
      final InputDecorator price = tester.widget<InputDecorator>(
        find.descendant(
          of: byKey('correction-price'),
          matching: find.byType(InputDecorator),
        ),
      );
      expect(
        (price.decoration.enabledBorder! as OutlineInputBorder)
            .borderSide
            .color,
        KitColors.danger,
      );
    });

    testWidgets('a running action holds its dialog, × included', (
      WidgetTester tester,
    ) async {
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
        tester.widget<OutlinedButton>(byKey('action-cancel')).onPressed,
        isNull,
      );
      await tester.tap(byKey('order-action-close'));
      await tester.pump();
      expect(byKey('order-action'), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await tester.pump();
      expect(byKey('order-action'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(byKey('order-action'), findsOneWidget);

      operations.hold = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(byKey('order-action'), findsNothing);
    });

    for (final Locale locale in const <Locale>[Locale('uz'), Locale('ru')]) {
      testWidgets(
        'the windows hold at 820x1180 with text x2 (${locale.languageCode})',
        (WidgetTester tester) async {
          auth.identities[SessionSlot.staff] = user(role: UserRole.admin);
          operations.details[orderA] = order(
            status: 'ready_for_delivery',
            items: <Object?>[bought()],
            requests: <Object?>[cancellationRequestJson()],
          );
          await openOrder(
            tester,
            size: const Size(820, 1180),
            textScale: 2,
            device: locale,
          );

          await tapAndSettle(tester, byKey('approve-request-$requestId'));
          expect(byKey('order-action'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tapAndSettle(tester, byKey('action-cancel'));

          await tapAndSettle(tester, byKey('correct-price-$itemId'));
          expect(byKey('price-correction'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
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
