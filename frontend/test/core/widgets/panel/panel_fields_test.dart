import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/panel/panel_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'a panel field is white with a line border, green when focused and red on error',
    (WidgetTester tester) async {
      final InputDecoration d = panelFieldDecoration(
        hint: 'Hint',
        suffix: 'UZS',
        helper: 'Help',
        counter: '0/10',
      );

      expect(d.filled, isTrue);
      expect(d.fillColor, Colors.white);
      expect(d.hintText, 'Hint');
      expect(d.suffixText, 'UZS');
      expect(d.helperText, 'Help');
      expect(d.counterText, '0/10');
      expect(d.helperStyle!.fontSize, 11);
      expect(d.helperStyle!.color, KitColors.muted);
      expect(d.counterStyle!.fontSize, 11);
      expect(d.counterStyle!.color, KitColors.muted);
      expect(d.errorStyle!.fontSize, 12);
      expect(d.errorStyle!.color, KitColors.danger);
      expect(d.contentPadding, const EdgeInsets.all(14));

      final OutlineInputBorder enabled = d.enabledBorder! as OutlineInputBorder;
      expect(enabled.borderSide.color, KitColors.line);
      expect(enabled.borderSide.width, 1);
      expect(enabled.borderRadius, BorderRadius.circular(14));
      final OutlineInputBorder focused = d.focusedBorder! as OutlineInputBorder;
      expect(focused.borderSide.color, KitColors.primary);
      expect(focused.borderSide.width, 1.5);
      final OutlineInputBorder error = d.errorBorder! as OutlineInputBorder;
      expect(error.borderSide.color, KitColors.danger);
      expect(error.borderSide.width, 1.5);
      expect(
        (d.focusedErrorBorder! as OutlineInputBorder).borderSide.color,
        KitColors.danger,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TextField(decoration: d)),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the panel search is a filled 40-high field with a search icon', (
    WidgetTester tester,
  ) async {
    final InputDecoration d = panelSearchDecoration(
      hint: 'Search',
      suffix: const Icon(Icons.close),
    );

    expect(d.hintText, 'Search');
    expect(d.fillColor, KitColors.field);
    expect(d.constraints, const BoxConstraints(minHeight: 40));
    expect(d.suffixIcon, isA<Icon>());
    expect(d.prefixIcon, isA<Icon>());
    expect(
      (d.border! as OutlineInputBorder).borderRadius,
      BorderRadius.circular(12),
    );
  });
}
