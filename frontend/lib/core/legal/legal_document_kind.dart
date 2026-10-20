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
