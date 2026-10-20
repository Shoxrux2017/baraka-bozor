import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import 'account_deleted_screen.dart';
import 'delete_account_screen.dart';
import 'edit_profile_screen.dart';
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
      routes: <RouteBase>[
        GoRoute(
          path: 'edit',
          name: 'customer-edit-profile',
          builder: (BuildContext context, GoRouterState state) =>
              const EditProfileScreen(),
        ),
        GoRoute(
          path: 'delete',
          name: 'customer-delete-account',
          builder: (BuildContext context, GoRouterState state) =>
              const DeleteAccountScreen(),
        ),
      ],
    ),
    GoRoute(
      path: AppPaths.accountDeleted,
      name: 'account-deleted',
      builder: (BuildContext context, GoRouterState state) =>
          const AccountDeletedScreen(),
    ),
  ],
);
