import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/features/addresses/presentation/address_point_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({required bool reduced}) => MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: const Scaffold(
        body: SearchAnswer(
          face: SearchFace.found,
          query: 'Navoiy 5',
          serial: 1,
        ),
      ),
    ),
  );

  double opacity(WidgetTester tester) => tester
      .widgetList<Opacity>(
        find.descendant(
          of: find.byType(SearchAnswer),
          matching: find.byType(Opacity),
        ),
      )
      .first
      .opacity;

  testWidgets('the answer fades in over 200 ms with animations removed', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(host(reduced: true));
    await tester.pump(const Duration(milliseconds: 50));

    expect(opacity(tester), allOf(greaterThan(0), lessThan(1)));
    await tester.pump(const Duration(milliseconds: 160));
    expect(opacity(tester), 1);
  });
}
