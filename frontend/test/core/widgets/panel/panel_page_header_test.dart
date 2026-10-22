import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/panel/panel_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Finder trailing = find.byKey(const ValueKey<String>('trailing'));

  testWidgets(
    'the header shows the title, the line under it and the trailing widget',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 600,
                child: PanelPageHeader(
                  title: 'Products',
                  subtitle: 'Updated 10:00',
                  trailing: SizedBox(
                    key: ValueKey<String>('trailing'),
                    width: 40,
                    height: 40,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final TextStyle title = tester.widget<Text>(find.text('Products')).style!;
      expect(title.fontSize, 24);
      expect(title.fontWeight, FontWeight.w700);
      expect(title.color, KitColors.ink);
      final TextStyle line = tester
          .widget<Text>(find.text('Updated 10:00'))
          .style!;
      expect(line.fontSize, 12);
      expect(line.color, KitColors.muted);
      expect(
        tester.getTopRight(trailing).dx,
        tester.getTopRight(find.byType(PanelPageHeader)).dx,
      );
      expect(
        tester.getCenter(trailing).dy,
        tester.getCenter(find.byType(PanelPageHeader)).dy,
      );
    },
  );

  testWidgets('the header without a subtitle shows only the title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PanelPageHeader(title: 'Products')),
      ),
    );

    expect(find.text('Products'), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
  });
}
