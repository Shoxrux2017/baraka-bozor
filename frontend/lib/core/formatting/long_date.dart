import '../localization/generated/app_localizations.dart';
import 'tashkent_time.dart';

/// The Tashkent day of [instant] in words: «19 октября 2026» or
/// «2026-yil 19-oktabr» (`DL-136` (1)).
String longDate(AppLocalizations l10n, DateTime instant) {
  final DateTime day = instant.toUtc().add(TashkentTime.offset);
  return l10n.dateLong(
    day.day.toString(),
    l10n.monthLong('m${day.month}'),
    day.year.toString(),
  );
}
