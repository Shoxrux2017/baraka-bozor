import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import 'change_password_screen.dart';
import 'code_screen.dart';
import 'customer_mode_screen.dart';
import 'phone_screen.dart';
import 'staff_login_screen.dart';
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
      builder: (BuildContext context, GoRouterState state) =>
          const PhoneScreen(),
    ),
    GoRoute(
      path: AppPaths.customerCode,
      name: 'customer-code',
      builder: (BuildContext context, GoRouterState state) =>
          const CodeScreen(),
    ),
    GoRoute(
      path: AppPaths.staffLogin,
      name: 'staff-login',
      builder: (BuildContext context, GoRouterState state) =>
          const StaffLoginScreen(),
    ),
    GoRoute(
      path: AppPaths.changePassword,
      name: 'change-password',
      builder: (BuildContext context, GoRouterState state) =>
          const ChangePasswordScreen(),
    ),
    GoRoute(
      path: AppPaths.customerMode,
      name: 'customer-mode',
      builder: (BuildContext context, GoRouterState state) =>
          const CustomerModeScreen(),
    ),
    GoRoute(
      path: AppPaths.unreachable,
      name: 'session-unreachable',
      builder: (BuildContext context, GoRouterState state) =>
          const UnreachableScreen(),
    ),
    GoRoute(
      path: AppPaths.wrongSurface,
      name: 'wrong-surface',
      builder: (BuildContext context, GoRouterState state) =>
          const WrongSurfaceScreen(),
    ),
  ],
);
