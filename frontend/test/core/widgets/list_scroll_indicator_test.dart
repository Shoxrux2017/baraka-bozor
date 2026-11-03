import 'package:baraka_bozor/core/widgets/list_scroll_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _thumb = ValueKey<String>('scroll-indicator');

Future<ScrollController> _open(
  WidgetTester tester, {
  required double contentHeight,
  required double full,
}) async {
  tester.view.physicalSize = const Size(400, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final ScrollController controller = ScrollController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListScrollIndicator(
          fullExtent: (ScrollMetrics metrics) => full,
          child: ListView(
            controller: controller,
            children: <Widget>[SizedBox(height: contentHeight)],
          ),
        ),
      ),
    ),
  );
  return controller;
}

double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.byKey(_thumb),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

void main() {
  testWidgets('shows while scrolling and fades 0.9 s after', (
    WidgetTester tester,
  ) async {
    await _open(tester, contentHeight: 1200, full: 2400);
    expect(find.byKey(_thumb), findsNothing);

    final TestGesture gesture = await tester.startGesture(
      const Offset(200, 300),
    );
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_opacity(tester), 1);

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 899));
    expect(_opacity(tester), 1);
    await tester.pump(const Duration(milliseconds: 301));
    expect(_opacity(tester), 0);
  });

  testWidgets('its length follows the full extent, not the loaded one', (
    WidgetTester tester,
  ) async {
    await _open(tester, contentHeight: 1200, full: 2400);
    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pump();

    final Size size = tester.getSize(find.byKey(_thumb));
    expect(size.width, 3);
    expect(size.height, closeTo((600 - 8) * 600 / 2400, 0.5));
    await tester.pumpAndSettle();
  });

  testWidgets('at the end of the loaded part it is not at the bottom of the '
      'track', (WidgetTester tester) async {
    await _open(tester, contentHeight: 1200, full: 2400);
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pump();

    final double length = (600 - 8) * 600 / 2400;
    final double top = 4 + (600 - 8 - length) * (600 / 1800);
    expect(tester.getTopLeft(find.byKey(_thumb)).dy, closeTo(top, 0.5));
    expect(
      tester.getBottomLeft(find.byKey(_thumb)).dy,
      lessThan(600 - 4 - 100),
    );
    expect(tester.getTopRight(find.byKey(_thumb)).dx, 400 - 2);
    await tester.pumpAndSettle();
  });

  testWidgets('nothing when the content fits', (WidgetTester tester) async {
    await _open(tester, contentHeight: 300, full: 300);
    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pump();

    expect(find.byKey(_thumb), findsNothing);
    await tester.pumpAndSettle();
  });
}
