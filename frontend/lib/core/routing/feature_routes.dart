import 'package:go_router/go_router.dart';

/// One feature's contribution to the application route table.
///
/// A feature declares its own fragment in
/// `lib/features/<feature>/presentation/<feature>_routes.dart` and the root
/// router collects it. This is the Flutter half of decision `D-8`
/// (`docs/07-architecture.md` section 3): feature tracks never edit each
/// other's routes.
class FeatureRoutes {
  const FeatureRoutes({required this.feature, required this.routes});

  /// The feature directory name under `lib/features/`, used in collision
  /// messages so a clash names the two fragments that caused it.
  final String feature;

  final List<RouteBase> routes;
}

/// Flattens [fragments] into one route table, rejecting collisions.
///
/// Two fragments claiming the same fully-resolved path, or the same route
/// name, is a defect that would otherwise surface as a route silently
/// resolving to the wrong feature. It throws instead, so the application
/// fails at startup rather than in production navigation.
List<RouteBase> collectFeatureRoutes(List<FeatureRoutes> fragments) {
  final Map<String, String> pathOwners = <String, String>{};
  final Map<String, String> nameOwners = <String, String>{};
  final List<RouteBase> collected = <RouteBase>[];

  for (final FeatureRoutes fragment in fragments) {
    for (final RouteBase route in fragment.routes) {
      _claim(route, '', fragment.feature, pathOwners, nameOwners);
    }
    collected.addAll(fragment.routes);
  }

  return List<RouteBase>.unmodifiable(collected);
}

void _claim(
  RouteBase route,
  String parentPath,
  String feature,
  Map<String, String> pathOwners,
  Map<String, String> nameOwners,
) {
  String fullPath = parentPath;

  if (route is GoRoute) {
    fullPath = _resolve(parentPath, route.path);

    final String? pathOwner = pathOwners[fullPath];
    if (pathOwner != null) {
      throw StateError(
        'Route path "$fullPath" is declared by both the "$pathOwner" and '
        '"$feature" route fragments. A path may be declared once. See '
        'docs/07-architecture.md section 3, decision D-8.',
      );
    }
    pathOwners[fullPath] = feature;

    final String? routeName = route.name;
    if (routeName != null) {
      final String? nameOwner = nameOwners[routeName];
      if (nameOwner != null) {
        throw StateError(
          'Route name "$routeName" is declared by both the "$nameOwner" and '
          '"$feature" route fragments. A name may be declared once, because '
          'named navigation would otherwise resolve to whichever fragment was '
          'registered first. See docs/07-architecture.md section 3, '
          'decision D-8.',
        );
      }
      nameOwners[routeName] = feature;
    }
  }

  for (final RouteBase child in route.routes) {
    _claim(child, fullPath, feature, pathOwners, nameOwners);
  }
}

/// Resolves a GoRouter child path against its parent.
///
/// A path starting with `/` is absolute and stands alone; anything else is
/// relative to the parent, which is what makes `/customer` plus `orders`
/// collide with a `/customer/orders` declared elsewhere.
String _resolve(String parentPath, String path) {
  if (path.startsWith('/')) {
    return path;
  }
  if (parentPath.isEmpty || parentPath == '/') {
    return '/$path';
  }
  return '$parentPath/$path';
}
