import 'package:dio/dio.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/network/api_call.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/storage/token_store.dart';
import '../domain/legal_documents.dart';

/// The data source for `docs/09-api-contracts.md` section 63, on the staff
/// session, with its strict parsing. Failures leave as `ApiFailure`.
class LegalDocumentsApi {
  LegalDocumentsApi(this._dio);

  final Dio _dio;

  static final Options _staff = RequestSlot.of(SessionSlot.staff);

  /// Always four entries: terms and privacy, each in Uzbek and Russian.
  Future<List<LegalDocumentEntry>> list() => guardApiCall(() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/admin/legal-documents',
      options: _staff,
    );
    final Object? data = ApiEnvelope.unwrap(response.data);
    if (data is! List<dynamic>) {
      throw const FormatException('the documents are not a list');
    }
    return <LegalDocumentEntry>[for (final Object? raw in data) parse(raw)];
  });

  /// Publishes [body] as the new edition; `null` takes the document down.
  Future<LegalDocumentEntry> publish(
    LegalDocumentKind kind,
    AppLanguage language,
    String? body,
  ) => guardApiCall(() async {
    final Response<dynamic> response = await _dio.put<dynamic>(
      '/admin/legal-documents/${kind.code}/${language.code}',
      data: <String, String?>{'body': body},
      options: _staff,
    );
    final LegalDocumentEntry entry = parse(ApiEnvelope.unwrap(response.data));
    if (entry.kind != kind || entry.language != language) {
      throw const FormatException('the answer is about another document');
    }
    return entry;
  });

  static LegalDocumentEntry parse(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'legal document');
    final Object? by = json.member('updated_by');
    return LegalDocumentEntry(
      kind: json.choice('kind', LegalDocumentKind.tryParse),
      language: json.choice('language', AppLanguage.tryParse),
      body: json.nullableString('body'),
      updatedAt: json.nullableInstant('updated_at'),
      updatedByName: by == null
          ? null
          : JsonFields.of(by, 'updated_by').string('full_name'),
    );
  }
}
