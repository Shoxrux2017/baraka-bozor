import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/panel/panel_pills.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a selected pill is green', (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: <Widget>[
              PanelPill(label: 'On', selected: true, onTap: () => taps++),
              PanelPill(label: 'Off', selected: false, count: 3, onTap: () {}),
            ],
          ),
        ),
      ),
    );

    Color? fill(String label) => tester
        .widget<Material>(
          find
              .ancestor(of: find.text(label), matching: find.byType(Material))
              .first,
        )
        .color;

    expect(fill('On'), KitColors.primary);
    expect(fill('Off'), Colors.white);
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.text('On'));
    expect(taps, 1);
  });

  testWidgets('a narrow row scrolls instead of wrapping', (
    WidgetTester tester,
  ) async {
    final List<Widget> pills = <Widget>[
      for (int i = 0; i < 6; i++)
        PanelPill(label: 'Status $i', selected: false, onTap: () {}),
    ];

    Future<void> pumpAt(double width, bool wrap) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: PanelPillRow(pills: pills, wrap: wrap),
          ),
        ),
      ),
    );

    await pumpAt(300, false);
    expect(find.byType(Wrap), findsNothing);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    await pumpAt(300, true);
    expect(find.byType(Wrap), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
  });
}
