import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:baraka_bozor/core/routing/app_page.dart';

GoRouterState stateFor({String? name = 'p'}) {
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(path: '/p/:id', builder: (_, _) => const SizedBox()),
    ],
  );
  addTearDown(router.dispose);
  return GoRouterState(
    router.configuration,
    uri: Uri.parse('/p/7?tab=a'),
    matchedLocation: '/p/7',
    name: name,
    path: '/p/:id',
    fullPath: '/p/:id',
    pathParameters: const <String, String>{'id': '7'},
    pageKey: const ValueKey<String>('/p/7'),
  );
}

Widget _screen(Widget child) => Scaffold(body: SizedBox.expand(child: child));

GoRouter _router() {
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: 'first',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            appPage(state, _screen(const Text('first')), entry: true),
      ),
      GoRoute(
        path: '/second',
        name: 'second',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            appPage(state, _screen(const Text('second'))),
      ),
      GoRoute(
        path: '/held',
        name: 'held',
        pageBuilder: (BuildContext context, GoRouterState state) => appPage(
          state,
          _screen(const PopScope(canPop: false, child: Text('held'))),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  return router;
}

Future<GoRouter> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final GoRouter router = _router();
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  const Widget child = SizedBox();

  test('a page the person opens is a MaterialPage with the route\'s key, name and arguments', () {
    final Page<void> page = appPage(stateFor(), child);
    expect(page, isA<MaterialPage<void>>());
    expect(page.key, const ValueKey<String>('/p/7'));
    expect(page.name, 'p');
    expect(page.arguments, <String, String>{'id': '7', 'tab': 'a'});
    expect(page.restorationId, '/p/7');
    expect((page as MaterialPage<void>).child, same(child));
  });

  test('an entry page has no transition', () {
    final Page<void> page = appPage(stateFor(), child, entry: true);
    expect(page, isA<NoTransitionPage<void>>());
    expect(page.key, const ValueKey<String>('/p/7'));
    expect(page.name, 'p');
    expect(page.arguments, <String, String>{'id': '7', 'tab': 'a'});
    expect(page.restorationId, '/p/7');
    final NoTransitionPage<void> none = page as NoTransitionPage<void>;
    expect(none.child, same(child));
    expect(none.transitionDuration, Duration.zero);
  });

  test('a route without a name is named by its path', () {
    expect(appPage(stateFor(name: null), child).name, '/p/:id');
  });

  testWidgets('a pushed page slides over the one beneath', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpApp(tester);
    router.push('/second');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('first'), findsNothing);
  });

  testWidgets('on iOS an edge swipe takes the page back', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpApp(tester);
    router.push('/second');
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(5, 300), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('on iOS a page that holds its back stays under a swipe', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpApp(tester);
    router.push('/held');
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(5, 300), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.text('held'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
