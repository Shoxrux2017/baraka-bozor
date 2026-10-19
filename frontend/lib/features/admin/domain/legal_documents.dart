import '../../../core/legal/legal_document_kind.dart';
import '../../../core/localization/app_language.dart';

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
