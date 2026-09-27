import 'dart:async';

import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_cart_repository.dart';
import '../../../support/fake_checkout_repository.dart';
import '../../../support/fake_customer_orders_repository.dart';
import '../../../support/fake_customer_repositories.dart';
import '../../../support/in_memory_stores.dart';

/// The checkout of `docs/09` sections 18 and 19 through the real router,
/// cart and checkout screens, with the repositories faked.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCartRepository cart;
  late FakeCheckoutRepository checkout;
  late FakeAddressesRepository addresses;
  late FakeCustomerOrdersRepository orders;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  BuildContext anywhere(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).last);

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(anywhere(tester));

  String top(WidgetTester tester) =>
      GoRouter.of(anywhere(tester))
          .routerDelegate
          .currentConfiguration
          .last
          .matchedLocation;

  bool enabled(WidgetTester tester, String key) =>
      tester.widget<RadioListTile<String>>(byKey(key)).enabled ?? true;

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.customer] = 'c';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.customer] = user(id: 'c');
    cart = FakeCartRepository(
      cart: cartOf(<Map<String, Object?>>[cartLineJson()]),
    );
    checkout = FakeCheckoutRepository();
    orders = FakeCustomerOrdersRepository(
      orders: <Map<String, Object?>>[customerOrderJson(id: placedOrderId)],
    );
    addresses = FakeAddressesRepository(
      rows: <Address>[
        address(),
        address(id: 'a-2', label: 'Ish', street: 'Navoiy', house: '5'),
      ],
    );
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(800, 2400),
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
        cart: cart,
        checkout: checkout,
        addresses: addresses,
        orders: orders,
        device: device,
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(anywhere(tester)).push('/customer/cart');
    await tester.pumpAndSettle();
    // On a small window the way to the checkout is below the lines.
    await tester.scrollUntilVisible(
      byKey('go-to-checkout'),
      300,
      scrollable: find
          .descendant(
            of: byKey('cart-lines'),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(byKey('go-to-checkout'));
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    // A lazy list builds only what is near the screen: scroll to it first.
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

  Future<void> calculate(WidgetTester tester, {String address = 'a-1'}) async {
    await tapAndSettle(tester, byKey('checkout-address-$address'));
    await tapAndSettle(tester, byKey('checkout-calculate'));
  }

  testWidgets('an address, cash, the wish, the preview, then the order', (
    WidgetTester tester,
  ) async {
    checkout.outsideHours = true;
    await open(tester);
    final AppLocalizations words = l10n(tester);

    expect(
      tester.widget<RadioListTile<Object>>(byKey('pay-online')).enabled,
      isFalse,
    );
    expect(find.text(words.checkoutOnlineUnavailable), findsOneWidget);
    expect(byKey('checkout-confirm'), findsNothing, reason: 'no preview yet');

    await tester.enterText(byKey('checkout-delivery-wish'), '  Kechqurun ');
    await calculate(tester);

    expect(checkout.previews.single.addressId, 'a-1');
    expect(checkout.previews.single.deliveryTimeNote, 'Kechqurun');
    expect(
      find.text('${words.checkoutAddress}: Amir Temur, 12'),
      findsOneWidget,
      reason: 'the preview says where',
    );
    expect(
      find.text('${words.orderSectionDeliveryWish}: Kechqurun'),
      findsOneWidget,
    );
    expect(
      find.text(
        '${MoneyFormat.uzs(47600, AppLanguage.uz)} · ${words.totalKindEstimate}',
      ),
      findsOneWidget,
    );
    expect(find.text(words.checkoutEstimateExplain), findsOneWidget);
    expect(find.text(words.checkoutClosedUntil('08:00')), findsOneWidget);

    final int cartLoads = cart.calls.length;
    await tapAndSettle(tester, byKey('checkout-confirm'));

    expect(checkout.placements.single.$1, 'token-1');
    expect(find.text(words.checkoutPlaced('1001')), findsOneWidget);
    expect(cart.calls.length, greaterThan(cartLoads), reason: 'cart reloaded');
    await tapAndSettle(tester, byKey('checkout-back-to-catalog'));
    expect(byKey('catalog-search'), findsOneWidget);
  });

  testWidgets('the placed order opens over the catalog, not the checkout', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await calculate(tester);
    await tapAndSettle(tester, byKey('checkout-confirm'));

    await tapAndSettle(tester, byKey('checkout-open-order'));
    expect(top(tester), AppPaths.customerOrder(placedOrderId));
    expect(byKey('order-status'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(byKey('catalog-search'), findsOneWidget);
  });

  testWidgets('what a preview was asked for cannot change while it runs', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tapAndSettle(tester, byKey('checkout-address-a-1'));
    final Completer<void> hold = Completer<void>();
    checkout.hold = hold;

    await tester.tap(byKey('checkout-calculate'));
    await tester.pump();

    expect(enabled(tester, 'checkout-address-a-2'), isFalse);
    expect(
      tester.widget<TextFormField>(byKey('checkout-delivery-wish')).enabled,
      isFalse,
    );
    checkout.hold = null;
    hold.complete();
    await tester.pumpAndSettle();
    expect(enabled(tester, 'checkout-address-a-2'), isTrue);

    // A change afterwards drops the preview.
    await tapAndSettle(tester, byKey('checkout-address-a-2'));
    expect(byKey('checkout-confirm'), findsNothing);
  });

  testWidgets(
    'a retry of a confirmation whose outcome is unknown reuses its key, and nothing else may change',
    (WidgetTester tester) async {
      await open(tester);
      await calculate(tester);

      checkout.placeFailure = const NetworkFailure();
      await tapAndSettle(tester, byKey('checkout-confirm'));

      expect(find.text(l10n(tester).errorNetwork), findsOneWidget);
      expect(byKey('checkout-unconfirmed'), findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(byKey('checkout-calculate')).onPressed,
        isNull,
      );
      expect(enabled(tester, 'checkout-address-a-2'), isFalse);
      expect(
        tester.widget<TextFormField>(byKey('checkout-delivery-wish')).enabled,
        isFalse,
      );

      // The order was placed after all: the same confirmation replays it.
      await tapAndSettle(tester, byKey('checkout-confirm'));
      expect(checkout.placements, hasLength(2));
      expect(checkout.placements[1], checkout.placements[0]);
      expect(find.text(l10n(tester).checkoutPlaced('1001')), findsOneWidget);
    },
  );

  testWidgets(
    'a confirmation whose outcome is unknown waits in the cart after the Customer left',
    (WidgetTester tester) async {
      await open(tester);
      await tester.enterText(byKey('checkout-delivery-wish'), 'Kechqurun');
      await calculate(tester);
      checkout.placeFailure = const NetworkFailure();
      await tapAndSettle(tester, byKey('checkout-confirm'));
      final (String token, String key) = checkout.placements.single;

      GoRouter.of(anywhere(tester)).pop();
      await tester.pumpAndSettle();
      expect(byKey('cart-unconfirmed-order'), findsOneWidget);

      await tapAndSettle(tester, byKey('cart-check-unconfirmed'));
      expect(byKey('checkout-unconfirmed'), findsOneWidget);
      // As it was sent: the address, the wish, and nothing else to change.
      expect(
        tester
            .widget<TextFormField>(byKey('checkout-delivery-wish'))
            .controller!
            .text,
        'Kechqurun',
      );
      expect(
        find.text('${l10n(tester).checkoutAddress}: Amir Temur, 12'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextButton>(byKey('checkout-add-address')).onPressed,
        isNull,
      );
      await tapAndSettle(tester, byKey('checkout-confirm'));

      expect(checkout.placements.last, (token, key));
      expect(find.text(l10n(tester).checkoutPlaced('1001')), findsOneWidget);
      GoRouter.of(anywhere(tester)).pop();
      await tester.pumpAndSettle();
      expect(byKey('cart-unconfirmed-order'), findsNothing);
    },
  );

  testWidgets(
    'a refused confirmation frees the checkout, and a new preview brings a new key',
    (WidgetTester tester) async {
      await open(tester);
      await calculate(tester);
      checkout.placeFailure = const ApiRefusal(
        ApiError(status: 409, code: 'product_unavailable'),
      );
      await tapAndSettle(tester, byKey('checkout-confirm'));
      expect(
        find.text(l10n(tester).errorCheckoutProductsUnavailable),
        findsOneWidget,
      );
      expect(byKey('checkout-unconfirmed'), findsNothing);

      await tester.enterText(byKey('checkout-delivery-wish'), 'Ertalab');
      await tester.pump();
      expect(byKey('checkout-confirm'), findsNothing);
      await tapAndSettle(tester, byKey('checkout-calculate'));
      expect(
        find.text(l10n(tester).errorCheckoutProductsUnavailable),
        findsNothing,
        reason: "the old confirmation's failure is gone with it",
      );
      await tapAndSettle(tester, byKey('checkout-confirm'));

      final (String token, String key) = checkout.placements.last;
      expect(token, 'token-2');
      expect(key, isNot(checkout.placements.first.$2));
    },
  );

  testWidgets(
    'a stale confirmation previews again by itself and says so, and a later failure shows as itself',
    (WidgetTester tester) async {
      await open(tester);
      await calculate(tester);

      checkout.placeFailure = const ApiRefusal(
        ApiError(status: 409, code: 'checkout_snapshot_stale'),
      );
      await tapAndSettle(tester, byKey('checkout-confirm'));

      expect(checkout.previews, hasLength(2));
      expect(checkout.previews[1].addressId, 'a-1');
      expect(byKey('checkout-refreshed'), findsOneWidget);

      checkout.placeFailure = const NetworkFailure();
      await tapAndSettle(tester, byKey('checkout-confirm'));
      expect(checkout.placements.last.$1, 'token-2');
      expect(
        checkout.placements.last.$2,
        isNot(checkout.placements.first.$2),
        reason: 'a new preview, a new key',
      );
      expect(byKey('checkout-refreshed'), findsNothing);
      expect(find.text(l10n(tester).errorNetwork), findsOneWidget);
    },
  );

  testWidgets('a refused recalculation leaves no old total to confirm', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await calculate(tester);
    expect(byKey('checkout-confirm'), findsOneWidget);

    checkout.previewFailure = const ApiRefusal(
      ApiError(status: 422, code: 'address_outside_service_area'),
    );
    await tapAndSettle(tester, byKey('checkout-calculate'));

    expect(byKey('checkout-confirm'), findsNothing);
    expect(find.text(l10n(tester).addressOutsideAreaPlain), findsOneWidget);
  });

  testWidgets('an address gone is no longer chosen', (
    WidgetTester tester,
  ) async {
    await open(tester);
    checkout.previewFailure = const ApiRefusal(
      ApiError(status: 404, code: 'resource_not_found'),
    );
    addresses.rows = <Address>[
      address(id: 'a-2', label: 'Ish', street: 'Navoiy', house: '5'),
    ];
    await calculate(tester);

    expect(find.text(l10n(tester).errorAddressGone), findsOneWidget);
    expect(byKey('checkout-address-a-1'), findsNothing);
    expect(
      tester.widget<OutlinedButton>(byKey('checkout-calculate')).onPressed,
      isNull,
    );
  });

  group('each refusal has its own words', () {
    Future<void> refused(
      WidgetTester tester,
      String code, {
      int status = 409,
      Map<String, Object?> details = const <String, Object?>{},
    }) async {
      await open(tester);
      checkout.previewFailure = ApiRefusal(
        ApiError(status: status, code: code, details: details),
      );
      await calculate(tester);
    }

    testWidgets('the minimum, with its amount and the shortfall', (
      WidgetTester tester,
    ) async {
      await refused(
        tester,
        'minimum_order_not_reached',
        details: <String, Object?>{
          'minimum_order_uzs': 100000,
          'shortfall_uzs': 72400,
        },
      );
      expect(
        find.text(
          l10n(tester).errorMinimumOrder(
            MoneyFormat.uzs(100000, AppLanguage.uz),
            MoneyFormat.uzs(72400, AppLanguage.uz),
          ),
        ),
        findsOneWidget,
      );
      await tapAndSettle(tester, byKey('checkout-back-to-cart'));
      expect(top(tester), '/customer/cart');
    });

    testWidgets('an address outside the area, with the distances', (
      WidgetTester tester,
    ) async {
      await refused(
        tester,
        'address_outside_service_area',
        status: 422,
        details: <String, Object?>{
          'distance_km': '7.40',
          'max_distance_km': '5.00',
        },
      );
      expect(
        find.text(l10n(tester).addressOutsideArea('7,40', '5,00')),
        findsOneWidget,
      );
    });

    testWidgets('a profile without a name, with the way to the profile', (
      WidgetTester tester,
    ) async {
      await refused(tester, 'customer_profile_incomplete');
      expect(find.text(l10n(tester).errorProfileIncomplete), findsOneWidget);
      await tapAndSettle(tester, byKey('checkout-open-profile'));
      expect(top(tester), AppPaths.customerProfile);
    });

    testWidgets(
      'a product that cannot be ordered, with the way back to the cart',
      (WidgetTester tester) async {
        await refused(tester, 'product_unavailable');
        expect(
          find.text(l10n(tester).errorCheckoutProductsUnavailable),
          findsOneWidget,
        );
        expect(byKey('checkout-back-to-cart'), findsOneWidget);
      },
    );

    for (final (String code, int status, String Function(AppLocalizations) text)
        in <(String, int, String Function(AppLocalizations))>[
          (
            'address_incomplete',
            409,
            (AppLocalizations l) => l.errorAddressIncomplete,
          ),
          ('cart_empty', 409, (AppLocalizations l) => l.errorCartEmpty),
          (
            'payment_method_unavailable',
            409,
            (AppLocalizations l) => l.errorPaymentMethodUnavailable,
          ),
          (
            'checkout_configuration_incomplete',
            409,
            (AppLocalizations l) => l.errorConfigurationIncomplete,
          ),
        ]) {
      testWidgets(code, (WidgetTester tester) async {
        await refused(tester, code, status: status);
        expect(find.text(text(l10n(tester))), findsOneWidget);
        expect(byKey('checkout-confirm'), findsNothing);
      });
    }

    testWidgets(
      'an order still being sent, which also keeps the checkout as it was sent',
      (WidgetTester tester) async {
        await open(tester);
        await calculate(tester);
        checkout.placeFailure = const ApiRefusal(
          ApiError(status: 409, code: 'idempotency_in_progress'),
        );
        await tapAndSettle(tester, byKey('checkout-confirm'));
        expect(find.text(l10n(tester).errorOrderInProgress), findsOneWidget);
        expect(byKey('checkout-unconfirmed'), findsOneWidget);
      },
    );
  });

  testWidgets('without an address it says so and offers to add one', (
    WidgetTester tester,
  ) async {
    addresses = FakeAddressesRepository(rows: <Address>[]);
    await open(tester);

    expect(byKey('checkout-no-address'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(byKey('checkout-calculate')).onPressed,
      isNull,
    );
    await tapAndSettle(tester, byKey('checkout-add-address'));
    expect(top(tester), AppPaths.customerNewAddress);
  });

  testWidgets('a wish longer than 160 characters is refused before sending', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.enterText(
      byKey('checkout-delivery-wish'),
      List<String>.filled(161, 'a').join(),
    );
    await calculate(tester);

    expect(find.text(l10n(tester).fieldTooLong(160)), findsOneWidget);
    expect(checkout.previews, isEmpty);
  });

  testWidgets('one confirmation at a time', (WidgetTester tester) async {
    await open(tester);
    await calculate(tester);
    final Completer<void> hold = Completer<void>();
    checkout.hold = hold;

    await tester.tap(byKey('checkout-confirm'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(byKey('checkout-confirm')).onPressed,
      isNull,
    );
    checkout.hold = null;
    hold.complete();
    await tester.pumpAndSettle();
    expect(checkout.placements, hasLength(1));
  });

  testWidgets('a preview never sent is not kept once the Customer leaves', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await calculate(tester);
    expect(byKey('checkout-confirm'), findsOneWidget);

    GoRouter.of(anywhere(tester)).pop();
    await tester.pumpAndSettle();
    await tapAndSettle(tester, byKey('go-to-checkout'));

    expect(byKey('checkout-confirm'), findsNothing);
    expect(byKey('cart-unconfirmed-order'), findsNothing);
  });

  testWidgets('a replay of an order cancelled meanwhile says it is cancelled', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await calculate(tester);
    checkout.placedAnswer = placedJson()
      ..['totals'] = <String, Object?>{
        'merchandise_subtotal_uzs': null,
        'service_fee_uzs': null,
        'delivery_fee_uzs': null,
        'total_uzs': null,
        'total_kind': 'none',
      };

    await tapAndSettle(tester, byKey('checkout-confirm'));

    expect(
      find.text(l10n(tester).checkoutPlacedCancelled('1001')),
      findsOneWidget,
    );
    expect(find.text(l10n(tester).totalNothingDue), findsOneWidget);
  });

  testWidgets('leaving while a stale confirmation previews again is safe', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await calculate(tester);
    checkout.placeFailure = const ApiRefusal(
      ApiError(status: 409, code: 'checkout_snapshot_stale'),
    );
    // The placement answers stale at once; the preview it asks for waits.
    final Completer<void> hold = Completer<void>();
    checkout.previewHold = hold;

    await tester.tap(byKey('checkout-confirm'));
    await tester.pump();
    await tester.pump();
    expect(checkout.previews, hasLength(2), reason: 'the new preview runs');
    GoRouter.of(anywhere(tester)).pop();
    await tester.pumpAndSettle();
    checkout.previewHold = null;
    hold.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('a server error on confirming asks for the cart again', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await calculate(tester);
    final int before = cart.calls.where((String c) => c == 'cart').length;
    checkout.placeFailure = const ApiRefusal(
      ApiError(status: 500, code: 'server_error'),
    );

    await tapAndSettle(tester, byKey('checkout-confirm'));

    expect(byKey('checkout-unconfirmed'), findsOneWidget);
    expect(
      cart.calls.where((String c) => c == 'cart').length,
      greaterThan(before),
    );
  });

  for (final Locale language in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'the checkout, a refusal and the placed order fit a phone with large text (${language.languageCode})',
      (WidgetTester tester) async {
        checkout.outsideHours = true;
        await open(
          tester,
          size: const Size(360, 800),
          textScale: 2,
          device: language,
        );
        checkout.previewFailure = const ApiRefusal(
          ApiError(
            status: 409,
            code: 'minimum_order_not_reached',
            details: <String, Object?>{
              'minimum_order_uzs': 100000,
              'shortfall_uzs': 72400,
            },
          ),
        );
        await calculate(tester);
        expect(tester.takeException(), isNull);

        await tapAndSettle(tester, byKey('checkout-calculate'));
        expect(byKey('checkout-preview'), findsOneWidget);
        await tapAndSettle(tester, byKey('checkout-confirm'));
        expect(byKey('checkout-placed'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
