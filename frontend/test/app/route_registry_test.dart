import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/route_fragment_scan.dart';

/// Guards decision `D-4`: the route registry in `lib/app/router.dart` is an
/// explicit list, so the thing that can go wrong is a feature shipping a
/// fragment nobody registered. The backend half fails at boot; this fails here.
void main() {
  group('the production registry', () {
    test('is being checked against the real tree, not a wrong directory', () {
      // Without this, a changed working directory would make every assertion
      // below pass by finding nothing at all.
      expect(
        File('lib/app/router.dart').existsSync(),
        isTrue,
        reason: 'tests must run from the package root',
      );
    });

    test('registers every route fragment present under lib/features', () {
      final List<RouteFragment> missing = unregisteredFragments(
        featuresDirectory: Directory('lib/features'),
        routerSource: File('lib/app/router.dart').readAsStringSync(),
      );

      expect(
        missing.map((RouteFragment f) => f.importPath),
        isEmpty,
        reason:
            'add the fragment to featureRouteFragments in lib/app/router.dart',
      );
    });
  });

  group('the check itself', () {
    late Directory features;

    setUp(() {
      features = Directory.systemTemp.createTempSync('bb_route_scan');
      _writeFragment(features, 'catalog');
    });

    tearDown(() => features.deleteSync(recursive: true));

    test('discovers a fragment and derives its import path and symbol', () {
      final List<RouteFragment> found = discoverRouteFragments(features);

      expect(found, hasLength(1));
      expect(found.single.feature, 'catalog');
      expect(
        found.single.importPath,
        'features/catalog/presentation/catalog_routes.dart',
      );
      expect(found.single.symbol, 'catalogRoutes');
    });

    test('reports a fragment the router never imports', () {
      final List<RouteFragment> missing = unregisteredFragments(
        featuresDirectory: features,
        routerSource: 'const List<FeatureRoutes> featureRouteFragments = [];',
      );

      expect(missing.single.importPath, contains('catalog_routes.dart'));
    });

    test('reports a fragment the router imports but never registers', () {
      // An import alone proves nothing: the entry in the list is what puts the
      // routes in the table.
      final List<RouteFragment> missing = unregisteredFragments(
        featuresDirectory: features,
        routerSource: '''
import '../features/catalog/presentation/catalog_routes.dart';

const List<FeatureRoutes> featureRouteFragments = <FeatureRoutes>[];
''',
      );

      expect(missing.single.symbol, 'catalogRoutes');
    });

    test('accepts a fragment that is imported and registered', () {
      final List<RouteFragment> missing = unregisteredFragments(
        featuresDirectory: features,
        routerSource: '''
import '../features/catalog/presentation/catalog_routes.dart';

const List<FeatureRoutes> featureRouteFragments = <FeatureRoutes>[
  catalogRoutes,
];
''',
      );

      expect(missing, isEmpty);
    });

    test('does not count a fragment named only in a comment', () {
      // The registry's own dartdoc explains the convention in prose, so a
      // mention must not be mistaken for an entry in the list.
      final List<RouteFragment> missing = unregisteredFragments(
        featuresDirectory: features,
        routerSource: '''
import '../features/catalog/presentation/catalog_routes.dart';

/// Add catalogRoutes to this list when the catalog feature lands.
const List<FeatureRoutes> featureRouteFragments = <FeatureRoutes>[];
''',
      );

      expect(missing.single.symbol, 'catalogRoutes');
    });

    test('turns a multi-word feature directory into a camelCase symbol', () {
      _writeFragment(features, 'order_history');

      final RouteFragment fragment = discoverRouteFragments(features)
          .firstWhere((RouteFragment f) => f.feature == 'order_history');

      expect(fragment.symbol, 'orderHistoryRoutes');
    });

    test('ignores a feature that declares no routes', () {
      Directory('${features.path}/notifications/data')
          .createSync(recursive: true);

      expect(
        discoverRouteFragments(features).map((RouteFragment f) => f.feature),
        <String>['catalog'],
      );
    });

    test('treats a missing features directory as no fragments', () {
      // The legitimate state until the first feature lands, exactly as an
      // empty module directory is on the backend half.
      expect(
        discoverRouteFragments(Directory('${features.path}/does_not_exist')),
        isEmpty,
      );
    });
  });
}

void _writeFragment(Directory features, String feature) {
  final Directory presentation = Directory(
    '${features.path}/$feature/presentation',
  )..createSync(recursive: true);
  File('${presentation.path}/${feature}_routes.dart').writeAsStringSync('');
}
