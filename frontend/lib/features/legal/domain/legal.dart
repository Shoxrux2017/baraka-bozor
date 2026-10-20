import '../../../core/legal/legal_document_kind.dart';
import '../../../core/localization/app_language.dart';

enum LegalBlockType { heading, paragraph, item }

final class LegalBlock {
  const LegalBlock({required this.type, required this.text});

  final LegalBlockType type;
  final String text;
}

/// One published edition of one document, as the index lists it. [language]
/// is the language the server answers in, which is its fallback when the
/// asked one is not published.
final class LegalEdition {
  const LegalEdition({
    required this.kind,
    required this.language,
    required this.updatedAt,
  });

  final LegalDocumentKind kind;
  final AppLanguage language;
  final DateTime updatedAt;
}

/// Which documents are published (`docs/09-api-contracts.md` section 61).
final class LegalIndex {
  const LegalIndex({required this.terms, required this.privacy});

  final LegalEdition? terms;
  final LegalEdition? privacy;

  LegalEdition? of(LegalDocumentKind kind) => switch (kind) {
    LegalDocumentKind.terms => terms,
    LegalDocumentKind.privacy => privacy,
  };

  bool get hasAny => terms != null || privacy != null;
}

final class LegalDocument {
  const LegalDocument({
    required this.kind,
    required this.language,
    required this.updatedAt,
    required this.blocks,
  });

  final LegalDocumentKind kind;
  final AppLanguage language;
  final DateTime updatedAt;
  final List<LegalBlock> blocks;
}

/// The public documents (`docs/09-api-contracts.md` sections 61 and 62),
/// read without a session. Every method throws an `ApiFailure`.
abstract interface class LegalRepository {
  Future<LegalIndex> index(AppLanguage language);

  /// `null` when neither language of [kind] is published. A block of a kind
  /// this app does not know is left out, so a later kind does not break the
  /// document.
  Future<LegalDocument?> document(LegalDocumentKind kind, AppLanguage language);
}
