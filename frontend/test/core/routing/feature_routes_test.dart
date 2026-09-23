import 'package:baraka_bozor/core/routing/feature_routes.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRoute _route(
  String path, {
  String? name,
  List<RouteBase> children = const [],
}) {
  return GoRoute(
    path: path,
    name: name,
    builder: (BuildContext context, GoRouterState state) =>
        const SizedBox.shrink(),
    routes: children,
  );
}

void main() {
  group('collectFeatureRoutes', () {
    test('returns no routes when no fragment is registered', () {
      expect(collectFeatureRoutes(const <FeatureRoutes>[]), isEmpty);
    });

    test('collects every fragment in registration order', () {
      final routes = collectFeatureRoutes(<FeatureRoutes>[
        FeatureRoutes(feature: 'auth', routes: <RouteBase>[_route('/auth')]),
        FeatureRoutes(
          feature: 'customer',
          routes: <RouteBase>[_route('/customer'), _route('/cart')],
        ),
      ]);

      expect(routes.whereType<GoRoute>().map((GoRoute r) => r.path), <String>[
        '/auth',
        '/customer',
        '/cart',
      ]);
    });

    test('rejects the same path declared by two fragments, naming both', () {
      expect(
        () => collectFeatureRoutes(<FeatureRoutes>[
          FeatureRoutes(
            feature: 'orders',
            routes: <RouteBase>[_route('/orders')],
          ),
          FeatureRoutes(
            feature: 'shopper',
            routes: <RouteBase>[_route('/orders')],
          ),
        ]),
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            allOf(contains('/orders'), contains('orders'), contains('shopper')),
          ),
        ),
      );
    });

    test(
      'rejects the same route name declared by two fragments, naming both',
      () {
        expect(
          () => collectFeatureRoutes(<FeatureRoutes>[
            FeatureRoutes(
              feature: 'orders',
              routes: <RouteBase>[_route('/orders/:id', name: 'orderDetail')],
            ),
            FeatureRoutes(
              feature: 'operator',
              routes: <RouteBase>[
                _route('/operator/orders/:id', name: 'orderDetail'),
              ],
            ),
          ]),
          throwsA(
            isA<StateError>().having(
              (StateError e) => e.message,
              'message',
              allOf(
                contains('orderDetail'),
                contains('orders'),
                contains('operator'),
              ),
            ),
          ),
        );
      },
    );

    test(
      'resolves a child route against its parent before comparing paths',
      () {
        expect(
          () => collectFeatureRoutes(<FeatureRoutes>[
            FeatureRoutes(
              feature: 'customer',
              routes: <RouteBase>[
                _route('/customer', children: <RouteBase>[_route('orders')]),
              ],
            ),
            FeatureRoutes(
              feature: 'orders',
              routes: <RouteBase>[_route('/customer/orders')],
            ),
          ]),
          throwsA(
            isA<StateError>().having(
              (StateError e) => e.message,
              'message',
              contains('/customer/orders'),
            ),
          ),
        );
      },
    );

    test('accepts the same relative child path under different parents', () {
      final routes = collectFeatureRoutes(<FeatureRoutes>[
        FeatureRoutes(
          feature: 'customer',
          routes: <RouteBase>[
            _route('/customer', children: <RouteBase>[_route('orders')]),
          ],
        ),
        FeatureRoutes(
          feature: 'shopper',
          routes: <RouteBase>[
            _route('/shopper', children: <RouteBase>[_route('orders')]),
          ],
        ),
      ]);

      expect(routes, hasLength(2));
    });
  });
}
