import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/features/addresses/data/address_search_api.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_client_adapter.dart';

void main() {
  late FakeHttpClientAdapter adapter;
  late AddressSearchRepositoryImpl search;
  late ResponseBody Function() reply;

  setUp(() {
    reply = () => jsonReply(200, <String, Object?>{
      'data': <String, Object?>{
        'latitude': '41.299512',
        'longitude': '69.240146',
      },
    });
    adapter = FakeHttpClientAdapter((RequestOptions options) => reply());
    search = AddressSearchRepositoryImpl(dioWith(adapter));
  });

  test('it posts the query and parses the point', () async {
    final GeoPoint? point = await search.locate('Navoiy 5');

    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.path, '/customer/address-search');
    expect(adapter.requests.single.data, <String, Object?>{
      'query': 'Navoiy 5',
    });
    expect(
      point,
      const GeoPoint(latitude: '41.299512', longitude: '69.240146'),
    );
  });

  test('data null is nothing found', () async {
    reply = () => jsonReply(200, <String, Object?>{'data': null});

    expect(await search.locate('Navoiy 5'), isNull);
  });

  test('a point off the contract is malformed', () async {
    reply = () => jsonReply(200, <String, Object?>{
      'data': <String, Object?>{'latitude': 41.3, 'longitude': '69.240146'},
    });

    await expectLater(
      search.locate('Navoiy 5'),
      throwsA(isA<MalformedResponseFailure>()),
    );
  });

  test('a 503 is the provider being unavailable', () async {
    reply = () => errorReply(503, 'provider_unavailable');

    await expectLater(
      search.locate('Navoiy 5'),
      throwsA(
        isA<ApiRefusal>().having(
          (ApiRefusal r) => r.code,
          'code',
          'provider_unavailable',
        ),
      ),
    );
  });
}
