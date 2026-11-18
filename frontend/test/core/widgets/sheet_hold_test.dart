import 'package:baraka_bozor/core/widgets/sheet_hold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _body = ValueKey<String>('body');

Widget _app({
  required bool holding,
  bool reduced = false,
  VoidCallback? onOuterDrag,
}) {
  return MaterialApp(
    home: Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: Scaffold(
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (_) => onOuterDrag?.call(),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SheetHold(
                holding: holding,
                child: const SizedBox(
                  key: _body,
                  width: 300,
                  height: 400,
                  child: ColoredBox(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('rubberBand follows the formula and never reaches the extent', () {
    expect(rubberBand(100, 400), closeTo(48.35, 0.01));
    // The band tends to the extent, never reaching it.
    expect(rubberBand(10000, 400), closeTo(372.88, 0.01));
    expect(rubberBand(10000, 400), lessThan(400));
    expect(rubberBand(-100, 400), closeTo(-rubberBand(100, 400), 1e-9));
    expect(rubberBand(0, 400), 0);
  });

  testWidgets('holding, a drag moves the child and it comes back in 380 ms', (
    tester,
  ) async {
    int outer = 0;
    await tester.pumpWidget(_app(holding: true, onOuterDrag: () => outer++));
    final double top = tester.getTopLeft(find.byKey(_body)).dy;

    final TestGesture g = await tester.startGesture(
      tester.getCenter(find.byKey(_body)),
    );
    await g.moveBy(const Offset(0, 40));
    await g.moveBy(const Offset(0, 60));
    await tester.pump();
    final double moved = tester.getTopLeft(find.byKey(_body)).dy - top;
    expect(moved, greaterThan(0));
    expect(moved, lessThan(100));
    expect(outer, 0);

    // It moves the other way too.
    await g.moveBy(const Offset(0, -300));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(_body)).dy - top, lessThan(0));

    await g.moveBy(const Offset(0, 400));
    await tester.pump();
    await g.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 190));
    final double half = tester.getTopLeft(find.byKey(_body)).dy - top;
    expect(half, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 191));
    expect(tester.getTopLeft(find.byKey(_body)).dy - top, 0);
  });

  testWidgets('not holding, the parent gets the drag', (tester) async {
    int outer = 0;
    await tester.pumpWidget(_app(holding: false, onOuterDrag: () => outer++));
    final double top = tester.getTopLeft(find.byKey(_body)).dy;

    await tester.drag(find.byKey(_body), const Offset(0, 80));
    await tester.pump();
    expect(outer, greaterThan(0));
    expect(tester.getTopLeft(find.byKey(_body)).dy, top);
  });

  testWidgets('reduced motion holds without moving', (tester) async {
    int outer = 0;
    await tester.pumpWidget(
      _app(holding: true, reduced: true, onOuterDrag: () => outer++),
    );
    final double top = tester.getTopLeft(find.byKey(_body)).dy;

    await tester.drag(find.byKey(_body), const Offset(0, 80));
    await tester.pump();
    expect(outer, 0);
    expect(tester.getTopLeft(find.byKey(_body)).dy, top);
  });

  testWidgets('a hold that ends mid-drag lets the child return', (
    tester,
  ) async {
    await tester.pumpWidget(_app(holding: true));
    final double top = tester.getTopLeft(find.byKey(_body)).dy;
    final TestGesture g = await tester.startGesture(
      tester.getCenter(find.byKey(_body)),
    );
    await g.moveBy(const Offset(0, 40));
    await g.moveBy(const Offset(0, 60));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(_body)).dy, greaterThan(top));

    await tester.pumpWidget(_app(holding: false));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getTopLeft(find.byKey(_body)).dy, top);
    await g.up();
    await tester.pumpAndSettle();
  });
}
