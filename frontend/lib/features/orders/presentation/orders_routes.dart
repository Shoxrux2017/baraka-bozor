import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import '../../catalog/domain/catalog.dart';
import 'order_edit_screen.dart';
import 'order_product_picker.dart';
import 'orders_screens.dart';
import 'rate_order_screen.dart';

/// The Customer's orders list, the third branch of the tabs' shell
/// (`features/shells`, `DL-118`).
final GoRoute ordersTabRoute = GoRoute(
  path: AppPaths.customerOrders,
  name: 'customer-orders',
  builder: (BuildContext context, GoRouterState state) => const OrdersScreen(),
);

/// The Customer's orders, inside the Customer area: an order, its
/// editor and the product picker the editor adds from. Each opens over the
/// screen it was reached from, so the system back returns there. An order's
/// id is taken in lower case, as the API answers it.
final FeatureRoutes ordersRoutes = FeatureRoutes(
  feature: 'orders',
  routes: <RouteBase>[
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
      // The products the editor keeps come along, to mark them; opened by
      // its address alone, the picker reads them from the order.
      builder: (BuildContext context, GoRouterState state) =>
          OrderProductPickerScreen(
            orderId: state.pathParameters['order']!.toLowerCase(),
            productIds: switch (state.extra) {
              final Set<String> ids => ids,
              _ => null,
            },
          ),
    ),
    GoRoute(
      path: AppPaths.customerOrderRatePattern,
      name: 'customer-order-rate',
      // The stars tapped before the screen opened; anything but 1 to 5 is
      // ignored.
      builder: (BuildContext context, GoRouterState state) => RateOrderScreen(
        orderId: state.pathParameters['order']!.toLowerCase(),
        stars: int.tryParse(state.uri.queryParameters['stars'] ?? ''),
      ),
    ),
  ],
);
