import 'dart:ui' show Locale;

/// The two client languages of `docs/07-architecture.md` section 27.
///
/// Uzbek is written in Latin script (interview topic 8). The machine value
/// `code` is what the API stores in `preferred_language`; the label a person
/// sees comes from the localized strings, never from this enum.
enum AppLanguage {
  uz('uz'),
  ru('ru');

  const AppLanguage(this.code);

  /// The value the API and the on-device preference carry.
  final String code;

  Locale get locale => Locale(code);

  static AppLanguage? tryParse(String? code) {
    for (final AppLanguage language in values) {
      if (language.code == code) {
        return language;
      }
    }
    return null;
  }

  /// The default for a device: Russian when the device speaks Russian,
  /// Uzbek otherwise — interview topic 8.2.
  static AppLanguage forDevice(Locale deviceLocale) =>
      deviceLocale.languageCode == 'ru' ? AppLanguage.ru : AppLanguage.uz;
}
