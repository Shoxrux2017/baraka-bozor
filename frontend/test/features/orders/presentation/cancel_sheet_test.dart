import 'dart:async';

import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/localization/failure_text.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/orders/presentation/cancel_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_cart_repository.dart';
import '../../../support/fake_customer_orders_repository.dart';
import '../../../support/in_memory_stores.dart';

/// The cancel sheet of `DL-133` through the real router and screens, with
/// the repositories faked.
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

  Future<void> open(WidgetTester tester, {String? at}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        orders: orders,
        cart: cart,
        device: const Locale('uz'),
      ),
    );
    await tester.pumpAndSettle();
    if (at != null) {
      GoRouter.of(anywhere(tester)).push(at);
      await tester.pumpAndSettle();
    }
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  bool fieldFocused(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

  String fieldText(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).controller.text;

  CancelSheetExit? exit;
  bool exited = false;

  /// Opens the sheet over the order's page and keeps what it answers.
  Future<void> openSheet(WidgetTester tester) async {
    exit = null;
    exited = false;
    unawaited(
      showCancelSheet(anywhere(tester), orderId: orderOne).then((
        CancelSheetExit? value,
      ) {
        exit = value;
        exited = true;
      }),
    );
    await tester.pumpAndSettle();
  }

  Map<String, Object?> shoppingRow({String? request}) => customerOrderJson(
    status: 'shopping',
    changeable: false,
    canRequestCancellation: request == null,
    cancellationRequest: request,
  );

  Map<String, Object?> cancelledRow() =>
      customerOrderJson(status: 'cancelled', changeable: false);

  Finder inConfirm(Finder what) =>
      find.descendant(of: byKey('cancel-confirm'), matching: what);

  Future<void> send(WidgetTester tester) async {
    await tester.ensureVisible(byKey('cancel-confirm'));
    await tester.tap(byKey('cancel-confirm'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  int orderLoads() =>
      orders.loads.where((String l) => l == 'order:$orderOne').length;

  List<String> announced(WidgetTester tester) => tester
      .takeAnnouncements()
      .map((CapturedAccessibilityAnnouncement a) => a.message)
      .toList();

  group('closing', () {
    testWidgets('the first tap above the sheet only hides the keyboard', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.customerOrder(orderOne));
      await tapAndSettle(tester, byKey('order-cancel'));
      await tester.tap(byKey('cancel-reason'));
      await tester.pumpAndSettle();
      expect(fieldFocused(tester), isTrue);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(byKey('cancel-reason'), findsOneWidget);
      expect(fieldFocused(tester), isFalse);

      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(byKey('cancel-reason'), findsNothing);
    });

    testWidgets('a closed sheet keeps its reason while the order is open', (
      WidgetTester tester,
    ) async {
      orders = FakeCustomerOrdersRepository(
        orders: <Map<String, Object?>>[
          customerOrderJson(),
          customerOrderJson(id: otherOrder),
        ],
      );
      await open(tester, at: AppPaths.customerOrders);
      await tapAndSettle(tester, byKey('order-$orderOne'));

      Future<void> reopenShows() async {
        await tapAndSettle(tester, byKey('order-cancel'));
        expect(fieldText(tester), 'Kerak emas');
      }

      await tapAndSettle(tester, byKey('order-cancel'));
      await tester.enterText(byKey('cancel-reason'), 'Kerak emas');
      await tapAndSettle(tester, byKey('cancel-sheet-close'));
      await reopenShows();

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      await reopenShows();

      await tester.fling(find.byType(BottomSheet), const Offset(0, 600), 2000);
      await tester.pumpAndSettle();
      await reopenShows();

      await tapAndSettle(tester, byKey('cancel-keep'));
      await tapAndSettle(tester, byKey('order-cancel'));
      expect(fieldText(tester), isEmpty);

      await tester.enterText(byKey('cancel-reason'), 'Kerak emas');
      await tapAndSettle(tester, byKey('cancel-sheet-close'));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, byKey('order-$orderOne'));
      await tapAndSettle(tester, byKey('order-cancel'));
      expect(fieldText(tester), isEmpty);
    });
  });

  group('the faces', () {
    testWidgets('the buttons say what they do and the title names the order', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.customerOrder(orderOne));
      await openSheet(tester);
      final AppLocalizations words = l10n(tester);

      expect(find.text(words.cancelSheetTitle(1001)), findsOneWidget);
      expect(find.text(words.orderCancelKeepKit), findsOneWidget);
      expect(find.text(words.cancelSheetConfirm), findsOneWidget);
      expect(find.text(words.cancelSheetHint), findsOneWidget);

      await tapAndSettle(tester, byKey('cancel-keep'));
      orders.rows = <Map<String, Object?>>[shoppingRow()];
      GoRouter.of(anywhere(tester)).pop();
      await tester.pumpAndSettle();
      GoRouter.of(anywhere(tester)).push(AppPaths.customerOrder(orderOne));
      await tester.pumpAndSettle();
      await openSheet(tester);

      expect(find.text(words.requestSheetTitle(1001)), findsOneWidget);
      expect(find.text(words.cancelSheetSendRequest), findsOneWidget);
      expect(find.text(words.requestSheetHint), findsOneWidget);
      expect(byKey('cancel-raced'), findsNothing);
    });

    testWidgets(
      'when the order allows neither the sheet says why and offers only Оставить заказ',
      (WidgetTester tester) async {
        await open(tester, at: AppPaths.customerOrder(orderOne));
        await openSheet(tester);
        orders
          ..failure = const ApiRefusal(
            ApiError(status: 409, code: 'order_cancellation_not_allowed'),
          )
          ..rows = <Map<String, Object?>>[
            customerOrderJson(status: 'on_the_way', changeable: false),
          ];
        await send(tester);

        expect(byKey('cancel-closed'), findsOneWidget);
        expect(
          find.text(l10n(tester).errorOrderCancellationNotAllowed),
          findsOneWidget,
        );
        expect(byKey('cancel-confirm'), findsNothing);
        expect(byKey('cancel-keep'), findsOneWidget);
      },
    );

    testWidgets(
      'shopping starting while the sheet is open turns it into a request in place',
      (WidgetTester tester) async {
        await open(tester, at: AppPaths.customerOrder(orderOne));
        await openSheet(tester);
        await tester.enterText(byKey('cancel-reason'), 'Kech qoldi');
        tester.takeAnnouncements();

        orders.rows = <Map<String, Object?>>[shoppingRow()];
        await tester.pump(const Duration(seconds: 15));
        await tester.pumpAndSettle();
        final AppLocalizations words = l10n(tester);

        expect(byKey('cancel-raced'), findsOneWidget);
        expect(find.text(words.cancelSheetRaced), findsOneWidget);
        expect(find.text(words.requestSheetTitle(1001)), findsOneWidget);
        expect(find.text(words.cancelSheetSendRequest), findsOneWidget);
        expect(find.text(words.cancelSheetHint), findsNothing);
        expect(fieldText(tester), 'Kech qoldi');
        expect(announced(tester), contains(words.cancelSheetRaced));
      },
    );

    testWidgets('the switch keeps the field focused and its words', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.customerOrder(orderOne));
      await openSheet(tester);
      await tester.tap(byKey('cancel-reason'));
      await tester.enterText(byKey('cancel-reason'), 'Kech qoldi');
      await tester.pumpAndSettle();
      expect(fieldFocused(tester), isTrue);

      orders.rows = <Map<String, Object?>>[shoppingRow()];
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();

      expect(byKey('cancel-raced'), findsOneWidget);
      expect(fieldFocused(tester), isTrue);
      expect(fieldText(tester), 'Kech qoldi');
    });

    testWidgets(
      'a 422 on the reason turns the sheet into a request and loads the order',
      (WidgetTester tester) async {
        await open(tester, at: AppPaths.customerOrder(orderOne));
        await openSheet(tester);
        final int before = orderLoads();

        orders.failure = const ApiRefusal(
          ApiError(
            status: 422,
            code: 'validation_failed',
            errors: <String, List<String>>{
              'reason': <String>['A cancellation request needs its reason.'],
            },
          ),
        );
        await send(tester);
        final AppLocalizations words = l10n(tester);

        expect(byKey('cancel-raced'), findsOneWidget);
        expect(find.text(words.requestSheetTitle(1001)), findsOneWidget);
        expect(find.text(words.cancelSheetSendRequest), findsOneWidget);
        expect(byKey('cancel-strip'), findsNothing);
        expect(orderLoads(), greaterThan(before));
      },
    );
  });

  group('sending', () {
    testWidgets(
      'the sheet stays while cancelling and says Заказ отменён before it closes',
      (WidgetTester tester) async {
        await open(tester, at: AppPaths.customerOrder(orderOne));
        await openSheet(tester);
        final AppLocalizations words = l10n(tester);
        orders
          ..answer = cancelledRow()
          ..hold = Completer<void>();

        await tester.tap(byKey('cancel-confirm'));
        await tester.pump();

        expect(
          inConfirm(find.text(words.cancelSheetCancelling)),
          findsOneWidget,
        );
        expect(
          inConfirm(find.byType(CircularProgressIndicator)),
          findsOneWidget,
        );
        expect(
          tester.widget<OutlinedButton>(byKey('cancel-keep')).onPressed,
          isNull,
        );
        await tester.tapAt(const Offset(20, 20));
        await tester.pump();
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.fling(
          find.byType(BottomSheet),
          const Offset(0, 600),
          2000,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(byKey('cancel-sheet'), findsOneWidget);

        orders.hold!.complete();
        await tester.pump();
        await tester.pump();

        expect(inConfirm(find.text(words.orderStateCancelled)), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 549));
        expect(byKey('cancel-sheet'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 2));
        await tester.pumpAndSettle();

        expect(byKey('cancel-sheet'), findsNothing);
        expect(exit, CancelSheetExit.cancelled);
        expect(find.text(words.orderStateCancelled), findsOneWidget);
      },
    );

    testWidgets('a second tap while sending sends nothing', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.customerOrder(orderOne));
      await openSheet(tester);
      orders
        ..answer = cancelledRow()
        ..hold = Completer<void>();

      await tester.tap(byKey('cancel-confirm'));
      await tester.pump();
      await tester.tap(byKey('cancel-confirm'));
      await tester.pump();

      expect(orders.cancels, hasLength(1));
      orders.hold!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'a refusal stays in the sheet with Повторить, which sends again',
      (WidgetTester tester) async {
        await open(tester, at: AppPaths.customerOrder(orderOne));
        await openSheet(tester);
        const ApiRefusal refusal = ApiRefusal(
          ApiError(status: 429, code: 'rate_limited'),
        );
        orders.failure = refusal;
        await send(tester);

        expect(byKey('cancel-strip'), findsOneWidget);
        expect(find.text(failureText(l10n(tester), refusal)!), findsOneWidget);

        orders.answer = cancelledRow();
        await tapAndSettle(tester, byKey('cancel-strip-retry'));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        expect(orders.cancels, hasLength(2));
        expect(orders.cancels[1].$3, isNot(orders.cancels[0].$3));
        expect(exit, CancelSheetExit.cancelled);
      },
    );

    testWidgets(
      'a direct cancel the server turned into a request ends as Просьба отправлена',
      (WidgetTester tester) async {
        await open(tester, at: AppPaths.customerOrder(orderOne));
        await openSheet(tester);
        orders
          ..answer = shoppingRow(request: 'pending')
          ..hold = Completer<void>();

        await tester.tap(byKey('cancel-confirm'));
        await tester.pump();
        orders.hold!.complete();
        await tester.pump();
        await tester.pump();

        expect(
          inConfirm(find.text(l10n(tester).cancelSheetRequested)),
          findsOneWidget,
        );
        await tester.pumpAndSettle();
        expect(exit, CancelSheetExit.requested);
      },
    );

    testWidgets(
      'an answer dropped for another account closes the sheet quietly',
      (WidgetTester tester) async {
        await open(tester, at: AppPaths.customerOrder(orderOne));
        await openSheet(tester);
        orders
          ..answer = cancelledRow()
          ..hold = Completer<void>();
        await tester.tap(byKey('cancel-confirm'));
        await tester.pump();
        final AppLocalizations words = l10n(tester);

        await ProviderScope.containerOf(
          tester.element(find.byType(Scaffold).first),
        ).read(sessionControllerProvider.notifier).logout(SessionMode.customer);
        await tester.pumpAndSettle();
        tester.takeAnnouncements();
        orders.hold!.complete();
        await tester.pumpAndSettle();

        expect(byKey('cancel-sheet'), findsNothing);
        expect(find.text(words.cancelSheetRequested), findsNothing);
        final List<String> spoken = announced(tester);
        expect(spoken, isNot(contains(words.orderStateCancelled)));
        expect(spoken, isNot(contains(words.cancelSheetRequested)));
      },
    );
  });

  group('an answer that was lost', () {
    testWidgets(
      'turns the sheet into its retry face and the retry is the same request',
      (WidgetTester tester) async {
        await open(tester, at: AppPaths.customerOrder(orderOne));
        await openSheet(tester);
        await tester.enterText(byKey('cancel-reason'), 'Kerak emas');
        orders.failure = const NetworkFailure();
        tester.takeAnnouncements();
        await send(tester);
        final AppLocalizations words = l10n(tester);

        expect(find.text(words.cancelSheetUnsureTitle), findsOneWidget);
        expect(find.text(words.cancelUnsureNow('cancel')), findsOneWidget);
        expect(byKey('cancel-unsure'), findsOneWidget);
        expect(find.text('«Kerak emas»'), findsOneWidget);
        expect(byKey('cancel-quote'), findsOneWidget);
        expect(find.text(words.cancelSheetSendAgain), findsOneWidget);
        expect(byKey('cancel-reason'), findsNothing);
        expect(announced(tester), contains(words.cancelUnsureNow('cancel')));

        await tapAndSettle(tester, byKey('cancel-sheet-close'));
        expect(exit, isNull);
        expect(exited, isTrue);
        await openSheet(tester);
        expect(find.text(words.cancelUnsureLater('cancel')), findsOneWidget);

        orders.answer = cancelledRow();
        await send(tester);

        expect(orders.cancels, hasLength(2));
        expect(orders.cancels[1].$3, orders.cancels[0].$3);
        expect(orders.cancels[1].$2, 'Kerak emas');
        expect(exit, CancelSheetExit.cancelled);
      },
    );

    testWidgets('a retry after a cancel that landed ends as Заказ отменён', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.customerOrder(orderOne));
      await openSheet(tester);
      orders.failure = const NetworkFailure();
      await send(tester);
      orders.rows = <Map<String, Object?>>[cancelledRow()];
      await send(tester);

      expect(orders.cancels, hasLength(2));
      expect(exit, CancelSheetExit.cancelled);
      expect(byKey('cancel-strip'), findsNothing);
    });

    testWidgets(
      'a request whose answer was lost says Просьба не подтвердилась',
      (WidgetTester tester) async {
        orders.rows = <Map<String, Object?>>[shoppingRow()];
        await open(tester, at: AppPaths.customerOrder(orderOne));
        await openSheet(tester);
        await tester.enterText(byKey('cancel-reason'), 'Kerak emas');
        orders.failure = const NetworkFailure();
        await send(tester);
        final AppLocalizations words = l10n(tester);

        expect(find.text(words.requestSheetUnsureTitle), findsOneWidget);
        expect(find.text(words.cancelUnsureNow('request')), findsOneWidget);
      },
    );

    testWidgets('a 5xx says no answer came', (WidgetTester tester) async {
      await open(tester, at: AppPaths.customerOrder(orderOne));
      await openSheet(tester);
      orders.failure = const ApiRefusal(
        ApiError(status: 503, code: 'service_unavailable'),
      );
      await send(tester);

      expect(
        find.text(l10n(tester).cancelUnsureServer('cancel')),
        findsOneWidget,
      );
    });
  });
}
