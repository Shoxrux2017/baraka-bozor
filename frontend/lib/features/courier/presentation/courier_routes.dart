import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import 'courier_screens.dart';

/// The Courier's area: their deliveries, and one delivery opened over the
/// list, so the system back returns to it. Ids are taken in lower case, as
/// the API answers them.
final FeatureRoutes courierRoutes = FeatureRoutes(
  feature: 'courier',
  routes: <RouteBase>[
    GoRoute(
      path: AppPaths.courier,
      name: 'courier-orders',
      builder: (BuildContext context, GoRouterState state) =>
          const CourierOrdersScreen(),
    ),
    GoRoute(
      path: AppPaths.courierOrderPattern,
      name: 'courier-order',
      builder: (BuildContext context, GoRouterState state) =>
          CourierOrderScreen(
            orderId: state.pathParameters['order']!.toLowerCase(),
          ),
    ),
  ],
);
