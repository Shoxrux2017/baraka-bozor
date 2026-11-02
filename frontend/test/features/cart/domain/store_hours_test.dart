import 'package:baraka_bozor/features/cart/domain/store_hours.dart';
import 'package:flutter_test/flutter_test.dart';

/// The working hours as the server answers them, read in Tashkent (UTC+5).
void main() {
  /// A Tashkent wall-clock time as an instant.
  DateTime at(int hour, int minute, {int day = 2}) => DateTime.utc(
    2026,
    11,
    day,
    hour,
    minute,
  ).subtract(const Duration(hours: 5));

  test('open from opening up to closing', () {
    final StoreHours hours = StoreHours.parse('08:00', '22:00');

    expect(hours.isOpenAt(at(8, 0)), isTrue);
    expect(hours.isOpenAt(at(21, 59)), isTrue);
    expect(hours.isOpenAt(at(22, 0)), isFalse);
    expect(hours.isOpenAt(at(7, 59)), isFalse);
    expect(hours.opensAt, '08:00');
  });

  test('hours over midnight', () {
    final StoreHours hours = StoreHours.parse('22:00', '02:00');

    expect(hours.isOpenAt(at(23, 0)), isTrue);
    expect(hours.isOpenAt(at(1, 59)), isTrue);
    expect(hours.isOpenAt(at(2, 0)), isFalse);
    expect(hours.isOpenAt(at(3, 0)), isFalse);
    expect(hours.isOpenAt(at(21, 59)), isFalse);
  });

  test('the next change', () {
    final StoreHours hours = StoreHours.parse('08:00', '22:00');

    expect(hours.nextChangeAfter(at(23, 10)), at(8, 0, day: 3));
    expect(hours.nextChangeAfter(at(9, 0)), at(22, 0));
    expect(
      hours.nextChangeAfter(at(8, 0)),
      at(22, 0),
      reason: 'strictly after',
    );
    expect(hours.nextChangeAfter(at(7, 59)), at(8, 0));
    expect(
      StoreHours.parse('22:00', '02:00').nextChangeAfter(at(23, 0)),
      at(2, 0, day: 3),
    );
  });

  test('it is a value', () {
    expect(
      StoreHours.parse('08:00', '22:00'),
      StoreHours.parse('08:00', '22:00'),
    );
    expect(
      StoreHours.parse('08:00', '22:00').hashCode,
      StoreHours.parse('08:00', '22:00').hashCode,
    );
    expect(
      StoreHours.parse('08:00', '22:00'),
      isNot(StoreHours.parse('09:00', '22:00')),
    );
  });

  test('a time that is not HH:MM is refused', () {
    for (final String bad in <String>[
      '8:00',
      '24:00',
      '08:60',
      '',
      '08:00:00',
    ]) {
      expect(
        () => StoreHours.parse(bad, '22:00'),
        throwsFormatException,
        reason: bad,
      );
    }
  });
}
