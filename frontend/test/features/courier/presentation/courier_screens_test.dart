import 'dart:async';

import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/localization/order_labels.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/courier/domain/courier_orders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_courier_orders_repository.dart';
import '../../../support/fake_shopper_orders_repository.dart';
import '../../../support/in_memory_stores.dart';

/// The Courier's area (`docs/09` sections 36 and 37, `DL-72`) through the
/// real router, session, controllers and screens: the list and a delivery,
/// accept and set off, the calls and the map, delivered with the cash, not
/// delivered with a reason, the refresh while shown, and the one menu that
/// keeps the app bar from crowding.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCourierOrdersRepository courier;
  late FakePhoneCalls phone;
  late FakeMapLinks maps;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  String money(int amount, [AppLanguage language = AppLanguage.uz]) =>
      MoneyFormat.uzs(amount, language);

  int count(String load) =>
      courier.loads.where((String each) => each == load).length;

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.staff] = 's';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.staff] = user(id: 's', role: UserRole.courier);
    courier = FakeCourierOrdersRepository(
      details: <String, CourierOrder>{
        courierOrderA: courierOrder(),
        courierOrderB: courierOrder(
          id: courierOrderB,
          number: 1002,
          status: 'on_the_way',
        ),
      },
    );
    phone = FakePhoneCalls();
    maps = FakeMapLinks();
  });

  Future<void> open(
    WidgetTester tester, {
    String? at,
    Size size = const Size(420, 1600),
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
        courier: courier,
        phoneCalls: phone,
        maps: maps,
        device: device,
      ),
    );
    await tester.pumpAndSettle();
    if (at != null) {
      GoRouter.of(tester.element(find.byType(Scaffold).first)).push(at);
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

  String location(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Scaffold).first)).state.uri.path;

  group('the list', () {
    testWidgets('the Courier lands on their deliveries, with what each needs', (
      WidgetTester tester,
    ) async {
      courier.details[courierOrderA] = courierOrder(pending: true);
      await open(tester);
      final AppLocalizations words = l10n(tester);

      expect(location(tester), AppPaths.courier);
      expect(find.text(words.shellCourier), findsOneWidget);
      expect(
        tester.getTopLeft(byKey('courier-order-$courierOrderA')).dy,
        lessThan(tester.getTopLeft(byKey('courier-order-$courierOrderB')).dy),
      );
      Finder inRow(String id, String text) => find.descendant(
        of: byKey('courier-order-$id'),
        matching: find.textContaining(text),
      );
      expect(
        inRow(courierOrderA, words.courierRecipient('Dilnoza Karimova')),
        findsOneWidget,
      );
      expect(
        inRow(courierOrderA, words.courierAddress('Amir Temur, 12, 34')),
        findsOneWidget,
      );
      expect(
        inRow(courierOrderA, words.courierCollect(money(55600))),
        findsOneWidget,
      );
      expect(inRow(courierOrderA, words.courierRequestPending), findsOneWidget);
      expect(inRow(courierOrderA, words.courierNotAccepted), findsOneWidget);
      expect(inRow(courierOrderB, words.courierRequestPending), findsNothing);
      expect(
        inRow(courierOrderB, words.courierAssignedAt('28.09.2026 14:00')),
        findsOneWidget,
      );

      await tapAndSettle(tester, byKey('courier-order-$courierOrderA'));
      expect(location(tester), AppPaths.courierOrder(courierOrderA));
      expect(byKey('courier-order'), findsOneWidget);
    });

    testWidgets('no delivery says so', (WidgetTester tester) async {
      courier.details.clear();
      await open(tester);
      expect(byKey('courier-orders-empty'), findsOneWidget);
      expect(find.text(l10n(tester).courierOrdersEmpty), findsOneWidget);
    });

    testWidgets('the app bar holds the language and one menu', (
      WidgetTester tester,
    ) async {
      await open(tester, size: const Size(360, 800));
      final Finder bar = find.byType(AppBar);
      expect(
        find.descendant(of: bar, matching: byKey('staff-menu')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: byKey('logout-button')),
        findsNothing,
      );
      await tapAndSettle(tester, byKey('staff-menu'));
      expect(byKey('switch-to-customer-button'), findsOneWidget);
    });

    testWidgets('the list keeps current every ten seconds while shown', (
      WidgetTester tester,
    ) async {
      await open(tester);
      final int loads = count('orders:1');
      await tester.pump(const Duration(seconds: 9));
      expect(count('orders:1'), loads);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(count('orders:1'), loads + 1);
    });
  });

  group('a delivery', () {
    testWidgets('shows who, where, when, what to take, and the calls', (
      WidgetTester tester,
    ) async {
      courier.details[courierOrderB] = courierOrder(
        id: courierOrderB,
        number: 1002,
        status: 'on_the_way',
        shopperPhone: '+998907654321',
      );
      await open(tester, at: AppPaths.courierOrder(courierOrderB));
      final AppLocalizations words = l10n(tester);

      expect(
        find.text(words.courierRecipient('Dilnoza Karimova')),
        findsOneWidget,
      );
      expect(
        find.text(words.courierAddress('Amir Temur, 12, 34')),
        findsOneWidget,
      );
      expect(
        find.text(words.courierLandmark('Maktab qarshisida')),
        findsOneWidget,
      );
      expect(
        find.text(words.courierDeliveryNote("Podyezdda qo'ng'iroq qiling")),
        findsOneWidget,
      );
      expect(
        find.text('${words.orderSectionDeliveryWish}: Kechqurun'),
        findsOneWidget,
      );
      expect(find.text(words.courierCollect(money(55600))), findsOneWidget);
      expect(find.text(words.courierDueBy('28.09.2026 15:10')), findsOneWidget);
      // Set off already: the Shopper stays reachable, the pickup is done.
      expect(byKey('courier-pickup-from-shopper'), findsNothing);

      await tapAndSettle(tester, byKey('call-recipient'));
      await tapAndSettle(tester, byKey('call-shopper'));
      expect(phone.calls, <String>['+998901234567', '+998907654321']);
      await tapAndSettle(tester, byKey('courier-open-map'));
      expect(maps.opened, <String>['41.311081,69.240562']);

      phone.opens = false;
      maps.opens = false;
      await tapAndSettle(tester, byKey('call-recipient'));
      expect(find.text(words.callFailed('+998 90 123 45 67')), findsOneWidget);
      ScaffoldMessenger.of(tester.element(byKey('courier-order')))
          .clearSnackBars();
      await tester.pumpAndSettle();
      await tapAndSettle(tester, byKey('courier-open-map'));
      expect(
        find.text(words.courierMapFailed('Amir Temur, 12, 34')),
        findsOneWidget,
      );
    });

    testWidgets(
      'with a handoff point, the Shopper is not the Courier\'s to call',
      (WidgetTester tester) async {
        await open(tester, at: AppPaths.courierOrder(courierOrderA));
        expect(byKey('call-shopper'), findsNothing);
        expect(find.text(l10n(tester).courierPickupFromShopper), findsNothing);
      },
    );

    testWidgets('accept, then set off', (WidgetTester tester) async {
      courier.afterAction[courierOrderA] = courierOrder(accepted: true);
      await open(tester, at: AppPaths.courierOrder(courierOrderA));
      expect(byKey('courier-start'), findsNothing);
      expect(byKey('courier-delivered'), findsNothing);

      await tapAndSettle(tester, byKey('courier-accept'));
      expect(courier.actions, <String>['accept:$courierOrderA']);
      expect(byKey('courier-accept'), findsNothing);
      expect(byKey('courier-delivered'), findsNothing, reason: 'not set off');

      courier.afterAction[courierOrderA] = courierOrder(status: 'on_the_way');
      await tapAndSettle(tester, byKey('courier-start'));
      expect(courier.actions.last, 'start:$courierOrderA');
      expect(byKey('courier-start'), findsNothing);
      expect(byKey('courier-delivered'), findsOneWidget);
      expect(byKey('courier-not-delivered'), findsOneWidget);
    });

    testWidgets(
      'a cancellation request waiting keeps the Courier from setting off, and says why',
      (WidgetTester tester) async {
        courier.details[courierOrderA] = courierOrder(
          accepted: true,
          pending: true,
        );
        await open(tester, at: AppPaths.courierOrder(courierOrderA));
        expect(byKey('courier-request-pending'), findsOneWidget);
        expect(byKey('courier-start'), findsNothing);

        // A request filed after the page was shown: the start is refused,
        // and the order loaded again says why.
        courier.details[courierOrderA] = courierOrder(accepted: true);
        await tester.pumpWidget(const SizedBox.shrink());
        await open(tester, at: AppPaths.courierOrder(courierOrderA));
        courier
          ..actionFailure = const ApiRefusal(
            ApiError(
              status: 409,
              code: 'delivery_state_conflict',
              details: <String, Object?>{
                'reason': 'cancellation_request_pending',
              },
            ),
          )
          ..details[courierOrderA] = courierOrder(
            accepted: true,
            pending: true,
          );
        await tapAndSettle(tester, byKey('courier-start'));
        // The order loaded again says why, once.
        expect(byKey('courier-request-pending'), findsOneWidget);
        expect(byKey('courier-start-held'), findsNothing);
        expect(
          find.text(l10n(tester).errorDeliveryStateConflict),
          findsNothing,
        );
        expect(byKey('courier-start'), findsNothing);
      },
    );

    testWidgets(
      'once the request is decided, nothing tells the Courier to wait',
      (WidgetTester tester) async {
        courier.details[courierOrderA] = courierOrder(accepted: true);
        await open(tester, at: AppPaths.courierOrder(courierOrderA));
        courier
          ..actionFailure = const ApiRefusal(
            ApiError(
              status: 409,
              code: 'delivery_state_conflict',
              details: <String, Object?>{
                'reason': 'cancellation_request_pending',
              },
            ),
          )
          ..details[courierOrderA] = courierOrder(
            accepted: true,
            pending: true,
          );
        await tapAndSettle(tester, byKey('courier-start'));
        expect(find.text(l10n(tester).courierRequestPending), findsOneWidget);

        // An Operator rejects the request; the refresh offers the start
        // again, and no stale "do not set off" stands beside it.
        courier.details[courierOrderA] = courierOrder(accepted: true);
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();
        expect(byKey('courier-start'), findsOneWidget);
        expect(find.text(l10n(tester).courierRequestPending), findsNothing);
        expect(byKey('failure-message'), findsNothing);

        // Any other conflict reads as one.
        courier.actionFailure = const ApiRefusal(
          ApiError(status: 409, code: 'delivery_state_conflict'),
        );
        await tapAndSettle(tester, byKey('courier-start'));
        expect(
          find.text(l10n(tester).errorDeliveryStateConflict),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'before setting off, without a handoff point, the pickup is from the Shopper',
      (WidgetTester tester) async {
        courier.details[courierOrderA] = courierOrder(
          accepted: true,
          shopperPhone: '+998907654321',
        );
        await open(tester, at: AppPaths.courierOrder(courierOrderA));
        expect(byKey('courier-pickup-from-shopper'), findsOneWidget);
        expect(byKey('call-shopper'), findsOneWidget);
      },
    );

    testWidgets('a delivery keeps current every ten seconds while shown', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.courierOrder(courierOrderA));
      final int loads = count('order:$courierOrderA');
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(count('order:$courierOrderA'), loads + 1);
    });

    testWidgets(
      'a delivery no longer the Courier\'s says so, with the way back',
      (WidgetTester tester) async {
        courier.details.remove(courierOrderA);
        await open(tester, at: AppPaths.courierOrder(courierOrderA));
        expect(byKey('courier-order-gone'), findsOneWidget);
        await tapAndSettle(tester, byKey('courier-order-gone-back'));
        expect(location(tester), AppPaths.courier);
      },
    );
  });

  group('delivered', () {
    setUp(() {
      courier.details[courierOrderA] = courierOrder(status: 'on_the_way');
      courier.afterAction[courierOrderA] = courierOrder(
        status: 'completed',
        ended: true,
      );
    });

    testWidgets('takes the cash typed, and leaves for the list, told so', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.courierOrder(courierOrderA));
      final AppLocalizations words = l10n(tester);

      await tapAndSettle(tester, byKey('courier-delivered'));
      expect(find.text(words.courierCashPrompt(money(55600))), findsOneWidget);
      final TextField field = tester.widget<TextField>(
        find.descendant(
          of: byKey('courier-cash'),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, isEmpty, reason: 'the Courier counts');

      for (final String typed in <String>['', '0', '55 6OO', '12,5']) {
        await tester.enterText(byKey('courier-cash'), typed);
        await tapAndSettle(tester, byKey('courier-delivered-confirm'));
        expect(
          find.text(words.courierCashInvalid),
          findsOneWidget,
          reason: typed,
        );
      }
      expect(courier.actions, isEmpty);

      await tester.enterText(byKey('courier-cash'), '55 600');
      await tapAndSettle(tester, byKey('courier-delivered-confirm'));

      expect(courier.actions, <String>['delivered:$courierOrderA:55600']);
      expect(courier.keys.single, isNotEmpty);
      expect(location(tester), AppPaths.courier);
      expect(find.text(words.courierDeliveredDone('1001')), findsOneWidget);
      expect(byKey('courier-order-$courierOrderA'), findsNothing);
    });

    testWidgets('a cash mismatch says what to collect, and keeps the dialog', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.courierOrder(courierOrderA));
      courier.actionFailure = const ApiRefusal(
        ApiError(
          status: 409,
          code: 'cash_amount_mismatch',
          details: <String, Object?>{'expected_uzs': 57000},
        ),
      );
      final int loads = count('order:$courierOrderA');

      await tapAndSettle(tester, byKey('courier-delivered'));
      await tester.enterText(byKey('courier-cash'), '55600');
      await tapAndSettle(tester, byKey('courier-delivered-confirm'));

      expect(byKey('courier-cash-mismatch'), findsOneWidget);
      expect(
        find.text(l10n(tester).courierCashMismatch(money(57000))),
        findsOneWidget,
      );
      expect(byKey('courier-delivered-confirm'), findsOneWidget);
      expect(count('order:$courierOrderA'), loads + 1, reason: 'read again');

      // The count corrected, a new handover goes.
      courier.actionFailure = null;
      await tester.enterText(byKey('courier-cash'), '57000');
      await tapAndSettle(tester, byKey('courier-delivered-confirm'));
      expect(courier.actions.last, 'delivered:$courierOrderA:57000');
      expect(courier.keys[1], isNot(courier.keys[0]));
      expect(location(tester), AppPaths.courier);
    });

    testWidgets(
      'after a lost answer the same cash goes again, under its key, and nothing else',
      (WidgetTester tester) async {
        await open(tester, at: AppPaths.courierOrder(courierOrderA));
        final AppLocalizations words = l10n(tester);
        courier.actionFailure = const NetworkFailure();

        await tapAndSettle(tester, byKey('courier-delivered'));
        await tester.enterText(byKey('courier-cash'), '55600');
        await tapAndSettle(tester, byKey('courier-delivered-confirm'));
        expect(find.text(words.errorNetwork), findsOneWidget);
        await tapAndSettle(tester, byKey('courier-delivered-cancel'));

        expect(byKey('courier-handover-unconfirmed'), findsOneWidget);
        expect(byKey('courier-not-delivered'), findsNothing);

        await tapAndSettle(tester, byKey('courier-delivered'));
        final TextField field = tester.widget<TextField>(
          find.descendant(
            of: byKey('courier-cash'),
            matching: find.byType(TextField),
          ),
        );
        expect(field.controller!.text, '55600');
        expect(field.readOnly, isTrue);
        expect(find.text(words.courierHandoverRepeating), findsOneWidget);

        courier.actionFailure = null;
        await tapAndSettle(tester, byKey('courier-delivered-confirm'));
        expect(courier.actions, everyElement('delivered:$courierOrderA:55600'));
        expect(courier.keys[1], courier.keys[0]);
        expect(location(tester), AppPaths.courier);
      },
    );

    testWidgets(
      'a lost answer whose delivery can no longer be read offers the handover again',
      (WidgetTester tester) async {
        await open(tester, at: AppPaths.courierOrder(courierOrderA));
        // The handover went through; its answer was lost.
        courier.actionFailure = const NetworkFailure();
        courier.details.remove(courierOrderA);

        await tapAndSettle(tester, byKey('courier-delivered'));
        await tester.enterText(byKey('courier-cash'), '55600');
        await tapAndSettle(tester, byKey('courier-delivered-confirm'));
        await tapAndSettle(tester, byKey('courier-delivered-cancel'));
        // The page keeps what it shows, until its refresh finds the
        // delivery gone.
        expect(byKey('courier-handover-unconfirmed'), findsOneWidget);
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();

        expect(byKey('courier-order-gone'), findsNothing);
        expect(byKey('courier-delivered-again'), findsOneWidget);
        courier.actionFailure = null;
        await tapAndSettle(tester, byKey('courier-delivered-again'));
        expect(courier.keys[1], courier.keys[0]);
        expect(courier.actions.last, 'delivered:$courierOrderA:55600');
        expect(location(tester), AppPaths.courier);
        expect(
          find.text(l10n(tester).courierDeliveredDone('1001')),
          findsOneWidget,
        );
      },
    );

    testWidgets('one handover at a time, and no refresh meanwhile', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.courierOrder(courierOrderA));
      await tapAndSettle(tester, byKey('courier-delivered'));
      await tester.enterText(byKey('courier-cash'), '55600');
      final Completer<void> hold = Completer<void>();
      courier.hold = hold;
      final int loads = count('order:$courierOrderA');

      await tester.tap(byKey('courier-delivered-confirm'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(byKey('courier-delivered-confirm'))
            .onPressed,
        isNull,
      );
      expect(
        tester.widget<TextButton>(byKey('courier-delivered-cancel')).onPressed,
        isNull,
      );
      await tester.pump(const Duration(seconds: 30));
      expect(count('order:$courierOrderA'), loads, reason: 'no refresh');

      courier.hold = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(courier.actions, hasLength(1));
    });

    testWidgets('an online order is handed over with nothing to take', (
      WidgetTester tester,
    ) async {
      courier.details[courierOrderA] = courierOrder(
        status: 'on_the_way',
        cash: false,
      );
      courier.afterAction[courierOrderA] = courierOrder(
        status: 'completed',
        cash: false,
        ended: true,
      );
      await open(tester, at: AppPaths.courierOrder(courierOrderA));
      expect(find.text(l10n(tester).courierPaidOnline), findsOneWidget);
      await tapAndSettle(tester, byKey('courier-delivered'));
      expect(byKey('courier-cash'), findsNothing);
      await tapAndSettle(tester, byKey('courier-delivered-confirm'));
      expect(courier.actions, <String>['delivered:$courierOrderA:null']);
    });
  });

  group('not delivered', () {
    setUp(() {
      courier.details[courierOrderA] = courierOrder(status: 'on_the_way');
      courier.afterAction[courierOrderA] = courierOrder(
        status: 'ready_for_delivery',
        ended: true,
      );
    });

    testWidgets('each reason reads as the panel reads it, in both languages', (
      WidgetTester tester,
    ) async {
      for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await open(
          tester,
          at: AppPaths.courierOrder(courierOrderA),
          device: device,
        );
        await tapAndSettle(tester, byKey('courier-not-delivered'));
        for (final DeliveryFailureReason reason
            in DeliveryFailureReason.values) {
          expect(
            find.descendant(
              of: byKey('failure-${reason.code}'),
              matching: find.text(
                OrderLabels.deliveryFailure(l10n(tester), reason),
              ),
            ),
            findsOneWidget,
            reason: '${reason.code} in ${device.languageCode}',
          );
        }
      }
    });

    testWidgets(
      'needs a reason, a note with "other", and goes back to the list',
      (WidgetTester tester) async {
        await open(tester, at: AppPaths.courierOrder(courierOrderA));
        final AppLocalizations words = l10n(tester);
        await tapAndSettle(tester, byKey('courier-not-delivered'));

        await tapAndSettle(tester, byKey('courier-not-delivered-confirm'));
        expect(byKey('courier-failure-reason-missing'), findsOneWidget);
        expect(courier.actions, isEmpty);

        await tapAndSettle(tester, byKey('failure-other'));
        expect(byKey('courier-failure-reason-missing'), findsNothing);
        await tester.enterText(byKey('courier-failure-note'), '   ');
        await tapAndSettle(tester, byKey('courier-not-delivered-confirm'));
        expect(find.text(words.fieldRequired), findsOneWidget);
        await tester.enterText(byKey('courier-failure-note'), 'a' * 301);
        await tapAndSettle(tester, byKey('courier-not-delivered-confirm'));
        expect(find.text(words.fieldTooLong(300)), findsOneWidget);
        expect(courier.actions, isEmpty);

        await tester.enterText(
          byKey('courier-failure-note'),
          '  Podyezd yopiq ',
        );
        await tapAndSettle(tester, byKey('courier-not-delivered-confirm'));
        expect(courier.actions, <String>[
          'not-delivered:$courierOrderA:other:Podyezd yopiq',
        ]);
        expect(location(tester), AppPaths.courier);
        expect(
          find.text(words.courierNotDeliveredDone('1001')),
          findsOneWidget,
        );
      },
    );

    testWidgets('a reason other than "other" goes without a note', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.courierOrder(courierOrderA));
      await tapAndSettle(tester, byKey('courier-not-delivered'));
      await tapAndSettle(tester, byKey('failure-no_answer'));
      await tapAndSettle(tester, byKey('courier-not-delivered-confirm'));
      expect(courier.actions, <String>[
        'not-delivered:$courierOrderA:no_answer:null',
      ]);
    });

    testWidgets('a refusal is said in the dialog, which stays open', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.courierOrder(courierOrderA));
      courier.actionFailure = const NetworkFailure();
      await tapAndSettle(tester, byKey('courier-not-delivered'));
      await tapAndSettle(tester, byKey('failure-refused'));
      await tapAndSettle(tester, byKey('courier-not-delivered-confirm'));
      expect(find.text(l10n(tester).errorNetwork), findsOneWidget);
      expect(byKey('courier-not-delivered-confirm'), findsOneWidget);

      // A natural repeat: sent again as it is.
      courier.actionFailure = null;
      await tapAndSettle(tester, byKey('courier-not-delivered-confirm'));
      expect(courier.actions, hasLength(2));
      expect(location(tester), AppPaths.courier);
    });

    testWidgets(
      'a failure whose answer was lost and went through leaves no handover offered',
      (WidgetTester tester) async {
        await open(tester, at: AppPaths.courierOrder(courierOrderA));
        courier
          ..actionFailure = const NetworkFailure()
          ..details.remove(courierOrderA);
        await tapAndSettle(tester, byKey('courier-not-delivered'));
        await tapAndSettle(tester, byKey('failure-no_answer'));
        await tapAndSettle(tester, byKey('courier-not-delivered-confirm'));
        await tapAndSettle(tester, byKey('courier-not-delivered-cancel'));

        // Loaded again at once, not at the next refresh.
        expect(byKey('courier-order-gone'), findsOneWidget);
        expect(byKey('courier-delivered'), findsNothing);
      },
    );
  });

  testWidgets('each outcome dialog says only what its own attempt answered', (
    WidgetTester tester,
  ) async {
    courier.details[courierOrderA] = courierOrder(status: 'on_the_way');
    await open(tester, at: AppPaths.courierOrder(courierOrderA));
    final AppLocalizations words = l10n(tester);
    courier.actionFailure = const ApiRefusal(
      ApiError(
        status: 409,
        code: 'cash_amount_mismatch',
        details: <String, Object?>{'expected_uzs': 57000},
      ),
    );
    await tapAndSettle(tester, byKey('courier-delivered'));
    await tester.enterText(byKey('courier-cash'), '5000');
    await tapAndSettle(tester, byKey('courier-delivered-confirm'));
    expect(byKey('courier-cash-mismatch'), findsOneWidget);
    await tapAndSettle(tester, byKey('courier-delivered-cancel'));

    await tapAndSettle(tester, byKey('courier-not-delivered'));
    expect(byKey('failure-message'), findsNothing);
    expect(find.text(words.errorCashAmountMismatch), findsNothing);
    await tapAndSettle(tester, byKey('courier-not-delivered-cancel'));

    await tapAndSettle(tester, byKey('courier-delivered'));
    expect(byKey('courier-cash-mismatch'), findsNothing);
    expect(byKey('failure-message'), findsNothing);
  });

  testWidgets(
    'a Courier who left while a handover went again is told, not taken back',
    (WidgetTester tester) async {
      courier.details[courierOrderA] = courierOrder(status: 'on_the_way');
      courier.afterAction[courierOrderA] = courierOrder(
        status: 'completed',
        ended: true,
      );
      await open(tester, at: AppPaths.courierOrder(courierOrderA));
      courier
        ..actionFailure = const NetworkFailure()
        ..details.remove(courierOrderA);
      await tapAndSettle(tester, byKey('courier-delivered'));
      await tester.enterText(byKey('courier-cash'), '55600');
      await tapAndSettle(tester, byKey('courier-delivered-confirm'));
      await tapAndSettle(tester, byKey('courier-delivered-cancel'));
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(byKey('courier-delivered-again'), findsOneWidget);

      courier.actionFailure = null;
      final Completer<void> hold = Completer<void>();
      courier.hold = hold;
      await tester.tap(byKey('courier-delivered-again'));
      await tester.pump();
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .push(AppPaths.courierOrder(courierOrderB));
      // Delivery B's load waits on the same hold: pump, do not settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      courier.hold = null;
      hold.complete();
      await tester.pumpAndSettle();

      expect(location(tester), AppPaths.courierOrder(courierOrderB));
      expect(
        find.text(l10n(tester).courierDeliveredDone('1001')),
        findsOneWidget,
      );
    },
  );

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'the list, a delivery and both dialogs fit a phone with large text (${device.languageCode})',
      (WidgetTester tester) async {
        courier.details[courierOrderB] = courierOrder(
          id: courierOrderB,
          number: 1002,
          status: 'on_the_way',
          pending: false,
          shopperPhone: '+998907654321',
        );
        courier.details[courierOrderA] = courierOrder(pending: true);
        await open(
          tester,
          size: const Size(360, 800),
          textScale: 2,
          device: device,
        );
        expect(tester.takeException(), isNull);
        await tapAndSettle(tester, byKey('courier-order-$courierOrderB'));
        expect(tester.takeException(), isNull);

        await tapAndSettle(tester, byKey('courier-delivered'));
        await tapAndSettle(tester, byKey('courier-delivered-confirm'));
        expect(find.text(l10n(tester).courierCashInvalid), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tapAndSettle(tester, byKey('courier-delivered-cancel'));

        await tapAndSettle(tester, byKey('courier-not-delivered'));
        await tapAndSettle(tester, byKey('courier-not-delivered-confirm'));
        expect(tester.takeException(), isNull);
        await tapAndSettle(tester, byKey('courier-not-delivered-cancel'));

        // The cash mismatch, then a handover without a sure answer.
        courier.actionFailure = const ApiRefusal(
          ApiError(
            status: 409,
            code: 'cash_amount_mismatch',
            details: <String, Object?>{'expected_uzs': 1234567},
          ),
        );
        await tapAndSettle(tester, byKey('courier-delivered'));
        await tester.enterText(byKey('courier-cash'), '5000');
        await tapAndSettle(tester, byKey('courier-delivered-confirm'));
        expect(byKey('courier-cash-mismatch'), findsOneWidget);
        expect(tester.takeException(), isNull);
        courier.actionFailure = const NetworkFailure();
        await tapAndSettle(tester, byKey('courier-delivered-confirm'));
        await tapAndSettle(tester, byKey('courier-delivered-cancel'));
        expect(byKey('courier-handover-unconfirmed'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // A delivery a request holds, and one no longer the Courier's.
        await tester.pumpWidget(const SizedBox.shrink());
        courier
          ..actionFailure = null
          ..details[courierOrderA] = courierOrder(
            accepted: true,
            pending: true,
          );
        await open(
          tester,
          at: AppPaths.courierOrder(courierOrderA),
          size: const Size(360, 800),
          textScale: 2,
          device: device,
        );
        expect(byKey('courier-request-pending'), findsOneWidget);
        expect(tester.takeException(), isNull);
        courier.details.remove(courierOrderA);
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();
        expect(byKey('courier-order-gone'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
