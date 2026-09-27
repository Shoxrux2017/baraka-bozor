import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import 'profile_screen.dart';

/// The Customer's profile, opened from the catalog's app bar.
final FeatureRoutes profileRoutes = FeatureRoutes(
  feature: 'profile',
  routes: <RouteBase>[
    GoRoute(
      path: AppPaths.customerProfile,
      name: 'customer-profile',
      builder: (BuildContext context, GoRouterState state) =>
          const ProfileScreen(),
    ),
  ],
);
