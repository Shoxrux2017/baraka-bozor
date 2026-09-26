import '../localization/app_language.dart';

/// Money as `docs/07-architecture.md` section 27 renders it: whole UZS with
/// thousands grouped by spaces and the currency after the amount —
/// `150 000 so'm` in Uzbek, `150 000 сум` in Russian. The spaces are
/// non-breaking so an amount never wraps across lines.
abstract final class MoneyFormat {
  static const String _space = '\u00A0';

  static String uzs(int amount, AppLanguage language) =>
      '${grouped(amount)}$_space${currency(language)}';

  /// The currency word alone, for an input field's suffix.
  static String currency(AppLanguage language) => switch (language) {
    AppLanguage.uz => "so'm",
    AppLanguage.ru => 'сум',
  };

  /// [amount] with its thousands grouped: `1500000` → `1 500 000`.
  static String grouped(int amount) {
    final String digits = amount.abs().toString();
    final StringBuffer out = StringBuffer(amount < 0 ? '-' : '');

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        out.write(_space);
      }
      out.write(digits[i]);
    }

    return out.toString();
  }
}
