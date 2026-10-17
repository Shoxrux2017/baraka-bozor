import 'package:baraka_bozor/core/formatting/address_format.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final AppLocalizations ru = lookupAppLocalizations(const Locale('ru'));
  final AppLocalizations uz = lookupAppLocalizations(const Locale('uz'));

  test('a number apartment is written short in each language', () {
    expect(
      addressFullLine(ru, street: 'Чиланзар', house: '14', apartment: '5'),
      'Чиланзар, 14, кв. 5',
    );
    expect(
      addressFullLine(uz, street: 'Chilonzor', house: '14', apartment: '5'),
      'Chilonzor, 14, 5-xonadon',
    );
  });

  test('an apartment that is not just digits stays as typed', () {
    expect(
      addressFullLine(ru, street: 'Чиланзар', house: '14', apartment: 'Офис 3'),
      'Чиланзар, 14, Офис 3',
    );
  });

  test('no apartment, or a blank one, gives no apartment part', () {
    expect(
      addressFullLine(ru, street: 'Чиланзар', house: '14'),
      'Чиланзар, 14',
    );
    expect(
      addressFullLine(ru, street: 'Чиланзар', house: '14', apartment: '  '),
      'Чиланзар, 14',
    );
  });

  test('the apartment part alone', () {
    expect(addressApartmentPart(ru, '12'), 'кв. 12');
    expect(addressApartmentPart(ru, ' Офис 3 '), 'Офис 3');
    expect(addressApartmentPart(ru, null), isNull);
    expect(addressApartmentPart(ru, ''), isNull);
  });
}
