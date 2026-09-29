import 'dart:async';

import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/shopper/data/shopper_orders_api.dart';
import 'package:baraka_bozor/features/shopper/domain/shopper_orders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_shopper_orders_repository.dart';
import '../../../support/in_memory_stores.dart';

/// The Shopper's area (`docs/09` sections 28 and 29, `DL-69`) through the
/// real router, session, controllers and screens: the list and an order,
/// accept and start, the call to the Customer, the refresh while shown, and
/// the menu that keeps Customer mode reachable.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeShopperOrdersRepository shopper;
  late FakePhoneCalls phone;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  String money(int amount) => MoneyFormat.uzs(amount, AppLanguage.uz);

  int count(String load) =>
      shopper.loads.where((String each) => each == load).length;

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.staff] = 's';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.staff] = user(id: 's', role: UserRole.shopper);
    shopper = FakeShopperOrdersRepository(
      rows: <ShopperOrderRow>[
        ShopperOrdersApi.parseRow(shopperRowJson()),
        ShopperOrdersApi.parseRow(
          shopperRowJson(
            id: shopperOrderB,
            number: 1002,
            status: 'shopping',
            accepted: true,
            open: 1,
          ),
        ),
      ],
      details: <String, ShopperOrder>{shopperOrderA: shopperOrder()},
    );
    phone = FakePhoneCalls();
  });

  Future<void> open(
    WidgetTester tester, {
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
        shopper: shopper,
        phoneCalls: phone,
        device: device,
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

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(byKey(key)).data!;

  testWidgets('the Shopper lands on their orders, the longest-waiting first', (
    WidgetTester tester,
  ) async {
    await open(tester);
    final AppLocalizations words = l10n(tester);

    expect(find.text(words.shellShopper), findsOneWidget);
    expect(
      tester.getTopLeft(byKey('shopper-order-$shopperOrderA')).dy,
      lessThan(tester.getTopLeft(byKey('shopper-order-$shopperOrderB')).dy),
    );
    expect(find.textContaining(words.shopperOpenLines(2, 2)), findsOneWidget);
    expect(find.textContaining(words.shopperOpenLines(1, 2)), findsOneWidget);
    expect(find.textContaining(words.shopperNotAccepted), findsOneWidget);
    expect(
      find.textContaining(words.shopperAssignedAt('27.09.2026 12:05')),
      findsOneWidget,
    );

    await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
    expect(byKey('shopper-order'), findsOneWidget);
    expect(find.text(words.boardOrderNumber('1001')), findsOneWidget);
  });

  testWidgets('no orders says so', (WidgetTester tester) async {
    shopper.rows = <ShopperOrderRow>[];
    await open(tester);

    expect(byKey('shopper-orders-empty'), findsOneWidget);
    expect(find.text(l10n(tester).shopperOrdersEmpty), findsOneWidget);
  });

  testWidgets('an order shows each line: what to buy, how far its price may '
      'go, and what became of it', (WidgetTester tester) async {
    shopper.details[shopperOrderA] = shopperOrder(
      status: 'shopping',
      items: <Object?>[
        shopperLineJson(
          status: 'awaiting_customer',
          patch: <String, Object?>{
            'approved_quantity_cap': '1.500',
            'replacement': <String, Object?>{
              'product_id': shopperProductCherry,
              'name_uz': 'Olcha pomidor',
              'name_ru': 'Помидоры черри',
              'market_price_uzs': 15500,
              'substitution_resolution': 'automatic',
              'bound': <String, Object?>{
                'customer_unit_price_uzs': 21160,
                'market_price_uzs': 19000,
              },
            },
            'pending_approval': <String, Object?>{
              'id': shopperQuestion,
              'type': 'price_over_tolerance',
              'expires_at': '2026-09-27T08:00:00Z',
            },
          },
        ),
        shopperLineJson(bread: true, status: 'purchased'),
      ],
    );
    await open(tester);
    await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
    final AppLocalizations words = l10n(tester);

    expect(
      find.text('${words.orderSectionDeliveryWish}: Kechqurun'),
      findsOneWidget,
    );
    expect(
      text(tester, 'shopper-line-status-$shopperLineTomato'),
      words.itemStatusAwaitingCustomer,
    );
    expect(
      text(tester, 'shopper-line-limit-$shopperLineTomato'),
      words.shopperPriceLimit(money(18400)),
    );
    expect(find.text(words.itemMarketPrice(money(16000))), findsOneWidget);
    expect(find.text(words.itemNote('Qizilini oling')), findsOneWidget);
    expect(find.textContaining(words.shopperLineCap('1,5')), findsOneWidget);
    expect(
      text(tester, 'shopper-line-replacement-$shopperLineTomato'),
      '${words.itemReplacedWith('Olcha pomidor')}, '
      '${words.replacementAutomatic}, ${words.itemMarketPrice(money(15500))}',
    );
    expect(find.text(words.shopperPriceLimit(money(19000))), findsOneWidget);
    expect(
      text(tester, 'shopper-line-question-$shopperLineTomato'),
      words.shopperQuestion(words.approvalTypePrice, '27.09.2026 13:00'),
    );
    // A fixed loaf bought as itself: no bound, and no price paid to show.
    expect(byKey('shopper-line-limit-$shopperLineBread'), findsNothing);
    expect(
      text(tester, 'shopper-line-bought-$shopperLineBread'),
      words.itemBought('2 ${words.unitPiece}'),
    );
    expect(find.textContaining(words.itemPricePaid('')), findsNothing);
  });

  testWidgets('the Shopper accepts, then starts; while shopping they can call '
      'the Customer', (WidgetTester tester) async {
    shopper.afterAction[shopperOrderA] = shopperOrder(accepted: true);
    await open(tester);
    await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
    expect(byKey('shopper-start'), findsNothing);
    expect(byKey('call-customer'), findsNothing);

    await tapAndSettle(tester, byKey('shopper-accept'));
    expect(shopper.actions, <String>['accept:$shopperOrderA']);
    expect(byKey('shopper-accept'), findsNothing);
    expect(byKey('shopper-start'), findsOneWidget);
    expect(byKey('call-customer'), findsNothing);

    shopper.afterAction[shopperOrderA] = shopperOrder(status: 'shopping');
    await tapAndSettle(tester, byKey('shopper-start'));
    expect(shopper.actions, <String>[
      'accept:$shopperOrderA',
      'start:$shopperOrderA',
    ]);
    expect(byKey('shopper-start'), findsNothing);
    expect(
      find.text(l10n(tester).callCustomer('+998 90 111 22 33')),
      findsOneWidget,
    );

    await tapAndSettle(tester, byKey('call-customer'));
    expect(phone.calls, <String>['+998901112233']);

    // A phone that cannot place the call says so, with the number.
    phone.opens = false;
    await tapAndSettle(tester, byKey('call-customer'));
    expect(
      find.text(l10n(tester).callFailed('+998 90 111 22 33')),
      findsOneWidget,
    );
  });

  testWidgets('a refusal is said and the order loaded again', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
    shopper
      ..actionFailure = const ApiRefusal(
        ApiError(status: 409, code: 'order_state_conflict'),
      )
      ..loads.clear();

    await tapAndSettle(tester, byKey('shopper-accept'));

    expect(find.text(l10n(tester).errorOrderStateConflict), findsOneWidget);
    expect(shopper.loads, contains('order:$shopperOrderA'));
  });

  testWidgets('one action at a time, and the buttons wait for the order it '
      'loads', (WidgetTester tester) async {
    shopper.afterAction[shopperOrderA] = shopperOrder(accepted: true);
    await open(tester);
    await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
    final Completer<void> hold = Completer<void>();
    shopper.hold = hold;

    await tester.tap(byKey('shopper-accept'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(byKey('shopper-accept')).onPressed,
      isNull,
    );
    shopper.hold = null;
    final Completer<void> reload = Completer<void>();
    shopper.holdOrder = reload;
    hold.complete();
    await tester.pump();
    await tester.pump();

    expect(shopper.actions, hasLength(1));
    expect(
      tester.widget<FilledButton>(byKey('shopper-accept')).onPressed,
      isNull,
      reason: 'the order the acceptance loads has not arrived',
    );
    shopper.holdOrder = null;
    reload.complete();
    await tester.pumpAndSettle();
    expect(byKey('shopper-start'), findsOneWidget);
  });

  group('the refresh while shown (DL-54 (15))', () {
    testWidgets('the list and the order ask again every ten seconds, and the '
        'list waits while an order is opened over it', (
      WidgetTester tester,
    ) async {
      await open(tester);
      expect(count('orders:1'), 1);

      await tester.pump(const Duration(seconds: 9));
      expect(count('orders:1'), 1);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(count('orders:1'), 2);

      await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
      final int list = count('orders:1');
      expect(count('order:$shopperOrderA'), 1);
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      expect(count('order:$shopperOrderA'), 3);
      expect(count('orders:1'), list, reason: 'the list is not shown');
    });

    testWidgets(
      'a refresh that fails stops, says so, and waits for the retry',
      (WidgetTester tester) async {
        await open(tester);
        shopper.listFailure = const NetworkFailure();

        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();
        expect(count('orders:1'), 2);
        expect(find.text(l10n(tester).errorNetwork), findsOneWidget);

        await tester.pump(const Duration(seconds: 60));
        await tester.pumpAndSettle();
        expect(count('orders:1'), 2, reason: 'a refresh is not a retry');

        shopper.listFailure = null;
        await tapAndSettle(tester, byKey('retry-load'));
        expect(count('orders:1'), 3);
        expect(byKey('shopper-order-$shopperOrderA'), findsOneWidget);
        await tester.pump(const Duration(seconds: 10));
        await tester.pump();
        expect(count('orders:1'), 4, reason: 'the refresh comes back');
      },
    );
  });

  testWidgets('the app bar keeps two buttons; the menu holds Customer mode '
      'and the way out', (WidgetTester tester) async {
    await open(tester, size: const Size(360, 800));
    final AppLocalizations words = l10n(tester);

    expect(find.text(words.shellShopper), findsOneWidget);
    expect(byKey('logout-button'), findsNothing);
    await tapAndSettle(tester, byKey('staff-menu'));
    expect(find.text(words.switchToCustomer), findsOneWidget);
    await tapAndSettle(tester, byKey('logout-button'));

    expect(auth.calls, contains('logout:staff'));
  });

  testWidgets('a phone-wide window with large text fits the list and an order '
      'in both languages', (WidgetTester tester) async {
    shopper.details[shopperOrderA] = shopperOrder(status: 'shopping');
    for (final Locale language in const <Locale>[Locale('uz'), Locale('ru')]) {
      await open(
        tester,
        size: const Size(360, 800),
        textScale: 2,
        device: language,
      );
      expect(tester.takeException(), isNull);
      await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
      await tester.drag(byKey('shopper-order'), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The next language starts from a fresh app, not this one's route.
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
