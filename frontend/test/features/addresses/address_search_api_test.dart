import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/features/addresses/data/address_search_api.dart';
import 'package:baraka_bozor/features/addresses/domain/address_search.dart';
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

  group('addressAt', () {
    const GeoPoint here = GeoPoint(
      latitude: '41.300000',
      longitude: '69.250000',
    );

    ResponseBody line(Object? value) =>
        jsonReply(200, <String, Object?>{'data': value});

    test(
      'addressAt sends the point and the language and reads the line',
      () async {
        reply = () =>
            line(<String, Object?>{'line': 'Navoiy 5', 'house_known': true});

        final PointAddress? address = await search.addressAt(
          here,
          language: 'ru',
        );

        expect(adapter.requests.single.method, 'POST');
        expect(
          adapter.requests.single.path,
          '/customer/address-search/reverse',
        );
        expect(adapter.requests.single.data, <String, Object?>{
          'latitude': '41.300000',
          'longitude': '69.250000',
          'language': 'ru',
        });
        expect(address?.line, 'Navoiy 5');
        expect(address?.houseKnown, isTrue);
      },
    );

    test('addressAt reads null as nothing known', () async {
      reply = () => line(null);

      expect(await search.addressAt(here, language: 'uz'), isNull);
    });

    test('a line off the contract is a failure', () async {
      final List<Object?> bad = <Object?>[
        <String, Object?>{'line': '', 'house_known': true},
        <String, Object?>{'line': 'x' * 161, 'house_known': true},
        <String, Object?>{'line': 'Navoiy 5'},
        <String, Object?>{'line': 'Navoiy 5', 'house_known': 'yes'},
      ];
      for (final Object? body in bad) {
        reply = () => line(body);
        await expectLater(
          search.addressAt(here, language: 'ru'),
          throwsA(isA<MalformedResponseFailure>()),
        );
      }
    });
  });

  group('serviceArea', () {
    ResponseBody area(Object? value) =>
        jsonReply(200, <String, Object?>{'data': value});

    test('serviceArea reads the centre and the radius', () async {
      reply = () => area(<String, Object?>{
        'latitude': '41.311081',
        'longitude': '69.240562',
        'radius_km': '10.00',
      });

      final ServiceArea? zone = await search.serviceArea();

      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, '/customer/service-area');
      expect(
        zone?.centre,
        const GeoPoint(latitude: '41.311081', longitude: '69.240562'),
      );
      expect(zone?.radiusKm, '10.00');
    });

    test('serviceArea reads null while unset', () async {
      reply = () => area(null);

      expect(await search.serviceArea(), isNull);
    });

    test('an area off the contract is a failure', () async {
      for (final Map<String, Object?> body in <Map<String, Object?>>[
        <String, Object?>{
          'latitude': '41.311081',
          'longitude': '69.240562',
          'radius_km': '0',
        },
        <String, Object?>{
          'latitude': '41.311081',
          'longitude': '69.240562',
          'radius_km': 'abc',
        },
        <String, Object?>{
          'latitude': '41.3110811',
          'longitude': '69.240562',
          'radius_km': '10.00',
        },
      ]) {
        reply = () => area(body);
        await expectLater(
          search.serviceArea(),
          throwsA(isA<MalformedResponseFailure>()),
        );
      }
    });
  });
}
