import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/panel/panel_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  Future<void> pump(
    WidgetTester tester, {
    required bool active,
    required ValueChanged<String?> onSelected,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: PanelMenuButton<String?>(
            buttonKey: 'menu',
            label: 'Payment',
            active: active,
            items: const <PanelMenuItem<String?>>[
              (value: null, label: 'All'),
              (value: 'cash', label: 'Cash'),
            ],
            onSelected: onSelected,
          ),
        ),
      ),
    ),
  );

  testWidgets('a menu button lists its items and reports the one chosen', (
    WidgetTester tester,
  ) async {
    final List<String?> chosen = <String?>[];
    await pump(tester, active: false, onSelected: chosen.add);

    // Drawn 40 high, tapped from 48 (DL-117).
    expect(tester.getSize(byKey('menu')).height, 48);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(byKey('menu-0'), findsNothing);

    await tester.tap(byKey('menu'));
    await tester.pumpAndSettle();
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);

    await tester.tap(byKey('menu-1'));
    await tester.pumpAndSettle();
    expect(chosen, <String?>['cash']);
    expect(byKey('menu-1'), findsNothing, reason: 'the menu closes');

    await tester.tap(byKey('menu'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('menu-0'));
    await tester.pumpAndSettle();
    expect(chosen, <String?>['cash', null]);
  });

  testWidgets('an active menu button is drawn green', (
    WidgetTester tester,
  ) async {
    await pump(tester, active: true, onSelected: (String? _) {});

    final OutlinedButton button = tester.widget<OutlinedButton>(byKey('menu'));
    expect(
      button.style!.backgroundColor!.resolve(<WidgetState>{}),
      KitColors.primaryWash,
    );
    final BorderSide side = button.style!.side!.resolve(<WidgetState>{})!;
    expect(side.color, KitColors.primary);
    expect(side.width, 1.5);
    expect(
      button.style!.foregroundColor!.resolve(<WidgetState>{}),
      KitColors.primaryDark,
    );
  });
}
