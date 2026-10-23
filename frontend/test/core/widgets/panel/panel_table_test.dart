import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/panel/panel_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  Future<void> pumpTable(WidgetTester tester, {VoidCallback? onTap}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PanelTable(
              columns: const <PanelColumn>[
                (label: 'Name', width: FlexColumnWidth(2), end: false),
                (label: 'Price', width: FlexColumnWidth(1), end: true),
              ],
              rows: <PanelTableRow>[
                PanelTableRow(
                  key: const ValueKey<String>('tapped'),
                  onTap: onTap,
                  cells: const <Widget>[Text('one'), Text('1 000')],
                ),
                const PanelTableRow(
                  key: ValueKey<String>('plain'),
                  faded: true,
                  cells: <Widget>[Text('two'), Text('2 000')],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the header is upper-cased and end columns align to the end', (
    WidgetTester tester,
  ) async {
    await pumpTable(tester);

    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('PRICE'), findsOneWidget);
    final Text price = tester.widget<Text>(find.text('PRICE'));
    expect(price.textAlign, TextAlign.end);
    expect(price.style!.fontSize, 11);
    expect(price.style!.fontWeight, FontWeight.w600);
    expect(price.style!.color, KitColors.muted);
    expect(tester.widget<Text>(find.text('NAME')).textAlign, TextAlign.start);
  });

  testWidgets('a row with a tap is an InkWell and one without is not', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await pumpTable(tester, onTap: () => taps++);

    expect(tester.widget(byKey('tapped')), isA<InkWell>());
    expect(tester.widget(byKey('plain')), isNot(isA<InkWell>()));
    expect(tester.widget<InkWell>(byKey('tapped')).hoverColor, KitColors.field);

    await tester.tap(byKey('tapped'));
    expect(taps, 1);
  });

  testWidgets('a faded row is painted lighter', (WidgetTester tester) async {
    await pumpTable(tester, onTap: () {});

    Color? paint(Finder box) =>
        (tester.widget<DecoratedBox>(box).decoration as BoxDecoration).color;

    expect(paint(byKey('plain')), KitColors.card);
    expect(
      paint(
        find
            .ancestor(of: byKey('tapped'), matching: find.byType(DecoratedBox))
            .first,
      ),
      isNull,
    );
  });
}
