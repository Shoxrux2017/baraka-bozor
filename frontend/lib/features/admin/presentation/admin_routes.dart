import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import 'admin_paths.dart';
import 'admin_shell.dart';
import 'settings_screen.dart';

/// The Admin area of the web panel (`docs/07-architecture.md` section 27):
/// every Admin screen inside one shell. The session guard admits only an
/// Admin here; the backend decides what each request may do.
final FeatureRoutes adminRoutes = FeatureRoutes(
  feature: 'admin',
  routes: <RouteBase>[
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) =>
          AdminShell(location: state.uri.path, child: child),
      routes: <RouteBase>[
        GoRoute(
          path: AppPaths.admin,
          name: 'admin-home',
          builder: (BuildContext context, GoRouterState state) =>
              const AdminHomeScreen(),
        ),
        GoRoute(
          path: AdminPaths.settings,
          name: 'admin-settings',
          builder: (BuildContext context, GoRouterState state) =>
              const SettingsScreen(),
        ),
      ],
    ),
  ],
);
