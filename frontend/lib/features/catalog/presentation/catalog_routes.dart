import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import 'catalog_paths.dart';
import 'catalog_screens.dart';

/// The Customer catalog is the Customer area's home (`docs/07-architecture.md`
/// section 27): the area's entry, a category's products and a product. The
/// session guard admits only the Customer mode here; the backend decides
/// what the requests may read.
final FeatureRoutes catalogRoutes = FeatureRoutes(
  feature: 'catalog',
  routes: <RouteBase>[
    GoRoute(
      path: AppPaths.customer,
      name: 'catalog-home',
      builder: (BuildContext context, GoRouterState state) =>
          const CatalogHomeScreen(),
    ),
    GoRoute(
      path: CatalogPaths.categoryPattern,
      name: 'catalog-category',
      builder: (BuildContext context, GoRouterState state) =>
          CategoryProductsScreen(categoryId: state.pathParameters['category']!),
    ),
    GoRoute(
      path: CatalogPaths.productPattern,
      name: 'catalog-product',
      builder: (BuildContext context, GoRouterState state) =>
          ProductScreen(productId: state.pathParameters['product']!),
    ),
  ],
);
