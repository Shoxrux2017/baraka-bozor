import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_page.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import '../../shells/presentation/panel_shell.dart';
import 'admin_paths.dart';
import 'categories_screen.dart';
import 'customers_screen.dart';
import 'legal_documents_screen.dart';
import 'product_edit_screen.dart';
import 'products_screen.dart';
import 'settings_screen.dart';
import 'staff_screen.dart';

/// The Admin area of the web panel (`docs/07-architecture.md` section 27):
/// every Admin screen inside the panel's shell. The session guard admits
/// only an Admin here; the backend decides what each request may do. The
/// area's own root opens the board, the Admin's home (`DL-37` (17)).
final FeatureRoutes adminRoutes = FeatureRoutes(
  feature: 'admin',
  routes: <RouteBase>[
    ShellRoute(
      pageBuilder: (BuildContext context, GoRouterState state, Widget child) =>
          appPage(
            state,
            PanelShell(location: state.uri.path, child: child),
            entry: true,
          ),
      routes: <RouteBase>[
        GoRoute(
          path: AppPaths.admin,
          name: 'admin-home',
          redirect: (BuildContext context, GoRouterState state) =>
              AppPaths.operations,
        ),
        GoRoute(
          path: AdminPaths.categories,
          name: 'admin-categories',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              appPage(state, const CategoriesScreen(), entry: true),
        ),
        GoRoute(
          path: AdminPaths.products,
          name: 'admin-products',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              appPage(state, const ProductsScreen(), entry: true),
        ),
        // Declared before the product pattern, which would otherwise read
        // "new" as a product id.
        GoRoute(
          path: AdminPaths.newProduct,
          name: 'admin-product-new',
          pageBuilder: (BuildContext context, GoRouterState state) => appPage(
            state,
            const ProductEditScreen(productId: null),
            entry: true,
          ),
        ),
        GoRoute(
          path: AdminPaths.productPattern,
          name: 'admin-product',
          pageBuilder: (BuildContext context, GoRouterState state) => appPage(
            state,
            ProductEditScreen(productId: state.pathParameters['product']),
            entry: true,
          ),
        ),
        GoRoute(
          path: AdminPaths.staff,
          name: 'admin-staff',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              appPage(state, const StaffScreen(), entry: true),
        ),
        GoRoute(
          path: AdminPaths.customers,
          name: 'admin-customers',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              appPage(state, const CustomersScreen(), entry: true),
        ),
        GoRoute(
          path: AdminPaths.legalDocuments,
          name: 'admin-legal-documents',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              appPage(state, const LegalDocumentsScreen(), entry: true),
        ),
        GoRoute(
          path: AdminPaths.settings,
          name: 'admin-settings',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              appPage(state, const SettingsScreen(), entry: true),
        ),
      ],
    ),
  ],
);
