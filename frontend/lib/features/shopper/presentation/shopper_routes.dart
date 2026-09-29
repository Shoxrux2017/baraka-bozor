import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import 'shopper_screens.dart';

/// The Shopper's area: their orders, and one order opened over the list,
/// so the system back returns to it. An order's id is taken in lower case,
/// as the API answers it.
final FeatureRoutes shopperRoutes = FeatureRoutes(
  feature: 'shopper',
  routes: <RouteBase>[
    GoRoute(
      path: AppPaths.shopper,
      name: 'shopper-orders',
      builder: (BuildContext context, GoRouterState state) =>
          const ShopperOrdersScreen(),
    ),
    GoRoute(
      path: AppPaths.shopperOrderPattern,
      name: 'shopper-order',
      builder: (BuildContext context, GoRouterState state) =>
          ShopperOrderScreen(
            orderId: state.pathParameters['order']!.toLowerCase(),
          ),
    ),
  ],
);
