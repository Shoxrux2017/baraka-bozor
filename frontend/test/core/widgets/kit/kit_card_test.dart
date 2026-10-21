import 'package:baraka_bozor/core/widgets/kit/kit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a tappable card is a button whose ink shows on the white', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KitCard(
            key: const ValueKey<String>('card'),
            onTap: () => taps++,
            semanticLabel: 'Call Anna',
            child: const Text('Anna'),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('card')));
    expect(taps, 1);
    expect(
      tester.getSemantics(find.byKey(const ValueKey<String>('card'))),
      matchesSemantics(label: 'Call Anna', isButton: true, hasTapAction: true),
    );
    final Material material = tester.widget<Material>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('card')),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, Colors.white);
    handle.dispose();
  });
}
