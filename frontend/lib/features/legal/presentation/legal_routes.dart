import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_page.dart';
import '../../../core/legal/legal_document_kind.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import 'legal_screen.dart';

/// The terms of use and the privacy policy: open pages, reachable signed in
/// or out (`AppPaths.openPages`).
final FeatureRoutes legalRoutes = FeatureRoutes(
  feature: 'legal',
  routes: <RouteBase>[
    GoRoute(
      path: AppPaths.legalTerms,
      name: 'legal-terms',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          appPage(state, const LegalScreen(kind: LegalDocumentKind.terms)),
    ),
    GoRoute(
      path: AppPaths.legalPrivacy,
      name: 'legal-privacy',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          appPage(state, const LegalScreen(kind: LegalDocumentKind.privacy)),
    ),
  ],
);
