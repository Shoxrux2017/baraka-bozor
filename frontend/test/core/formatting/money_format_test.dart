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

  test('a change is signed: plus, the true minus sign, or a bare zero', () {
    final String minus = String.fromCharCode(0x2212);
    expect(MoneyFormat.signed(5300), '+5${nbsp}300');
    expect(MoneyFormat.signed(-5000), '${minus}5${nbsp}000');
    expect(MoneyFormat.signed(0), '0');
    expect(
      MoneyFormat.signedUzs(-20000, AppLanguage.ru),
      '${minus}20${nbsp}000$nbspсум',
    );
    expect(MoneyFormat.signedUzs(5300, AppLanguage.ru), '+5${nbsp}300$nbspсум');
    expect(
      MoneyFormat.signedUzs(-20000, AppLanguage.uz),
      "${minus}20${nbsp}000${nbsp}so'm",
    );
    expect(MoneyFormat.signedUzs(0, AppLanguage.uz), "0${nbsp}so'm");
  });
}
