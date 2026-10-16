import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/features/catalog/presentation/quantity_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The sheet that takes an exact quantity (drawing 18a), on its own.
void main() {
  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  final List<String?> answers = <String?>[];

  Future<void> open(
    WidgetTester tester, {
    UnitCode unit = UnitCode.kg,
    String current = '1',
    Locale locale = const Locale('ru'),
    Size size = const Size(400, 800),
    double textScale = 1,
  }) async {
    answers.clear();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              key: const ValueKey<String>('open-sheet'),
              onPressed: () async => answers.add(
                await showQuantitySheet(context, unit: unit, current: current),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(byKey('open-sheet'));
    await tester.pumpAndSettle();
  }

  Future<void> done(WidgetTester tester, String text) async {
    await tester.enterText(byKey('line-quantity'), text);
    await tester.tap(byKey('quantity-done'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the title and the current quantity as it is read', (
    WidgetTester tester,
  ) async {
    await open(tester, current: '1.5');

    expect(find.text('Количество'), findsWidgets);
    expect(find.text('Готово'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(byKey('line-quantity')).controller!.text,
      '1,5',
    );
  });

  testWidgets('a fraction is returned normalized', (WidgetTester tester) async {
    await open(tester);
    await done(tester, '1,25');

    expect(answers, <String?>['1.25']);
    expect(byKey('quantity-done'), findsNothing);
  });

  for (final String bad in <String>['0', 'abc', '']) {
    testWidgets('"$bad" shows the field error and keeps the sheet open', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await done(tester, bad);

      expect(
        find.text(
          AppLocalizations.of(tester.element(byKey('quantity-done')))
              .cartQuantityFraction,
        ),
        findsOneWidget,
      );
      expect(byKey('quantity-done'), findsOneWidget);
      expect(answers, isEmpty);
    });
  }

  testWidgets(
    'a piece product takes no fraction and refuses what is not whole',
    (WidgetTester tester) async {
      await open(tester, unit: UnitCode.piece);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(byKey('quantity-done')),
      );

      // The field keeps the comma out, so 1,5 can only be typed as 15.
      await tester.enterText(byKey('line-quantity'), '1,5');
      expect(
        tester.widget<TextFormField>(byKey('line-quantity')).controller!.text,
        '15',
      );

      for (final String bad in <String>['0', '']) {
        await done(tester, bad);
        expect(find.text(l10n.cartQuantityWhole), findsOneWidget);
        expect(byKey('quantity-done'), findsOneWidget);
        expect(answers, isEmpty);
      }
    },
  );

  testWidgets('dismissing returns nothing', (WidgetTester tester) async {
    await open(tester);
    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();

    expect(byKey('quantity-done'), findsNothing);
    expect(answers, <String?>[null]);
  });

  for (final Locale locale in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets('holds at 320x640 with text x2 in $locale', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        locale: locale,
        size: const Size(320, 640),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(byKey('quantity-done'), findsOneWidget);
    });
  }
}
