import 'dart:async';

import 'package:baraka_bozor/core/routing/rising_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const Key _rising = Key('rising');
const Size _screen = Size(800, 600);

/// A router whose `/up` route is built with [risingPage].
Future<GoRouter> _pumpApp(WidgetTester tester, {required bool reduced}) async {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/up',
        pageBuilder: (BuildContext context, GoRouterState state) => risingPage(
          state,
          const Scaffold(body: SizedBox.expand(key: _rising)),
          reduced: reduced,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  unawaited(router.push<void>('/up'));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('the screen leaves slowly at first and fast at the end', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpApp(tester, reduced: false);
    expect(tester.getTopLeft(find.byKey(_rising)).dy, 0);

    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    // Ease-in: half way through the 260 ms it has covered under half the
    // distance, and each quarter covers more than the one before.
    final double half = tester.getTopLeft(find.byKey(_rising)).dy;
    expect(half, greaterThan(0));
    expect(half, lessThan(_screen.height / 2));

    await tester.pump(const Duration(milliseconds: 65));
    final double threeQuarters = tester.getTopLeft(find.byKey(_rising)).dy;
    expect(threeQuarters - half, greaterThan(half / 2));
    await tester.pumpAndSettle();
  });

  testWidgets('with reduced motion the fade leaves the same way', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpApp(tester, reduced: true);

    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final double half = tester
        .widget<Opacity>(
          find.ancestor(
            of: find.byKey(_rising),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
    // Half way through the 200 ms it is still mostly there.
    expect(half, greaterThan(0.5));
    await tester.pumpAndSettle();
  });
}
