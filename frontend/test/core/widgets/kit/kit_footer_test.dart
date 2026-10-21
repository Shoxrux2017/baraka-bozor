import 'package:baraka_bozor/core/widgets/kit/kit_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pinned footer and its button.
void main() {
  testWidgets('a busy footer button holds and spins', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KitFooter(
            children: <Widget>[
              KitFooterButton(
                buttonKey: 'go',
                icon: Icons.check,
                label: 'Go',
                busy: true,
                onPressed: () => taps++,
              ),
            ],
          ),
        ),
      ),
    );

    final Finder button = find.byKey(const ValueKey<String>('go'));
    await tester.tap(button);
    expect(taps, 0);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(
      find.descendant(
        of: button,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
  });
}
