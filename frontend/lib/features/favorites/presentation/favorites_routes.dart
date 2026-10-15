import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import 'favorites_screen.dart';

/// The Customer's favourites, a tab of the bottom bar.
final FeatureRoutes favoritesRoutes = FeatureRoutes(
  feature: 'favorites',
  routes: <RouteBase>[
    GoRoute(
      path: AppPaths.customerFavorites,
      name: 'customer-favorites',
      builder: (BuildContext context, GoRouterState state) =>
          const FavoritesScreen(),
    ),
  ],
);
