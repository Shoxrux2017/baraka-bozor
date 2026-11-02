import 'package:baraka_bozor/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const Set<String> _entryNames = <String>{
  'bootstrap',
  'customer-phone',
  'customer-code',
  'staff-login',
  'change-password',
  'staff-password',
  'customer-name',
  'session-unreachable',
  'wrong-surface',
  'account-deleted',
  'catalog-home',
  'customer-favorites',
  'customer-orders',
  'customer-profile',
  'shopper-orders',
  'courier-orders',
  'shell-manager',
  'admin-categories',
  'admin-products',
  'admin-product-new',
  'admin-product',
  'admin-staff',
  'admin-customers',
  'admin-legal-documents',
  'admin-settings',
  'operations-board',
  'operations-order',
};

const Set<String> _pageNames = <String>{
  'catalog-categories',
  'catalog-category',
  'catalog-recommended',
  'catalog-search',
  'catalog-all-products',
  'catalog-product',
  'cart',
  'checkout',
  'customer-order',
  'customer-order-edit',
  'customer-order-add',
  'customer-order-rate',
  'customer-edit-profile',
  'customer-delete-account',
  'customer-addresses',
  'customer-address-new',
  'customer-address',
  'legal-terms',
  'legal-privacy',
  'shopper-order',
  'shopper-replace',
  'shopper-done',
  'courier-order',
};

void _walk(List<RouteBase> routes, void Function(RouteBase route) visit) {
  for (final RouteBase route in routes) {
    visit(route);
    if (route is StatefulShellRoute) {
      for (final StatefulShellBranch branch in route.branches) {
        _walk(branch.routes, visit);
      }
    } else {
      _walk(route.routes, visit);
    }
  }
}

List<RouteBase> _all(GoRouter router) {
  final List<RouteBase> all = <RouteBase>[];
  _walk(router.configuration.routes, all.add);
  return all;
}

GoRouterState _stateFor(GoRouter router, String? name, String path) {
  final String location = path.replaceAllMapped(
    RegExp(r':(\w+)\??'),
    (_) => '1',
  );
  final Map<String, String> params = <String, String>{
    for (final RegExpMatch m in RegExp(r':(\w+)').allMatches(path))
      m.group(1)!: '1',
  };
  return GoRouterState(
    router.configuration,
    uri: Uri.parse(location),
    matchedLocation: location,
    name: name,
    path: path,
    fullPath: path,
    pathParameters: params,
    pageKey: ValueKey<String>(location),
  );
}

void main() {
  test('no route keeps a builder', () {
    final GoRouter router = buildRouter();
    addTearDown(router.dispose);
    for (final RouteBase route in _all(router)) {
      if (route is GoRoute) {
        expect(route.builder, isNull, reason: route.path);
        if (route.redirect == null) {
          expect(route.pageBuilder, isNotNull, reason: route.path);
        }
      } else if (route is ShellRoute) {
        expect(route.builder, isNull);
        expect(route.pageBuilder, isNotNull);
      } else if (route is StatefulShellRoute) {
        expect(route.builder, isNull);
        expect(route.pageBuilder, isNotNull);
      }
    }
  });

  testWidgets('the flat routes stand in place and the rest slide in', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final BuildContext context = tester.element(find.byType(SizedBox));
    final GoRouter router = buildRouter();
    addTearDown(router.dispose);
    final Set<String> standing = <String>{};
    final Set<String> sliding = <String>{};
    for (final RouteBase route in _all(router)) {
      if (route is! GoRoute || route.pageBuilder == null) continue;
      final Page<dynamic> page = route.pageBuilder!(
        context,
        _stateFor(router, route.name, route.path),
      );
      final String name = route.name ?? route.path;
      if (page is NoTransitionPage) {
        standing.add(name);
      } else {
        expect(page, isA<MaterialPage<dynamic>>(), reason: name);
        sliding.add(name);
      }
    }
    expect(standing, _entryNames);
    expect(sliding, _pageNames);
  });

  testWidgets('the panel shells stand in place', (tester) async {
    await tester.pumpWidget(const SizedBox());
    final BuildContext context = tester.element(find.byType(SizedBox));
    final GoRouter router = buildRouter();
    addTearDown(router.dispose);
    int shells = 0;
    for (final RouteBase route in _all(router)) {
      if (route is ShellRoute) {
        shells++;
        final GoRoute first = route.routes.whereType<GoRoute>().first;
        final Page<dynamic> page = route.pageBuilder!(
          context,
          _stateFor(router, first.name, first.path),
          const SizedBox(),
        );
        expect(page, isA<NoTransitionPage<dynamic>>());
      }
    }
    expect(shells, 2);
  });
}
