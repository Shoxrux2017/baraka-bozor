import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_page.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import '../../../core/routing/flight_page.dart';
import 'catalog_paths.dart';
import 'category_tile.dart';
import 'all_products_screen.dart';
import 'all_categories_screen.dart';
import 'product_photo.dart';
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
  pageBuilder: (BuildContext context, GoRouterState state) =>
      appPage(state, const CatalogHomeScreen(), entry: true),
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
      pageBuilder: (BuildContext context, GoRouterState state) =>
          appPage(state, const AllCategoriesScreen()),
    ),
    GoRoute(
      path: CatalogPaths.categoryPattern,
      name: 'catalog-category',
      pageBuilder: (BuildContext context, GoRouterState state) => appPage(
        state,
        CategoryScreen(
          categoryId: state.pathParameters['category']!,
          opening: switch (state.extra) {
            final CategoryOpening opening => opening,
            _ => null,
          },
        ),
      ),
    ),
    GoRoute(
      path: CatalogPaths.recommended,
      name: 'catalog-recommended',
      pageBuilder: (BuildContext context, GoRouterState state) => flightPage(
        state,
        const RecommendedScreen(),
        opening: state.extra is FlightOpening
            ? state.extra! as FlightOpening
            : null,
      ),
    ),
    GoRoute(
      path: CatalogPaths.search,
      name: 'catalog-search',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          appPage(state, const SearchScreen()),
    ),
    GoRoute(
      path: CatalogPaths.products,
      name: 'catalog-all-products',
      pageBuilder: (BuildContext context, GoRouterState state) => flightPage(
        state,
        const AllProductsScreen(),
        opening: state.extra is FlightOpening
            ? state.extra! as FlightOpening
            : null,
      ),
    ),
    GoRoute(
      path: CatalogPaths.productPattern,
      name: 'catalog-product',
      // The photo flies by the shared page's transition (`DL-122`, `DL-124`).
      pageBuilder: (BuildContext context, GoRouterState state) => appPage(
        state,
        ProductScreen(
          productId: state.pathParameters['product']!,
          opening: switch (state.extra) {
            final ProductOpening opening => opening,
            _ => null,
          },
        ),
      ),
    ),
  ],
);
