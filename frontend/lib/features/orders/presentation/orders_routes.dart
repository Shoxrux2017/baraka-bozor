import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_page.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import 'order_edit_screen.dart';
import 'order_product_picker.dart';
import 'orders_list_screen.dart';
import 'orders_screens.dart';
import 'rate_order_screen.dart';

/// The Customer's orders list, the third branch of the tabs' shell
/// (`features/shells`, `DL-118`).
final GoRoute ordersTabRoute = GoRoute(
  path: AppPaths.customerOrders,
  name: 'customer-orders',
  pageBuilder: (BuildContext context, GoRouterState state) =>
      appPage(state, const OrdersScreen(), entry: true),
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
      pageBuilder: (BuildContext context, GoRouterState state) => appPage(
        state,
        OrderScreen(orderId: state.pathParameters['order']!.toLowerCase()),
      ),
    ),
    GoRoute(
      path: AppPaths.customerOrderEditPattern,
      name: 'customer-order-edit',
      pageBuilder: (BuildContext context, GoRouterState state) => appPage(
        state,
        OrderEditScreen(orderId: state.pathParameters['order']!.toLowerCase()),
      ),
    ),
    GoRoute(
      path: AppPaths.customerOrderAddPattern,
      name: 'customer-order-add',
      // The picker adds to the editor's draft, so only the editor opens it;
      // opened by its address alone it gives way to the editor (`DL-132`).
      redirect: (BuildContext context, GoRouterState state) =>
          state.extra is OrderPickerOpening
          ? null
          : AppPaths.customerOrderEdit(state.pathParameters['order']!),
      pageBuilder: (BuildContext context, GoRouterState state) => appPage(
        state,
        OrderProductPickerScreen(
          orderId: state.pathParameters['order']!.toLowerCase(),
        ),
      ),
    ),
    GoRoute(
      path: AppPaths.customerOrderRatePattern,
      name: 'customer-order-rate',
      // The stars tapped before the screen opened; anything but 1 to 5 is
      // ignored.
      pageBuilder: (BuildContext context, GoRouterState state) => appPage(
        state,
        RateOrderScreen(
          orderId: state.pathParameters['order']!.toLowerCase(),
          stars: int.tryParse(state.uri.queryParameters['stars'] ?? ''),
        ),
      ),
    ),
  ],
);
