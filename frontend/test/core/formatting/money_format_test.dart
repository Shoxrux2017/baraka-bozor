import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:flutter_test/flutter_test.dart';

/// `docs/07-architecture.md` section 27: `150 000 so'm` / `150 000 сум`.
void main() {
  const String nbsp = '\u00A0';

  test('an amount is grouped by thousands with the currency after it', () {
    expect(
      MoneyFormat.uzs(150000, AppLanguage.uz),
      '150${nbsp}000${nbsp}so\'m',
    );
    expect(MoneyFormat.uzs(150000, AppLanguage.ru), '150${nbsp}000$nbspсум');
  });

  test('grouping works at every length', () {
    expect(MoneyFormat.grouped(0), '0');
    expect(MoneyFormat.grouped(999), '999');
    expect(MoneyFormat.grouped(1000), '1${nbsp}000');
    expect(MoneyFormat.grouped(1000000000), '1${nbsp}000${nbsp}000${nbsp}000');
    expect(MoneyFormat.grouped(-15000), '-15${nbsp}000');
  });
}
