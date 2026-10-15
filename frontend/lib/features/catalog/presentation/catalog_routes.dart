import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import 'catalog_paths.dart';
import 'all_products_screen.dart';
import 'catalog_screens.dart';
import 'recommended_screen.dart';

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
      path: CatalogPaths.recommended,
      name: 'catalog-recommended',
      builder: (BuildContext context, GoRouterState state) =>
          const RecommendedScreen(),
    ),
    GoRoute(
      path: CatalogPaths.products,
      name: 'catalog-all-products',
      builder: (BuildContext context, GoRouterState state) =>
          const AllProductsScreen(),
    ),
    GoRoute(
      path: CatalogPaths.productPattern,
      name: 'catalog-product',
      builder: (BuildContext context, GoRouterState state) =>
          ProductScreen(productId: state.pathParameters['product']!),
    ),
  ],
);
