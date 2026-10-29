import 'dart:async';

import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/active_mode_bar.dart';
import 'package:baraka_bozor/core/widgets/fold.dart';
import 'package:baraka_bozor/features/addresses/application/delivery_address.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:baraka_bozor/features/addresses/application/addresses_controllers.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/address_map.dart';
import 'package:baraka_bozor/features/profile/domain/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_address_map.dart';
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
  late FakeProfileRepository profile;
  late InMemoryPreferenceStore preferences;

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

  setUp(() {
    preferences = InMemoryPreferenceStore();
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
    profile = FakeProfileRepository();
    addresses = FakeAddressesRepository(
      rows: <Address>[
        address(),
        address(id: 'a-2', label: 'Ish', street: 'Navoiy', house: '5'),
      ],
    );
  });

  /// Opens the checkout from the cart. The figures come on opening; with
  /// [settle] false the screen is left as it is while a held request runs.
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(800, 2400),
    double textScale = 1,
    Locale device = const Locale('uz'),
    bool settle = true,
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
        profile: profile,
        orders: orders,
        preferences: preferences,
        device: device,
        overrides: [addressMapProvider.overrideWithValue(FakeAddressMap())],
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
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
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

  Future<void> order(WidgetTester tester) =>
      tapAndSettle(tester, byKey('checkout-confirm'));

  /// The Customer picks [id] in the delivery address sheet.
  Future<void> pick(WidgetTester tester, String id) async {
    await tapAndSettle(tester, byKey('checkout-address-change'));
    await tapAndSettle(tester, byKey('delivery-address-$id'));
  }

  bool orderActive(WidgetTester tester) =>
      tester.widget<FilledButton>(byKey('checkout-confirm')).onPressed != null;

  bool wishActive(WidgetTester tester) =>
      tester.widget<TextFormField>(byKey('checkout-delivery-wish')).enabled;

  bool changeActive(WidgetTester tester) =>
      tester.widget<TextButton>(byKey('checkout-address-change')).onPressed !=
      null;

  Finder inCard(String text) =>
      find.descendant(of: byKey('checkout-address'), matching: find.text(text));

  testWidgets('it previews on opening, and the order is placed on one tap', (
    WidgetTester tester,
  ) async {
    await open(tester);
    final AppLocalizations words = l10n(tester);

    expect(checkout.previews, hasLength(1));
    expect(checkout.previews.single.addressId, 'a-1');
    expect(checkout.previews.single.deliveryTimeNote, isNull);
    expect(byKey('pay-cash'), findsOneWidget);
    expect(find.byType(RadioListTile<Object>), findsNothing);
    expect(
      find.descendant(
        of: byKey('pay-online-soon'),
        matching: find.text(words.checkoutOnlineSoon),
      ),
      findsOneWidget,
    );
    expect(byKey('checkout-total'), findsOneWidget);

    await tester.enterText(byKey('checkout-delivery-wish'), '  Kechqurun ');
    await tester.pump();
    expect(checkout.previews, hasLength(1), reason: 'typing asks nothing');
    expect(byKey('checkout-total'), findsOneWidget, reason: 'figures stay');

    final int cartLoads = cart.calls.length;
    await order(tester);

    expect(checkout.previews, hasLength(2));
    expect(checkout.previews.last.deliveryTimeNote, 'Kechqurun');
    expect(checkout.placements.single.$1, 'token-2');
    expect(find.text(words.checkoutPlaced('1001')), findsOneWidget);
    expect(cart.calls.length, greaterThan(cartLoads), reason: 'cart reloaded');
    await tapAndSettle(tester, byKey('checkout-to-home'));
    expect(byKey('catalog-search'), findsOneWidget);
  });

  testWidgets(
    'a wish typed after the preview is previewed before it is placed',
    (WidgetTester tester) async {
      await open(tester);
      await tester.enterText(byKey('checkout-delivery-wish'), 'после 18:00');
      await tester.pump();

      await order(tester);

      expect(checkout.placements.single.$1, 'token-2');
      expect(checkout.previews.last.deliveryTimeNote, 'после 18:00');
    },
  );

  testWidgets('the card names the recipient from the profile', (
    WidgetTester tester,
  ) async {
    profile.current = const CustomerProfile(
      id: 'c',
      phone: '+998901234567',
      fullName: 'Aziz Karimov',
    );
    await open(tester);

    expect(
      find.descendant(
        of: byKey('checkout-recipient'),
        matching: find.text('Aziz Karimov'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the closed banner shows the opening time', (
    WidgetTester tester,
  ) async {
    checkout.outsideHours = true;
    await open(tester);

    expect(
      find.descendant(
        of: byKey('checkout-closed'),
        matching: find.text(l10n(tester).checkoutClosedBanner('08:00')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the placed window names the order and says how to pay', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await order(tester);

    expect(find.text(l10n(tester).checkoutPlaced('1001')), findsOneWidget);
    expect(find.text(l10n(tester).checkoutPlacedCash), findsOneWidget);
    expect(byKey('checkout-open-order'), findsOneWidget);
    expect(
      find.text(l10n(tester).checkoutPlacedOpensAt('08:00')),
      findsNothing,
    );
  });

  testWidgets('outside the hours it says when collecting starts', (
    WidgetTester tester,
  ) async {
    checkout.outsideHours = true;
    await open(tester);
    await order(tester);

    expect(
      find.text(l10n(tester).checkoutPlacedOpensAt('08:00')),
      findsOneWidget,
    );
  });

  testWidgets('back from the placed window goes home', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await order(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(top(tester), AppPaths.customer);
  });

  testWidgets('"На главную" goes home', (WidgetTester tester) async {
    await open(tester);
    await order(tester);

    await tapAndSettle(tester, byKey('checkout-to-home'));
    expect(top(tester), AppPaths.customer);
  });

  testWidgets('the placed window\'s buttons are kit buttons', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await order(tester);

    final OutlinedButton home = tester.widget<OutlinedButton>(
      byKey('checkout-to-home'),
    );
    expect(
      home.style!.shape!.resolve(<WidgetState>{}),
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
    expect(
      home.style!.foregroundColor!.resolve(<WidgetState>{}),
      KitColors.ink,
    );
  });

  testWidgets('the placed order opens over the catalog, not the checkout', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await order(tester);

    await tapAndSettle(tester, byKey('checkout-open-order'));
    expect(top(tester), AppPaths.customerOrder(placedOrderId));
    expect(byKey('order-status'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(byKey('catalog-search'), findsOneWidget);
  });

  testWidgets(
    'while a preview runs the wish can be typed; the address and Заказать wait',
    (WidgetTester tester) async {
      final Completer<void> hold = Completer<void>();
      checkout.previewHold = hold;
      await open(tester, settle: false);

      expect(wishActive(tester), isTrue);
      expect(changeActive(tester), isFalse);
      expect(orderActive(tester), isFalse);

      checkout.previewHold = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(wishActive(tester), isTrue);
      expect(changeActive(tester), isTrue);
      expect(orderActive(tester), isTrue);
    },
  );

  testWidgets(
    'a wish typed during the opening preview is previewed again before placing',
    (WidgetTester tester) async {
      final Completer<void> hold = Completer<void>();
      checkout.previewHold = hold;
      await open(tester, settle: false);

      await tester.enterText(byKey('checkout-delivery-wish'), 'после 18:00');
      await tester.pump();
      checkout.previewHold = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(checkout.previews, hasLength(1), reason: 'typing asks nothing');

      await order(tester);

      expect(checkout.previews, hasLength(2));
      expect(checkout.previews.last.deliveryTimeNote, 'после 18:00');
      expect(checkout.placements.single.$1, 'token-2');
    },
  );

  testWidgets('the wish survives a trip to the cart and back', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.enterText(byKey('checkout-delivery-wish'), 'после 18:00');
    await tester.pump();

    GoRouter.of(anywhere(tester)).pop();
    await tester.pumpAndSettle();
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

    expect(
      tester
          .widget<TextFormField>(byKey('checkout-delivery-wish'))
          .controller!
          .text,
      'после 18:00',
    );
    expect(checkout.previews.last.deliveryTimeNote, 'после 18:00');
  });

  testWidgets(
    'a sent confirmation comes back with the wish it was sent with, locked',
    (WidgetTester tester) async {
      await open(tester);
      await tester.enterText(byKey('checkout-delivery-wish'), 'Kechqurun');
      checkout.placeFailure = const NetworkFailure();
      await order(tester);

      GoRouter.of(anywhere(tester)).pop();
      await tester.pumpAndSettle();
      await tapAndSettle(tester, byKey('cart-check-unconfirmed'));

      expect(
        tester
            .widget<TextFormField>(byKey('checkout-delivery-wish'))
            .controller!
            .text,
        'Kechqurun',
      );
      expect(wishActive(tester), isFalse);
    },
  );

  testWidgets(
    'a retry of a confirmation whose outcome is unknown reuses its key, and nothing else may change',
    (WidgetTester tester) async {
      await open(tester);

      checkout.placeFailure = const NetworkFailure();
      await order(tester);

      expect(find.text(l10n(tester).errorNetwork), findsOneWidget);
      expect(byKey('checkout-unconfirmed'), findsOneWidget);
      expect(changeActive(tester), isFalse);
      expect(wishActive(tester), isFalse);

      // The order was placed after all: the same confirmation replays it.
      await order(tester);
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
      checkout.placeFailure = const NetworkFailure();
      await order(tester);
      final (String token, String key) = checkout.placements.single;
      final int previews = checkout.previews.length;

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
      expect(inCard('Uy'), findsOneWidget);
      expect(changeActive(tester), isFalse);
      expect(wishActive(tester), isFalse);
      expect(checkout.previews, hasLength(previews), reason: 'none asked');
      await order(tester);

      expect(checkout.placements.last, (token, key));
      expect(find.text(l10n(tester).checkoutPlaced('1001')), findsOneWidget);
      GoRouter.of(anywhere(tester)).pop();
      await tester.pumpAndSettle();
      expect(byKey('cart-unconfirmed-order'), findsNothing);
    },
  );

  testWidgets(
    'a refused confirmation frees the checkout, and the next tap brings a new key',
    (WidgetTester tester) async {
      await open(tester);
      checkout.placeFailure = const ApiRefusal(
        ApiError(status: 409, code: 'product_unavailable'),
      );
      await order(tester);
      expect(
        find.text(l10n(tester).errorCheckoutProductsUnavailable),
        findsOneWidget,
      );
      expect(byKey('checkout-unconfirmed'), findsNothing);
      expect(orderActive(tester), isTrue);

      await order(tester);

      expect(
        find.text(l10n(tester).errorCheckoutProductsUnavailable),
        findsNothing,
        reason: "the old confirmation's failure is gone with it",
      );
      expect(checkout.previews, hasLength(2));
      final (String token, String key) = checkout.placements.last;
      expect(token, 'token-2');
      expect(key, isNot(checkout.placements.first.$2));
    },
  );

  testWidgets(
    'a stale confirmation previews again by itself, and places when the offer is the same',
    (WidgetTester tester) async {
      await open(tester);
      checkout.placeFailure = const ApiRefusal(
        ApiError(status: 409, code: 'checkout_snapshot_stale'),
      );

      await order(tester);

      expect(checkout.previews, hasLength(2));
      expect(checkout.previews[1].addressId, 'a-1');
      expect(checkout.placements, hasLength(2));
      expect(checkout.placements.last.$1, 'token-2');
      expect(checkout.placements.last.$2, isNot(checkout.placements.first.$2));
      expect(find.text(l10n(tester).checkoutPlaced('1001')), findsOneWidget);
    },
  );

  testWidgets(
    'a stale confirmation that brings another total shows it and waits for the tap',
    (WidgetTester tester) async {
      await open(tester);
      final AppLocalizations words = l10n(tester);
      checkout.queuedPreviews
        ..add(previewJson(total: 48600))
        ..add(previewJson(total: 48600));
      checkout.placeFailure = const ApiRefusal(
        ApiError(status: 409, code: 'checkout_snapshot_stale'),
      );

      await order(tester);

      expect(checkout.previews, hasLength(2));
      expect(checkout.placements, hasLength(1), reason: 'only the stale one');
      expect(byKey('checkout-refreshed'), findsOneWidget);
      expect(
        find.text(
          words.cartLineEstimate(MoneyFormat.uzs(47600, AppLanguage.uz)),
        ),
        findsOneWidget,
        reason: 'the old total, struck through',
      );
      expect(
        find.text(
          words.cartLineEstimate(MoneyFormat.uzs(48600, AppLanguage.uz)),
        ),
        findsNWidgets(2),
        reason: 'the new total, on the screen and in the footer',
      );

      // The Customer has seen it: the tap places exactly it.
      await order(tester);
      expect(checkout.placements.last.$1, 'token-2');
      expect(find.text(words.checkoutPlaced('1001')), findsOneWidget);
    },
  );

  testWidgets('a refused recalculation leaves no old total to confirm', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.enterText(byKey('checkout-delivery-wish'), 'Ertalab');
    checkout.previewFailure = const ApiRefusal(
      ApiError(status: 422, code: 'address_outside_service_area'),
    );

    await order(tester);

    expect(checkout.placements, isEmpty);
    expect(find.text(l10n(tester).addressOutsideAreaPlain), findsOneWidget);
  });

  group('the delivery address', () {
    testWidgets('checkout opens with the delivery address chosen on the home', (
      WidgetTester tester,
    ) async {
      preferences.values[DeliveryAddressChoice.preferenceKey('c')] = 'a-2';
      await open(tester);

      expect(inCard('Ish'), findsOneWidget);
      expect(checkout.previews.first.addressId, 'a-2');
    });

    testWidgets('without a choice it opens on the newest address', (
      WidgetTester tester,
    ) async {
      await open(tester);

      expect(inCard('Uy'), findsOneWidget);
      expect(checkout.previews.first.addressId, 'a-1');
    });

    testWidgets(
      'another address picked at checkout becomes the delivery address',
      (WidgetTester tester) async {
        await open(tester);
        await pick(tester, 'a-2');

        expect(
          preferences.values[DeliveryAddressChoice.preferenceKey('c')],
          'a-2',
        );
        expect(inCard('Ish'), findsOneWidget);
        expect(checkout.previews.last.addressId, 'a-2');
      },
    );

    testWidgets(
      'an address added at checkout becomes the selected one and the choice',
      (WidgetTester tester) async {
        preferences.values[DeliveryAddressChoice.preferenceKey('c')] = 'a-2';
        await open(tester);
        expect(inCard('Ish'), findsOneWidget);

        await tapAndSettle(tester, byKey('checkout-address-change'));
        await tapAndSettle(tester, byKey('delivery-address-new'));
        await tapAndSettle(tester, byKey('address-point-confirm'));
        await tester.enterText(byKey('field-street'), 'Dacha');
        await tester.enterText(byKey('field-house'), '9');
        await tapAndSettle(tester, byKey('address-save'));

        expect(checkout.previews.last.addressId, 'a-new-1');
        expect(
          preferences.values[DeliveryAddressChoice.preferenceKey('c')],
          'a-new-1',
        );
      },
    );

    testWidgets(
      'a confirmation whose outcome is unknown keeps the address it was sent with',
      (WidgetTester tester) async {
        await open(tester);
        checkout.placeFailure = const NetworkFailure();
        await order(tester);
        GoRouter.of(anywhere(tester)).pop();
        await tester.pumpAndSettle();

        // The home's choice moved meanwhile.
        await ProviderScope.containerOf(anywhere(tester))
            .read(deliveryAddressChoiceProvider('c').notifier)
            .choose('a-2');
        await tapAndSettle(tester, byKey('cart-check-unconfirmed'));

        expect(byKey('checkout-unconfirmed'), findsOneWidget);
        expect(inCard('Uy'), findsOneWidget);
        expect(changeActive(tester), isFalse);
        await order(tester);
        expect(checkout.placements.last, checkout.placements.first);
        expect(checkout.previews, hasLength(1));
      },
    );

    testWidgets('the preselected address is held: when it disappears nothing '
        'else is chosen silently', (WidgetTester tester) async {
      await open(tester);
      expect(inCard('Uy'), findsOneWidget);

      addresses.rows = <Address>[
        address(id: 'a-2', label: 'Ish', street: 'Navoiy', house: '5'),
      ];
      ProviderScope.containerOf(anywhere(tester)).invalidate(addressesProvider);
      await tester.pumpAndSettle();

      expect(inCard(l10n(tester).errorAddressGone), findsOneWidget);
      expect(checkout.previews, hasLength(1), reason: 'none for a-2');
      expect(orderActive(tester), isFalse);
    });

    testWidgets('a chosen address since removed is not preselected', (
      WidgetTester tester,
    ) async {
      preferences.values[DeliveryAddressChoice.preferenceKey('c')] = 'a-gone';
      await open(tester);

      expect(inCard('Uy'), findsOneWidget);
      expect(checkout.previews.first.addressId, 'a-1');
    });
  });

  testWidgets('a held address that disappears is not replaced', (
    WidgetTester tester,
  ) async {
    await open(tester);
    expect(byKey('checkout-total'), findsOneWidget);

    addresses.rows = <Address>[
      address(id: 'a-2', label: 'Ish', street: 'Navoiy', house: '5'),
    ];
    ProviderScope.containerOf(anywhere(tester)).invalidate(addressesProvider);
    await tester.pumpAndSettle();

    expect(inCard(l10n(tester).errorAddressGone), findsOneWidget);
    expect(inCard('Ish'), findsNothing);
    expect(byKey('checkout-total'), findsNothing, reason: 'the figures go');
    expect(checkout.previews, hasLength(1));
    expect(orderActive(tester), isFalse);

    // Only the Customer picks another one.
    await pick(tester, 'a-2');
    expect(checkout.previews.last.addressId, 'a-2');
    expect(inCard('Ish'), findsOneWidget);
    expect(orderActive(tester), isTrue);
  });

  testWidgets('an address gone is no longer chosen', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.enterText(byKey('checkout-delivery-wish'), 'Ertalab');
    checkout.previewFailure = const ApiRefusal(
      ApiError(status: 404, code: 'resource_not_found'),
    );
    addresses.rows = <Address>[
      address(id: 'a-2', label: 'Ish', street: 'Navoiy', house: '5'),
    ];

    await order(tester);

    expect(find.text(l10n(tester).errorAddressGone), findsOneWidget);
    expect(checkout.placements, isEmpty);
    expect(orderActive(tester), isFalse);
  });

  group('each refusal has its own words', () {
    Future<void> refused(
      WidgetTester tester,
      String code, {
      int status = 409,
      Map<String, Object?> details = const <String, Object?>{},
    }) async {
      checkout.previewFailure = ApiRefusal(
        ApiError(status: status, code: code, details: details),
      );
      await open(tester);
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

    testWidgets('a profile without a name, with the way to the name editor', (
      WidgetTester tester,
    ) async {
      await refused(tester, 'customer_profile_incomplete');
      expect(find.text(l10n(tester).errorProfileIncomplete), findsOneWidget);
      await tapAndSettle(tester, byKey('checkout-open-profile'));
      expect(top(tester), AppPaths.customerEditProfile);

      GoRouter.of(anywhere(tester)).pop();
      await tester.pumpAndSettle();
      expect(top(tester), AppPaths.customerCheckout);
    });

    testWidgets(
      'a product that cannot be ordered, with the way back to the cart',
      (WidgetTester tester) async {
        await refused(tester, 'product_unavailable');
        expect(
          find.text(l10n(tester).errorCheckoutProductsUnavailable),
          findsOneWidget,
          reason: 'no line of the cart is named: the footer says it',
        );
        expect(byKey('checkout-back-to-cart'), findsOneWidget);
      },
    );

    testWidgets('a product that went off sale is named, with the way back', (
      WidgetTester tester,
    ) async {
      await refused(
        tester,
        'product_unavailable',
        details: <String, Object?>{
          'product_ids': <Object?>[tomatoProduct],
        },
      );

      expect(byKey('checkout-gone-to-cart'), findsOneWidget);
      expect(find.text('Pomidor'), findsOneWidget);
      expect(
        find.text(l10n(tester).errorCheckoutProductsUnavailable),
        findsNothing,
      );
      await tapAndSettle(tester, byKey('checkout-gone-to-cart'));
      expect(top(tester), '/customer/cart');
    });

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
        expect(checkout.placements, isEmpty);
      });
    }

    testWidgets(
      'an order still being sent, which also keeps the checkout as it was sent',
      (WidgetTester tester) async {
        await open(tester);
        checkout.placeFailure = const ApiRefusal(
          ApiError(status: 409, code: 'idempotency_in_progress'),
        );
        await order(tester);
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

    expect(inCard(l10n(tester).deliveryAddressAdd), findsOneWidget);
    expect(inCard(l10n(tester).checkoutAddressAdd), findsOneWidget);
    expect(checkout.previews, isEmpty);
    expect(orderActive(tester), isFalse);
    await tapAndSettle(tester, byKey('checkout-address-change'));
    expect(top(tester), AppPaths.customerNewAddress);
  });

  testWidgets('without an address a line says why under the grey button', (
    WidgetTester tester,
  ) async {
    addresses = FakeAddressesRepository(rows: <Address>[]);
    await open(tester);

    expect(
      tester.widget<Text>(byKey('checkout-why')).data,
      l10n(tester).checkoutWhyNoAddress,
    );
    expect(orderActive(tester), isFalse);
  });

  testWidgets(
    'a recount shows было → стало above Заказать and goes with the next change',
    (WidgetTester tester) async {
      await open(tester);
      final AppLocalizations words = l10n(tester);
      checkout.queuedPreviews.add(previewJson(total: 48600));
      checkout.placeFailure = const ApiRefusal(
        ApiError(status: 409, code: 'checkout_snapshot_stale'),
      );

      await order(tester);

      final String before = words.cartLineEstimate(
        MoneyFormat.uzs(47600, AppLanguage.uz),
      );
      final String after = words.cartLineEstimate(
        MoneyFormat.uzs(48600, AppLanguage.uz),
      );
      expect(
        tester.getTopLeft(byKey('checkout-refreshed')).dy,
        lessThan(tester.getTopLeft(byKey('checkout-confirm')).dy),
      );
      final String plain = tester
          .widgetList<RichText>(
            find.descendant(
              of: byKey('checkout-refreshed'),
              matching: find.byType(RichText),
            ),
          )
          .map((RichText t) => t.text.toPlainText())
          .join();
      expect(plain, contains(before));
      expect(plain, contains(after));

      await tester.enterText(byKey('checkout-delivery-wish'), 'Qo‘ng‘iroq');
      await tester.pumpAndSettle();
      expect(byKey('checkout-refreshed'), findsNothing);
    },
  );

  testWidgets('every target of the checkout meets iOSTapTargetGuideline', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    checkout.outsideHours = true;
    await open(tester);
    await tapAndSettle(tester, byKey('checkout-items-toggle'));
    checkout.queuedPreviews.add(previewJson(total: 48600));
    checkout.placeFailure = const ApiRefusal(
      ApiError(status: 409, code: 'checkout_snapshot_stale'),
    );
    await order(tester);
    expect(byKey('checkout-refreshed'), findsOneWidget);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('without an address every target meets iOSTapTargetGuideline', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    addresses = FakeAddressesRepository(rows: <Address>[]);
    await open(tester);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'at large text the recount, Итого and Заказать fit a small phone (${device.languageCode})',
      (WidgetTester tester) async {
        await open(
          tester,
          size: const Size(320, 640),
          textScale: 2,
          device: device,
        );
        checkout.queuedPreviews.add(previewJson(total: 48600));
        checkout.placeFailure = const ApiRefusal(
          ApiError(status: 409, code: 'checkout_snapshot_stale'),
        );

        await order(tester);

        expect(tester.takeException(), isNull);
        expect(byKey('checkout-refreshed'), findsOneWidget);
        expect(byKey('checkout-footer-total'), findsOneWidget);
        expect(byKey('checkout-confirm').hitTestable(), findsOneWidget);
      },
    );
  }

  testWidgets('a wish longer than 160 characters is refused before sending', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.enterText(
      byKey('checkout-delivery-wish'),
      List<String>.filled(161, 'a').join(),
    );

    await order(tester);

    expect(find.text(l10n(tester).fieldTooLong(160)), findsOneWidget);
    expect(checkout.previews, hasLength(1), reason: 'only the first');
    expect(checkout.placements, isEmpty);
  });

  testWidgets(
    'Заказать with an over-long wish brings the field into view and focuses it',
    (WidgetTester tester) async {
      await open(tester, size: const Size(320, 640));
      await tester.enterText(
        byKey('checkout-delivery-wish'),
        List<String>.filled(161, 'a').join(),
      );
      await tester.pump();
      final FocusNode wishFocus = tester
          .widget<EditableText>(
            find.descendant(
              of: byKey('checkout-delivery-wish'),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode;
      await tester.drag(byKey('checkout'), const Offset(0, -5000));
      await tester.pumpAndSettle();
      final int previews = checkout.previews.length;
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(wishFocus.hasFocus, isFalse);

      await tester.tap(byKey('checkout-confirm'));
      await tester.pumpAndSettle();

      final Rect field = tester.getRect(byKey('checkout-delivery-wish'));
      expect(field.top, greaterThanOrEqualTo(0));
      expect(field.bottom, lessThanOrEqualTo(640));
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: byKey('checkout-delivery-wish'),
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(find.text(l10n(tester).fieldTooLong(160)), findsOneWidget);
      expect(checkout.previews, hasLength(previews));
      expect(checkout.placements, isEmpty);
    },
  );

  testWidgets(
    'a wish scrolled far away is kept, so Заказать still brings it into view',
    (WidgetTester tester) async {
      await open(tester, size: const Size(320, 640), textScale: 2);
      await tester.enterText(
        byKey('checkout-delivery-wish'),
        List<String>.filled(161, 'a').join(),
      );
      await tester.drag(byKey('checkout'), const Offset(0, -9000));
      await tester.pumpAndSettle();
      // A shorter window: the field is then far out of the laid-out part.
      tester.view.physicalSize = const Size(320, 420);
      await tester.pumpAndSettle();
      await tester.drag(byKey('checkout'), const Offset(0, -9000));
      await tester.pumpAndSettle();
      final int previews = checkout.previews.length;
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.drag(byKey('checkout'), const Offset(0, 30));
      await tester.pumpAndSettle();

      await tester.tap(byKey('checkout-confirm'));
      await tester.pumpAndSettle();

      final Rect field = tester.getRect(byKey('checkout-delivery-wish'));
      expect(field.top, greaterThanOrEqualTo(0));
      expect(field.bottom, lessThanOrEqualTo(420));
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: byKey('checkout-delivery-wish'),
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(find.text(l10n(tester).fieldTooLong(160)), findsOneWidget);
      expect(checkout.previews, hasLength(previews));
      expect(checkout.placements, isEmpty);
    },
  );

  testWidgets('two quick taps place once', (WidgetTester tester) async {
    await open(tester);

    await tester.tap(byKey('checkout-confirm'));
    await tester.tap(byKey('checkout-confirm'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(checkout.placements, hasLength(1));
  });

  testWidgets('one confirmation at a time', (WidgetTester tester) async {
    await open(tester);
    final Completer<void> hold = Completer<void>();
    checkout.hold = hold;

    await tester.tap(byKey('checkout-confirm'));
    await tester.pump();
    expect(orderActive(tester), isFalse);
    checkout.hold = null;
    hold.complete();
    await tester.pumpAndSettle();
    expect(checkout.placements, hasLength(1));
  });

  testWidgets('after a failed first preview the tap only shows the figures', (
    WidgetTester tester,
  ) async {
    checkout.previewFailure = const NetworkFailure();
    await open(tester);
    expect(find.text(l10n(tester).errorNetwork), findsOneWidget);
    expect(byKey('checkout-total'), findsNothing);
    expect(orderActive(tester), isTrue);

    await order(tester);

    expect(checkout.placements, isEmpty);
    expect(byKey('checkout-total'), findsOneWidget);
    expect(find.text(l10n(tester).errorNetwork), findsNothing);
  });

  testWidgets('a preview never sent is not kept once the Customer leaves', (
    WidgetTester tester,
  ) async {
    await open(tester);
    expect(checkout.previews, hasLength(1));

    GoRouter.of(anywhere(tester)).pop();
    await tester.pumpAndSettle();
    await tapAndSettle(tester, byKey('go-to-checkout'));

    expect(checkout.previews, hasLength(2), reason: 'asked again');
    expect(byKey('cart-unconfirmed-order'), findsNothing);
    await order(tester);
    expect(checkout.placements.single.$1, 'token-2');
  });

  testWidgets('a replay of an order cancelled meanwhile says it is cancelled', (
    WidgetTester tester,
  ) async {
    await open(tester);
    checkout.placedAnswer = placedJson()
      ..['totals'] = <String, Object?>{
        'merchandise_subtotal_uzs': null,
        'service_fee_uzs': null,
        'delivery_fee_uzs': null,
        'total_uzs': null,
        'total_kind': 'none',
      };

    await order(tester);

    expect(
      find.text(l10n(tester).checkoutPlacedCancelled('1001')),
      findsOneWidget,
    );
    expect(find.text(l10n(tester).totalNothingDue), findsOneWidget);
  });

  testWidgets(
    'a replay of an order cancelled meanwhile never promises collection',
    (WidgetTester tester) async {
      checkout.outsideHours = true;
      await open(tester);
      checkout.placedAnswer = placedJson()
        ..['totals'] = <String, Object?>{
          'merchandise_subtotal_uzs': null,
          'service_fee_uzs': null,
          'delivery_fee_uzs': null,
          'total_uzs': null,
          'total_kind': 'none',
        };

      await order(tester);

      expect(
        find.text(l10n(tester).checkoutPlacedCancelled('1001')),
        findsOneWidget,
      );
      expect(
        find.text(l10n(tester).checkoutPlacedOpensAt('08:00')),
        findsNothing,
      );
    },
  );

  testWidgets('the placed window keeps the active-mode bar on top', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await order(tester);

    expect(byKey('checkout-placed'), findsOneWidget);
    expect(find.byType(ActiveModeBar), findsOneWidget);
  });

  List<MethodCall> mockHaptics(WidgetTester tester) {
    final List<MethodCall> calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return calls;
  }

  Iterable<MethodCall> lightImpacts(List<MethodCall> calls) => calls.where(
    (MethodCall c) =>
        c.method == 'HapticFeedback.vibrate' &&
        c.arguments == 'HapticFeedbackType.lightImpact',
  );

  double cardOpacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find.ancestor(
          of: byKey('checkout-placed-card'),
          matching: find.byType(FadeTransition),
        ),
      )
      .opacity
      .value;

  double circleScale(WidgetTester tester) => tester
      .widget<ScaleTransition>(
        find
            .ancestor(
              of: byKey('checkout-placed-circle'),
              matching: find.byType(ScaleTransition),
            )
            .first,
      )
      .scale
      .value;

  testWidgets('the placed card rises from below with a light haptic', (
    WidgetTester tester,
  ) async {
    final List<MethodCall> calls = mockHaptics(tester);
    await open(tester);
    await tester.ensureVisible(byKey('checkout-confirm'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('checkout-confirm'));
    await tester.pump();
    await tester.pump();

    expect(byKey('checkout-placed-card'), findsOneWidget);
    expect(lightImpacts(calls), hasLength(1));
    final double startOpacity = cardOpacity(tester);
    final double startBottom = tester
        .getBottomLeft(byKey('checkout-placed-card'))
        .dy;
    expect(startOpacity, lessThan(0.2));
    expect(circleScale(tester), lessThan(0.7));

    await tester.pump(const Duration(milliseconds: 210));
    final double midOpacity = cardOpacity(tester);
    expect(midOpacity, inExclusiveRange(startOpacity, 1));
    expect(
      tester.getBottomLeft(byKey('checkout-placed-card')).dy,
      lessThan(startBottom),
    );
    expect(circleScale(tester), inExclusiveRange(0.6, 1));

    await tester.pump(const Duration(milliseconds: 500));
    expect(cardOpacity(tester), 1);
    expect(circleScale(tester), 1);
    final double endBottom = tester
        .getBottomLeft(byKey('checkout-placed-card'))
        .dy;
    expect(startBottom - endBottom, closeTo(48, 3));
    expect(lightImpacts(calls), hasLength(1));
  });

  testWidgets(
    'with reduced motion the placed card stands at once, and still buzzes',
    (WidgetTester tester) async {
      final List<MethodCall> calls = mockHaptics(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await open(tester);
      await order(tester);

      expect(cardOpacity(tester), 1);
      expect(circleScale(tester), 1);
      expect(lightImpacts(calls), hasLength(1));
    },
  );

  testWidgets('the placed view meets iOSTapTargetGuideline', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await open(tester);
    await order(tester);

    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('leaving while a stale confirmation previews again is safe', (
    WidgetTester tester,
  ) async {
    await open(tester);
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
    final int before = cart.calls.where((String c) => c == 'cart').length;
    checkout.placeFailure = const ApiRefusal(
      ApiError(status: 500, code: 'server_error'),
    );

    await order(tester);

    expect(byKey('checkout-unconfirmed'), findsOneWidget);
    expect(
      cart.calls.where((String c) => c == 'cart').length,
      greaterThan(before),
    );
  });

  testWidgets(
    'leaving during the opening preview and coming back shows the figures before anything is placed',
    (WidgetTester tester) async {
      final Completer<void> hold = Completer<void>();
      checkout.previewHold = hold;
      await open(tester, settle: false);
      GoRouter.of(anywhere(tester)).pop();
      await tester.pumpAndSettle();

      checkout.previewHold = null;
      await tester.tap(byKey('go-to-checkout'));
      await tester.pump();
      await tester.pump();
      expect(byKey('checkout-total'), findsNothing);

      hold.complete();
      await tester.pumpAndSettle();

      expect(checkout.placements, isEmpty);
      expect(byKey('checkout-total'), findsOneWidget, reason: 'shown first');
      expect(checkout.previews, hasLength(2), reason: 'its own preview');

      await order(tester);
      expect(checkout.placements.single.$1, 'token-2');
      expect(checkout.previews, hasLength(2));
    },
  );

  testWidgets(
    'an unknown outcome whose address was removed can still be confirmed',
    (WidgetTester tester) async {
      await open(tester);
      checkout.placeFailure = const NetworkFailure();
      await order(tester);
      expect(byKey('checkout-unconfirmed'), findsOneWidget);

      addresses.rows = <Address>[
        address(id: 'a-2', label: 'Ish', street: 'Navoiy', house: '5'),
      ];
      ProviderScope.containerOf(anywhere(tester)).invalidate(addressesProvider);
      await tester.pumpAndSettle();

      expect(orderActive(tester), isTrue);
      expect(byKey('checkout-total'), findsOneWidget, reason: 'as it was sent');
      expect(inCard(l10n(tester).errorAddressGone), findsNothing);
      expect(
        inCard('Amir Temur, 12'),
        findsOneWidget,
        reason: 'as it was sent',
      );

      await order(tester);
      expect(checkout.placements, hasLength(2));
      expect(checkout.placements[1], checkout.placements[0]);
      expect(find.text(l10n(tester).checkoutPlaced('1001')), findsOneWidget);
    },
  );

  testWidgets('an address picked but not listed yet is not called gone', (
    WidgetTester tester,
  ) async {
    await open(tester);
    final ProviderContainer container = ProviderScope.containerOf(
      anywhere(tester),
    );
    addresses.rows = <Address>[
      ...addresses.rows,
      address(id: 'a-3', label: 'Dacha', street: 'Bog', house: '1'),
    ];
    addresses.loadHold = Completer<void>();
    container.invalidate(addressesProvider);
    await container
        .read(deliveryAddressChoiceProvider('c').notifier)
        .choose('a-3');
    await tester.pump();
    await tester.pump();

    expect(inCard(l10n(tester).errorAddressGone), findsNothing);

    addresses.loadHold!.complete();
    addresses.loadHold = null;
    await tester.pumpAndSettle();
    expect(inCard('Dacha'), findsOneWidget);
    expect(checkout.previews.last.addressId, 'a-3');
  });

  testWidgets(
    'a recount that changes only the hours does not strike the total',
    (WidgetTester tester) async {
      await open(tester);
      final AppLocalizations words = l10n(tester);
      checkout.queuedPreviews.add(previewJson(outside: true));
      checkout.placeFailure = const ApiRefusal(
        ApiError(status: 409, code: 'checkout_snapshot_stale'),
      );

      await order(tester);

      expect(checkout.placements, hasLength(1));
      expect(byKey('checkout-refreshed'), findsOneWidget);
      expect(byKey('checkout-closed'), findsOneWidget);
      expect(
        find.text(
          words.cartLineEstimate(MoneyFormat.uzs(47600, AppLanguage.uz)),
        ),
        findsNWidgets(2),
        reason: 'the total on the screen and in the footer, none struck',
      );
    },
  );

  testWidgets('after a recount a failing tap shows itself, not the recount', (
    WidgetTester tester,
  ) async {
    await open(tester);
    checkout.queuedPreviews.add(previewJson(total: 48600));
    checkout.placeFailure = const ApiRefusal(
      ApiError(status: 409, code: 'checkout_snapshot_stale'),
    );
    await order(tester);
    expect(byKey('checkout-refreshed'), findsOneWidget);

    checkout.placeFailure = const NetworkFailure();
    await order(tester);

    expect(find.text(l10n(tester).errorNetwork), findsOneWidget);
    expect(byKey('checkout-refreshed'), findsNothing);
  });

  testWidgets('another address picked drops the figures until its preview', (
    WidgetTester tester,
  ) async {
    await open(tester);
    expect(byKey('checkout-total'), findsOneWidget);
    final Completer<void> hold = Completer<void>();
    checkout.previewHold = hold;

    await tapAndSettle(tester, byKey('checkout-address-change'));
    await tester.tap(byKey('delivery-address-a-2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(byKey('checkout-total'), findsNothing);
    expect(byKey('checkout-total-pending'), findsOneWidget);
    expect(checkout.previews.last.addressId, 'a-2');
    checkout.previewHold = null;
    hold.complete();
    await tester.pumpAndSettle();
    expect(byKey('checkout-total'), findsOneWidget);
    expect(byKey('checkout-total-pending'), findsNothing);
  });

  testWidgets(
    'the goods and the amounts stand in place while the figures come',
    (WidgetTester tester) async {
      final Completer<void> hold = Completer<void>();
      checkout.previewHold = hold;
      await open(tester, settle: false);
      await tester.pump(const Duration(milliseconds: 100));

      expect(byKey('checkout-items'), findsOneWidget);
      expect(byKey('checkout-total-pending'), findsOneWidget);
      expect(byKey('checkout-total'), findsNothing);
      final double top = tester.getTopLeft(byKey('checkout-items')).dy;

      checkout.previewHold = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(byKey('checkout-total'), findsOneWidget);
      expect(byKey('checkout-total-pending'), findsNothing);
      expect(tester.getTopLeft(byKey('checkout-items')).dy, top);
    },
  );

  testWidgets(
    'figures never show for another address, not even in the composition',
    (WidgetTester tester) async {
      await open(tester);
      await tapAndSettle(tester, byKey('checkout-items-toggle'));
      const String sum = 'checkout-item-$tomatoLine-sum';
      expect(byKey(sum), findsOneWidget);

      final Completer<void> hold = Completer<void>();
      checkout.previewHold = hold;
      await tapAndSettle(tester, byKey('checkout-address-change'));
      await tester.tap(byKey('delivery-address-a-2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(byKey('checkout-total'), findsNothing);
      expect(byKey(sum), findsNothing);
      expect(byKey('checkout-total-pending'), findsOneWidget);
      expect(byKey('checkout-item-$tomatoLine-pending'), findsOneWidget);

      checkout.previewHold = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(byKey('checkout-total'), findsOneWidget);
      expect(byKey(sum), findsOneWidget);
    },
  );

  testWidgets(
    'the closed banner unfolds once and stays while the figures are recounted',
    (WidgetTester tester) async {
      checkout.outsideHours = true;
      await open(tester, settle: false);
      final Finder fold = find.ancestor(
        of: byKey('checkout-closed'),
        matching: find.byType(Fold),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final double early = tester.getSize(fold).height;
      await tester.pumpAndSettle();
      final double full = tester.getSize(fold).height;
      expect(early, lessThan(full));
      expect(full, greaterThan(0));

      final Completer<void> hold = Completer<void>();
      checkout.previewHold = hold;
      await tapAndSettle(tester, byKey('checkout-address-change'));
      await tester.tap(byKey('delivery-address-a-2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(byKey('checkout-closed'), findsOneWidget);
      expect(tester.getSize(fold).height, full);

      checkout.outsideHours = false;
      checkout.previewHold = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(byKey('checkout-closed'), findsNothing);
    },
  );

  testWidgets('a refused preview leaves still bars and the refusal', (
    WidgetTester tester,
  ) async {
    checkout.previewFailure = const ApiRefusal(
      ApiError(status: 422, code: 'address_outside_service_area'),
    );
    await open(tester);

    expect(byKey('failure-message'), findsOneWidget);
    expect(byKey('checkout-total-pending'), findsOneWidget);
    expect(byKey('checkout-total'), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
    'tapping the marked address after the home moved on is adopted when the sheet closes',
    (WidgetTester tester) async {
      await open(tester);
      checkout.placeFailure = const NetworkFailure();
      await order(tester);
      GoRouter.of(anywhere(tester)).pop();
      await tester.pumpAndSettle();
      // The home's choice moved meanwhile; the sent checkout keeps a-1.
      await ProviderScope.containerOf(anywhere(tester))
          .read(deliveryAddressChoiceProvider('c').notifier)
          .choose('a-2');
      await tapAndSettle(tester, byKey('cart-check-unconfirmed'));
      expect(inCard('Uy'), findsOneWidget);

      // The replay is refused: the checkout is free, still on a-1.
      checkout.placeFailure = const ApiRefusal(
        ApiError(status: 409, code: 'cart_empty'),
      );
      await order(tester);
      expect(inCard('Uy'), findsOneWidget);

      await pick(tester, 'a-2');

      expect(inCard('Ish'), findsOneWidget);
      expect(checkout.previews.last.addressId, 'a-2');
    },
  );

  for (final Locale language in const <Locale>[Locale('uz'), Locale('ru')]) {
    const Size phone = Size(320, 640);

    testWidgets(
      'the checkout with its figures fits a phone with large text (${language.languageCode})',
      (WidgetTester tester) async {
        checkout.outsideHours = true;
        await open(tester, size: phone, textScale: 2, device: language);

        expect(byKey('checkout-closed'), findsOneWidget);
        await tester.scrollUntilVisible(
          byKey('checkout-total'),
          300,
          scrollable: find
              .descendant(
                of: byKey('checkout'),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a refusal in the footer fits a phone with large text (${language.languageCode})',
      (WidgetTester tester) async {
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
        await open(tester, size: phone, textScale: 2, device: language);

        expect(byKey('failure-message'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'the sheet of a product gone fits a phone with large text (${language.languageCode})',
      (WidgetTester tester) async {
        checkout.previewFailure = const ApiRefusal(
          ApiError(
            status: 409,
            code: 'product_unavailable',
            details: <String, Object?>{
              'product_ids': <Object?>[tomatoProduct],
            },
          ),
        );
        await open(tester, size: phone, textScale: 2, device: language);

        expect(byKey('checkout-gone-to-cart'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'the placed order fits a phone with large text (${language.languageCode})',
      (WidgetTester tester) async {
        await open(tester, size: phone, textScale: 2, device: language);
        await order(tester);

        expect(byKey('checkout-placed'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    for (final (String name, ApiFailure failure) in <(String, ApiFailure)>[
      (
        'a server error',
        const ApiRefusal(ApiError(status: 500, code: 'server_error')),
      ),
      (
        'an order still being sent',
        const ApiRefusal(
          ApiError(status: 409, code: 'idempotency_in_progress'),
        ),
      ),
      ('a lost answer', const NetworkFailure()),
    ]) {
      testWidgets(
        'the footer after $name keeps "Заказать" in reach at large text (${language.languageCode})',
        (WidgetTester tester) async {
          await open(tester, size: phone, textScale: 2, device: language);
          checkout.placeFailure = failure;
          await order(tester);

          expect(byKey('checkout-unconfirmed'), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(byKey('checkout-confirm').hitTestable(), findsOneWidget);
        },
      );
    }

    testWidgets(
      'a product gone, not named, keeps "Заказать" in reach at large text (${language.languageCode})',
      (WidgetTester tester) async {
        checkout.previewFailure = const ApiRefusal(
          ApiError(status: 409, code: 'product_unavailable'),
        );
        await open(tester, size: phone, textScale: 2, device: language);

        expect(byKey('checkout-back-to-cart'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(byKey('checkout-confirm').hitTestable(), findsOneWidget);
      },
    );

    testWidgets(
      'the change buttons keep a 48 px target at large text (${language.languageCode})',
      (WidgetTester tester) async {
        await open(tester, size: phone, textScale: 2, device: language);

        // As drawn on the screen, after any scaling of the button.
        final Offset topLeft = tester.getTopLeft(
          byKey('checkout-address-change'),
        );
        final Offset bottomRight = tester.getBottomRight(
          byKey('checkout-address-change'),
        );
        expect(bottomRight.dy - topLeft.dy, greaterThanOrEqualTo(48));
        expect(bottomRight.dx - topLeft.dx, greaterThanOrEqualTo(48));
      },
    );
  }
}
