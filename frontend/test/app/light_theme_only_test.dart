import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The kit and `DL-77` cover the light screens only, so a phone in dark mode
/// still shows the light theme until the kit's dark screens are drawn.
void main() {
  testWidgets('a phone in dark mode still gets the light theme', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(appUnderTest());
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    final BuildContext context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, Brightness.light);
    expect(Theme.of(context).inputDecorationTheme.fillColor, KitColors.field);
    final TextField field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('phone-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.style?.color, KitColors.ink);
  });
}
