import 'package:baraka_bozor/core/legal/legal_document_kind.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/features/admin/data/legal_documents_api.dart';
import 'package:baraka_bozor/features/admin/domain/legal_documents.dart';
import 'package:dio/dio.dart';

/// The four documents in memory, answering as the server does: a publish
/// returns the entry with the time and the author.
class FakeLegalDocumentsApi extends LegalDocumentsApi {
  FakeLegalDocumentsApi() : super(Dio());

  final List<LegalDocumentEntry> entries = <LegalDocumentEntry>[
    for (final LegalDocumentKind kind in LegalDocumentKind.values)
      for (final AppLanguage language in AppLanguage.values)
        LegalDocumentEntry(
          kind: kind,
          language: language,
          body: null,
          updatedAt: null,
          updatedByName: null,
        ),
  ];

  /// Every publish received, as kind, language and body.
  final List<(LegalDocumentKind, AppLanguage, String?)> published =
      <(LegalDocumentKind, AppLanguage, String?)>[];

  int loads = 0;

  ApiFailure? listFailure;

  void set(LegalDocumentKind kind, AppLanguage language, String body) {
    final int index = entries.indexWhere(
      (LegalDocumentEntry e) => e.kind == kind && e.language == language,
    );
    entries[index] = LegalDocumentEntry(
      kind: kind,
      language: language,
      body: body,
      updatedAt: DateTime.utc(2026, 10, 19, 10),
      updatedByName: 'Admin Adminov',
    );
  }

  @override
  Future<List<LegalDocumentEntry>> list() async {
    loads++;
    final ApiFailure? failure = listFailure;
    if (failure != null) {
      throw failure;
    }
    return List<LegalDocumentEntry>.of(entries);
  }

  @override
  Future<LegalDocumentEntry> publish(
    LegalDocumentKind kind,
    AppLanguage language,
    String? body,
  ) async {
    published.add((kind, language, body));
    final int index = entries.indexWhere(
      (LegalDocumentEntry e) => e.kind == kind && e.language == language,
    );
    entries[index] = LegalDocumentEntry(
      kind: kind,
      language: language,
      body: body,
      updatedAt: DateTime.utc(2026, 10, 19, 12),
      updatedByName: 'Admin Adminov',
    );
    return entries[index];
  }
}
