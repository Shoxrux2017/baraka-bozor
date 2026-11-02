import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_page.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import 'favorites_screen.dart';

/// The Customer's favourites, the second branch of the tabs' shell
/// (`features/shells`, `DL-118`).
final GoRoute favoritesTabRoute = GoRoute(
  path: AppPaths.customerFavorites,
  name: 'customer-favorites',
  pageBuilder: (BuildContext context, GoRouterState state) =>
      appPage(state, const FavoritesScreen(), entry: true),
);

/// The favourites' screen is a tab, so this fragment has no route of its
/// own; it stays registered with the feature.
final FeatureRoutes favoritesRoutes = FeatureRoutes(
  feature: 'favorites',
  routes: <RouteBase>[],
);
