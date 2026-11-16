import 'package:baraka_bozor/core/widgets/swipe_to_remove.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const Key rowKey = ValueKey<String>('row');
  const Duration frame = Duration(milliseconds: 16);
  const Key buttonKey = ValueKey<String>('button');
  int removed = 0;
  int taps = 0;
  List<bool> reveals = <bool>[];

  Future<void> show(
    WidgetTester tester, {
    bool removing = false,
    bool reducedMotion = false,
    bool inList = false,
    bool reveal = false,
    bool revealed = false,
    bool semanticsAction = true,
    double width = 800,
  }) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final Widget swipe = SwipeToRemove(
      label: 'Remove',
      removing: removing,
      onRemove: () => removed++,
      reveal: reveal,
      revealed: revealed,
      onRevealChanged: reveals.add,
      semanticsAction: semanticsAction,
      buttonKey: buttonKey,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: reveal ? () => taps++ : null,
        child: const ColoredBox(
          key: rowKey,
          color: Colors.transparent,
          child: SizedBox(height: 300),
        ),
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
                    child: SizedBox(width: width, child: swipe),
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

  setUp(() {
    removed = 0;
    taps = 0;
    reveals = <bool>[];
  });

  Future<void> dragSlowly(WidgetTester tester, double dx) async {
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byKey(rowKey)),
    );
    // The row's own tap rule decides the drag after the touch slop, which
    // the first steps spend; the row then follows the rest of [dx].
    const double slop = 20;
    final double total = dx - slop;
    final int steps = (total.abs() / 10).ceil();
    for (int i = 0; i < steps; i++) {
      await gesture.moveBy(Offset(total / steps, 0));
      await tester.pump(frame);
    }
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
  }

  testWidgets('a fast drag left removes', (WidgetTester tester) async {
    await show(tester);

    await tester.fling(find.byKey(rowKey), const Offset(-300, 0), 1000);
    await run(tester, const Duration(milliseconds: 280));

    expect(removed, 1);
    expect(offset(tester), lessThan(-800));
    await tester.pumpAndSettle();
    expect(removed, 1);
  });

  testWidgets('a second swipe while the row slides out still removes once', (
    WidgetTester tester,
  ) async {
    await show(tester);

    await tester.fling(find.byKey(rowKey), const Offset(-300, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.flingFrom(const Offset(300, 150), const Offset(-100, 0), 500);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(removed, 1);
    expect(offset(tester), lessThan(-800));
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

  testWidgets('the row has an action for screen readers and no scroll '
      'actions', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await show(tester);

    final SemanticsNode node = tester.getSemantics(find.byKey(rowKey));
    final SemanticsData data = node.getSemanticsData();
    final List<CustomSemanticsAction> actions = data.customSemanticsActionIds!
        .map(CustomSemanticsAction.getAction)
        .whereType<CustomSemanticsAction>()
        .toList();
    expect(actions.single.label, 'Remove');
    expect(data.hasAction(SemanticsAction.scrollLeft), isFalse);
    expect(data.hasAction(SemanticsAction.scrollRight), isFalse);

    node.owner!.performAction(
      node.id,
      SemanticsAction.customAction,
      CustomSemanticsAction.getIdentifier(actions.single),
    );
    await run(tester, const Duration(milliseconds: 280));
    expect(removed, 1);
    handle.dispose();
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

  group('reveal mode', () {
    testWidgets('a medium swipe reveals the red button and keeps the row at '
        '-88', (WidgetTester tester) async {
      await show(tester, reveal: true, width: 360);

      await dragSlowly(tester, -150);
      await run(tester, const Duration(milliseconds: 300));

      expect(offset(tester), -88);
      expect(reveals, <bool>[true]);
      expect(removed, 0);
      expect(
        find.descendant(
          of: find.byKey(buttonKey),
          matching: find.text('Remove'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(buttonKey),
          matching: find.byIcon(Icons.delete_outline),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping the revealed button removes', (
      WidgetTester tester,
    ) async {
      await show(tester, reveal: true, width: 360);
      await dragSlowly(tester, -150);
      await run(tester, const Duration(milliseconds: 300));

      await tester.tap(find.byKey(buttonKey));
      await tester.pump();

      expect(removed, 1);
      expect(offset(tester), -88);
    });

    testWidgets('a long swipe removes at once', (WidgetTester tester) async {
      await show(tester, reveal: true, width: 360);

      await dragSlowly(tester, -234);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(removed, 0);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(frame);

      expect(offset(tester), -360);
      expect(removed, 1);
    });

    testWidgets('a fast fling past the lower mark removes at once', (
      WidgetTester tester,
    ) async {
      await show(tester, reveal: true, width: 360);

      await tester.fling(find.byKey(rowKey), const Offset(-170, 0), 2000);
      await run(tester, const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 20));

      expect(offset(tester), -360);
      expect(removed, 1);
    });

    testWidgets('a short swipe springs back', (WidgetTester tester) async {
      await show(tester, reveal: true, width: 360);

      await dragSlowly(tester, -30);
      await run(tester, const Duration(milliseconds: 300));

      expect(offset(tester), 0);
      expect(reveals, isEmpty);
      expect(removed, 0);
    });

    testWidgets('a tap on a revealed row closes it and does not reach the '
        'row', (WidgetTester tester) async {
      await show(tester, reveal: true, width: 360);
      await dragSlowly(tester, -150);
      await run(tester, const Duration(milliseconds: 300));
      await show(tester, reveal: true, revealed: true, width: 360);
      reveals.clear();

      await tester.tapAt(const Offset(100, 150));
      await tester.pump();

      expect(taps, 0);
      expect(reveals, <bool>[false]);
    });

    testWidgets('turning revealed off from outside springs the row back', (
      WidgetTester tester,
    ) async {
      await show(tester, reveal: true, width: 360);
      await dragSlowly(tester, -150);
      await run(tester, const Duration(milliseconds: 300));
      await show(tester, reveal: true, revealed: true, width: 360);

      await show(tester, reveal: true, width: 360);
      await run(tester, const Duration(milliseconds: 300));

      expect(offset(tester), 0);
    });

    testWidgets('a mostly vertical drag does not move the row', (
      WidgetTester tester,
    ) async {
      await show(tester, reveal: true, width: 360, inList: true);

      await tester.drag(find.byKey(rowKey), const Offset(-20, -120));
      await tester.pumpAndSettle();

      expect(offset(tester), 0);
      expect(reveals, isEmpty);
      expect(tester.getTopLeft(find.byKey(rowKey)).dy, lessThan(0));
    });

    testWidgets('without the semantics action the row adds no custom '
        'action', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await show(tester, reveal: true, width: 360, semanticsAction: false);

      final SemanticsData data = tester
          .getSemantics(find.byKey(rowKey))
          .getSemanticsData();

      expect(data.customSemanticsActionIds ?? <int>[], isEmpty);
      handle.dispose();
    });

    testWidgets('reduced motion moves the row without sliding', (
      WidgetTester tester,
    ) async {
      await show(tester, reveal: true, width: 360, reducedMotion: true);

      await dragSlowly(tester, -150);
      await tester.pump();

      expect(offset(tester), -88);
      expect(reveals, <bool>[true]);
    });
  });
}
