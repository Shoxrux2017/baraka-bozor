import '../../../core/localization/app_language.dart';

/// The two legal documents (`docs/09-api-contracts.md` section 63). The code
/// is the machine value of the API path; the name a person reads comes from
/// the localized strings.
enum LegalDocumentKind {
  terms('terms'),
  privacy('privacy');

  const LegalDocumentKind(this.code);

  final String code;

  static LegalDocumentKind? tryParse(String? code) {
    for (final LegalDocumentKind kind in values) {
      if (kind.code == code) {
        return kind;
      }
    }
    return null;
  }
}

/// One edition in force of one document in one language; [body] is `null`
/// while nothing is published.
final class LegalDocumentEntry {
  const LegalDocumentEntry({
    required this.kind,
    required this.language,
    required this.body,
    required this.updatedAt,
    required this.updatedByName,
  });

  final LegalDocumentKind kind;
  final AppLanguage language;
  final String? body;
  final DateTime? updatedAt;
  final String? updatedByName;
}
