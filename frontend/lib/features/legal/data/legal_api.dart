import 'package:dio/dio.dart';

import '../../../core/legal/legal_document_kind.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/network/api_call.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/json_fields.dart';
import '../domain/legal.dart';

/// `GET /legal` and `GET /legal/{kind}` (`docs/09` sections 61 and 62), sent
/// without a session as the login code request is.
class LegalApi implements LegalRepository {
  LegalApi(this._dio);

  final Dio _dio;

  static final Options _public = RequestSlot.of(null);

  @override
  Future<LegalIndex> index(AppLanguage language) => guardApiCall(() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/legal',
      queryParameters: <String, String>{'language': language.code},
      options: _public,
    );
    final JsonFields json = JsonFields.of(
      ApiEnvelope.unwrap(response.data),
      'legal index',
    );
    return LegalIndex(
      terms: _edition(json, LegalDocumentKind.terms),
      privacy: _edition(json, LegalDocumentKind.privacy),
    );
  });

  @override
  Future<LegalDocument?> document(
    LegalDocumentKind kind,
    AppLanguage language,
  ) async {
    try {
      return await guardApiCall(() async {
        final Response<dynamic> response = await _dio.get<dynamic>(
          '/legal/${kind.code}',
          queryParameters: <String, String>{'language': language.code},
          options: _public,
        );
        return _document(ApiEnvelope.unwrap(response.data), kind);
      });
    } on ApiRefusal catch (refusal) {
      if (refusal.status == 404) {
        return null;
      }
      rethrow;
    }
  }

  static LegalEdition? _edition(JsonFields index, LegalDocumentKind kind) {
    final Object? raw = index.member(kind.code);
    if (raw == null) {
      return null;
    }
    final JsonFields json = JsonFields.of(raw, kind.code);
    return LegalEdition(
      kind: kind,
      language: json.choice('language', AppLanguage.tryParse),
      updatedAt: json.instant('updated_at'),
    );
  }

  static LegalDocument _document(Object? raw, LegalDocumentKind asked) {
    final JsonFields json = JsonFields.of(raw, 'legal document');
    final LegalDocumentKind kind = json.choice(
      'kind',
      LegalDocumentKind.tryParse,
    );
    if (kind != asked) {
      throw const FormatException('the answer is about another document');
    }
    final Object? blocks = json.member('blocks');
    if (blocks is! List<dynamic>) {
      throw const FormatException('blocks is not a list');
    }
    final List<LegalBlock> known = <LegalBlock>[];
    for (final Object? block in blocks) {
      final LegalBlock? parsed = _block(block);
      if (parsed != null) {
        known.add(parsed);
      }
    }
    return LegalDocument(
      kind: kind,
      language: json.choice('language', AppLanguage.tryParse),
      updatedAt: json.instant('updated_at'),
      blocks: known,
    );
  }

  /// A block of an unknown type is skipped; a malformed one is not.
  static LegalBlock? _block(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'block');
    final LegalBlockType? type = switch (json.string('type')) {
      'heading' => LegalBlockType.heading,
      'paragraph' => LegalBlockType.paragraph,
      'item' => LegalBlockType.item,
      _ => null,
    };
    if (type == null) {
      return null;
    }
    return LegalBlock(type: type, text: json.string('text'));
  }
}
