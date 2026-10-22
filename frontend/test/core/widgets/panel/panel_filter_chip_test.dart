import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/panel/panel_filter_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required bool selected}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PanelFilterChip(
                chipKey: 'chip',
                icon: Icons.person_outline,
                label: 'Mine',
                selected: selected,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

  testWidgets('a filter chip is 32 high and turns green when selected', (
    WidgetTester tester,
  ) async {
    const Key key = ValueKey<String>('chip');

    await pump(tester, selected: false);
    expect(tester.getSize(find.byKey(key)).height, 32);
    Material material = tester.widget<Material>(find.byKey(key));
    expect(material.color, Colors.white);
    expect(
      (material.shape! as RoundedRectangleBorder).side.color,
      KitColors.line,
    );

    await pump(tester, selected: true);
    expect(tester.getSize(find.byKey(key)).height, 32);
    material = tester.widget<Material>(find.byKey(key));
    expect(material.color, KitColors.primaryWash);
    expect(
      (material.shape! as RoundedRectangleBorder).side.color,
      KitColors.primary,
    );
    expect(
      tester.widget<Text>(find.text('Mine')).style!.color,
      KitColors.primaryDark,
    );
  });
}
