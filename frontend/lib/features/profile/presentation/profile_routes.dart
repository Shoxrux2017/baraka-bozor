import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import 'account_deleted_screen.dart';
import 'delete_account_screen.dart';
import 'edit_profile_screen.dart';
import 'profile_screen.dart';

/// The Customer's profile, the fourth branch of the tabs' shell
/// (`features/shells`, `DL-118`). Its editors are top-level routes, so they
/// open over the bar.
final GoRoute profileTabRoute = GoRoute(
  path: AppPaths.customerProfile,
  name: 'customer-profile',
  builder: (BuildContext context, GoRouterState state) => const ProfileScreen(),
);

/// The profile's editors and the screen after a deleted account.
final FeatureRoutes profileRoutes = FeatureRoutes(
  feature: 'profile',
  routes: <RouteBase>[
    GoRoute(
      path: AppPaths.customerEditProfile,
      name: 'customer-edit-profile',
      builder: (BuildContext context, GoRouterState state) =>
          const EditProfileScreen(),
    ),
    GoRoute(
      path: AppPaths.customerDeleteAccount,
      name: 'customer-delete-account',
      builder: (BuildContext context, GoRouterState state) =>
          const DeleteAccountScreen(),
    ),
    GoRoute(
      path: AppPaths.accountDeleted,
      name: 'account-deleted',
      builder: (BuildContext context, GoRouterState state) =>
          const AccountDeletedScreen(),
    ),
  ],
);
