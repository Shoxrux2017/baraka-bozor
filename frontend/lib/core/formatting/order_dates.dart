import '../localization/generated/app_localizations.dart';
import 'tashkent_time.dart';

DateTime _tashkent(DateTime instant) =>
    instant.toUtc().add(TashkentTime.offset);

String _two(int value) => value.toString().padLeft(2, '0');

/// The Tashkent calendar day of [instant] against that of [now]: the word
/// for today or yesterday, a day and month within [now]'s year, the full
/// date otherwise.
String orderDay(AppLocalizations l10n, DateTime instant, DateTime now) {
  final DateTime day = _tashkent(instant);
  final DateTime today = _tashkent(now);
  final int days = DateTime.utc(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime.utc(day.year, day.month, day.day)).inDays;
  if (days == 0) {
    return l10n.dayToday;
  }
  if (days == 1) {
    return l10n.dayYesterday;
  }
  if (day.year == today.year) {
    return l10n.dayDate('${day.day}', l10n.monthShort('m${day.month}'));
  }
  return '${_two(day.day)}.${_two(day.month)}.${day.year}';
}

/// "Сегодня, 12:40".
String orderWhen(AppLocalizations l10n, DateTime instant, DateTime now) =>
    l10n.orderWhen(orderDay(l10n, instant, now), TashkentTime.time(instant));

/// "Сегодня в 13:05".
String orderAt(AppLocalizations l10n, DateTime instant, DateTime now) =>
    l10n.orderAt(orderDay(l10n, instant, now), TashkentTime.time(instant));

/// [orderAt] with its first letter lower-cased, for the middle of a
/// sentence: "Вы отменили сегодня в 18:24".
String orderAtLower(AppLocalizations l10n, DateTime instant, DateTime now) {
  final String text = orderAt(l10n, instant, now);
  return text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);
}

/// A moment on the web panel: "18:00" on [now]'s Tashkent day, "21.10 18:00"
/// on any other (`DL-100` (8)).
String panelWhen(DateTime instant, DateTime now) {
  final DateTime day = _tashkent(instant);
  final DateTime today = _tashkent(now);
  final String time = TashkentTime.time(instant);
  if (day.year == today.year &&
      day.month == today.month &&
      day.day == today.day) {
    return time;
  }
  return '${_two(day.day)}.${_two(day.month)} $time';
}
