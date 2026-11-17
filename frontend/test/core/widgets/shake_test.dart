import 'package:baraka_bozor/core/widgets/shake.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(int trigger, {bool reduced = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Align(
        alignment: Alignment.topLeft,
        child: Shake(
          trigger: trigger,
          child: const SizedBox(key: Key('box'), width: 20, height: 20),
        ),
      ),
    ),
  );

  double x(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(const Key('box'))).dx;

  testWidgets('a shake follows the keyframes once per trigger', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(0));
    final double rest = x(tester);
    await tester.pumpWidget(host(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 72));
    expect(x(tester) - rest, closeTo(-6, 0.01));
    await tester.pump(const Duration(milliseconds: 72));
    expect(x(tester) - rest, closeTo(5, 0.01));
    await tester.pump(const Duration(milliseconds: 216));
    expect(x(tester) - rest, closeTo(0, 0.01));

    // The same trigger again is no new shake.
    await tester.pumpWidget(host(1));
    await tester.pump(const Duration(milliseconds: 72));
    expect(x(tester) - rest, closeTo(0, 0.01));
  });

  testWidgets('reduced motion does not shake', (WidgetTester tester) async {
    await tester.pumpWidget(host(0, reduced: true));
    final double rest = x(tester);
    await tester.pumpWidget(host(1, reduced: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 72));
    expect(x(tester), rest);
  });
}
