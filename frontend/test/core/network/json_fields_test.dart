import 'package:baraka_bozor/core/network/json_fields.dart';
import 'package:flutter_test/flutter_test.dart';

enum _Colour { red }

void main() {
  final JsonFields json = JsonFields.of(<String, dynamic>{
    'name': 'Pomidor',
    'empty': '',
    'missing_value': null,
    'count': 3,
    'flag': true,
    'at': '2026-09-26T10:00:00Z',
    'offset': '2026-09-26T15:00:00+05:00',
    'local': '2026-09-26T10:00:00',
    'colour': 'red',
  }, 'thing');

  test('a member the contract names must be there, even when null', () {
    expect(json.nullableString('missing_value'), isNull);
    expect(() => json.nullableString('absent'), throwsFormatException);
    expect(() => json.string('absent'), throwsFormatException);
  });

  test('each reader takes only its own type', () {
    expect(json.string('name'), 'Pomidor');
    expect(() => json.string('empty'), throwsFormatException);
    expect(() => json.nullableString('empty'), throwsFormatException);
    expect(() => json.string('count'), throwsFormatException);
    expect(json.integer('count'), 3);
    expect(() => json.integer('name'), throwsFormatException);
    expect(json.nullableInteger('missing_value'), isNull);
    expect(json.boolean('flag'), isTrue);
    expect(() => json.boolean('count'), throwsFormatException);
  });

  test('an instant is UTC in the Z form', () {
    expect(json.instant('at'), DateTime.utc(2026, 9, 26, 10));
    expect(json.nullableInstant('missing_value'), isNull);
    expect(() => json.instant('offset'), throwsFormatException);
    expect(() => json.instant('local'), throwsFormatException);
  });

  test('a machine value must be a known one', () {
    _Colour? parse(String value) => value == 'red' ? _Colour.red : null;

    expect(json.choice('colour', parse), _Colour.red);
    expect(() => json.choice('name', parse), throwsFormatException);
  });

  test('only an object has fields', () {
    expect(() => JsonFields.of(<dynamic>[], 'thing'), throwsFormatException);
    expect(() => JsonFields.of(null, 'thing'), throwsFormatException);
  });
}
