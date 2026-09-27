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

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  BuildContext anywhere(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).last);

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(anywhere(tester));

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.customer] = 'c';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.customer] = user(id: 'c');
    cart = FakeCartRepository(
      cart: cartOf(<Map<String, Object?>>[cartLineJson()]),
    );
    checkout = FakeCheckoutRepository();
    addresses = FakeAddressesRepository();
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(800, 2000),
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
        device: device,
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(anywhere(tester)).push('/customer/cart');
    await tester.pumpAndSettle();
    await tester.tap(byKey('go-to-checkout'));
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> calculate(WidgetTester tester) async {
    await tapAndSettle(tester, byKey('checkout-address-a-1'));
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
    expect(
      cart.calls.length,
      greaterThan(cartLoads),
      reason: 'the cart is asked for again',
    );
    await tapAndSettle(tester, byKey('checkout-back-to-catalog'));
    expect(
      find.byKey(const ValueKey<String>('catalog-search')),
      findsOneWidget,
    );
  });

  testWidgets('a retry reuses the key; a new preview brings a new one', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await calculate(tester);

    checkout.placeFailure = const NetworkFailure();
    await tapAndSettle(tester, byKey('checkout-confirm'));
    expect(find.text(l10n(tester).errorNetwork), findsOneWidget);
    checkout.placeFailure = const NetworkFailure();
    await tapAndSettle(tester, byKey('checkout-confirm'));

    expect(checkout.placements, hasLength(2));
    expect(
      checkout.placements[1],
      checkout.placements[0],
      reason: 'the same token and key',
    );

    // A changed wish asks for a new preview, and that for a new key.
    await tester.enterText(byKey('checkout-delivery-wish'), 'Ertalab');
    await tester.pump();
    expect(byKey('checkout-confirm'), findsNothing);
    await tapAndSettle(tester, byKey('checkout-calculate'));
    await tapAndSettle(tester, byKey('checkout-confirm'));

    final (String token, String key) = checkout.placements.last;
    expect(token, 'token-2');
    expect(key, isNot(checkout.placements.first.$2));
    expect(find.text(l10n(tester).checkoutPlaced('1001')), findsOneWidget);
  });

  testWidgets(
    'a stale confirmation asks for a new preview by itself and says so',
    (WidgetTester tester) async {
      await open(tester);
      await calculate(tester);

      checkout.placeFailure = const ApiRefusal(
        ApiError(status: 409, code: 'checkout_snapshot_stale'),
      );
      await tapAndSettle(tester, byKey('checkout-confirm'));

      expect(checkout.previews, hasLength(2));
      expect(byKey('checkout-refreshed'), findsOneWidget);
      expect(find.text(l10n(tester).errorCheckoutStale), findsOneWidget);

      await tapAndSettle(tester, byKey('checkout-confirm'));
      expect(checkout.placements.last.$1, 'token-2');
      expect(
        checkout.placements.last.$2,
        isNot(checkout.placements.first.$2),
        reason: 'a new preview, a new key',
      );
    },
  );

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
      expect(byKey('checkout-back-to-cart'), findsOneWidget);
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
      expect(
        GoRouter.of(anywhere(tester))
            .routerDelegate
            .currentConfiguration
            .last
            .matchedLocation,
        AppPaths.customerProfile,
      );
    });

    for (final (String code, int status, String Function(AppLocalizations) text)
        in <(String, int, String Function(AppLocalizations))>[
          (
            'address_incomplete',
            409,
            (AppLocalizations l) => l.errorAddressIncomplete,
          ),
          (
            'resource_not_found',
            404,
            (AppLocalizations l) => l.errorAddressGone,
          ),
          ('cart_empty', 409, (AppLocalizations l) => l.errorCartEmpty),
          (
            'product_unavailable',
            409,
            (AppLocalizations l) => l.errorCheckoutProductsUnavailable,
          ),
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

    testWidgets('an order still being sent', (WidgetTester tester) async {
      await open(tester);
      await calculate(tester);
      checkout.placeFailure = const ApiRefusal(
        ApiError(status: 409, code: 'idempotency_in_progress'),
      );
      await tapAndSettle(tester, byKey('checkout-confirm'));
      expect(find.text(l10n(tester).errorOrderInProgress), findsOneWidget);
    });
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
    expect(
      GoRouter.of(anywhere(tester))
          .routerDelegate
          .currentConfiguration
          .last
          .matchedLocation,
      AppPaths.customerNewAddress,
    );
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

  for (final Locale language in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'the checkout fits a phone with large text (${language.languageCode})',
      (WidgetTester tester) async {
        checkout.outsideHours = true;
        await open(
          tester,
          size: const Size(360, 3200),
          textScale: 2,
          device: language,
        );
        await calculate(tester);
        expect(byKey('checkout-preview'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
