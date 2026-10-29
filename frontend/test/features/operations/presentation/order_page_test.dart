import 'dart:async';

import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/localization/order_labels.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/kit/kit_note.dart';
import 'package:baraka_bozor/core/widgets/panel/panel_card.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/operations/data/operations_api.dart';
import 'package:baraka_bozor/features/operations/domain/board.dart';
import 'package:baraka_bozor/features/operations/presentation/board_widgets.dart';
import 'package:baraka_bozor/features/operations/presentation/order_detail_screen.dart';
import 'package:baraka_bozor/features/operations/presentation/order_side.dart';
import 'package:baraka_bozor/features/operations/presentation/order_staff.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_operations_repository.dart';
import '../../../support/in_memory_stores.dart';
import '../../../support/operations_json.dart';

/// The order page of `DL-100` (4) through the real router, shell and
/// controllers: the path, the two columns and the cards of the side column.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeOperationsRepository operations;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  BuildContext anywhere(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).first);

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(anywhere(tester));

  BoardOrder order({
    String status = 'shopping',
    Map<String, Object?> timestamps = const <String, Object?>{},
    List<Object?>? assignments,
    List<Object?>? couriers,
    List<Object?>? requests,
    Map<String, Object?>? payment,
    Map<String, Object?>? rating,
    Map<String, Object?>? totals,
    bool erased = false,
  }) => OperationsApi.parseOrder(
    orderJson(
      status: status,
      timestamps: timestamps,
      assignments: assignments,
      courierAssignments: couriers,
      cancellationRequests: requests,
      payment: payment,
      rating: rating,
      totals: totals,
      erased: erased,
      history: <Object?>[],
    ),
  );

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.staff] = 's';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.staff] = user(role: UserRole.operator);
    operations = FakeOperationsRepository();
  });

  Future<void> openOrder(
    WidgetTester tester, {
    Size size = const Size(1440, 900),
    double textScale = 1,
    Locale device = const Locale('ru'),
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
        // The fixture's day, so its times read as clock times.
        clock: clock ?? () => DateTime.utc(2026, 9, 27, 10),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/operations/orders/$orderA');
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder inStep(int step, Finder matching) =>
      find.descendant(of: byKey('order-path-$step'), matching: matching);

  /// The circle of a step: its decoration.
  BoxDecoration dot(WidgetTester tester, int step) {
    final Finder circles = inStep(
      step,
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    return tester.widget<Container>(circles.first).decoration! as BoxDecoration;
  }

  bool done(WidgetTester tester, int step) =>
      dot(tester, step).color == KitColors.primary &&
      inStep(step, find.byIcon(Icons.check)).evaluate().isNotEmpty;

  bool current(WidgetTester tester, int step) {
    final BoxDecoration decoration = dot(tester, step);
    return decoration.color == Colors.white &&
        decoration.border!.top.color == KitColors.primary &&
        decoration.border!.top.width == 5;
  }

  bool ahead(WidgetTester tester, int step) {
    final BoxDecoration decoration = dot(tester, step);
    return decoration.color == Colors.white &&
        decoration.border!.top.color == KitColors.line &&
        decoration.border!.top.width == 3;
  }

  group('the path', () {
    testWidgets('marks the steps reached and the one under way', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(status: 'new');
      await openOrder(tester);
      final AppLocalizations words = l10n(tester);

      expect(byKey('order-path'), findsOneWidget);
      expect(current(tester, 0), isTrue);
      expect(
        inStep(0, find.text(words.orderPathWaiting('12:00'))),
        findsOneWidget,
      );
      expect(inStep(0, find.text(words.orderPathCreated)), findsOneWidget);
      for (final int step in <int>[1, 2, 3, 4]) {
        expect(ahead(tester, step), isTrue, reason: 'step $step');
        expect(inStep(step, find.text('—')), findsOneWidget);
      }

      operations.details[orderA] = order(
        timestamps: <String, Object?>{
          'shopping_started_at': '2026-09-27T07:41:00Z',
        },
      );
      await tapAndSettle(tester, byKey('order-refresh'));
      expect(done(tester, 0), isTrue);
      expect(inStep(0, find.text('12:00')), findsOneWidget);
      expect(current(tester, 1), isTrue);
      expect(
        inStep(1, find.text(words.orderPathRunning('12:41'))),
        findsOneWidget,
      );
      expect(ahead(tester, 2), isTrue);

      operations.details[orderA] = order(
        status: 'on_the_way',
        timestamps: <String, Object?>{
          'shopping_started_at': '2026-09-27T07:41:00Z',
          'ready_for_delivery_at': '2026-09-27T08:30:00Z',
          'on_the_way_at': '2026-09-27T09:00:00Z',
        },
      );
      await tapAndSettle(tester, byKey('order-refresh'));
      for (final int step in <int>[0, 1, 2]) {
        expect(done(tester, step), isTrue, reason: 'step $step');
      }
      expect(current(tester, 3), isTrue);
      expect(
        inStep(3, find.text(words.orderPathRunning('14:00'))),
        findsOneWidget,
      );
      expect(ahead(tester, 4), isTrue);

      operations.details[orderA] = order(
        status: 'completed',
        timestamps: <String, Object?>{
          'shopping_started_at': '2026-09-27T07:41:00Z',
          'ready_for_delivery_at': '2026-09-27T08:30:00Z',
          'on_the_way_at': '2026-09-27T09:00:00Z',
          'completed_at': '2026-09-27T09:40:00Z',
        },
      );
      await tapAndSettle(tester, byKey('order-refresh'));
      for (final int step in <int>[0, 1, 2, 3, 4]) {
        expect(done(tester, step), isTrue, reason: 'step $step');
      }
      expect(inStep(4, find.text('14:40')), findsOneWidget);
    });

    testWidgets('marks what was reached in uncommon states', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        status: 'final_payment_pending',
        timestamps: <String, Object?>{
          'shopping_started_at': '2026-09-27T07:41:00Z',
        },
      );
      await openOrder(tester);
      final AppLocalizations words = l10n(tester);

      expect(current(tester, 1), isTrue);
      expect(
        inStep(
          1,
          find.text(OrderLabels.status(words, OrderStatus.finalPaymentPending)),
        ),
        findsOneWidget,
      );
      expect(inStep(1, find.textContaining('12:41')), findsNothing);

      // Back at the market after a failed delivery: the server cleared the
      // moment the Courier set off.
      operations.details[orderA] = order(
        status: 'ready_for_delivery',
        timestamps: <String, Object?>{
          'shopping_started_at': '2026-09-27T07:41:00Z',
          'ready_for_delivery_at': '2026-09-27T08:30:00Z',
        },
      );
      await tapAndSettle(tester, byKey('order-refresh'));
      expect(done(tester, 1), isTrue);
      expect(current(tester, 2), isTrue);
      expect(
        inStep(2, find.text(words.orderPathWaiting('13:30'))),
        findsOneWidget,
      );
      expect(ahead(tester, 3), isTrue);

      // Cancelled before shopping: one step reached, then the red end.
      operations.details[orderA] = order(status: 'cancelled');
      await tapAndSettle(tester, byKey('order-refresh'));
      expect(done(tester, 0), isTrue);
      expect(
        inStep(1, find.text(OrderLabels.status(words, OrderStatus.cancelled))),
        findsOneWidget,
      );
      expect(inStep(1, find.text('13:00')), findsOneWidget);
      expect(dot(tester, 1).color, KitColors.danger);
      expect(byKey('order-path-2'), findsNothing);
      expect(byKey('order-path-4'), findsNothing);
    });
  });

  group('the layout', () {
    Finder itemsCard() => find.ancestor(
      of: byKey('order-item-$itemId'),
      matching: find.byType(PanelCard),
    );

    testWidgets('a wide order page has two columns', (
      WidgetTester tester,
    ) async {
      await openOrder(tester);

      expect(
        tester.getTopRight(itemsCard()).dx,
        lessThan(tester.getTopLeft(find.byType(ClientCard)).dx),
      );
      expect(tester.getSize(find.byType(ClientCard)).width, 372);
      expect(
        tester.getTopLeft(itemsCard()).dy,
        tester.getTopLeft(find.byType(ClientCard)).dy,
        reason: 'both columns start under the path',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a narrow order page has one', (WidgetTester tester) async {
      // A 1147 window leaves a page of 1099.
      await openOrder(tester, size: const Size(1147, 900));
      expect(
        tester.getTopLeft(find.byType(ClientCard)).dy,
        lessThan(tester.getTopLeft(itemsCard()).dy),
      );
      expect(
        tester.getTopLeft(find.byType(ClientCard)).dx,
        tester.getTopLeft(itemsCard()).dx,
      );
      expect(tester.takeException(), isNull);

      // One more pixel makes the page 1100: two columns.
      await openOrder(tester, size: const Size(1148, 900));
      expect(
        tester.getTopRight(itemsCard()).dx,
        lessThan(tester.getTopLeft(find.byType(ClientCard)).dx),
      );
      expect(OrderDetailScreen.twoColumns, 1100);

      await openOrder(tester, size: const Size(820, 1180));
      expect(
        tester.getTopLeft(find.byType(ClientCard)).dy,
        lessThan(tester.getTopLeft(itemsCard()).dy),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the Shopper and Courier cards stand side by side from a page '
        'of 640', (WidgetTester tester) async {
      // 688 less the 24 padding on both sides is 640.
      await openOrder(tester, size: const Size(688, 1400));
      expect(
        tester.getTopLeft(find.byType(ShopperCard)).dy,
        tester.getTopLeft(find.byType(CourierCard)).dy,
      );
      expect(
        tester.getTopLeft(find.byType(CourierCard)).dx,
        greaterThan(tester.getTopRight(find.byType(ShopperCard)).dx - 1),
      );

      await openOrder(tester, size: const Size(687, 1400));
      expect(
        tester.getTopLeft(find.byType(CourierCard)).dy,
        greaterThan(tester.getBottomLeft(find.byType(ShopperCard)).dy - 1),
      );
      expect(
        tester.getTopLeft(find.byType(CourierCard)).dx,
        tester.getTopLeft(find.byType(ShopperCard)).dx,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the header names the order, its status and when it was placed', (
    WidgetTester tester,
  ) async {
    await openOrder(tester);
    final AppLocalizations words = l10n(tester);

    final TextStyle title = tester
        .widget<Text>(find.text(words.orderTitle('1001')))
        .style!;
    expect(title.fontSize, 24);
    expect(title.fontWeight, FontWeight.w700);
    expect(find.byType(OrderStatusChip), findsOneWidget);
    expect(
      find.text(
        '${words.orderPlacedAt('27.09.2026 12:00')} · '
        '${words.paymentCash}',
      ),
      findsOneWidget,
    );

    expect(
      find.descendant(
        of: byKey('order-back'),
        matching: find.text(words.orderBackToBoard),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: byKey('order-back'),
        matching: find.byIcon(Icons.arrow_back),
      ),
      findsOneWidget,
    );
    // Drawn 40 high, tapped from 48 (DL-117).
    expect(tester.getSize(byKey('order-refresh')).height, 48);

    await tapAndSettle(tester, byKey('order-back'));
    expect(byKey('operations-board'), findsOneWidget);
  });

  PanelCard cardWith(WidgetTester tester, Finder inside) =>
      tester.widget<PanelCard>(
        find.ancestor(of: inside, matching: find.byType(PanelCard)).first,
      );

  group('the side column', () {
    testWidgets('a cancellation request waiting tops the side column, in '
        'amber', (WidgetTester tester) async {
      operations.details[orderA] = order(
        requests: <Object?>[cancellationRequestJson()],
      );
      await openOrder(tester);
      final AppLocalizations words = l10n(tester);

      final PanelCard card = cardWith(tester, byKey('request-$requestId'));
      expect(card.tone, KitTone.amber);
      expect(find.text(words.requestStatusPending), findsOneWidget);
      expect(byKey('approve-request-$requestId'), findsOneWidget);
      expect(byKey('reject-request-$requestId'), findsOneWidget);
      expect(
        tester.getTopLeft(byKey('request-$requestId')).dy,
        lessThan(tester.getTopLeft(find.byType(ClientCard)).dy),
      );
      expect(find.byType(RequestsCard), findsOneWidget);
    });

    testWidgets('no request, no section', (WidgetTester tester) async {
      await openOrder(tester);
      final AppLocalizations words = l10n(tester);

      expect(find.byType(RequestsCard), findsNothing);
      expect(find.text(words.orderSectionCancellationRequests), findsNothing);
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith('request-'),
        ),
        findsNothing,
      );
    });

    testWidgets('a low rating waits on top until it is reviewed', (
      WidgetTester tester,
    ) async {
      operations.details[orderA] = order(
        status: 'completed',
        requests: <Object?>[cancellationRequestJson(status: 'rejected')],
        rating: ratingJson(),
      );
      operations.afterAction[orderA] = order(
        status: 'completed',
        requests: <Object?>[cancellationRequestJson(status: 'rejected')],
        rating: ratingJson(reviewed: true),
      );
      await openOrder(tester);
      final AppLocalizations words = l10n(tester);

      expect(cardWith(tester, byKey('rating-stars')).tone, KitTone.amber);
      expect(
        tester.getTopLeft(byKey('rating-stars')).dy,
        greaterThan(tester.getTopLeft(byKey('request-$requestId')).dy),
        reason: 'under any request',
      );
      expect(
        tester
            .widgetList<Icon>(
              find.descendant(
                of: byKey('rating-stars'),
                matching: find.byType(Icon),
              ),
            )
            .where((Icon icon) => icon.color == KitColors.star),
        hasLength(2),
      );
      final TextStyle reason = tester
          .widget<Text>(
            find.text(OrderLabels.ratingReason(words, RatingReason.notFresh)),
          )
          .style!;
      expect(reason.color, KitColors.danger);
      expect(find.text('Kartoshka eski edi'), findsOneWidget);
      expect(tester.getSize(byKey('rating-review')).height, 44);

      await tapAndSettle(tester, byKey('rating-review'));

      expect(cardWith(tester, byKey('rating-stars')).tone, isNull);
      final TextStyle reviewed = tester
          .widget<Text>(byKey('rating-reviewed'))
          .style!;
      expect(reviewed.color, KitColors.primaryDark);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });

  testWidgets('the Courier card says when a Courier can be assigned', (
    WidgetTester tester,
  ) async {
    await openOrder(tester);
    final AppLocalizations words = l10n(tester);

    expect(find.text(words.courierAssignmentsNone), findsOneWidget);
    expect(find.text(words.orderCourierLater), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(words.orderCourierLater)).dy,
      greaterThan(
        tester.getTopLeft(find.text(words.courierAssignmentsNone)).dy,
      ),
    );
    expect(byKey('assign-courier'), findsNothing);
  });

  testWidgets('a recorded payment shows its rows', (WidgetTester tester) async {
    operations.details[orderA] = order(
      status: 'ready_for_delivery',
      payment: paymentJson(),
    );
    await openOrder(tester);
    final AppLocalizations words = l10n(tester);

    final Finder card = find.ancestor(
      of: byKey('payment'),
      matching: find.byType(PanelCard),
    );
    expect(
      find.descendant(of: card, matching: find.text(words.paymentCash)),
      findsOneWidget,
      reason: 'the method in the header',
    );
    final Finder tag = find.descendant(
      of: card,
      matching: find.text(words.paymentStatusPaid),
    );
    expect(tag, findsOneWidget);
    expect(tester.widget<Text>(tag).style!.color, KitColors.primaryDark);
    expect(
      find.text(words.paymentAmount(MoneyFormat.uzs(75200, AppLanguage.ru))),
      findsOneWidget,
    );
    expect(find.text(words.paymentPaidAt('27.09.2026 16:00')), findsOneWidget);
    expect(find.text(words.paymentRecordedBy('Kamol Karimov')), findsOneWidget);

    operations.details[orderA] = order(status: 'new');
    await tapAndSettle(tester, byKey('order-refresh'));
    expect(tester.widget<Text>(byKey('payment')).data, words.paymentNone);
  });

  testWidgets('an erased Customer reads so in the client card', (
    WidgetTester tester,
  ) async {
    operations.details[orderA] = order(erased: true);
    await openOrder(tester);
    final AppLocalizations words = l10n(tester);

    final Finder card = find.byType(ClientCard);
    final Finder erased = find.descendant(
      of: card,
      matching: find.text(words.orderCustomerErased),
    );
    expect(erased, findsOneWidget);
    final TextStyle style = tester.widget<Text>(erased).style!;
    expect(style.fontStyle, FontStyle.italic);
    expect(style.color, KitColors.muted);
    expect(
      find.descendant(of: card, matching: find.byIcon(Icons.person_off)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text(words.orderSectionAddress.toUpperCase()),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.text(words.orderNoDeliveryWish)),
      findsNothing,
    );
  });

  testWidgets('an assignment in flight shows on its button', (
    WidgetTester tester,
  ) async {
    operations.details[orderA] = order(status: 'new', assignments: <Object?>[]);
    operations.afterAssignment[orderA] = order(status: 'shopping_assigned');
    await openOrder(tester);
    final AppLocalizations words = l10n(tester);

    await tapAndSettle(tester, byKey('assign-shopper'));
    final Completer<void> hold = Completer<void>();
    operations.hold = hold;
    await tester.tap(byKey('pick-shopper-$shopperId'));
    await tester.pump();
    await tester.pump();

    expect(
      tester.widget<FilledButton>(byKey('assign-shopper')).onPressed,
      isNull,
    );
    expect(
      find.descendant(
        of: byKey('assign-shopper'),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: byKey('assign-shopper'),
        matching: find.text(words.assigningShopper),
      ),
      findsOneWidget,
    );

    operations.hold = null;
    hold.complete();
    await tester.pumpAndSettle();
    expect(byKey('assign-shopper'), findsNothing);
  });

  testWidgets('a failed delivery offers a new Courier or the end', (
    WidgetTester tester,
  ) async {
    operations.details[orderA] = order(
      status: 'ready_for_delivery',
      couriers: <Object?>[
        courierAssignmentJson(
          acceptedAt: '2026-09-27T09:05:00Z',
          startedAt: '2026-09-27T09:30:00Z',
          endedAt: '2026-09-27T10:00:00Z',
          endedReason: 'delivery_failed',
          failedReason: 'other',
          failedNote: 'Podyezd yopiq',
        ),
      ],
    );
    await openOrder(tester);

    expect(tester.widget<FilledButton>(byKey('assign-courier')), isNotNull);
    expect(
      tester.widget<OutlinedButton>(byKey('cancel-failed-delivery')),
      isNotNull,
    );
    expect(
      tester.getTopLeft(byKey('assign-courier')).dy,
      tester.getTopLeft(byKey('cancel-failed-delivery')).dy,
    );
    expect(
      tester.getTopLeft(byKey('cancel-failed-delivery')).dx,
      greaterThan(tester.getTopRight(byKey('assign-courier')).dx),
    );
    final OutlinedButton cancel = tester.widget<OutlinedButton>(
      byKey('cancel-failed-delivery'),
    );
    expect(
      cancel.style!.side!.resolve(<WidgetState>{})!.color,
      KitColors.danger,
    );
    expect(
      tester.widget<Text>(byKey('courier-failure-$courierAssignmentId')).data,
      endsWith(': Podyezd yopiq'),
    );
    expect(
      cardWith(tester, byKey('assign-courier')).tone,
      KitTone.red,
      reason: 'the card is outlined in red',
    );
  });

  for (final Locale language in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'the order page holds at the extremes (${language.languageCode})',
      (WidgetTester tester) async {
        final Map<String, Object?> json = orderJson(
          status: 'ready_for_delivery',
          totals: <String, Object?>{
            'merchandise_subtotal_uzs': 99999999,
            'service_fee_uzs': 99999999,
            'delivery_fee_uzs': 99999999,
            'total_uzs': 99999999,
            'total_kind': 'estimate',
          },
          courierAssignments: <Object?>[
            courierAssignmentJson(
              acceptedAt: '2026-09-27T09:05:00Z',
              startedAt: '2026-09-27T09:30:00Z',
              endedAt: '2026-09-27T10:00:00Z',
              endedReason: 'delivery_failed',
              failedReason: 'other',
              failedNote: 'q' * 300,
            ),
          ],
          cancellationRequests: <Object?>[cancellationRequestJson()],
          payment: paymentJson(),
          rating: ratingJson(),
          history: <Object?>[],
        );
        json['delivery_time_note'] = 'w' * 160;
        (json['customer']! as Map<String, Object?>)['full_name'] =
            'Abdurahmonov-Karimjonov Muhammadsodiqbekzoda Shahzodabegim';
        (json['address']! as Map<String, Object?>)['landmark'] = 'l' * 255;
        operations.details[orderA] = OperationsApi.parseOrder(json);

        await openOrder(
          tester,
          size: const Size(820, 1180),
          textScale: 2,
          device: language,
        );

        expect(byKey('order-detail'), findsOneWidget);
        expect(find.byType(ClientCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('the order page: every target meets iOSTapTargetGuideline', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await openOrder(tester);

    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });
}
