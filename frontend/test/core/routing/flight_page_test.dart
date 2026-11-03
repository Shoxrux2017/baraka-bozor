import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:baraka_bozor/core/routing/app_page.dart';
import 'package:baraka_bozor/core/routing/flight_page.dart';
import 'package:baraka_bozor/core/widgets/kit_app_bar.dart';

const Size _screen = Size(800, 600);
const Key _copy = Key('copy');
const Key _target = Key('target');
const Key _source = Key('source');
const Key _mid = Key('mid');
const Key _fade = ValueKey<String>('flight-page-fade');

/// A piece twice the size of its place, so a flight scales.
final Rect _from = Rect.fromLTWH(10, 20, 200, 100);

class _Rig {
  _Rig(this.router, this.holding);

  final GoRouter router;
  final ValueNotifier<bool> holding;
}

GoRouterState _stateOf(GoRouter router) => GoRouterState(
  router.configuration,
  uri: Uri.parse('/flight'),
  matchedLocation: '/flight',
  name: 'flight',
  path: '/flight',
  fullPath: '/flight',
  pathParameters: const <String, String>{},
  pageKey: const ValueKey<String>('/flight'),
);

Widget _page({Offset at = const Offset(100, 200)}) => Scaffold(
  body: Stack(
    children: <Widget>[
      Positioned(
        left: at.dx,
        top: at.dy,
        child: const FlightTarget(
          id: 'card',
          child: SizedBox(key: _target, width: 100, height: 50),
        ),
      ),
    ],
  ),
);

Future<_Rig> _pumpApp(
  WidgetTester tester, {
  bool withOpening = true,
  Offset at = const Offset(100, 200),
  FlightFit fit = FlightFit.scale,
  Duration flight = const Duration(milliseconds: 400),
  Duration flightBack = const Duration(milliseconds: 400),
}) async {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final ValueNotifier<bool> holding = ValueNotifier<bool>(false);
  addTearDown(holding.dispose);
  final FlightOpening opening = FlightOpening(
    screen: _screen,
    holding: holding,
    items: <FlightItem>[
      FlightItem(
        id: 'card',
        from: _from,
        fit: fit,
        builder: (BuildContext context) => const SizedBox.expand(
          key: _copy,
          child: ColoredBox(color: Colors.red),
        ),
      ),
    ],
  );
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        pageBuilder: (BuildContext context, GoRouterState state) => appPage(
          state,
          const Scaffold(body: Text('below', key: _source)),
          entry: true,
        ),
      ),
      GoRoute(
        path: '/mid',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            appPage(state, const Scaffold(body: Text('mid', key: _mid))),
      ),
      GoRoute(
        path: '/flight',
        pageBuilder: (BuildContext context, GoRouterState state) => flightPage(
          state,
          _page(at: at),
          opening: withOpening ? opening : null,
          flight: flight,
          flightBack: flightBack,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return _Rig(router, holding);
}

/// Pushes the flight page and runs the two frames that start its tickers.
Future<void> _open(WidgetTester tester, _Rig rig) async {
  rig.router.push('/flight');
  await tester.pump();
  await tester.pump();
}

Rect _copyRect(WidgetTester tester) => tester.getRect(find.byKey(_copy));

double _pageOpacity(WidgetTester tester) =>
    tester.widget<FadeTransition>(find.byKey(_fade)).opacity.value;

double _targetOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find
          .ancestor(of: find.byKey(_target), matching: find.byType(Opacity))
          .first,
    )
    .opacity;

Matcher _rectNear(Rect expected) => isA<Rect>().having(
  (Rect r) =>
      (r.left - expected.left).abs() +
      (r.top - expected.top).abs() +
      (r.width - expected.width).abs() +
      (r.height - expected.height).abs(),
  'distance',
  lessThan(0.6),
);

void main() {
  const Rect place = Rect.fromLTWH(100, 200, 100, 50);

  testWidgets(
    'the page fades in over the still page below and the pieces fly from where they were',
    (WidgetTester tester) async {
      final _Rig rig = await _pumpApp(tester);
      await _open(tester, rig);
      expect(_copyRect(tester), _rectNear(_from));
      expect(_targetOpacity(tester), 0);
      expect(_pageOpacity(tester), 0);
      final Offset belowAtStart = tester.getTopLeft(find.byKey(_source));

      await tester.pump(const Duration(milliseconds: 60));
      expect(_pageOpacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 140));
      final Rect middle = _copyRect(tester);
      expect(middle.left, greaterThan(_from.left));
      expect(middle.left, lessThan(place.left));
      expect(middle.width, lessThan(_from.width));
      expect(middle.width, greaterThan(place.width));
      expect(_targetOpacity(tester), 0);
      expect(tester.getTopLeft(find.byKey(_source)), belowAtStart);

      await tester.pump(const Duration(milliseconds: 100));
      expect(_pageOpacity(tester), 1);
      expect(_targetOpacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_copyRect(tester), _rectNear(place));
      expect(_targetOpacity(tester), 0);

      await tester.pumpAndSettle();
      expect(find.byKey(_copy), findsNothing);
      expect(_targetOpacity(tester), 1);
    },
  );

  testWidgets('back flies the pieces home and fades the page out', (
    WidgetTester tester,
  ) async {
    final _Rig rig = await _pumpApp(tester);
    await _open(tester, rig);
    await tester.pumpAndSettle();

    rig.router.pop();
    await tester.pump();
    await tester.pump();
    expect(_copyRect(tester), _rectNear(place));
    expect(_targetOpacity(tester), 0);
    expect(_pageOpacity(tester), 1);

    await tester.pump(const Duration(milliseconds: 110));
    expect(
      _pageOpacity(tester),
      closeTo(1 - Curves.easeIn.transform(0.5), 0.02),
    );
    final Rect middle = _copyRect(tester);
    expect(middle.left, lessThan(place.left));
    expect(middle.left, greaterThan(_from.left));

    await tester.pump(const Duration(milliseconds: 110));
    expect(_pageOpacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 180));
    expect(_copyRect(tester), _rectNear(_from));

    await tester.pumpAndSettle();
    expect(find.byKey(_target), findsNothing);
    expect(rig.holding.value, isFalse);
  });

  testWidgets(
    'a back mid-flight turns back from where it is and leaves nothing hidden',
    (WidgetTester tester) async {
      final _Rig rig = await _pumpApp(tester);
      await _open(tester, rig);
      await tester.pump(const Duration(milliseconds: 150));
      final Rect drawn = _copyRect(tester);
      expect(drawn.left, greaterThan(_from.left));

      rig.router.pop();
      await tester.pump();
      await tester.pump();
      expect(_copyRect(tester), _rectNear(drawn));
      expect(rig.holding.value, isTrue);

      await tester.pump(const Duration(milliseconds: 60));
      final Rect nearer = _copyRect(tester);
      expect(nearer.left, lessThan(drawn.left));
      expect(nearer.left, greaterThan(_from.left));
      expect(_targetOpacity(tester), 0);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.byKey(_copy), findsNothing);
      expect(find.byKey(_target), findsNothing);
      expect(rig.holding.value, isFalse);

      // Opened again, it flies as the first time.
      await _open(tester, rig);
      expect(_copyRect(tester), _rectNear(_from));
      await tester.pumpAndSettle();
      expect(_targetOpacity(tester), 1);
      expect(rig.holding.value, isFalse);
    },
  );

  testWidgets('on iOS the page below does not slide', (
    WidgetTester tester,
  ) async {
    final _Rig rig = await _pumpApp(tester);
    rig.router.push('/mid');
    await tester.pumpAndSettle();
    final Offset before = tester.getTopLeft(find.byKey(_mid));
    await _open(tester, rig);
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getTopLeft(find.byKey(_mid)), before);
    await tester.pumpAndSettle();
    rig.router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getTopLeft(find.byKey(_mid)), before);
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a back-swipe let go halfway stays open and shows every piece', (
    WidgetTester tester,
  ) async {
    final _Rig rig = await _pumpApp(tester);
    await _open(tester, rig);
    await tester.pumpAndSettle();

    final TestGesture swipe = await tester.startGesture(const Offset(5, 300));
    await swipe.moveBy(const Offset(300, 0));
    await tester.pump();
    // The flight follows the finger.
    expect(find.byKey(_copy), findsOneWidget);
    expect(_copyRect(tester).left, lessThan(place.left));
    expect(_copyRect(tester).left, greaterThan(_from.left));
    expect(rig.holding.value, isTrue);
    await swipe.up();
    await tester.pumpAndSettle();

    expect(find.byKey(_target), findsOneWidget);
    expect(find.byKey(_copy), findsNothing);
    expect(_targetOpacity(tester), 1);
    expect(_pageOpacity(tester), 1);
    expect(rig.holding.value, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'an Android predictive back let go turns back from where the pieces are',
    (WidgetTester tester) async {
      final _Rig rig = await _pumpApp(tester);
      await _open(tester, rig);
      await tester.pumpAndSettle();

      Future<void> send(String method, [Map<String, Object?>? arguments]) {
        return tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/backgesture',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(method, arguments),
          ),
          (ByteData? _) {},
        );
      }

      await send('startBackGesture', <String, Object?>{
        'touchOffset': <double>[5, 300],
        'progress': 0.0,
        'swipeEdge': 0,
      });
      await tester.pump();
      await send('updateBackGestureProgress', <String, Object?>{
        'x': 100.0,
        'y': 300.0,
        'progress': 0.6,
        'swipeEdge': 0,
      });
      await tester.pump();
      final double beforeCommit = _pageOpacity(tester);
      expect(beforeCommit, closeTo(0.4, 0.02));

      await send('commitBackGesture');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 5));
      double last = _pageOpacity(tester);
      expect(last, lessThanOrEqualTo(beforeCommit + 0.001));
      Rect copy = _copyRect(tester);
      expect(copy.left, greaterThan(_from.left));
      expect(copy.left, lessThan(place.left));
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (find.byKey(_fade).evaluate().isEmpty) {
          break;
        }
        final double now = _pageOpacity(tester);
        expect(now, lessThanOrEqualTo(last + 0.001));
        last = now;
        if (find.byKey(_copy).evaluate().isNotEmpty) {
          copy = _copyRect(tester);
          expect(copy.left, lessThanOrEqualTo(place.left + 0.5));
          expect(copy.left, greaterThanOrEqualTo(_from.left - 0.5));
        }
      }
      await tester.pumpAndSettle();
      expect(find.byKey(_target), findsNothing);
      expect(rig.holding.value, isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('a back-swipe past half closes the page', (
    WidgetTester tester,
  ) async {
    final _Rig rig = await _pumpApp(tester);
    await _open(tester, rig);
    await tester.pumpAndSettle();

    final TestGesture swipe = await tester.startGesture(const Offset(5, 300));
    await swipe.moveBy(const Offset(500, 0));
    await tester.pump();
    await swipe.up();
    await tester.pumpAndSettle();

    expect(find.byKey(_target), findsNothing);
    expect(find.byKey(_source), findsOneWidget);
    expect(rig.holding.value, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('after the screen size changes back fades without a flight', (
    WidgetTester tester,
  ) async {
    final _Rig rig = await _pumpApp(tester);
    await _open(tester, rig);
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(600, 800);
    await tester.pump();
    rig.router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    expect(find.byKey(_copy), findsNothing);
    expect(_targetOpacity(tester), 1);
    expect(_pageOpacity(tester), lessThan(1));
    expect(_pageOpacity(tester), greaterThan(0));
    expect(rig.holding.value, isFalse);

    await tester.pumpAndSettle();
    expect(find.byKey(_target), findsNothing);
  });

  testWidgets('holding is true while the pieces are away', (
    WidgetTester tester,
  ) async {
    final _Rig rig = await _pumpApp(tester);
    expect(rig.holding.value, isFalse);
    await _open(tester, rig);
    expect(rig.holding.value, isTrue);
    await tester.pump(const Duration(milliseconds: 200));
    expect(rig.holding.value, isTrue);
    await tester.pumpAndSettle();
    expect(rig.holding.value, isFalse);

    rig.router.pop();
    await tester.pump();
    await tester.pump();
    expect(rig.holding.value, isTrue);
    await tester.pumpAndSettle();
    expect(rig.holding.value, isFalse);
  });

  testWidgets('a piece whose target is off the screen does not fly', (
    WidgetTester tester,
  ) async {
    final _Rig rig = await _pumpApp(tester, at: const Offset(900, 700));
    await _open(tester, rig);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(_copy), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byKey(_target), findsOneWidget);
  });

  testWidgets('a stretching piece is laid out at the size it has', (
    WidgetTester tester,
  ) async {
    final _Rig rig = await _pumpApp(tester, fit: FlightFit.stretch);
    await _open(tester, rig);
    expect(_copyRect(tester), _rectNear(_from));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_copyRect(tester), _rectNear(place));
    await tester.pumpAndSettle();
  });

  testWidgets('with reduced motion it only fades, 200 ms', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final _Rig rig = await _pumpApp(tester);
    await _open(tester, rig);
    expect(find.byKey(_copy), findsNothing);
    expect(_targetOpacity(tester), 1);
    expect(rig.holding.value, isFalse);
    expect(_pageOpacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_pageOpacity(tester), closeTo(Curves.easeOut.transform(0.5), 0.02));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_pageOpacity(tester), 1);

    rig.router.pop();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      _pageOpacity(tester),
      closeTo(1 - Curves.easeIn.transform(0.5), 0.02),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byKey(_target), findsNothing);
  });

  testWidgets('a target outside a flight page is its child', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FlightTarget(
          id: 'x',
          child: SizedBox(key: _target),
        ),
      ),
    );
    expect(find.byKey(_target), findsOneWidget);
  });

  testWidgets('without an opening the platform page is used', (
    WidgetTester tester,
  ) async {
    final _Rig rig = await _pumpApp(tester, withOpening: false);
    final Page<void> page = flightPage(
      _stateOf(rig.router),
      const SizedBox(),
      opening: null,
    );
    expect(page, isA<MaterialPage<void>>());
    await _open(tester, rig);
    await tester.pumpAndSettle();
    expect(find.byKey(_target), findsOneWidget);
    expect(find.byKey(_copy), findsNothing);
  });

  testWidgets('a title with titleFlight is a target; without it, not', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(appBar: kitAppBar(title: 'A', titleFlight: true)),
      ),
    );
    expect(
      find.ancestor(of: find.text('A'), matching: find.byType(FlightTarget)),
      findsOneWidget,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(appBar: kitAppBar(title: 'A')),
      ),
    );
    expect(find.byType(FlightTarget), findsNothing);
  });
}
