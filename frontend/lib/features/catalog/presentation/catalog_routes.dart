import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import 'catalog_paths.dart';
import 'all_products_screen.dart';
import 'all_categories_screen.dart';
import 'product_screen.dart';
import 'home_screen.dart';
import 'category_screen.dart';
import 'recommended_screen.dart';
import 'search_screen.dart';

/// The Customer's home tab, the first branch of the tabs' shell
/// (`features/shells`, `DL-118`).
final GoRoute catalogHomeRoute = GoRoute(
  path: AppPaths.customer,
  name: 'catalog-home',
  builder: (BuildContext context, GoRouterState state) =>
      const CatalogHomeScreen(),
);

/// The Customer catalog is the Customer area's home (`docs/07-architecture.md`
/// section 27): a category's products and a product. The
/// session guard admits only the Customer mode here; the backend decides
/// what the requests may read.
final FeatureRoutes catalogRoutes = FeatureRoutes(
  feature: 'catalog',
  routes: <RouteBase>[
    GoRoute(
      path: CatalogPaths.categories,
      name: 'catalog-categories',
      builder: (BuildContext context, GoRouterState state) =>
          const AllCategoriesScreen(),
    ),
    GoRoute(
      path: CatalogPaths.categoryPattern,
      name: 'catalog-category',
      builder: (BuildContext context, GoRouterState state) =>
          CategoryScreen(categoryId: state.pathParameters['category']!),
    ),
    GoRoute(
      path: CatalogPaths.recommended,
      name: 'catalog-recommended',
      builder: (BuildContext context, GoRouterState state) =>
          const RecommendedScreen(),
    ),
    GoRoute(
      path: CatalogPaths.search,
      name: 'catalog-search',
      builder: (BuildContext context, GoRouterState state) =>
          const SearchScreen(),
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
