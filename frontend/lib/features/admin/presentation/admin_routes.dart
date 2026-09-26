import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import 'admin_paths.dart';
import 'admin_shell.dart';
import 'categories_screen.dart';
import 'product_edit_screen.dart';
import 'products_screen.dart';
import 'settings_screen.dart';

/// The Admin area of the web panel (`docs/07-architecture.md` section 27):
/// every Admin screen inside one shell. The session guard admits only an
/// Admin here; the backend decides what each request may do.
final FeatureRoutes adminRoutes = FeatureRoutes(
  feature: 'admin',
  routes: <RouteBase>[
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) =>
          AdminShell(location: state.uri.path, child: child),
      routes: <RouteBase>[
        GoRoute(
          path: AppPaths.admin,
          name: 'admin-home',
          builder: (BuildContext context, GoRouterState state) =>
              const AdminHomeScreen(),
        ),
        GoRoute(
          path: AdminPaths.categories,
          name: 'admin-categories',
          builder: (BuildContext context, GoRouterState state) =>
              const CategoriesScreen(),
        ),
        GoRoute(
          path: AdminPaths.products,
          name: 'admin-products',
          builder: (BuildContext context, GoRouterState state) =>
              const ProductsScreen(),
        ),
        // Declared before the product pattern, which would otherwise read
        // "new" as a product id.
        GoRoute(
          path: AdminPaths.newProduct,
          name: 'admin-product-new',
          builder: (BuildContext context, GoRouterState state) =>
              const ProductEditScreen(productId: null),
        ),
        GoRoute(
          path: AdminPaths.productPattern,
          name: 'admin-product',
          builder: (BuildContext context, GoRouterState state) =>
              ProductEditScreen(productId: state.pathParameters['product']),
        ),
        GoRoute(
          path: AdminPaths.settings,
          name: 'admin-settings',
          builder: (BuildContext context, GoRouterState state) =>
              const SettingsScreen(),
        ),
      ],
    ),
  ],
);
