import 'package:baraka_bozor/features/admin/presentation/settings_form_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// The form refuses what `docs/09-api-contracts.md` section 44 and `DL-19`
/// refuse, and accepts what they accept.
void main() {
  const SettingsFieldProblem? ok = null;

  test('a percentage has at most three integer digits and two decimals', () {
    for (final String value in <String>['0', '15', '15.5', '15.00', '999.99']) {
      expect(
        SettingsFormRules.percent(value, required: true),
        ok,
        reason: value,
      );
    }
    for (final String value in <String>[
      '1000',
      '12,5',
      '12.345',
      '-1',
      '.5',
      '5.',
      '1e2',
      'abc',
    ]) {
      expect(
        SettingsFormRules.percent(value, required: true),
        SettingsFieldProblem.percent,
        reason: value,
      );
    }
    expect(
      SettingsFormRules.percent('  ', required: true),
      SettingsFieldProblem.required,
    );
    expect(SettingsFormRules.percent('', required: false), ok);
  });

  test('an amount is whole UZS up to one billion, grouped or not', () {
    for (final String value in <String>[
      '',
      '0',
      '15000',
      '15 000',
      '1\u00A0000\u00A0000',
      '1000000000',
    ]) {
      expect(SettingsFormRules.amount(value), ok, reason: value);
    }
    for (final String value in <String>[
      '1000000001',
      '99999999999',
      '-5',
      '1.5',
      '15k',
    ]) {
      expect(
        SettingsFormRules.amount(value),
        SettingsFieldProblem.amount,
        reason: value,
      );
    }
    expect(SettingsFormRules.amountValue('15 000'), 15000);
    expect(SettingsFormRules.amountValue(''), isNull);
  });

  test('a time is HH:MM on a 24-hour clock', () {
    for (final String value in <String>['', '00:00', '09:30', '23:59']) {
      expect(SettingsFormRules.time(value), ok, reason: value);
    }
    for (final String value in <String>[
      '24:00',
      '9:30',
      '09:60',
      '0930',
      '09:30:00',
    ]) {
      expect(
        SettingsFormRules.time(value),
        SettingsFieldProblem.time,
        reason: value,
      );
    }
  });

  test('working hours come as a pair and must differ', () {
    expect(
      SettingsFormRules.pairHalf('', '21:00'),
      SettingsFieldProblem.pairIncomplete,
    );
    expect(SettingsFormRules.pairHalf('', ''), ok);
    expect(
      SettingsFormRules.closesAt('', '09:00'),
      SettingsFieldProblem.pairIncomplete,
    );
    expect(
      SettingsFormRules.closesAt('09:00', '09:00'),
      SettingsFieldProblem.sameTime,
    );
    expect(SettingsFormRules.closesAt('00:00', '09:00'), ok);
    expect(SettingsFormRules.closesAt('', ''), ok);
  });

  test('coordinates have at most six decimals and stay in range', () {
    for (final String value in <String>['', '41.311081', '-90', '90', '0']) {
      expect(SettingsFormRules.latitude(value), ok, reason: value);
    }
    for (final String value in <String>[
      '90.000001',
      '-91',
      '41.3110811',
      '141.3',
      '41,3',
    ]) {
      expect(
        SettingsFormRules.latitude(value),
        SettingsFieldProblem.latitude,
        reason: value,
      );
    }
    for (final String value in <String>['', '69.240562', '-180', '180']) {
      expect(SettingsFormRules.longitude(value), ok, reason: value);
    }
    for (final String value in <String>['180.000001', '1800', '69.2405621']) {
      expect(
        SettingsFormRules.longitude(value),
        SettingsFieldProblem.longitude,
        reason: value,
      );
    }
  });

  test('a radius is above zero and at most 9999.99', () {
    for (final String value in <String>['', '5', '5.00', '0.01', '9999.99']) {
      expect(SettingsFormRules.radius(value), ok, reason: value);
    }
    for (final String value in <String>['0', '0.00', '10000', '5.001', '-5']) {
      expect(
        SettingsFormRules.radius(value),
        SettingsFieldProblem.radius,
        reason: value,
      );
    }
  });

  test('the delay threshold is required, 1 to 1440 minutes', () {
    expect(SettingsFormRules.minutes(''), SettingsFieldProblem.required);
    for (final String value in <String>['1', '30', '1440']) {
      expect(SettingsFormRules.minutes(value), ok, reason: value);
    }
    for (final String value in <String>['0', '1441', '30.5', '-1', '99999']) {
      expect(
        SettingsFormRules.minutes(value),
        SettingsFieldProblem.minutes,
        reason: value,
      );
    }
  });

  test('an optional field is sent trimmed, or as null when empty', () {
    expect(SettingsFormRules.optional('  09:00 '), '09:00');
    expect(SettingsFormRules.optional('   '), isNull);
  });
}
