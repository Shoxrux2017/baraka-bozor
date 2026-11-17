import 'dart:async';

import 'package:baraka_bozor/core/routing/fading_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const Key _faded = Key('faded');

Future<GoRouter> _pumpApp(WidgetTester tester, {required bool reduced}) async {
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/fade',
        pageBuilder: (BuildContext context, GoRouterState state) => fadingPage(
          state,
          const Scaffold(body: SizedBox.expand(key: _faded)),
          reduced: reduced,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.byKey(_faded),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

void main() {
  testWidgets('a fading page fades in 320 ms', (tester) async {
    final GoRouter router = await _pumpApp(tester, reduced: false);
    unawaited(router.push<void>('/fade'));
    await tester.pump();
    await tester.pump();
    expect(_opacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 160));
    expect(_opacity(tester), inExclusiveRange(0.3, 0.99));
    await tester.pump(const Duration(milliseconds: 160));
    expect(_opacity(tester), closeTo(1, 0.001));
    await tester.pumpAndSettle();
  });

  testWidgets('reduced, it fades in 200 ms', (tester) async {
    final GoRouter router = await _pumpApp(tester, reduced: true);
    unawaited(router.push<void>('/fade'));
    await tester.pump();
    await tester.pump();
    expect(_opacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_opacity(tester), closeTo(1, 0.001));
    await tester.pumpAndSettle();
  });

  testWidgets('it leaves in 200 ms', (tester) async {
    final GoRouter router = await _pumpApp(tester, reduced: false);
    unawaited(router.push<void>('/fade'));
    await tester.pumpAndSettle();
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_opacity(tester), inExclusiveRange(0.01, 0.99));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_opacity(tester), closeTo(0, 0.001));
    await tester.pumpAndSettle();
    expect(find.byKey(_faded), findsNothing);
  });
}
