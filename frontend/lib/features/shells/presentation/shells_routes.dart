import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import '../../auth/domain/app_user.dart';
import 'role_shell_screen.dart';

/// The six areas of `docs/07-architecture.md` section 29, each entered
/// through its role's shell. A feature that fills an area later declares its
/// pages inside it.
final FeatureRoutes shellsRoutes = FeatureRoutes(
  feature: 'shells',
  routes: <RouteBase>[
    for (final UserRole role in UserRole.values)
      GoRoute(
        path: AppPaths.areaOf(role),
        name: 'shell-${role.code}',
        builder: (BuildContext context, GoRouterState state) =>
            RoleShellScreen(role: role),
      ),
  ],
);
