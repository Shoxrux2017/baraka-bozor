import '../localization/generated/app_localizations.dart';

/// The apartment as a line shows it: "кв. 5" / "5-xonadon" when it is digits
/// only, as typed otherwise, and `null` when there is none.
String? addressApartmentPart(AppLocalizations l10n, String? apartment) {
  final String? typed = apartment?.trim();
  if (typed == null || typed.isEmpty) {
    return null;
  }
  return RegExp(r'^\d+$').hasMatch(typed)
      ? l10n.addressApartmentShort(typed)
      : typed;
}

/// "street, house", then the apartment: the one line every surface uses for
/// an address.
String addressFullLine(
  AppLocalizations l10n, {
  required String street,
  required String house,
  String? apartment,
}) {
  final String? part = addressApartmentPart(l10n, apartment);
  return part == null ? '$street, $house' : '$street, $house, $part';
}
