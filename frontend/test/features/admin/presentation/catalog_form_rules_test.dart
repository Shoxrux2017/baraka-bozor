import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations_uz.dart';
import 'package:baraka_bozor/features/admin/presentation/catalog_form_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// The catalog forms refuse what `DL-20` (6) refuses.
void main() {
  final AppLocalizations l10n = AppLocalizationsUz();

  test('a name is required and bounded in code points', () {
    expect(CatalogFormRules.name(l10n, '   ', 120), l10n.fieldRequired);
    expect(CatalogFormRules.name(l10n, 'я' * 120, 120), isNull);
    expect(CatalogFormRules.name(l10n, 'я' * 121, 120), l10n.fieldTooLong(120));
    expect(CatalogFormRules.name(l10n, '  ${'a' * 160}  ', 160), isNull);
  });

  test('a description is optional and at most 2000', () {
    expect(CatalogFormRules.description(l10n, ''), isNull);
    expect(CatalogFormRules.description(l10n, 'd' * 2000), isNull);
    expect(
      CatalogFormRules.description(l10n, 'd' * 2001),
      l10n.fieldTooLong(2000),
    );
  });

  test('a sort order is an integer from -100 000 to 100 000', () {
    for (final String value in <String>['', '0', '-100000', '100000', '42']) {
      expect(CatalogFormRules.sortOrder(l10n, value), isNull, reason: value);
    }
    for (final String value in <String>[
      '100001',
      '-100001',
      '1.5',
      'abc',
      '1000000',
    ]) {
      expect(
        CatalogFormRules.sortOrder(l10n, value),
        l10n.fieldSortOrder,
        reason: value,
      );
    }
    expect(CatalogFormRules.sortOrderValue(''), 0);
    expect(CatalogFormRules.sortOrderValue(' -7 '), -7);
  });

  test('a market price is whole UZS from 1 to one billion', () {
    expect(CatalogFormRules.marketPrice(l10n, ''), l10n.fieldRequired);
    for (final String value in <String>['1', '16000', '16 000', '1000000000']) {
      expect(CatalogFormRules.marketPrice(l10n, value), isNull, reason: value);
    }
    for (final String value in <String>[
      '0',
      '1000000001',
      '-5',
      '16.5',
      'abc',
    ]) {
      expect(
        CatalogFormRules.marketPrice(l10n, value),
        l10n.fieldMarketPrice,
        reason: value,
      );
    }
    expect(CatalogFormRules.marketPriceValue('16 000'), 16000);
  });
}
