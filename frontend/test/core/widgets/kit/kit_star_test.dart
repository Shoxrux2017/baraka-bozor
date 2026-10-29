import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/kit/kit_star.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required bool filled}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: KitStar(filled: filled, size: 24)),
      ),
    );
  }

  testWidgets('a filled star is amber with an edge', (tester) async {
    await pump(tester, filled: true);

    final List<Icon> icons = tester
        .widgetList<Icon>(find.byType(Icon))
        .toList();
    expect(icons, hasLength(2));
    expect(icons[0].icon, Icons.star);
    expect(icons[0].color, KitColors.star);
    expect(icons[0].size, 24);
    expect(icons[1].icon, Icons.star_border);
    expect(icons[1].color, KitColors.starEdge);
    expect(icons[1].size, 24);
  });

  testWidgets('an empty star is a grey outline', (tester) async {
    await pump(tester, filled: false);

    final Icon icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, Icons.star_border);
    expect(icon.color, KitColors.muted);
    expect(icon.size, 24);
  });

  testWidgets('adds no semantics node', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pump(tester, filled: true);

    expect(
      find.descendant(
        of: find.byType(KitStar),
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
    expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
    handle.dispose();
  });
}
