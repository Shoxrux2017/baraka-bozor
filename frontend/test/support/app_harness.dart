import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/features/cart/application/cart_controllers.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/addresses/application/addresses_controllers.dart';
import 'package:baraka_bozor/features/catalog/application/catalog_controllers.dart';
import 'package:baraka_bozor/features/checkout/application/checkout_controllers.dart';
import 'package:baraka_bozor/features/orders/application/customer_orders_controllers.dart';
import 'package:baraka_bozor/core/platform/map_links.dart';
import 'package:baraka_bozor/core/platform/phone_calls.dart';
import 'package:baraka_bozor/features/courier/application/courier_orders_controllers.dart';
import 'package:baraka_bozor/features/operations/application/board_controllers.dart';
import 'package:baraka_bozor/features/shopper/application/shopper_orders_controllers.dart';
import 'package:baraka_bozor/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'fake_auth_repository.dart';
import 'fake_cart_repository.dart';
import 'fake_catalog_repository.dart';
import 'fake_checkout_repository.dart';
import 'fake_courier_orders_repository.dart';
import 'fake_customer_orders_repository.dart';
import 'fake_customer_repositories.dart';
import 'fake_operations_repository.dart';
import 'fake_shopper_orders_repository.dart';
import 'in_memory_stores.dart';

/// The app without the platform plugins: in-memory stores, fake repositories
/// and a chosen surface, so a widget test never touches a method channel and
/// drives the real router, session controller and screens.
Widget appUnderTest({
  InMemoryTokenStore? tokens,
  FakeAuthRepository? repository,
  FakeCatalogRepository? catalog,
  FakeOperationsRepository? operations,
  FakeCartRepository? cart,
  FakeCheckoutRepository? checkout,
  FakeAddressesRepository? addresses,
  FakeCustomerOrdersRepository? orders,
  FakeShopperOrdersRepository? shopper,
  FakeCourierOrdersRepository? courier,
  FakePhoneCalls? phoneCalls,
  FakeMapLinks? maps,
  Surface surface = Surface.mobile,
  Locale device = const Locale('uz'),
  List<Override> overrides = const <Override>[],
}) {
  return ProviderScope(
    retry: noAutomaticRetry,
    overrides: [
      tokenStoreProvider.overrideWithValue(tokens ?? InMemoryTokenStore()),
      preferenceStoreProvider.overrideWithValue(InMemoryPreferenceStore()),
      deviceLocaleProvider.overrideWithValue(device),
      authRepositoryProvider.overrideWithValue(
        repository ?? FakeAuthRepository(),
      ),
      surfaceProvider.overrideWithValue(surface),
      catalogRepositoryProvider.overrideWithValue(
        catalog ?? FakeCatalogRepository(),
      ),
      operationsRepositoryProvider.overrideWithValue(
        operations ?? FakeOperationsRepository(),
      ),
      cartRepositoryProvider.overrideWithValue(cart ?? FakeCartRepository()),
      checkoutRepositoryProvider.overrideWithValue(
        checkout ?? FakeCheckoutRepository(),
      ),
      addressesRepositoryProvider.overrideWithValue(
        addresses ?? FakeAddressesRepository(),
      ),
      customerOrdersRepositoryProvider.overrideWithValue(
        orders ?? FakeCustomerOrdersRepository(),
      ),
      shopperOrdersRepositoryProvider.overrideWithValue(
        shopper ?? FakeShopperOrdersRepository(),
      ),
      courierOrdersRepositoryProvider.overrideWithValue(
        courier ?? FakeCourierOrdersRepository(),
      ),
      phoneCallsProvider.overrideWithValue(phoneCalls ?? FakePhoneCalls()),
      mapLinksProvider.overrideWithValue(maps ?? FakeMapLinks()),
      ...overrides,
    ],
    child: const BarakaBozorApp(),
  );
}
