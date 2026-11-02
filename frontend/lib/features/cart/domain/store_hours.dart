import '../../../core/formatting/tashkent_time.dart';

/// The business's working hours in Tashkent, as the cart answers them
/// (`DL-125`): open from opening up to, not including, closing; a closing
/// before the opening spans midnight. Display only: checkout stays the
/// authority on orders outside the hours.
final class StoreHours {
  const StoreHours({required this.opensMinute, required this.closesMinute});

  /// From two `HH:MM` times; anything else is a [FormatException].
  factory StoreHours.parse(String opensAt, String closesAt) => StoreHours(
    opensMinute: _minute(opensAt),
    closesMinute: _minute(closesAt),
  );

  /// Minutes of the Tashkent day.
  final int opensMinute;
  final int closesMinute;

  static final RegExp _time = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');
  static const int _dayEnd = 23 * 60 + 59;

  static int _minute(String time) {
    final RegExpMatch? parts = _time.firstMatch(time);
    if (parts == null) {
      throw FormatException('"$time" is not a time of day HH:MM');
    }
    return int.parse(parts[1]!) * 60 + int.parse(parts[2]!);
  }

  /// The opening time as `HH:MM`.
  String get opensAt =>
      '${(opensMinute ~/ 60).toString().padLeft(2, '0')}:'
      '${(opensMinute % 60).toString().padLeft(2, '0')}';

  bool get _alwaysOpen => opensMinute == 0 && closesMinute == _dayEnd;

  bool isOpenAt(DateTime instant) {
    if (_alwaysOpen) {
      return true;
    }
    final DateTime local = instant.toUtc().add(TashkentTime.offset);
    final int minute = local.hour * 60 + local.minute;
    return opensMinute < closesMinute
        ? minute >= opensMinute && minute < closesMinute
        : minute >= opensMinute || minute < closesMinute;
  }

  /// The next moment after [instant] that the store opens or closes.
  DateTime nextChangeAfter(DateTime instant) {
    final DateTime local = instant.toUtc().add(TashkentTime.offset);
    final DateTime midnight = DateTime.utc(local.year, local.month, local.day);
    DateTime? next;
    for (final int boundary in <int>[opensMinute, closesMinute]) {
      DateTime candidate = midnight.add(Duration(minutes: boundary));
      if (!candidate.isAfter(local)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      if (next == null || candidate.isBefore(next)) {
        next = candidate;
      }
    }
    return next!.subtract(TashkentTime.offset);
  }

  @override
  bool operator ==(Object other) =>
      other is StoreHours &&
      other.opensMinute == opensMinute &&
      other.closesMinute == closesMinute;

  @override
  int get hashCode => Object.hash(opensMinute, closesMinute);
}
