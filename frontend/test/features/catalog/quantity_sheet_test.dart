import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/catalog_labels.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/orders/estimate_preview.dart';
import 'package:baraka_bozor/core/orders/quantity_rules.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/features/catalog/presentation/quantity_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/paragraphs.dart';

/// The sheet that takes an exact quantity (drawing 18a, `DL-122`), on its
/// own.
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
    int? price,
    double keyboard = 0,
  }) async {
    answers.clear();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.resetViewInsets);
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
                await showQuantitySheet(
                  context,
                  unit: unit,
                  current: current,
                  name: 'Помидор',
                  unitPriceUzs: price,
                ),
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

  Material chip(WidgetTester tester, String quantity) =>
      tester.widget<Material>(byKey('quantity-chip-$quantity'));

  testWidgets('shows the question naming the product and the quantity', (
    WidgetTester tester,
  ) async {
    await open(tester, current: '1.5');

    expect(find.text('Помидор — сколько килограммов?'), findsOneWidget);
    expect(find.text('Готово'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(byKey('line-quantity')).controller!.text,
      '1,5',
    );
  });

  testWidgets('a piece product is asked for in pieces', (
    WidgetTester tester,
  ) async {
    await open(tester, unit: UnitCode.piece);

    expect(find.text('Помидор — сколько штук?'), findsOneWidget);
  });

  testWidgets('the keyboard opens at once with the quantity selected', (
    WidgetTester tester,
  ) async {
    await open(tester, current: '1.5');

    final EditableText text = tester.widget<EditableText>(
      find.descendant(
        of: byKey('line-quantity'),
        matching: find.byType(EditableText),
      ),
    );
    expect(text.focusNode.hasFocus, isTrue);
    expect(
      text.controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 3),
    );
  });

  testWidgets('a chip sets the quantity and is marked', (
    WidgetTester tester,
  ) async {
    await open(tester, price: 12075);
    expect(chip(tester, '1').color, KitColors.primarySoft);
    expect(chip(tester, '2').color, KitColors.field);

    await tester.tap(byKey('quantity-chip-0.5'));
    await tester.pump();

    expect(
      tester.widget<TextFormField>(byKey('line-quantity')).controller!.text,
      '0,5',
    );
    expect(chip(tester, '0.5').color, KitColors.primarySoft);
    expect(chip(tester, '1').color, KitColors.field);

    await tester.tap(byKey('quantity-done'));
    await tester.pumpAndSettle();
    expect(answers, <String?>['0.5']);
  });

  testWidgets('a whole unit offers whole chips', (WidgetTester tester) async {
    await open(tester, unit: UnitCode.piece, current: '5');

    expect(byKey('quantity-chip-10'), findsOneWidget);
    expect(byKey('quantity-chip-0.5'), findsNothing);
    expect(chip(tester, '5').color, KitColors.primarySoft);
  });

  testWidgets('the chips name the unit', (WidgetTester tester) async {
    Future<void> expectChips(UnitCode unit, List<String> values) async {
      await open(tester, unit: unit);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(byKey('quantity-done')),
      );
      final String word = CatalogLabels.unit(l10n, unit);
      for (final String value in values) {
        final String text = '${QuantityRules.display(value)} $word';
        expect(
          find.descendant(
            of: byKey('quantity-chip-$value'),
            matching: find.text(text),
          ),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel(text), findsOneWidget);
      }
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }

    await expectChips(UnitCode.kg, <String>['0.5', '1', '1.5', '2', '3']);
    await expectChips(UnitCode.piece, <String>['1', '2', '3', '5', '10']);
  });

  testWidgets('the sum follows the typing', (WidgetTester tester) async {
    await open(tester, price: 12075);
    await tester.enterText(byKey('line-quantity'), '0,5');
    await tester.pump();

    final String sum = MoneyFormat.uzs(
      EstimatePreview.lineUzs(12075, '0.5'),
      AppLanguage.ru,
    );
    expect(
      tester.widget<Text>(byKey('quantity-preview')).data,
      '≈ $sum за 0,5 кг',
    );
  });

  testWidgets('without a price there is no sum', (WidgetTester tester) async {
    await open(tester);

    expect(byKey('quantity-preview'), findsNothing);
  });

  testWidgets('an empty field asks for a quantity, quietly', (
    WidgetTester tester,
  ) async {
    await open(tester, price: 12075);
    await tester.enterText(byKey('line-quantity'), '');
    await tester.pump();

    final Text preview = tester.widget<Text>(byKey('quantity-preview'));
    expect(preview.data, 'Введите количество');
    expect(preview.style!.color, KitColors.muted);
  });

  testWidgets('a fraction is returned normalized', (WidgetTester tester) async {
    await open(tester);
    await done(tester, '1,25');

    expect(answers, <String?>['1.25']);
    expect(byKey('quantity-done'), findsNothing);
  });

  for (final String bad in <String>['0', '1,2345']) {
    testWidgets('"$bad" shows the error as typed and keeps the sheet open', (
      WidgetTester tester,
    ) async {
      await open(tester, price: 12075);
      await done(tester, bad);

      final Text preview = tester.widget<Text>(byKey('quantity-preview'));
      expect(
        preview.data,
        AppLocalizations.of(tester.element(byKey('quantity-done')))
            .cartQuantityFraction,
      );
      expect(preview.style!.color, KitColors.danger);
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
        expect(
          tester.widget<Text>(byKey('quantity-preview')).data,
          bad.isEmpty ? l10n.quantitySheetEmpty : l10n.cartQuantityWhole,
        );
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
    testWidgets('holds over the keyboard at 320x640 with text x2 in $locale', (
      WidgetTester tester,
    ) async {
      await loadMontserrat();
      await open(
        tester,
        locale: locale,
        size: const Size(320, 640),
        textScale: 2,
        price: 12075,
        keyboard: 300,
      );
      expect(tester.takeException(), isNull);

      for (final Finder target in <Finder>[
        byKey('line-quantity'),
        byKey('quantity-chip-0.5'),
        byKey('quantity-chip-3'),
        byKey('quantity-preview'),
        byKey('quantity-done'),
      ]) {
        await tester.ensureVisible(target);
        await tester.pump();
        expect(target.hitTestable(), findsOneWidget);
        // The keyboard covers the lower 300 of 640.
        expect(tester.getRect(target).bottom, lessThanOrEqualTo(340));
      }
    });
  }

  testWidgets('the sheet meets iOSTapTargetGuideline', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await open(tester, price: 12075);

    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });
}
