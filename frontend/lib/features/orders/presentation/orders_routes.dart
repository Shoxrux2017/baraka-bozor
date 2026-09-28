import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import '../../catalog/domain/catalog.dart';
import 'order_edit_screen.dart';
import 'order_product_picker.dart';
import 'orders_screens.dart';

/// The Customer's orders, inside the Customer area: the list, an order, its
/// editor and the product picker the editor adds from. Each opens over the
/// screen it was reached from, so the system back returns there. An order's
/// id is taken in lower case, as the API answers it.
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
      // A product picked by a picker opened alone comes along (`DL-52` (1)).
      builder: (BuildContext context, GoRouterState state) => OrderEditScreen(
        orderId: state.pathParameters['order']!.toLowerCase(),
        adding: switch (state.extra) {
          final CatalogProduct product => product,
          _ => null,
        },
      ),
    ),
    GoRoute(
      path: AppPaths.customerOrderAddPattern,
      name: 'customer-order-add',
      builder: (BuildContext context, GoRouterState state) =>
          OrderProductPickerScreen(
            orderId: state.pathParameters['order']!.toLowerCase(),
          ),
    ),
  ],
);
