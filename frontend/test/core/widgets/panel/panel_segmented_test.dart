import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/panel/panel_segmented.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  Widget host(String selected, ValueChanged<String>? onSelected) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: PanelSegmented<String>(
          segments: const <PanelSegment<String>>[
            (
              value: 'a',
              label: 'Active',
              key: ValueKey<String>('seg-a'),
              dot: KitColors.primary,
            ),
            (
              value: 'b',
              label: 'Blocked',
              key: ValueKey<String>('seg-b'),
              dot: null,
            ),
          ],
          selected: selected,
          onSelected: onSelected,
        ),
      ),
    ),
  );

  Color? fill(WidgetTester tester, String key) =>
      (tester
                  .widget<Ink>(
                    find.descendant(of: byKey(key), matching: find.byType(Ink)),
                  )
                  .decoration!
              as BoxDecoration)
          .color;

  testWidgets('the selected segment is white and a tap selects another', (
    WidgetTester tester,
  ) async {
    String? tapped;
    await tester.pumpWidget(host('a', (String v) => tapped = v));

    FontWeight? weight(String label) =>
        tester.widget<Text>(find.text(label)).style!.fontWeight;

    expect(fill(tester, 'seg-a'), Colors.white);
    expect(fill(tester, 'seg-b'), isNull);
    expect(weight('Active'), FontWeight.w600);
    expect(weight('Blocked'), FontWeight.w500);
    // Drawn 34 high, tapped from 44 high (DL-117).
    expect(tester.getSize(byKey('seg-a')).height, 44);
    expect(
      tester
          .getSize(
            find.descendant(of: byKey('seg-a'), matching: find.byType(Ink)),
          )
          .height,
      34,
    );
    expect(
      tester.getSemantics(byKey('seg-a')),
      matchesSemantics(
        label: 'Active',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(byKey('seg-b'));
    expect(tapped, 'b');
    await tester.pumpWidget(host('b', (String v) => tapped = v));
    expect(fill(tester, 'seg-b'), Colors.white);
    expect(fill(tester, 'seg-a'), isNull);
  });

  testWidgets('a dot shows before the label', (WidgetTester tester) async {
    await tester.pumpWidget(host('a', (String _) {}));

    bool isDot(Widget w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).shape == BoxShape.circle;

    final Finder dot = find.descendant(
      of: byKey('seg-a'),
      matching: find.byWidgetPredicate(isDot),
    );
    expect(dot, findsOneWidget);
    expect(tester.getSize(dot), const Size(8, 8));
    expect(
      tester.getTopRight(dot).dx + 8,
      tester.getTopLeft(find.text('Active')).dx,
    );
    expect(
      find.descendant(
        of: byKey('seg-b'),
        matching: find.byWidgetPredicate(isDot),
      ),
      findsNothing,
    );
  });

  testWidgets('a null onSelected disables every segment', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host('a', null));

    for (final String key in <String>['seg-a', 'seg-b']) {
      expect(
        tester
            .widget<InkWell>(
              find.descendant(of: byKey(key), matching: find.byType(InkWell)),
            )
            .onTap,
        isNull,
      );
    }
  });

  testWidgets('every target meets iOSTapTargetGuideline', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(host('a', (String _) {}));

    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });
}
