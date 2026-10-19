import 'package:baraka_bozor/core/legal/legal_document_kind.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/features/legal/domain/legal.dart';

/// The public documents in memory. Nothing is published until a test says so;
/// a failure set on it is thrown by every read until it is cleared.
class FakeLegalRepository implements LegalRepository {
  /// The index answered in every language.
  LegalIndex publishedIndex = const LegalIndex(terms: null, privacy: null);

  /// The documents, by kind and the language asked for.
  final Map<(LegalDocumentKind, AppLanguage), LegalDocument?> documents =
      <(LegalDocumentKind, AppLanguage), LegalDocument?>{};

  ApiFailure? indexFailure;
  ApiFailure? documentFailure;

  int indexCalls = 0;

  /// Every document read, as kind and language.
  final List<(LegalDocumentKind, AppLanguage)> documentCalls =
      <(LegalDocumentKind, AppLanguage)>[];

  /// Publishes both documents in the index.
  void publishBoth() {
    publishedIndex = LegalIndex(
      terms: _edition(LegalDocumentKind.terms),
      privacy: _edition(LegalDocumentKind.privacy),
    );
  }

  /// Publishes only [kind] in the index.
  void publishOnly(LegalDocumentKind kind) {
    publishedIndex = LegalIndex(
      terms: kind == LegalDocumentKind.terms
          ? _edition(LegalDocumentKind.terms)
          : null,
      privacy: kind == LegalDocumentKind.privacy
          ? _edition(LegalDocumentKind.privacy)
          : null,
    );
  }

  LegalEdition _edition(LegalDocumentKind kind) => LegalEdition(
    kind: kind,
    language: AppLanguage.ru,
    updatedAt: DateTime.utc(2026, 10, 18, 20, 30),
  );

  @override
  Future<LegalIndex> index(AppLanguage language) async {
    indexCalls++;
    final ApiFailure? failure = indexFailure;
    if (failure != null) {
      throw failure;
    }
    return publishedIndex;
  }

  @override
  Future<LegalDocument?> document(
    LegalDocumentKind kind,
    AppLanguage language,
  ) async {
    documentCalls.add((kind, language));
    final ApiFailure? failure = documentFailure;
    if (failure != null) {
      throw failure;
    }
    return documents[(kind, language)];
  }
}
