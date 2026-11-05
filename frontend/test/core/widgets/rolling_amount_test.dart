import 'package:baraka_bozor/core/widgets/rolling_amount.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// An amount that rolls from the old figure to the new (`DL-132`).
void main() {
  const Key text = ValueKey<String>('amount');

  Future<void> show(
    WidgetTester tester,
    int amount, {
    bool reduced = false,
    bool waiting = false,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Center(
          child: RollingAmount(
            amountUzs: amount,
            format: (int v) => '$v sum',
            waiting: waiting,
            textKey: text,
          ),
        ),
      ),
    ),
  );

  String shown(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(text)).data!;

  int figure(WidgetTester tester) => int.parse(shown(tester).split(' ').first);

  testWidgets('a new amount rolls in 320 ms in steps of 100 and ends exact', (
    WidgetTester tester,
  ) async {
    await show(tester, 10000);
    expect(shown(tester), '10000 sum', reason: 'the first build is still');
    await show(tester, 12345);

    int last = figure(tester);
    expect(last, 10000, reason: 'it starts from the old amount');
    for (final int ms in <int>[80, 80, 80, 60]) {
      await tester.pump(Duration(milliseconds: ms));
      final int now = figure(tester);
      expect(now, greaterThanOrEqualTo(last), reason: 'it only rises');
      expect(now, lessThanOrEqualTo(12345));
      last = now;
    }
    await tester.pump(const Duration(milliseconds: 20));
    expect(shown(tester), '12345 sum', reason: 'the last figure is exact');

    await show(tester, 10000);
    await tester.pump(const Duration(milliseconds: 100));
    final int mid = figure(tester);
    expect(mid % 100, 0, reason: 'a figure on the way is a round hundred');
    expect(mid, inExclusiveRange(10000, 12345));
    await tester.pumpAndSettle();
    expect(shown(tester), '10000 sum');
  });

  testWidgets('with reduced motion the amount changes at once', (
    WidgetTester tester,
  ) async {
    await show(tester, 10000, reduced: true);
    await show(tester, 12345, reduced: true);
    expect(shown(tester), '12345 sum');
    await tester.pump();
    expect(shown(tester), '12345 sum');
  });

  testWidgets('a screen reader hears only the final amount', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await show(tester, 10000);
    await show(tester, 12345);
    await tester.pump(const Duration(milliseconds: 100));

    expect(shown(tester), isNot('12345 sum'), reason: 'still on the way');
    expect(tester.getSemantics(find.byKey(text)).label, '12345 sum');
    expect(find.bySemanticsLabel(RegExp(r'^1[01]\d00 sum$')), findsNothing);
    handle.dispose();
  });

  testWidgets('a waiting amount dims to 0.45 over 200 ms', (
    WidgetTester tester,
  ) async {
    Finder dim() => find.ancestor(
      of: find.byKey(text),
      matching: find.byType(AnimatedOpacity),
    );
    await show(tester, 10000);
    expect(tester.widget<AnimatedOpacity>(dim()).opacity, 1);
    await show(tester, 10000, waiting: true);
    expect(tester.widget<AnimatedOpacity>(dim()).opacity, 0.45);
    expect(
      tester.widget<AnimatedOpacity>(dim()).duration,
      const Duration(milliseconds: 200),
    );
  });
}
