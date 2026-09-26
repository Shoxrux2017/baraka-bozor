import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import 'addresses_screens.dart';

/// The Customer's addresses, opened from the profile.
final FeatureRoutes addressesRoutes = FeatureRoutes(
  feature: 'addresses',
  routes: <RouteBase>[
    GoRoute(
      path: AppPaths.customerAddresses,
      name: 'customer-addresses',
      builder: (BuildContext context, GoRouterState state) =>
          const AddressesScreen(),
    ),
    // Declared before the address pattern, which would otherwise read "new"
    // as an address id.
    GoRoute(
      path: AppPaths.customerNewAddress,
      name: 'customer-address-new',
      builder: (BuildContext context, GoRouterState state) =>
          const AddressFormScreen(addressId: null),
    ),
    GoRoute(
      path: AppPaths.customerAddressPattern,
      name: 'customer-address',
      builder: (BuildContext context, GoRouterState state) =>
          AddressFormScreen(addressId: state.pathParameters['address']),
    ),
  ],
);
