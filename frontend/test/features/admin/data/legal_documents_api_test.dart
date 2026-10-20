import 'dart:convert';

import 'package:baraka_bozor/core/legal/legal_document_kind.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/network/auth_interceptor.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/admin/data/legal_documents_api.dart';
import 'package:baraka_bozor/features/admin/domain/legal_documents.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  late FakeHttpClientAdapter adapter;
  late LegalDocumentsApi api;
  late ResponseBody Function(RequestOptions options) reply;

  Map<String, Object?> entry(
    String kind,
    String language, {
    String? body,
    String? updatedAt,
    Map<String, Object?>? updatedBy,
  }) => <String, Object?>{
    'kind': kind,
    'language': language,
    'body': body,
    'updated_at': updatedAt,
    'updated_by': updatedBy,
  };

  setUp(() {
    reply = (RequestOptions options) => jsonReply(200, <String, Object?>{
      'data': <Map<String, Object?>>[
        entry('terms', 'uz'),
        entry(
          'terms',
          'ru',
          body: '## Условия',
          updatedAt: '2026-10-19T10:00:00Z',
          updatedBy: <String, Object?>{
            'id': '0198a000-0000-7000-8000-000000000001',
            'full_name': 'Admin Adminov',
          },
        ),
        entry('privacy', 'uz'),
        entry('privacy', 'ru'),
      ],
    });
    adapter = FakeHttpClientAdapter((RequestOptions options) => reply(options));
    api = LegalDocumentsApi(dioWith(adapter));
  });

  test('the list parses four entries on the staff session', () async {
    final List<LegalDocumentEntry> entries = await api.list();

    final RequestOptions request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/admin/legal-documents');
    expect(
      RequestSlot.resolve(request, () => SessionSlot.customer),
      SessionSlot.staff,
    );
    expect(entries, hasLength(4));
    expect(entries[0].kind, LegalDocumentKind.terms);
    expect(entries[0].language, AppLanguage.uz);
    expect(entries[0].body, isNull);
    expect(entries[0].updatedAt, isNull);
    expect(entries[0].updatedByName, isNull);
    expect(entries[1].body, '## Условия');
    expect(entries[1].updatedAt, DateTime.utc(2026, 10, 19, 10));
    expect(entries[1].updatedByName, 'Admin Adminov');
    expect(entries[3].kind, LegalDocumentKind.privacy);
  });

  test('a malformed list is a failure', () async {
    reply = (RequestOptions options) => jsonReply(200, <String, Object?>{
      'data': <Map<String, Object?>>[entry('cookies', 'uz')],
    });

    await expectLater(api.list(), throwsA(anything));
  });

  test('publish sends a PUT with the body', () async {
    reply = (RequestOptions options) => jsonReply(200, <String, Object?>{
      'data': entry(
        'terms',
        'ru',
        body: 'x',
        updatedAt: '2026-10-19T10:00:00Z',
        updatedBy: <String, Object?>{
          'id': '0198a000-0000-7000-8000-000000000001',
          'full_name': 'Admin Adminov',
        },
      ),
    });

    final LegalDocumentEntry saved = await api.publish(
      LegalDocumentKind.terms,
      AppLanguage.ru,
      'x',
    );

    final RequestOptions request = adapter.requests.single;
    expect(request.method, 'PUT');
    expect(request.path, '/admin/legal-documents/terms/ru');
    expect(jsonDecode(jsonEncode(request.data)), <String, Object?>{
      'body': 'x',
    });
    expect(saved.body, 'x');
  });

  test('publishing nothing sends a null body', () async {
    reply = (RequestOptions options) =>
        jsonReply(200, <String, Object?>{'data': entry('privacy', 'uz')});

    await api.publish(LegalDocumentKind.privacy, AppLanguage.uz, null);

    final RequestOptions request = adapter.requests.single;
    expect(request.path, '/admin/legal-documents/privacy/uz');
    expect(jsonDecode(jsonEncode(request.data)), <String, Object?>{
      'body': null,
    });
  });

  test('an answer for another document is malformed', () async {
    reply = (RequestOptions options) =>
        jsonReply(200, <String, Object?>{'data': entry('terms', 'uz')});

    await expectLater(
      api.publish(LegalDocumentKind.terms, AppLanguage.ru, 'x'),
      throwsA(anything),
    );
  });
}
