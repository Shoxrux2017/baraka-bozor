import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import 'order_edit_screen.dart';
import 'orders_screens.dart';

/// The Customer's orders, inside the Customer area: the list, an order and
/// its editor. Each opens over the screen it was reached from, so the system
/// back returns there. An order's id is taken in lower case, as the API
/// answers it.
final FeatureRoutes ordersRoutes = FeatureRoutes(
  feature: 'orders',
  routes: <RouteBase>[
    GoRoute(
      path: AppPaths.customerOrders,
      name: 'customer-orders',
      builder: (BuildContext context, GoRouterState state) =>
          const OrdersScreen(),
    ),
    GoRoute(
      path: AppPaths.customerOrderPattern,
      name: 'customer-order',
      builder: (BuildContext context, GoRouterState state) =>
          OrderScreen(orderId: state.pathParameters['order']!.toLowerCase()),
    ),
    GoRoute(
      path: AppPaths.customerOrderEditPattern,
      name: 'customer-order-edit',
      builder: (BuildContext context, GoRouterState state) => OrderEditScreen(
        orderId: state.pathParameters['order']!.toLowerCase(),
      ),
    ),
  ],
);
