import '../../../core/localization/generated/app_localizations.dart';
import 'settings_form_rules.dart';

/// The checks behind the category and product forms, mirroring `DL-20` (6):
/// names of 1 to 120 characters for a category and 1 to 160 for a product,
/// descriptions of at most 2000, a sort order from -100 000 to 100 000, and a
/// market price of 1 to 1 000 000 000 UZS. Lengths count code points, as the
/// server's `max` does. Each answers the text to show, or `null` when the
/// value may be sent.
abstract final class CatalogFormRules {
  static const int categoryNameMax = 120;
  static const int productNameMax = 160;
  static const int descriptionMax = 2000;
  static const int sortOrderLimit = 100000;
  static const int marketPriceMax = 1000000000;

  static final RegExp _integer = RegExp(r'^-?\d{1,6}$');
  static final RegExp _groupSpaces = RegExp(r'[\s\u00A0]');

  static String? name(AppLocalizations l10n, String text, int max) {
    final String value = text.trim();
    if (value.isEmpty) {
      return l10n.fieldRequired;
    }
    return value.runes.length > max ? l10n.fieldTooLong(max) : null;
  }

  static String? description(AppLocalizations l10n, String text) =>
      text.trim().runes.length > descriptionMax
      ? l10n.fieldTooLong(descriptionMax)
      : null;

  static String? sortOrder(AppLocalizations l10n, String text) {
    final String value = text.trim();
    if (value.isEmpty) {
      return null;
    }
    final int? order = _integer.hasMatch(value) ? int.parse(value) : null;
    return order != null && order.abs() <= sortOrderLimit
        ? null
        : l10n.fieldSortOrder;
  }

  /// The sort order [text] holds; an empty field is the default, `0`.
  static int sortOrderValue(String text) {
    final String value = text.trim();
    return value.isEmpty ? 0 : int.parse(value);
  }

  static String? marketPrice(AppLocalizations l10n, String text) {
    final String value = text.replaceAll(_groupSpaces, '');
    if (value.isEmpty) {
      return l10n.fieldRequired;
    }
    return SettingsFormRules.amount(value) == null &&
            int.parse(value) >= 1 &&
            int.parse(value) <= marketPriceMax
        ? null
        : l10n.fieldMarketPrice;
  }

  static int marketPriceValue(String text) =>
      int.parse(text.replaceAll(_groupSpaces, ''));

  /// The text of an optional field as the API takes it.
  static String? optional(String text) => SettingsFormRules.optional(text);
}
