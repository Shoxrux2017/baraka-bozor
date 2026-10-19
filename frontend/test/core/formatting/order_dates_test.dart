import 'package:baraka_bozor/core/formatting/order_dates.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final AppLocalizations ru = lookupAppLocalizations(const Locale('ru'));
  final AppLocalizations uz = lookupAppLocalizations(const Locale('uz'));
  // 14:00 in Tashkent.
  final DateTime now = DateTime.utc(2026, 10, 18, 9);

  test('today and yesterday by the Tashkent day', () {
    expect(
      orderWhen(ru, DateTime.utc(2026, 10, 18, 7, 40), now),
      'Сегодня, 12:40',
    );
    expect(
      orderWhen(ru, DateTime.utc(2026, 10, 17, 14, 45), now),
      'Вчера, 19:45',
    );
    expect(
      orderWhen(ru, DateTime.utc(2026, 10, 17, 19, 30), now),
      'Сегодня, 00:30',
    );
  });

  test('a day this year names the month, another year the full date', () {
    final DateTime day = DateTime.utc(2026, 10, 7, 13, 20);
    expect(orderWhen(ru, day, now), '7 окт, 18:20');
    expect(orderWhen(uz, day, now), '7-okt, 18:20');
    expect(
      orderWhen(ru, DateTime.utc(2025, 12, 30, 10), now),
      '30.12.2025, 15:00',
    );
  });

  test('orderAt reads "в"', () {
    final DateTime at = DateTime.utc(2026, 10, 18, 8, 5);
    expect(orderAt(ru, at, now), 'Сегодня в 13:05');
    expect(orderAtLower(ru, at, now), 'сегодня в 13:05');
  });
}
