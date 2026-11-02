import 'package:baraka_bozor/core/widgets/press_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(
  WidgetTester tester, {
  required VoidCallback onTap,
  bool reduced = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(
          body: Center(
            child: PressScale(
              label: 'Фрукты',
              onTap: onTap,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      ),
    ),
  );
}

double _scale(WidgetTester tester) => tester
    .widget<ScaleTransition>(
      find.descendant(
        of: find.byType(PressScale),
        matching: find.byType(ScaleTransition),
      ),
    )
    .scale
    .value;

void main() {
  testWidgets('pressing shrinks to 0.96 and a release taps', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await _open(tester, onTap: () => taps++);
    expect(_scale(tester), 1);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressScale)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(_scale(tester), closeTo(0.96, 0.001));
    expect(taps, 0);

    await gesture.up();
    await tester.pump();
    expect(taps, 1);
    await tester.pump(const Duration(milliseconds: 120));
    expect(_scale(tester), closeTo(1, 0.001));
  });

  testWidgets('a drag out restores without a tap', (WidgetTester tester) async {
    int taps = 0;
    await _open(tester, onTap: () => taps++);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressScale)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(_scale(tester), closeTo(0.96, 0.001));

    await gesture.moveBy(const Offset(0, 200));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 120));

    expect(taps, 0);
    expect(_scale(tester), closeTo(1, 0.001));
  });

  testWidgets('with reduced motion it does not scale', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await _open(tester, onTap: () => taps++, reduced: true);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressScale)),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(_scale(tester), 1);
    await gesture.up();
    expect(taps, 1);
  });

  testWidgets('it is one button node with its label', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _open(tester, onTap: () {});

    expect(
      tester.getSemantics(find.byType(PressScale)),
      matchesSemantics(label: 'Фрукты', isButton: true, hasTapAction: true),
    );
    semantics.dispose();
  });
}
