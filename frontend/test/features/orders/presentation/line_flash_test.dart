import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/features/orders/presentation/line_flash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The flash over an order line the Customer's answer changed (`DL-130`).
void main() {
  final Finder rect = find.byKey(const ValueKey<String>('line-flash'));

  Color colour(WidgetTester tester) =>
      ((tester.widget<DecoratedBox>(rect).decoration) as BoxDecoration).color!;

  Future<void> show(
    WidgetTester tester,
    int flash, {
    bool reduced = false,
    Color? color,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Center(
          child: LineFlash(
            flash: flash,
            color: color ?? KitColors.lineFlash,
            child: const SizedBox(width: 100, height: 40),
          ),
        ),
      ),
    ),
  );

  testWidgets('there is no flash on the first build', (
    WidgetTester tester,
  ) async {
    await show(tester, 3);
    expect(colour(tester).a, 0);
    await tester.pump(const Duration(milliseconds: 300));
    expect(colour(tester).a, 0);
  });

  testWidgets('a new count flashes the colour, 6 px past the row, and fades', (
    WidgetTester tester,
  ) async {
    await show(tester, 0);
    await show(tester, 1);
    await tester.pump();

    expect(colour(tester), KitColors.lineFlash);
    final Rect row = tester.getRect(find.byType(SizedBox).last);
    expect(tester.getRect(rect), row.inflate(6));
    final BoxDecoration decoration =
        tester.widget<DecoratedBox>(rect).decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(12));

    await tester.pump(const Duration(milliseconds: 700));
    expect(colour(tester).a, inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 700));
    expect(colour(tester).a, 0);
  });

  testWidgets('with reduced motion nothing flashes', (
    WidgetTester tester,
  ) async {
    await show(tester, 0, reduced: true);
    await show(tester, 1, reduced: true);
    await tester.pump();
    expect(colour(tester).a, 0);
  });

  testWidgets('a flash takes the colour it is given', (
    WidgetTester tester,
  ) async {
    await show(tester, 0, color: KitColors.dangerWash);
    await show(tester, 1, color: KitColors.dangerWash);
    await tester.pump();
    expect(colour(tester), KitColors.dangerWash);
  });
}
