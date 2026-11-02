import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_page.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import 'auth_entry_screen.dart';
import 'change_password_screen.dart';
import 'code_screen.dart';
import 'customer_name_screen.dart';
import 'staff_login_screen.dart';
import 'staff_password_screen.dart';
import 'unreachable_screen.dart';
import 'wrong_surface_screen.dart';

/// The screens outside every role shell. They are flat, not nested: none
/// is a page over another, so no back gesture lands on a screen the session
/// guard would only bounce away from. Each screen carries its own way back.
final FeatureRoutes authRoutes = FeatureRoutes(
  feature: 'auth',
  routes: <RouteBase>[
    GoRoute(
      path: AppPaths.auth,
      name: 'customer-phone',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          appPage(state, const AuthEntryScreen(), entry: true),
    ),
    GoRoute(
      path: AppPaths.customerCode,
      name: 'customer-code',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          appPage(state, const CodeScreen(), entry: true),
    ),
    GoRoute(
      path: AppPaths.staffLogin,
      name: 'staff-login',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          appPage(state, const StaffLoginScreen(), entry: true),
    ),
    GoRoute(
      path: AppPaths.changePassword,
      name: 'change-password',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          appPage(state, const ChangePasswordScreen(), entry: true),
    ),
    GoRoute(
      path: AppPaths.staffPassword,
      name: 'staff-password',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          appPage(state, const StaffPasswordScreen(), entry: true),
    ),
    GoRoute(
      path: AppPaths.customerName,
      name: 'customer-name',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          appPage(state, const CustomerNameScreen(), entry: true),
    ),
    GoRoute(
      path: AppPaths.unreachable,
      name: 'session-unreachable',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          appPage(state, const UnreachableScreen(), entry: true),
    ),
    GoRoute(
      path: AppPaths.wrongSurface,
      name: 'wrong-surface',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          appPage(state, const WrongSurfaceScreen(), entry: true),
    ),
  ],
);
