import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/feature_routes.dart';
import 'cart_paths.dart';
import 'cart_screen.dart';

/// The Customer's cart, inside the Customer area (`docs/07-architecture.md`
/// section 27); it opens over the screen it was reached from, so the
/// system back returns there.
final FeatureRoutes cartRoutes = FeatureRoutes(
  feature: 'cart',
  routes: <RouteBase>[
    GoRoute(
      path: CartPaths.cart,
      name: 'cart',
      builder: (BuildContext context, GoRouterState state) =>
          CartScreen(openLineId: state.uri.queryParameters['line']),
    ),
  ],
);
