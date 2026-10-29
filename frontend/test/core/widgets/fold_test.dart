import 'package:baraka_bozor/core/widgets/fold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _box(String id) => SizedBox(key: Key(id), height: 40, width: 100);

Widget _app(
  List<String> items, {
  bool reduced = false,
  Widget Function(String)? build,
}) {
  return MaterialApp(
    home: Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: Scaffold(
          body: SingleChildScrollView(
            child: FoldingColumn<String>(
              items: items,
              keyOf: (String s) => s,
              itemBuilder: (BuildContext c, String s) =>
                  build == null ? _box(s) : build(s),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The height the item's fold takes in the column.
double _fold(WidgetTester t, String id) => t
    .getSize(
      find.ancestor(of: find.byKey(Key(id)), matching: find.byType(Fold)).first,
    )
    .height;

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const Key('c'),
    onTap: () => setState(() => n++),
    child: SizedBox(height: 40, child: Text('n$n')),
  );
}

void main() {
  testWidgets('the first items show without folding', (tester) async {
    await tester.pumpWidget(_app(<String>['a', 'b']));
    expect(_fold(tester, 'a'), 40);
    expect(_fold(tester, 'b'), 40);
  });

  testWidgets('a new item unfolds in 0.3 s', (tester) async {
    await tester.pumpWidget(_app(<String>['a']));
    await tester.pumpWidget(_app(<String>['a', 'b']));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final double mid = _fold(tester, 'b');
    expect(mid, greaterThan(0));
    expect(mid, lessThan(40));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(_fold(tester, 'b'), 40);
  });

  testWidgets('a removed item folds in place in 0.26 s, then leaves', (
    tester,
  ) async {
    await tester.pumpWidget(_app(<String>['a', 'b', 'c']));
    await tester.pumpWidget(_app(<String>['a', 'c']));
    await tester.pump();
    final double aY = tester.getTopLeft(find.byKey(const Key('a'))).dy;
    final double bY = tester.getTopLeft(find.byKey(const Key('b'))).dy;
    final double cY = tester.getTopLeft(find.byKey(const Key('c'))).dy;
    expect(bY, greaterThan(aY));
    expect(bY, lessThan(cY));
    final Iterable<IgnorePointer> guards = tester.widgetList<IgnorePointer>(
      find.ancestor(
        of: find.byKey(const Key('b')),
        matching: find.byType(IgnorePointer),
      ),
    );
    expect(guards.any((IgnorePointer w) => w.ignoring), isTrue);
    await tester.pump(const Duration(milliseconds: 130));
    final double mid = _fold(tester, 'b');
    expect(mid, greaterThan(0));
    expect(mid, lessThan(40));
    await tester.pump(const Duration(milliseconds: 140));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('b')), findsNothing);
  });

  testWidgets('a fold fades out in 200 ms while the height is still going', (
    tester,
  ) async {
    await tester.pumpWidget(_app(<String>['a', 'b']));
    await tester.pumpWidget(_app(<String>['a']));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final Opacity fade = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byKey(const Key('b')),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(fade.opacity, closeTo(0, 0.001));
    expect(_fold(tester, 'b'), greaterThan(0));
  });
  testWidgets('an item keeps its state while a neighbour folds', (
    tester,
  ) async {
    Widget build(String s) => s == 'c' ? const _Counter() : _box(s);
    await tester.pumpWidget(_app(<String>['a', 'b', 'c'], build: build));
    for (int i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('c')));
    }
    await tester.pump();
    expect(find.text('n3'), findsOneWidget);
    await tester.pumpWidget(_app(<String>['a', 'c'], build: build));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('n3'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('n3'), findsOneWidget);
  });

  testWidgets('a key that comes back unfolds in place', (tester) async {
    await tester.pumpWidget(_app(<String>['a', 'b']));
    await tester.pumpWidget(_app(<String>['a']));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final double folding = _fold(tester, 'b');
    expect(folding, lessThan(40));
    await tester.pumpWidget(_app(<String>['a', 'b']));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(_fold(tester, 'b'), greaterThan(folding));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_fold(tester, 'b'), 40);
    final Iterable<IgnorePointer> guards = tester.widgetList<IgnorePointer>(
      find.ancestor(
        of: find.byKey(const Key('b')),
        matching: find.byType(IgnorePointer),
      ),
    );
    expect(guards.any((IgnorePointer w) => w.ignoring), isFalse);
  });

  testWidgets('with reduced motion nothing folds', (tester) async {
    await tester.pumpWidget(_app(<String>['a', 'b'], reduced: true));
    await tester.pumpWidget(_app(<String>['a'], reduced: true));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('b')), findsNothing);
  });

  Widget single(bool shown, {bool appear = false, VoidCallback? onFolded}) =>
      MaterialApp(
        home: Scaffold(
          body: Fold(
            shown: shown,
            appear: appear,
            onFolded: onFolded,
            child: _box('x'),
          ),
        ),
      );

  double heightOf(WidgetTester t) => t.getSize(find.byType(Fold)).height;

  testWidgets('a fold first built hidden starts folded and still', (
    tester,
  ) async {
    int folded = 0;
    await tester.pumpWidget(single(false, onFolded: () => folded++));
    await tester.pump();
    expect(heightOf(tester), 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(folded, 0);
  });

  testWidgets('a fold reversed while folding keeps its height', (tester) async {
    await tester.pumpWidget(single(true));
    await tester.pumpWidget(single(false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    final double h = heightOf(tester);
    expect(h, inInclusiveRange(1, 39));
    await tester.pumpWidget(single(true));
    await tester.pump();
    expect(heightOf(tester), closeTo(h, 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(heightOf(tester), greaterThan(h));
    await tester.pump(const Duration(milliseconds: 400));
    expect(heightOf(tester), 40);
  });

  testWidgets('a fold reversed while unfolding keeps its height', (
    tester,
  ) async {
    await tester.pumpWidget(single(false));
    await tester.pumpWidget(single(true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final double h = heightOf(tester);
    expect(h, inInclusiveRange(1, 39));
    await tester.pumpWidget(single(false));
    await tester.pump();
    expect(heightOf(tester), closeTo(h, 1));
    await tester.pump(const Duration(milliseconds: 60));
    expect(heightOf(tester), lessThan(h));
    await tester.pump(const Duration(milliseconds: 400));
    expect(heightOf(tester), 0);
  });
}
