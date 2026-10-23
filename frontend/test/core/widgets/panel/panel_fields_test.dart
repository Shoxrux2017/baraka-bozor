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

  testWidgets('a prefix stands before the text', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(
            decoration: panelFieldDecoration(hint: 'Hint', prefix: '+998'),
          ),
        ),
      ),
    );

    final Finder prefix = find.text('+998');
    expect(prefix, findsOneWidget);
    final Text text = tester.widget<Text>(prefix);
    expect(text.style!.fontSize, 13);
    expect(text.style!.fontWeight, FontWeight.w600);
    expect(text.style!.color, KitColors.ink2);
    expect(
      tester.getTopLeft(prefix).dx,
      lessThan(tester.getTopLeft(find.text('Hint')).dx),
    );
  });

  testWidgets(
    'a field row stands side by side from its minimum and stacks below',
    (WidgetTester tester) async {
      const Key a = ValueKey<String>('a');
      const Key b = ValueKey<String>('b');

      Future<void> pumpAt(double width) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: const PanelFieldRow(
                  children: <Widget>[
                    SizedBox(key: a, height: 30),
                    SizedBox(key: b, height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await pumpAt(416);
      expect(
        tester.getTopLeft(find.byKey(a)).dy,
        tester.getTopLeft(find.byKey(b)).dy,
      );
      expect(tester.getSize(find.byKey(a)).width, 200);
      expect(tester.getTopLeft(find.byKey(b)).dx, 216);

      await pumpAt(415);
      expect(
        tester.getTopLeft(find.byKey(b)).dy,
        greaterThan(tester.getTopLeft(find.byKey(a)).dy),
      );
      expect(tester.getSize(find.byKey(a)).width, 415);
    },
  );
}
