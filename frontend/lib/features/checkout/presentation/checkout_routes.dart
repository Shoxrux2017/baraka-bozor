import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_page.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import 'checkout_screen.dart';

/// The checkout, inside the Customer area; it opens over the cart, so the
/// system back returns there.
final FeatureRoutes checkoutRoutes = FeatureRoutes(
  feature: 'checkout',
  routes: <RouteBase>[
    GoRoute(
      path: AppPaths.customerCheckout,
      name: 'checkout',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          appPage(state, const CheckoutScreen()),
    ),
  ],
);
