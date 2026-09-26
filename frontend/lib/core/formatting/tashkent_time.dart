import 'package:intl/intl.dart';

/// Instants as the business reads them: in `Asia/Tashkent`, whatever the
/// device's own zone (`docs/07-architecture.md` section 26 — device clocks
/// are never authoritative). Uzbekistan keeps UTC+5 all year, so the zone is
/// a fixed offset.
abstract final class TashkentTime {
  static const Duration offset = Duration(hours: 5);

  static final DateFormat _dateTime = DateFormat('dd.MM.yyyy HH:mm');

  /// [instant] as a Tashkent wall-clock reading: `26.09.2026 10:00`.
  static String format(DateTime instant) =>
      _dateTime.format(instant.toUtc().add(offset));
}
