import 'package:baraka_bozor/core/formatting/long_date.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final AppLocalizations ru = lookupAppLocalizations(const Locale('ru'));
  final AppLocalizations uz = lookupAppLocalizations(const Locale('uz'));

  test('all twelve months read in both languages (DL-136)', () {
    const List<String> ruMonths = <String>[
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    const List<String> uzMonths = <String>[
      'yanvar',
      'fevral',
      'mart',
      'aprel',
      'may',
      'iyun',
      'iyul',
      'avgust',
      'sentabr',
      'oktabr',
      'noyabr',
      'dekabr',
    ];
    for (int m = 1; m <= 12; m++) {
      final DateTime noon = DateTime.utc(2026, m, 5, 7);
      expect(longDate(ru, noon), '5 ${ruMonths[m - 1]} 2026');
      expect(longDate(uz, noon), '2026-yil 5-${uzMonths[m - 1]}');
    }
  });

  test('the day is the Tashkent day, not the UTC day', () {
    // 21:30 UTC on the 18th is 02:30 on the 19th in Tashkent.
    final DateTime late = DateTime.utc(2026, 10, 18, 21, 30);
    expect(longDate(ru, late), '19 октября 2026');
    expect(longDate(uz, late), '2026-yil 19-oktabr');
  });

  test('the first and the last day of the year keep their year', () {
    expect(longDate(ru, DateTime.utc(2026, 12, 31, 19)), '1 января 2027');
    expect(longDate(uz, DateTime.utc(2026, 12, 31, 18)), '2026-yil 31-dekabr');
  });
}
