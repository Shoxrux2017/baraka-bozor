/// Why the settings form refuses a value before sending it. The rules mirror
/// `docs/09-api-contracts.md` section 44 and `DL-19`, so the form refuses
/// what the API would refuse; the server still decides, and its field errors
/// are shown the same way.
enum SettingsFieldProblem {
  required,
  percent,
  amount,
  time,
  latitude,
  longitude,
  radius,
  minutes,
  pairIncomplete,
  sameTime,
}

/// The pure checks behind every field of the settings form. Each takes the
/// field's text as typed and answers the problem, or `null` when the value
/// may be sent. An empty optional field means "not set".
abstract final class SettingsFormRules {
  static final RegExp _percent = RegExp(r'^\d{1,3}(\.\d{1,2})?$');
  static final RegExp _digits = RegExp(r'^\d+$');
  static final RegExp _time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
  static final RegExp _latitude = RegExp(r'^-?\d{1,2}(\.\d{1,6})?$');
  static final RegExp _longitude = RegExp(r'^-?\d{1,3}(\.\d{1,6})?$');
  static final RegExp _radius = RegExp(r'^\d{1,4}(\.\d{1,2})?$');
  static final RegExp _groupSpaces = RegExp(r'[\s\u00A0]');

  static const int maxUzs = 1000000000;
  static const int maxMinutes = 1440;

  /// A percentage with at most three integer digits and two decimals.
  static SettingsFieldProblem? percent(String text, {required bool required}) {
    final String value = text.trim();
    if (value.isEmpty) {
      return required ? SettingsFieldProblem.required : null;
    }
    return _percent.hasMatch(value) ? null : SettingsFieldProblem.percent;
  }

  /// Whole UZS from 0 to one billion. Spaces between the thousands are
  /// allowed, as the amounts are shown that way.
  static SettingsFieldProblem? amount(String text) {
    final String value = text.replaceAll(_groupSpaces, '');
    if (value.isEmpty) {
      return null;
    }
    final int? amount = _digits.hasMatch(value) && value.length <= 10
        ? int.parse(value)
        : null;
    return amount != null && amount <= maxUzs
        ? null
        : SettingsFieldProblem.amount;
  }

  /// The amount [text] holds, or `null` when it is empty. Call after
  /// [amount] accepted it.
  static int? amountValue(String text) {
    final String value = text.replaceAll(_groupSpaces, '');
    return value.isEmpty ? null : int.parse(value);
  }

  static SettingsFieldProblem? time(String text) {
    final String value = text.trim();
    if (value.isEmpty) {
      return null;
    }
    return _time.hasMatch(value) ? null : SettingsFieldProblem.time;
  }

  static SettingsFieldProblem? latitude(String text) =>
      _coordinate(text, _latitude, 90, SettingsFieldProblem.latitude);

  static SettingsFieldProblem? longitude(String text) =>
      _coordinate(text, _longitude, 180, SettingsFieldProblem.longitude);

  /// A radius in kilometres above zero, at most 9999.99.
  static SettingsFieldProblem? radius(String text) {
    final String value = text.trim();
    if (value.isEmpty) {
      return null;
    }
    return _radius.hasMatch(value) && double.parse(value) > 0
        ? null
        : SettingsFieldProblem.radius;
  }

  /// The delay threshold: required, 1 to 1440 minutes.
  static SettingsFieldProblem? minutes(String text) {
    final String value = text.trim();
    if (value.isEmpty) {
      return SettingsFieldProblem.required;
    }
    final int? minutes = _digits.hasMatch(value) && value.length <= 4
        ? int.parse(value)
        : null;
    return minutes != null && minutes >= 1 && minutes <= maxMinutes
        ? null
        : SettingsFieldProblem.minutes;
  }

  /// Working hours and the centre come in pairs: the problem belongs to the
  /// empty half of a half-filled pair.
  static SettingsFieldProblem? pairHalf(String self, String other) =>
      self.trim().isEmpty && other.trim().isNotEmpty
      ? SettingsFieldProblem.pairIncomplete
      : null;

  /// Opening and closing must differ (`DL-19` (8)).
  static SettingsFieldProblem? closesAt(String closes, String opens) {
    final SettingsFieldProblem? own = time(closes) ?? pairHalf(closes, opens);
    if (own != null) {
      return own;
    }
    return closes.trim().isNotEmpty && closes.trim() == opens.trim()
        ? SettingsFieldProblem.sameTime
        : null;
  }

  /// The text of an optional field as the API takes it: trimmed, or `null`
  /// when empty.
  static String? optional(String text) {
    final String value = text.trim();
    return value.isEmpty ? null : value;
  }

  static SettingsFieldProblem? _coordinate(
    String text,
    RegExp shape,
    double limit,
    SettingsFieldProblem problem,
  ) {
    final String value = text.trim();
    if (value.isEmpty) {
      return null;
    }
    return shape.hasMatch(value) && double.parse(value).abs() <= limit
        ? null
        : problem;
  }
}
