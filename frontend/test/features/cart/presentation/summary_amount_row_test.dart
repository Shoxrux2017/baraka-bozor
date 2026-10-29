import 'package:baraka_bozor/features/cart/presentation/cart_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `SummaryAmountRow` keeps an amount whole at any text size (`DL-119`).
void main() {
  const String value = '≈ 149 375 сум';
  const String label = 'Итого заказа';

  Future<void> pumpRow(
    WidgetTester tester, {
    required double width,
    String? replaced,
    String text = value,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: SummaryAmountRow(
                  valueKey: 'amount',
                  label: label,
                  value: text,
                  replaced: replaced,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder amount() => find.byKey(const ValueKey<String>('amount'));

  /// True when the value is one line tall (a 14 px line, never 1.5 of it).
  bool oneLine(WidgetTester tester) =>
      tester.getSize(amount()).height < 14 * 1.5;

  testWidgets('with room it is one row: label left, value right', (
    WidgetTester tester,
  ) async {
    await pumpRow(tester, width: 600);

    expect(oneLine(tester), isTrue);
    expect(tester.getTopRight(amount()).dx, closeTo(600, 0.5));
    expect(tester.getTopLeft(find.text(label)).dx, 0);
    expect(
      tester.getTopLeft(amount()).dy,
      tester.getTopLeft(find.text(label)).dy,
    );
  });

  testWidgets('without room the value stands under the label, end-aligned, '
      'on one line', (WidgetTester tester) async {
    await pumpRow(tester, width: 240);

    expect(tester.takeException(), isNull);
    expect(oneLine(tester), isTrue);
    expect(tester.getTopRight(amount()).dx, closeTo(240, 0.5));
    expect(
      tester.getTopLeft(amount()).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.text(label)).dy),
    );
    expect(tester.getSize(amount()).width, lessThanOrEqualTo(240));
  });

  testWidgets('a value wider than the row is scaled down, never broken', (
    WidgetTester tester,
  ) async {
    await pumpRow(tester, width: 100);

    expect(tester.takeException(), isNull);
    expect(oneLine(tester), isTrue);
    expect(tester.getTopRight(amount()).dx, closeTo(100, 0.5));
    expect(tester.getTopLeft(amount()).dx, greaterThanOrEqualTo(0));
  });

  testWidgets('a replaced figure goes with the value, on one line', (
    WidgetTester tester,
  ) async {
    await pumpRow(tester, width: 300, replaced: ' 149 375 сум');

    expect(tester.takeException(), isNull);
    expect(oneLine(tester), isTrue);
    expect(tester.getTopRight(amount()).dx, closeTo(300, 0.5));
    expect(
      tester.getTopLeft(amount()).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.text(label)).dy),
    );
  });
}
