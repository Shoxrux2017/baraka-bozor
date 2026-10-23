import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/panel/panel_person.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('initials come from the first two words, grey when muted', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              PanelPersonLine(name: 'Aziz Karimov Bobur', detail: '+998'),
              PanelPersonLine(name: 'omina', detail: '+998', muted: true),
            ],
          ),
        ),
      ),
    );

    expect(find.text('AK'), findsOneWidget);
    expect(find.text('O'), findsOneWidget);

    final Finder mutedAvatar = find.ancestor(
      of: find.text('O'),
      matching: find.byType(Container),
    );
    expect(
      (tester.widget<Container>(mutedAvatar.first).decoration as BoxDecoration)
          .color,
      KitColors.field,
    );
    expect(tester.widget<Text>(find.text('O')).style!.color, KitColors.muted);
    expect(
      tester.widget<Text>(find.text('omina')).style!.color,
      KitColors.muted,
    );
    expect(
      tester.widget<Text>(find.text('Aziz Karimov Bobur')).style!.color,
      KitColors.ink,
    );
  });

  testWidgets('a long name ellipsises in one line at x2', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: const Scaffold(
            body: SizedBox(
              width: 220,
              child: PanelPersonLine(
                name: 'Abdurakhmonovich Muhammadrasul Karimjonov',
                detail: '+998 90 123 45 67',
                tags: <Widget>[Text('Admin')],
              ),
            ),
          ),
        ),
      ),
    );

    final Text name = tester.widget<Text>(
      find.text('Abdurakhmonovich Muhammadrasul Karimjonov'),
    );
    expect(name.maxLines, 1);
    expect(name.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });
}
