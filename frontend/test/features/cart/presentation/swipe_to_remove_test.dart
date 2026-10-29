import 'package:baraka_bozor/features/cart/presentation/swipe_to_remove.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const Key rowKey = ValueKey<String>('row');
  const Duration frame = Duration(milliseconds: 16);
  int removed = 0;

  Future<void> show(
    WidgetTester tester, {
    bool removing = false,
    bool reducedMotion = false,
    bool inList = false,
  }) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final Widget swipe = SwipeToRemove(
      label: 'Remove',
      removing: removing,
      onRemove: () => removed++,
      child: const ColoredBox(
        key: rowKey,
        color: Colors.transparent,
        child: SizedBox(height: 300),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: Scaffold(
            body: inList
                ? ListView(
                    children: <Widget>[swipe, const SizedBox(height: 2000)],
                  )
                : Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(width: 800, child: swipe),
                  ),
          ),
        ),
      ),
    );
  }

  double offset(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(rowKey)).dx;

  Future<void> run(WidgetTester tester, Duration length) async {
    await tester.pump();
    await tester.pump(length);
  }

  setUp(() => removed = 0);

  testWidgets('a fast drag left removes', (WidgetTester tester) async {
    await show(tester);

    await tester.fling(find.byKey(rowKey), const Offset(-300, 0), 1000);
    await run(tester, const Duration(milliseconds: 280));

    expect(removed, 1);
    expect(offset(tester), lessThan(-800));
    await tester.pumpAndSettle();
    expect(removed, 1);
  });

  testWidgets('a short slow drag springs back', (WidgetTester tester) async {
    await show(tester);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byKey(rowKey)),
    );
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();
    expect(offset(tester), closeTo(-60, 1));
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await run(tester, const Duration(milliseconds: 320));

    expect(offset(tester), 0);
    expect(removed, 0);
  });

  testWidgets('a drag right resists', (WidgetTester tester) async {
    await show(tester);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byKey(rowKey)),
    );
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();

    expect(offset(tester), greaterThan(0));
    expect(offset(tester), lessThan(110));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(removed, 0);
  });

  testWidgets('a vertical drag never moves the row', (
    WidgetTester tester,
  ) async {
    await show(tester, inList: true);

    await tester.drag(find.byKey(rowKey), const Offset(-20, -200));
    await tester.pumpAndSettle();

    expect(offset(tester), 0);
    expect(removed, 0);
    expect(tester.getTopLeft(find.byKey(rowKey)).dy, lessThan(0));
  });

  testWidgets('the row has an action for screen readers', (
    WidgetTester tester,
  ) async {
    await show(tester);

    final Semantics semantics = tester.widget<Semantics>(
      find.descendant(
        of: find.byType(SwipeToRemove),
        matching: find.byType(Semantics),
      ),
    );
    final Map<CustomSemanticsAction, VoidCallback> actions =
        semantics.properties.customSemanticsActions!;
    expect(actions.keys.single.label, 'Remove');

    actions.values.single();
    await run(tester, const Duration(milliseconds: 280));
    expect(removed, 1);
  });

  testWidgets('with reduced motion it removes and springs back without '
      'sliding', (WidgetTester tester) async {
    await show(tester, reducedMotion: true);

    await tester.fling(find.byKey(rowKey), const Offset(-300, 0), 1000);
    await tester.pump();
    expect(removed, 1);
    expect(offset(tester), lessThan(-800));

    await show(tester, reducedMotion: true, removing: true);
    await show(tester, reducedMotion: true);
    await tester.pump();
    expect(offset(tester), 0, reason: 'at once, with no frame between');
  });

  testWidgets('a failed removal springs back', (WidgetTester tester) async {
    await show(tester);
    await tester.fling(find.byKey(rowKey), const Offset(-300, 0), 1000);
    await run(tester, const Duration(milliseconds: 280));
    expect(removed, 1);

    await show(tester, removing: true);
    await tester.pump(frame);
    expect(offset(tester), lessThan(-800), reason: 'stays out while removing');

    await show(tester);
    await run(tester, const Duration(milliseconds: 320));
    expect(offset(tester), 0);
  });
}
