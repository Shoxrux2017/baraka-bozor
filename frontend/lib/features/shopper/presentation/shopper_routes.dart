import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_page.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import 'shopper_done_screen.dart';
import 'shopper_list_screen.dart';
import 'shopper_replace_screen.dart';
import 'shopper_order_screen.dart';

/// The Shopper's area: their orders, one order opened over the list, a
/// line's replacement search opened over the order — so the system back
/// returns to each — and the closing screen of a completed order, which
/// replaces them. Ids are taken in lower case, as the API answers them.
final FeatureRoutes shopperRoutes = FeatureRoutes(
  feature: 'shopper',
  routes: <RouteBase>[
    GoRoute(
      path: AppPaths.shopper,
      name: 'shopper-orders',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          appPage(state, const ShopperOrdersScreen(), entry: true),
    ),
    GoRoute(
      path: AppPaths.shopperOrderPattern,
      name: 'shopper-order',
      pageBuilder: (BuildContext context, GoRouterState state) => appPage(
        state,
        ShopperOrderScreen(
          orderId: state.pathParameters['order']!.toLowerCase(),
        ),
      ),
    ),
    GoRoute(
      path: AppPaths.shopperReplacePattern,
      name: 'shopper-replace',
      pageBuilder: (BuildContext context, GoRouterState state) => appPage(
        state,
        ShopperReplaceScreen(
          orderId: state.pathParameters['order']!.toLowerCase(),
          itemId: state.pathParameters['item']!.toLowerCase(),
        ),
      ),
    ),
    GoRoute(
      path: AppPaths.shopperDonePattern,
      name: 'shopper-done',
      // Only an order number: anything else is no closing screen.
      redirect: (BuildContext context, GoRouterState state) =>
          _orderNumber(state) == null ? AppPaths.shopper : null,
      pageBuilder: (BuildContext context, GoRouterState state) => appPage(
        state,
        ShopperDoneScreen(orderNumber: _orderNumber(state)!),
        entry: true,
      ),
    ),
  ],
);

int? _orderNumber(GoRouterState state) {
  final String number = state.pathParameters['number'] ?? '';
  final int? parsed = RegExp(r'^[1-9]\d{0,9}$').hasMatch(number)
      ? int.tryParse(number)
      : null;
  return parsed;
}
