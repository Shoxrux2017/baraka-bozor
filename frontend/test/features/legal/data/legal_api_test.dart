import 'package:baraka_bozor/core/legal/legal_document_kind.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/auth_interceptor.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/legal/data/legal_api.dart';
import 'package:baraka_bozor/features/legal/domain/legal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  late FakeHttpClientAdapter adapter;
  late LegalApi api;
  late ResponseBody Function(RequestOptions options) reply;

  setUp(() {
    reply = (RequestOptions options) => jsonReply(200, <String, Object?>{});
    adapter = FakeHttpClientAdapter((RequestOptions options) => reply(options));
    api = LegalApi(dioWith(adapter));
  });

  test('the index is read without a session', () async {
    reply = (RequestOptions options) => jsonReply(200, <String, Object?>{
      'data': <String, Object?>{
        'terms': <String, Object?>{
          'language': 'ru',
          'updated_at': '2026-10-19T10:00:00Z',
        },
        'privacy': null,
      },
    });

    final LegalIndex index = await api.index(AppLanguage.ru);

    final RequestOptions request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/legal');
    expect(request.queryParameters, <String, Object?>{'language': 'ru'});
    expect(request.headers.containsKey('Authorization'), isFalse);
    expect(RequestSlot.resolve(request, () => SessionSlot.customer), isNull);
    expect(index.terms?.kind, LegalDocumentKind.terms);
    expect(index.terms?.language, AppLanguage.ru);
    expect(index.terms?.updatedAt, DateTime.utc(2026, 10, 19, 10));
    expect(index.privacy, isNull);
    expect(index.of(LegalDocumentKind.privacy), isNull);
    expect(index.of(LegalDocumentKind.terms), same(index.terms));
    expect(index.hasAny, isTrue);
  });

  test('an index with nothing published has none', () async {
    reply = (RequestOptions options) => jsonReply(200, <String, Object?>{
      'data': <String, Object?>{'terms': null, 'privacy': null},
    });

    expect((await api.index(AppLanguage.uz)).hasAny, isFalse);
  });

  test(
    'a document keeps the server fallback language and block order',
    () async {
      reply = (RequestOptions options) => jsonReply(200, <String, Object?>{
        'data': <String, Object?>{
          'kind': 'terms',
          'language': 'ru',
          'updated_at': '2026-10-19T10:00:00Z',
          'blocks': <Map<String, Object?>>[
            <String, Object?>{'type': 'heading', 'text': 'Условия'},
            <String, Object?>{'type': 'paragraph', 'text': 'Текст'},
            <String, Object?>{'type': 'table', 'text': 'x'},
            <String, Object?>{'type': 'item', 'text': 'Пункт'},
          ],
        },
      });

      final LegalDocument? document = await api.document(
        LegalDocumentKind.terms,
        AppLanguage.uz,
      );

      final RequestOptions request = adapter.requests.single;
      expect(request.path, '/legal/terms');
      expect(request.queryParameters, <String, Object?>{'language': 'uz'});
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(document, isNotNull);
      expect(document!.kind, LegalDocumentKind.terms);
      expect(document.language, AppLanguage.ru);
      expect(document.updatedAt, DateTime.utc(2026, 10, 19, 10));
      expect(
        document.blocks.map((LegalBlock b) => (b.type, b.text)).toList(),
        <(LegalBlockType, String)>[
          (LegalBlockType.heading, 'Условия'),
          (LegalBlockType.paragraph, 'Текст'),
          (LegalBlockType.item, 'Пункт'),
        ],
      );
    },
  );

  test('a 404 is no document', () async {
    reply = (RequestOptions options) => errorReply(404, 'not_found');

    expect(
      await api.document(LegalDocumentKind.privacy, AppLanguage.ru),
      isNull,
    );
  });

  test('a 500 is the usual failure', () async {
    reply = (RequestOptions options) => errorReply(500, 'server_error');

    await expectLater(
      api.document(LegalDocumentKind.terms, AppLanguage.ru),
      throwsA(isA<ApiFailure>()),
    );
    await expectLater(api.index(AppLanguage.ru), throwsA(isA<ApiFailure>()));
  });
}
