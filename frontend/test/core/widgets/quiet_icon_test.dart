import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/kit/quiet_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a grey 64 circle with a silent icon', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: QuietIcon(icon: Icons.wifi_off)),
        ),
      ),
    );

    expect(tester.getSize(find.byType(QuietIcon)), const Size(64, 64));
    final DecoratedBox circle = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(QuietIcon),
        matching: find.byType(DecoratedBox),
      ),
    );
    final BoxDecoration decoration = circle.decoration as BoxDecoration;
    expect(decoration.color, KitColors.chip);
    expect(decoration.shape, BoxShape.circle);
    final Icon icon = tester.widget<Icon>(find.byIcon(Icons.wifi_off));
    expect(icon.size, 30);
    expect(icon.color, KitColors.ink2);
    expect(
      find.ancestor(
        of: find.byIcon(Icons.wifi_off),
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
    expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
    handle.dispose();
  });
}
