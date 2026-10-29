import 'dart:async';

import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/formatting/order_dates.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/language_menu.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/localization/order_labels.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/idempotency_key.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/kit/kit_empty_state.dart';
import 'package:baraka_bozor/core/widgets/kit/kit_note.dart';
import 'package:baraka_bozor/core/widgets/kit/kit_status_card.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/courier/application/courier_orders_controllers.dart';
import 'package:baraka_bozor/features/courier/data/courier_orders_api.dart';
import 'package:baraka_bozor/features/courier/domain/courier_orders.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  // The list's clock: 15:00 in Tashkent, the day the fixtures were made.
  final DateTime listNow = DateTime.utc(2026, 9, 28, 10);

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
        clock: () => listNow,
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
      await open(tester);
      final AppLocalizations words = l10n(tester);

      expect(location(tester), AppPaths.courier);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(words.myDeliveries),
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(byKey('courier-order-$courierOrderA')).dy,
        lessThan(tester.getTopLeft(byKey('courier-order-$courierOrderB')).dy),
      );
      Finder inRow(String id, String text) => find.descendant(
        of: byKey('courier-order-$id'),
        matching: find.text(text),
      );
      expect(
        inRow(courierOrderA, words.customerOrderTitle(1001)),
        findsOneWidget,
      );
      expect(
        inRow(courierOrderA, 'Amir Temur, 12, 34-xonadon'),
        findsOneWidget,
      );
      expect(
        inRow(
          courierOrderA,
          words.courierAssigned(
            orderAtLower(words, DateTime.utc(2026, 9, 28, 9), listNow),
          ),
        ),
        findsOneWidget,
      );
      expect(inRow(courierOrderA, words.courierChipNew), findsOneWidget);
      expect(
        inRow(courierOrderA, words.courierCollect(money(55600))),
        findsOneWidget,
      );
      expect(inRow(courierOrderA, words.courierOpenToAccept), findsOneWidget);
      expect(inRow(courierOrderA, words.courierRequestShort), findsNothing);

      expect(
        inRow(courierOrderB, words.customerOrderTitle(1002)),
        findsOneWidget,
      );
      expect(
        inRow(courierOrderB, OrderLabels.status(words, OrderStatus.onTheWay)),
        findsOneWidget,
      );
      expect(
        inRow(
          courierOrderB,
          words.courierOnTheWayLine(
            orderAtLower(words, DateTime.utc(2026, 9, 28, 9, 10), listNow),
            '15:10',
          ),
        ),
        findsOneWidget,
      );
      expect(inRow(courierOrderB, words.courierOpenToAccept), findsNothing);
      final List<Color> bar = tester
          .widget<SegmentBar>(
            find.descendant(
              of: byKey('courier-order-$courierOrderB'),
              matching: find.byType(SegmentBar),
            ),
          )
          .segments;
      expect(bar, hasLength(4));
      expect(bar.where((Color c) => c == KitColors.primary), hasLength(3));

      await tapAndSettle(tester, byKey('courier-order-$courierOrderA'));
      expect(location(tester), AppPaths.courierOrder(courierOrderA));
      expect(byKey('courier-order'), findsOneWidget);
    });

    testWidgets(
      'an accepted delivery with a request waiting says not to set off',
      (WidgetTester tester) async {
        courier.details[courierOrderA] = courierOrder(
          accepted: true,
          pending: true,
        );
        await open(tester);
        final AppLocalizations words = l10n(tester);
        Finder inRow(String text) => find.descendant(
          of: byKey('courier-order-$courierOrderA'),
          matching: find.text(text),
        );

        expect(inRow(words.courierChipAccepted), findsOneWidget);
        expect(inRow(words.courierChipNew), findsNothing);
        expect(
          inRow(
            words.courierAccepted(
              orderAtLower(words, DateTime.utc(2026, 9, 28, 9, 5), listNow),
            ),
          ),
          findsOneWidget,
        );
        expect(inRow(words.courierRequestShort), findsOneWidget);
        expect(inRow(words.courierOpenToAccept), findsNothing);
      },
    );

    testWidgets('an online delivery says nothing is to be taken', (
      WidgetTester tester,
    ) async {
      courier.details[courierOrderA] = courierOrder(cash: false);
      await open(tester);
      final AppLocalizations words = l10n(tester);

      expect(
        find.descendant(
          of: byKey('courier-order-$courierOrderA'),
          matching: find.text(words.courierPaidOnline),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a delivery wish shows on the card', (
      WidgetTester tester,
    ) async {
      await open(tester);
      final AppLocalizations words = l10n(tester);

      expect(
        find.descendant(
          of: byKey('courier-order-$courierOrderA'),
          matching: find.text(words.courierDeliveryWish('Kechqurun')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no delivery says so', (WidgetTester tester) async {
      courier.details.clear();
      await open(tester);
      final AppLocalizations words = l10n(tester);
      expect(byKey('courier-orders-empty'), findsOneWidget);
      expect(
        tester.widget(byKey('courier-orders-empty')),
        isA<KitEmptyState>(),
      );
      expect(find.text(words.courierEmptyTitle), findsOneWidget);
      expect(find.text(words.courierOrdersEmpty), findsOneWidget);
    });

    for (final Locale language in const <Locale>[Locale('uz'), Locale('ru')]) {
      testWidgets(
        'the list holds at 320x640 with text x2 (${language.languageCode})',
        (WidgetTester tester) async {
          courier.details
            ..clear()
            ..[courierOrderA] = courierOrder()
            ..[courierOrderB] = courierOrder(
              id: courierOrderB,
              number: 1002,
              accepted: true,
              pending: true,
            )
            ..[courierOrderC] = courierOrder(
              id: courierOrderC,
              number: 1003,
              status: 'on_the_way',
            );
          await open(
            tester,
            size: const Size(320, 640),
            textScale: 2,
            device: language,
          );
          expect(tester.takeException(), isNull);
          await tester.drag(byKey('courier-orders'), const Offset(0, -3000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets("the Courier's app bar holds one menu", (
      WidgetTester tester,
    ) async {
      // The customer session opened with the code that signed in.
      tokens.tokens[SessionSlot.customer] = 'c';
      auth.identities[SessionSlot.customer] = user(id: 'c');
      await open(tester, size: const Size(360, 800));
      final Finder bar = find.byType(AppBar);
      expect(
        find.descendant(of: bar, matching: byKey('staff-menu')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: find.byType(LanguageMenuButton)),
        findsNothing,
      );
      expect(
        find.descendant(of: bar, matching: byKey('logout-button')),
        findsNothing,
      );
      await tapAndSettle(tester, byKey('staff-menu'));
      expect(byKey('switch-to-customer-button'), findsOneWidget);
      await tapAndSettle(tester, byKey('staff-menu-language'));
      expect(byKey('language-sheet'), findsOneWidget);
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
    // The card, the steps and the footer of a delivery page.
    Finder inStatus(Finder matching) =>
        find.descendant(of: byKey('courier-order-status'), matching: matching);
    Finder inFooter(Finder matching) =>
        find.descendant(of: byKey('courier-order-footer'), matching: matching);
    KitStatusCard card(WidgetTester tester) =>
        tester.widget<KitStatusCard>(byKey('courier-order-status'));
    int greens(WidgetTester tester) => tester
        .widget<SegmentBar>(inStatus(find.byType(SegmentBar)))
        .segments
        .where((Color c) => c == KitColors.primary)
        .length;
    Text textAt(WidgetTester tester, String key) =>
        tester.widget<Text>(byKey(key));

    testWidgets('shows who, where, when, what to take, and the calls', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.courierOrder(courierOrderA));
      final AppLocalizations words = l10n(tester);

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(words.customerOrderTitle(1001)),
        ),
        findsOneWidget,
      );
      expect(card(tester).title, words.courierStatusNew);
      expect(card(tester).hint, words.courierStatusNewHint);
      expect(card(tester).tone, KitTone.green);
      expect(inStatus(find.text(words.courierStatusNew)), findsOneWidget);
      final KitSteps steps = tester.widget<KitSteps>(
        inStatus(find.byType(KitSteps)),
      );
      expect(steps.steps.map((KitStep step) => step.label), <String>[
        words.courierStepAssigned,
        words.courierStepAccepted,
        words.courierStepOnTheWay,
        words.courierStepDelivered,
      ]);
      expect(steps.steps.first.at, DateTime.utc(2026, 9, 28, 9));
      expect(inStatus(find.text('14:00')), findsOneWidget);
      expect(steps.reached, 1);
      expect(greens(tester), 1);
      expect(
        inStatus(find.text(words.courierDeliveryWish('Kechqurun'))),
        findsOneWidget,
      );

      expect(find.text(words.courierRecipientTitle), findsOneWidget);
      expect(
        find.descendant(
          of: byKey('call-recipient'),
          matching: find.text('Dilnoza Karimova'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: byKey('call-recipient'),
          matching: find.text('+998 90 123 45 67'),
        ),
        findsOneWidget,
      );

      expect(find.text(words.courierAddressTitle), findsOneWidget);
      Finder inAddress(Finder matching) => find.descendant(
        of: byKey('courier-address-card'),
        matching: matching,
      );
      expect(inAddress(byKey('courier-address')), findsOneWidget);
      expect(
        textAt(tester, 'courier-address').data,
        'Amir Temur, 12, 34-xonadon',
      );
      expect(inAddress(find.text(words.courierLandmarkLabel)), findsOneWidget);
      expect(inAddress(find.text('Maktab qarshisida')), findsOneWidget);
      expect(inAddress(find.text(words.courierNoteLabel)), findsOneWidget);
      expect(
        inAddress(find.text("Podyezdda qo'ng'iroq qiling")),
        findsOneWidget,
      );

      expect(find.text(words.courierPaymentTitle), findsOneWidget);
      Finder inAmount(Finder matching) =>
          find.descendant(of: byKey('courier-amount'), matching: matching);
      expect(inAmount(find.text(words.courierCollectLabel)), findsOneWidget);
      expect(inAmount(find.text(money(55600))), findsOneWidget);

      expect(inFooter(byKey('courier-accept')), findsOneWidget);
      expect(
        find.descendant(
          of: byKey('courier-accept'),
          matching: find.text(words.courierAccept),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a delivery without a wish says so', (
      WidgetTester tester,
    ) async {
      final Map<String, Object?> json = courierOrderJson();
      json['delivery_time_note'] = null;
      courier.details[courierOrderA] = CourierOrdersApi.parseOrder(json);
      await open(tester, at: AppPaths.courierOrder(courierOrderA));

      expect(inStatus(find.text(l10n(tester).courierNoWish)), findsOneWidget);
    });

    testWidgets('the calls dial, and say the number when nothing opens', (
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

      await tapAndSettle(tester, byKey('call-recipient'));
      await tapAndSettle(tester, byKey('call-shopper'));
      expect(phone.calls, <String>['+998901234567', '+998907654321']);

      phone.opens = false;
      await tapAndSettle(tester, byKey('call-recipient'));
      expect(find.text(words.callFailed('+998 90 123 45 67')), findsOneWidget);
    });

    testWidgets('an online delivery says nothing is to be taken', (
      WidgetTester tester,
    ) async {
      courier.details[courierOrderA] = courierOrder(cash: false);
      await open(tester, at: AppPaths.courierOrder(courierOrderA));
      final AppLocalizations words = l10n(tester);

      Finder inAmount(String text) => find.descendant(
        of: byKey('courier-amount'),
        matching: find.text(text),
      );
      expect(inAmount(words.courierPaidOnlineLabel), findsOneWidget);
      expect(inAmount(words.courierNoCash), findsOneWidget);
      expect(inAmount(words.courierCollectLabel), findsNothing);
    });

    testWidgets('open in Yandex asks for the point', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.courierOrder(courierOrderB));

      await tapAndSettle(tester, byKey('courier-open-yandex'));
      expect(maps.opened, <String>['41.311081,69.240562']);
      expect(byKey('courier-open-map'), findsNothing);
    });

    testWidgets('a failed open shows the address', (WidgetTester tester) async {
      maps.opens = false;
      await open(tester, at: AppPaths.courierOrder(courierOrderB));
      final AppLocalizations words = l10n(tester);

      await tapAndSettle(tester, byKey('courier-open-yandex'));
      expect(
        find.text(words.courierMapFailed('Amir Temur, 12, 34-xonadon')),
        findsOneWidget,
      );
    });

    testWidgets('copy puts the line on the clipboard and says so', (
      WidgetTester tester,
    ) async {
      final Map<String, Object?> json = courierOrderJson(
        id: courierOrderB,
        number: 1002,
        status: 'on_the_way',
      );
      json['address'] = <String, Object?>{
        'latitude': '41.311081',
        'longitude': '69.240562',
        'street': 'Чиланзар, 9-й квартал',
        'house': '14',
        'apartment': '5',
        'landmark': null,
      };
      courier.details[courierOrderB] = CourierOrdersApi.parseOrder(json);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text']! as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await open(
        tester,
        at: AppPaths.courierOrder(courierOrderB),
        device: const Locale('ru'),
      );

      final ButtonStyle copyStyle = tester
          .widget<OutlinedButton>(byKey('courier-copy-address'))
          .style!;
      expect(
        copyStyle.foregroundColor!.resolve(<WidgetState>{}),
        KitColors.ink,
      );
      expect(copyStyle.side!.resolve(<WidgetState>{})!.color, KitColors.line);
      expect(tester.getSize(byKey('courier-copy-address')), const Size(44, 44));
      expect(find.byTooltip(l10n(tester).courierCopyAddress), findsOneWidget);
      expect(tester.getSize(byKey('courier-open-yandex')).height, 44);

      await tapAndSettle(tester, byKey('courier-copy-address'));
      expect(copied, 'Чиланзар, 9-й квартал, 14, кв. 5');
      expect(find.text('Адрес скопирован'), findsOneWidget);
    });

    testWidgets('accept, then set off', (WidgetTester tester) async {
      courier.afterAction[courierOrderA] = courierOrder(accepted: true);
      await open(tester, at: AppPaths.courierOrder(courierOrderA));
      final AppLocalizations words = l10n(tester);
      expect(byKey('courier-start'), findsNothing);
      expect(byKey('courier-delivered'), findsNothing);

      await tapAndSettle(tester, byKey('courier-accept'));
      expect(courier.actions, <String>['accept:$courierOrderA']);
      expect(byKey('courier-accept'), findsNothing);
      expect(card(tester).title, words.courierStatusAccepted);
      expect(card(tester).hint, words.courierStatusAcceptedHint('1001'));
      expect(greens(tester), 2);
      expect(inFooter(byKey('courier-start')), findsOneWidget);
      expect(
        find.descendant(
          of: byKey('courier-start'),
          matching: find.text(words.courierStart),
        ),
        findsOneWidget,
      );
      expect(byKey('courier-delivered'), findsNothing, reason: 'not set off');

      courier.afterAction[courierOrderA] = courierOrder(status: 'on_the_way');
      await tapAndSettle(tester, byKey('courier-start'));
      expect(courier.actions.last, 'start:$courierOrderA');
      expect(byKey('courier-start'), findsNothing);
      expect(byKey('courier-delivered'), findsOneWidget);
      expect(byKey('courier-not-delivered'), findsOneWidget);
    });

    testWidgets('the pickup says where the package waits', (
      WidgetTester tester,
    ) async {
      // No Shopper's phone is sent: the package waits at the handoff point.
      await open(tester, at: AppPaths.courierOrder(courierOrderA));
      final AppLocalizations words = l10n(tester);
      expect(
        textAt(tester, 'courier-pickup-at-point').data,
        words.courierPickupAtPoint('1001'),
      );
      expect(byKey('courier-pickup-from-shopper'), findsNothing);
      expect(byKey('call-shopper'), findsNothing);

      // A Shopper named: take the package from them, and call them.
      await tester.pumpWidget(const SizedBox.shrink());
      courier.details[courierOrderA] = courierOrder(
        shopperPhone: '+998907654321',
      );
      await open(tester, at: AppPaths.courierOrder(courierOrderA));
      expect(
        textAt(tester, 'courier-pickup-from-shopper').data,
        words.courierPickupFromShopper,
      );
      expect(byKey('courier-pickup-at-point'), findsNothing);
      expect(
        find.descendant(
          of: byKey('call-shopper'),
          matching: find.text(words.courierCallShopper),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: byKey('call-shopper'),
          matching: find.text('+998 90 765 43 21'),
        ),
        findsOneWidget,
      );
      await tapAndSettle(tester, byKey('call-shopper'));
      expect(phone.calls, <String>['+998907654321']);

      // No Shopper named: the note, and nobody to call.
      await tester.pumpWidget(const SizedBox.shrink());
      courier.details[courierOrderA] = courierOrder(shopperPhone: null);
      await open(tester, at: AppPaths.courierOrder(courierOrderA));
      expect(byKey('courier-pickup-from-shopper'), findsOneWidget);
      expect(byKey('courier-pickup-at-point'), findsNothing);
      expect(byKey('call-shopper'), findsNothing);

      // On the way the package is picked up; the Shopper stays reachable.
      await tester.pumpWidget(const SizedBox.shrink());
      courier.details[courierOrderA] = courierOrder(
        status: 'on_the_way',
        shopperPhone: '+998907654321',
      );
      await open(tester, at: AppPaths.courierOrder(courierOrderA));
      expect(byKey('courier-pickup-from-shopper'), findsNothing);
      expect(byKey('courier-pickup-at-point'), findsNothing);
      expect(byKey('call-shopper'), findsOneWidget);
    });

    testWidgets(
      'a cancellation request waiting keeps the Courier from setting off, and says why',
      (WidgetTester tester) async {
        courier.details[courierOrderA] = courierOrder(
          accepted: true,
          pending: true,
        );
        await open(tester, at: AppPaths.courierOrder(courierOrderA));
        final AppLocalizations words = l10n(tester);
        expect(card(tester).tone, KitTone.amber);
        expect(card(tester).title, words.courierStatusRequest);
        expect(
          tester.widget<KitSteps>(find.byType(KitSteps)).rest,
          KitColors.warningSoft,
        );
        expect(
          textAt(tester, 'courier-request-pending').data,
          words.courierRequestPending,
        );
        expect(inFooter(find.text(words.courierWaitOperator)), findsOneWidget);
        expect(
          tester.widget<FilledButton>(byKey('courier-start')).onPressed,
          isNull,
        );

        // A request filed after the page was shown: the start is refused,
        // and the order loaded again says why.
        courier.details[courierOrderA] = courierOrder(accepted: true);
        await tester.pumpWidget(const SizedBox.shrink());
        await open(tester, at: AppPaths.courierOrder(courierOrderA));
        expect(card(tester).tone, KitTone.green);
        expect(byKey('courier-request-pending'), findsNothing);
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
        expect(card(tester).tone, KitTone.amber);
        expect(byKey('courier-request-pending'), findsOneWidget);
        expect(find.text(words.courierRequestPending), findsOneWidget);
        expect(find.text(words.errorDeliveryStateConflict), findsNothing);
        expect(find.text(words.courierWaitOperator), findsOneWidget);
        expect(
          tester.widget<FilledButton>(byKey('courier-start')).onPressed,
          isNull,
        );
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
        expect(
          tester.widget<FilledButton>(byKey('courier-start')).onPressed,
          isNotNull,
        );
        expect(find.text(l10n(tester).courierRequestPending), findsNothing);
        expect(find.text(l10n(tester).courierWaitOperator), findsNothing);
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

    testWidgets('on the way, the outcome is one tap away', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.courierOrder(courierOrderB));
      final AppLocalizations words = l10n(tester);

      expect(
        card(tester).title,
        OrderLabels.status(words, OrderStatus.onTheWay),
      );
      expect(
        textAt(tester, 'courier-due-by').data,
        words.courierOnTheWayHint('14:10', '15:10'),
      );
      expect(greens(tester), 3);
      expect(byKey('courier-pickup-at-point'), findsNothing);

      expect(inFooter(byKey('courier-delivered')), findsOneWidget);
      expect(inFooter(byKey('courier-not-delivered')), findsOneWidget);
      expect(
        find.descendant(
          of: byKey('courier-delivered'),
          matching: find.text(words.courierDelivered),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: byKey('courier-not-delivered'),
          matching: find.text(words.courierNotDelivered),
        ),
        findsOneWidget,
      );
      final ButtonStyle outlined = tester
          .widget<OutlinedButton>(byKey('courier-not-delivered'))
          .style!;
      expect(
        outlined.foregroundColor!.resolve(<WidgetState>{}),
        KitColors.danger,
      );
      expect(tester.widget(byKey('courier-delivered')), isA<FilledButton>());
      expect(
        tester.getTopLeft(byKey('courier-not-delivered')).dx,
        lessThan(tester.getTopLeft(byKey('courier-delivered')).dx),
      );
      expect(
        tester.getTopLeft(byKey('courier-not-delivered')).dy,
        tester.getTopLeft(byKey('courier-delivered')).dy,
      );
    });

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
        final AppLocalizations words = l10n(tester);
        expect(
          tester.widget(byKey('courier-order-gone')),
          isA<KitEmptyState>(),
        );
        expect(find.text(words.courierOrderGone), findsOneWidget);
        expect(find.text(words.courierOrderGoneHint), findsOneWidget);
        expect(
          find.descendant(
            of: byKey('courier-order-gone-back'),
            matching: find.text(words.courierBack),
          ),
          findsOneWidget,
        );
        await tapAndSettle(tester, byKey('courier-order-gone-back'));
        expect(location(tester), AppPaths.courier);
      },
    );

    testWidgets('the delivery holds at the extremes', (
      WidgetTester tester,
    ) async {
      Map<String, Object?> extreme(String status) {
        final Map<String, Object?> json = courierOrderJson(status: status);
        json['address'] = <String, Object?>{
          'latitude': '41.311081',
          'longitude': '69.240562',
          'street': "Mirzo Ulugbek tumani, Universitet ko'chasi " * 3,
          'house': '12/3-A',
          'apartment': '1204',
          'landmark': 'L' * 255,
        };
        json['delivery_note'] = 'N' * 300;
        json['delivery_time_note'] = 'W' * 160;
        json['amount_to_collect_uzs'] = 99999999;
        return json;
      }

      for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
        for (final String status in <String>[
          'delivery_assigned',
          'on_the_way',
        ]) {
          await tester.pumpWidget(const SizedBox.shrink());
          courier.details[courierOrderA] = CourierOrdersApi.parseOrder(
            extreme(status),
          );
          await open(
            tester,
            at: AppPaths.courierOrder(courierOrderA),
            size: const Size(320, 640),
            textScale: 2,
            device: device,
          );
          final String reason = '$status ${device.languageCode}';
          expect(tester.takeException(), isNull, reason: reason);
          expect(
            tester.getBottomLeft(byKey('courier-order-footer')).dy,
            lessThanOrEqualTo(640),
            reason: reason,
          );
          await tester.scrollUntilVisible(
            byKey('courier-amount'),
            300,
            scrollable: find.descendant(
              of: byKey('courier-order'),
              matching: find.byType(Scrollable),
            ),
            maxScrolls: 200,
          );
          expect(tester.takeException(), isNull, reason: reason);
          expect(
            find.text(
              money(99999999, AppLanguage.tryParse(device.languageCode)!),
            ),
            findsOneWidget,
            reason: reason,
          );
        }
      }
    });

    for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
      testWidgets(
        'the order holds at 320x640 with text x2 (${device.languageCode})',
        (WidgetTester tester) async {
          final Map<String, CourierOrder Function()> stages =
              <String, CourierOrder Function()>{
                'new': () => courierOrder(),
                'accepted, no handoff point': () =>
                    courierOrder(accepted: true, shopperPhone: '+998907654321'),
                'request waiting': () =>
                    courierOrder(accepted: true, pending: true),
                'on the way, cash': () => courierOrder(status: 'on_the_way'),
                'on the way, online': () =>
                    courierOrder(status: 'on_the_way', cash: false),
                'unanswered': () => courierOrder(status: 'on_the_way'),
              };
          for (final MapEntry<String, CourierOrder Function()> stage
              in stages.entries) {
            await tester.pumpWidget(const SizedBox.shrink());
            courier.details[courierOrderA] = stage.value();
            await open(
              tester,
              at: AppPaths.courierOrder(courierOrderA),
              size: const Size(320, 640),
              textScale: 2,
              device: device,
            );
            if (stage.key == 'unanswered') {
              ProviderScope.containerOf(
                    tester.element(find.byType(Scaffold).first),
                  )
                  .read(unansweredHandoverProvider(courierOrderA).notifier)
                  .set(const UnansweredRequest<int?>('key', 55600));
              await tester.pumpAndSettle();
              await tester.scrollUntilVisible(
                byKey('courier-handover-unconfirmed'),
                300,
                scrollable: find.descendant(
                  of: byKey('courier-order'),
                  matching: find.byType(Scrollable),
                ),
              );
              expect(byKey('courier-handover-unconfirmed'), findsOneWidget);
            }
            expect(tester.takeException(), isNull, reason: stage.key);
            await tapAndSettle(tester, byKey('courier-copy-address'));
            expect(byKey('courier-address-card'), findsOneWidget);
            await tapAndSettle(tester, byKey('courier-open-yandex'));
            expect(tester.takeException(), isNull, reason: stage.key);
          }
        },
      );
    }
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
      expect(byKey('courier-delivered-sheet'), findsOneWidget);
      expect(find.text(words.courierCashPrompt(money(55600))), findsOneWidget);
      expect(
        find.descendant(
          of: byKey('courier-delivered-sheet'),
          matching: find.text(words.courierCashField),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: byKey('courier-cash'),
          matching: find.text(MoneyFormat.currency(AppLanguage.uz)),
        ),
        findsOneWidget,
        reason: 'the suffix',
      );
      final TextField field = tester.widget<TextField>(
        find.descendant(
          of: byKey('courier-cash'),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, isEmpty, reason: 'the Courier counts');

      for (final String typed in <String>['', '0']) {
        await tester.enterText(byKey('courier-cash'), typed);
        await tapAndSettle(tester, byKey('courier-delivered-confirm'));
        expect(
          find.text(words.courierCashInvalid),
          findsOneWidget,
          reason: typed,
        );
      }
      expect(courier.actions, isEmpty);

      // The kit's field takes digits only, grouped as typed.
      await tester.enterText(byKey('courier-cash'), '55600');
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: byKey('courier-cash'),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        '55 600',
      );
      await tester.enterText(byKey('courier-cash'), '55 600');
      await tapAndSettle(tester, byKey('courier-delivered-confirm'));

      expect(courier.actions, <String>['delivered:$courierOrderA:55600']);
      expect(courier.keys.single, isNotEmpty);
      expect(location(tester), AppPaths.courier);
      expect(find.text(words.courierDeliveredDone('1001')), findsOneWidget);
      expect(byKey('courier-order-$courierOrderA'), findsNothing);
    });

    testWidgets('a cash mismatch says what to collect, and keeps the sheet', (
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
      expect(tester.widget(byKey('courier-cash-mismatch')), isA<KitNote>());
      expect(
        tester.widget<KitNote>(byKey('courier-cash-mismatch')).tone,
        KitTone.red,
      );
      expect(
        find.text(l10n(tester).courierCashMismatch(money(57000))),
        findsOneWidget,
      );
      expect(byKey('courier-delivered-sheet'), findsOneWidget);
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

    testWidgets('after a lost answer only the handover goes again', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.courierOrder(courierOrderA));
      final AppLocalizations words = l10n(tester);
      courier.actionFailure = const NetworkFailure();

      await tapAndSettle(tester, byKey('courier-delivered'));
      await tester.enterText(byKey('courier-cash'), '55600');
      await tapAndSettle(tester, byKey('courier-delivered-confirm'));
      expect(find.text(words.errorNetwork), findsOneWidget);
      await tapAndSettle(tester, byKey('courier-delivered-cancel'));

      expect(
        tester.widget<Text>(byKey('courier-handover-unconfirmed')).data,
        words.courierHandoverUnconfirmed,
      );
      expect(byKey('courier-not-delivered'), findsNothing);
      expect(
        find.descendant(
          of: byKey('courier-order-footer'),
          matching: find.byType(FilledButton),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: byKey('courier-delivered'),
          matching: find.text(words.courierDeliveredAgain),
        ),
        findsOneWidget,
      );

      await tapAndSettle(tester, byKey('courier-delivered'));
      final TextField field = tester.widget<TextField>(
        find.descendant(
          of: byKey('courier-cash'),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, '55 600');
      expect(field.enabled, isFalse, reason: 'locked');
      expect(find.text(words.courierHandoverRepeating), findsOneWidget);

      courier.actionFailure = null;
      await tapAndSettle(tester, byKey('courier-delivered-confirm'));
      expect(courier.actions, everyElement('delivered:$courierOrderA:55600'));
      expect(courier.keys[1], courier.keys[0]);
      expect(location(tester), AppPaths.courier);
    });

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
        expect(
          find.descendant(
            of: byKey('courier-order-footer'),
            matching: find.text(l10n(tester).courierDeliveredAgain),
          ),
          findsOneWidget,
        );
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
        tester
            .widget<OutlinedButton>(byKey('courier-delivered-cancel'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.descendant(
                of: byKey('courier-delivered-confirm'),
                matching: find.byType(CircularProgressIndicator),
              ),
            )
            .color,
        KitColors.muted,
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
      expect(find.text(l10n(tester).courierPaidOnlineLabel), findsOneWidget);
      await tapAndSettle(tester, byKey('courier-delivered'));
      expect(byKey('courier-cash'), findsNothing);
      expect(
        find.text(l10n(tester).courierOnlineNothingToTake),
        findsOneWidget,
      );
      expect(
        tester
            .widget<KitNote>(
              find.ancestor(
                of: find.text(l10n(tester).courierOnlineNothingToTake),
                matching: find.byType(KitNote),
              ),
            )
            .tone,
        KitTone.green,
      );
      await tapAndSettle(tester, byKey('courier-delivered-confirm'));
      expect(courier.actions, <String>['delivered:$courierOrderA:null']);
    });

    testWidgets('the resent handover locks the cash it sent', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.courierOrder(courierOrderA));
      courier.actionFailure = const NetworkFailure();
      await tapAndSettle(tester, byKey('courier-delivered'));
      await tester.enterText(byKey('courier-cash'), '55 600');
      await tapAndSettle(tester, byKey('courier-delivered-confirm'));
      await tapAndSettle(tester, byKey('courier-delivered-cancel'));

      await tapAndSettle(tester, byKey('courier-delivered'));
      expect(byKey('courier-delivered-sheet'), findsOneWidget);
      final TextField field = tester.widget<TextField>(
        find.descendant(
          of: byKey('courier-cash'),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, '55 600');
      expect(field.enabled, isFalse);
      expect(find.text(l10n(tester).courierHandoverRepeating), findsOneWidget);
    });

    testWidgets('a running handover holds its sheet', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.courierOrder(courierOrderA));
      await tapAndSettle(tester, byKey('courier-delivered'));
      await tester.enterText(byKey('courier-cash'), '55600');
      final Completer<void> hold = Completer<void>();
      courier.hold = hold;

      await tester.tap(byKey('courier-delivered-confirm'));
      await tester.pump();

      await tester.tap(byKey('courier-delivered-sheet-close'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(byKey('courier-delivered-sheet'), findsOneWidget, reason: 'the x');
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 400));
      expect(byKey('courier-delivered-sheet'), findsOneWidget, reason: 'back');
      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        byKey('courier-delivered-sheet'),
        findsOneWidget,
        reason: 'the scrim',
      );

      courier.hold = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(byKey('courier-delivered-sheet'), findsNothing);
      expect(courier.actions, hasLength(1));
      expect(location(tester), AppPaths.courier);
    });
  });

  group('the list under a delivery', () {
    setUp(() {
      courier.details[courierOrderA] = courierOrder(status: 'on_the_way');
      courier.afterAction[courierOrderA] = courierOrder(
        status: 'completed',
        ended: true,
      );
    });

    testWidgets('a delivery handed over leaves the list under it at once', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await tapAndSettle(tester, byKey('courier-order-$courierOrderA'));
      await tapAndSettle(tester, byKey('courier-delivered'));
      await tester.enterText(byKey('courier-cash'), '55600');
      final Completer<void> hold = Completer<void>();
      courier.holdList = hold;
      await tapAndSettle(tester, byKey('courier-delivered-confirm'));

      expect(location(tester), AppPaths.courier);
      expect(byKey('courier-order-$courierOrderA'), findsNothing);
      expect(byKey('courier-order-$courierOrderB'), findsOneWidget);

      hold.complete();
      await tester.pumpAndSettle();
      expect(byKey('courier-order-$courierOrderA'), findsNothing);
      expect(byKey('courier-order-$courierOrderB'), findsOneWidget);
    });

    testWidgets(
      'a delivery accepted and set off before its handover leaves the list '
      'with one load',
      (WidgetTester tester) async {
        courier.details[courierOrderA] = courierOrder();
        await open(tester);
        await tapAndSettle(tester, byKey('courier-order-$courierOrderA'));

        courier.afterAction[courierOrderA] = courierOrder(accepted: true);
        await tapAndSettle(tester, byKey('courier-accept'));
        courier.afterAction[courierOrderA] = courierOrder(status: 'on_the_way');
        await tapAndSettle(tester, byKey('courier-start'));

        courier.afterAction[courierOrderA] = courierOrder(
          status: 'completed',
          ended: true,
        );
        await tapAndSettle(tester, byKey('courier-delivered'));
        await tester.enterText(byKey('courier-cash'), '55600');
        final Completer<void> hold = Completer<void>();
        courier.holdList = hold;
        final int loads = count('orders:1');
        await tapAndSettle(tester, byKey('courier-delivered-confirm'));

        expect(location(tester), AppPaths.courier);
        expect(byKey('courier-order-$courierOrderA'), findsNothing);
        expect(byKey('courier-order-$courierOrderB'), findsOneWidget);
        expect(count('orders:1'), loads + 1, reason: 'one load, not two');

        courier.details[courierOrderC] = courierOrder(
          id: courierOrderC,
          number: 1003,
          status: 'on_the_way',
        );
        hold.complete();
        await tester.pumpAndSettle();
        expect(byKey('courier-order-$courierOrderC'), findsOneWidget);
        expect(byKey('courier-order-$courierOrderA'), findsNothing);
      },
    );
  });

  group('not delivered', () {
    setUp(() {
      courier.details[courierOrderA] = courierOrder(status: 'on_the_way');
      courier.afterAction[courierOrderA] = courierOrder(
        status: 'ready_for_delivery',
        ended: true,
      );
    });

    testWidgets('a running not-delivered report holds its sheet', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.courierOrder(courierOrderA));
      await tapAndSettle(tester, byKey('courier-not-delivered'));
      await tapAndSettle(tester, byKey('failure-no_answer'));
      final Completer<void> hold = Completer<void>();
      courier.hold = hold;

      await tester.tap(byKey('courier-not-delivered-confirm'));
      await tester.pump();

      await tester.tap(byKey('courier-not-delivered-sheet-close'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        byKey('courier-not-delivered-sheet'),
        findsOneWidget,
        reason: 'the x',
      );
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        byKey('courier-not-delivered-sheet'),
        findsOneWidget,
        reason: 'back',
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        byKey('courier-not-delivered-sheet'),
        findsOneWidget,
        reason: 'the scrim',
      );

      courier.hold = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(byKey('courier-not-delivered-sheet'), findsNothing);
      expect(courier.actions, hasLength(1));
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
        expect(byKey('courier-not-delivered-sheet'), findsOneWidget);
        expect(
          find.text(l10n(tester).courierNotDeliveredExplained),
          findsOneWidget,
        );
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

        expect(
          find.text(words.courierNotDeliveredNoteOptional),
          findsOneWidget,
        );
        expect(find.text(words.courierNotDeliveredNoteHint), findsOneWidget);
        await tapAndSettle(tester, byKey('failure-other'));
        expect(byKey('courier-failure-reason-missing'), findsNothing);
        expect(find.text(words.courierNotDeliveredNote), findsOneWidget);
        expect(find.text(words.courierOtherNoteHint), findsOneWidget);
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

    testWidgets('a refusal is said in the sheet, which stays open', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.courierOrder(courierOrderA));
      courier.actionFailure = const NetworkFailure();
      await tapAndSettle(tester, byKey('courier-not-delivered'));
      await tapAndSettle(tester, byKey('failure-refused'));
      await tapAndSettle(tester, byKey('courier-not-delivered-confirm'));
      expect(find.text(l10n(tester).errorNetwork), findsOneWidget);
      expect(byKey('courier-not-delivered-sheet'), findsOneWidget);
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

  testWidgets('each outcome sheet says only what its own attempt answered', (
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
      'the list, a delivery and both sheets fit a phone with large text (${device.languageCode})',
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
          size: const Size(320, 640),
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
        // "Other" with a full note, the keyboard up.
        await tapAndSettle(tester, byKey('failure-other'));
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        await tester.enterText(
          byKey('courier-failure-note'),
          List.filled(300, 'я').join(),
        );
        await tester.pumpAndSettle();
        expect(byKey('courier-not-delivered-sheet'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'other with a note');
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
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
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        await tester.enterText(byKey('courier-cash'), '5000');
        await tapAndSettle(tester, byKey('courier-delivered-confirm'));
        expect(byKey('courier-cash-mismatch'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'the mismatch');
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        courier.actionFailure = const NetworkFailure();
        await tapAndSettle(tester, byKey('courier-delivered-confirm'));
        await tapAndSettle(tester, byKey('courier-delivered-cancel'));
        // The note sits under the status card, at large text above the fold.
        await tester.scrollUntilVisible(
          byKey('courier-handover-unconfirmed'),
          300,
          scrollable: find.descendant(
            of: byKey('courier-order'),
            matching: find.byType(Scrollable),
          ),
        );
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
          size: const Size(320, 640),
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

  testWidgets('the list: every target meets iOSTapTargetGuideline', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await open(tester);

    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('the order: every target meets iOSTapTargetGuideline', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await open(tester, at: AppPaths.courierOrder(courierOrderA));

    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });
}
