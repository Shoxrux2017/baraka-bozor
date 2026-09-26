import 'package:baraka_bozor/core/network/auth_interceptor.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/addresses/data/addresses_api.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:baraka_bozor/features/profile/data/profile_api.dart';
import 'package:baraka_bozor/features/profile/domain/profile.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_client_adapter.dart';

const String addressId = '3c4d5e6f-7a8b-4c9d-8e0f-1a2b3c4d5e6f';
const String customerId = '9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d';

Map<String, Object?> addressJson() => <String, Object?>{
  'id': addressId,
  'label': null,
  'latitude': '41.311081',
  'longitude': '69.240562',
  'street': 'Amir Temur',
  'house': '12',
  'apartment': null,
  'landmark': 'Metro yonida',
  'delivery_note': null,
  'created_at': '2026-09-26T05:00:00Z',
  'updated_at': '2026-09-26T05:00:00Z',
};

void main() {
  test('a point from the map is written with six decimals', () {
    final GeoPoint point = GeoPoint.fromDegrees(41.3, 69.2405617);

    expect(point.latitude, '41.300000');
    expect(point.longitude, '69.240562');
  });

  test('an address parses, and a malformed one is refused', () {
    final Address parsed = AddressesRepositoryImpl.parse(addressJson());
    expect(
      parsed.point,
      const GeoPoint(latitude: '41.311081', longitude: '69.240562'),
    );
    expect(parsed.landmark, 'Metro yonida');

    for (final Map<String, Object?> broken in <Map<String, Object?>>[
      <String, Object?>{...addressJson(), 'latitude': 41.3},
      <String, Object?>{...addressJson(), 'latitude': '41.3'},
      <String, Object?>{...addressJson(), 'latitude': '91.000000'},
      <String, Object?>{...addressJson(), 'longitude': '181.000000'},
      <String, Object?>{...addressJson(), 'id': 'a-1'},
    ]) {
      expect(
        () => AddressesRepositoryImpl.parse(broken),
        throwsFormatException,
      );
    }
  });

  test('a profile is held to its contract', () {
    final Map<String, Object?> json = <String, Object?>{
      'id': customerId,
      'phone': '+998901234567',
      'full_name': null,
    };
    expect(ProfileRepositoryImpl.parse(json).phone, '+998901234567');
    for (final Map<String, Object?> broken in <Map<String, Object?>>[
      <String, Object?>{...json, 'id': 'c'},
      <String, Object?>{...json, 'phone': '901234567'},
    ]) {
      expect(() => ProfileRepositoryImpl.parse(broken), throwsFormatException);
    }
  });

  test('an edit sends what changed, and the point only as a pair', () {
    final Address address = AddressesRepositoryImpl.parse(addressJson());
    final AddressDraft same = AddressDraft.fromAddress(address);

    expect(AddressesRepositoryImpl.changed(address, same), isEmpty);
    expect(
      AddressesRepositoryImpl.changed(
        address,
        AddressDraft(
          label: 'Uy',
          point: const GeoPoint(latitude: '41.311081', longitude: '69.250000'),
          street: same.street,
          house: same.house,
          apartment: same.apartment,
          landmark: null,
          deliveryNote: same.deliveryNote,
        ),
      ),
      <String, Object?>{
        'label': 'Uy',
        'latitude': '41.311081',
        'longitude': '69.250000',
        'landmark': null,
      },
    );
  });

  group('requests', () {
    late FakeHttpClientAdapter adapter;
    late AddressesRepositoryImpl addresses;
    late ProfileRepositoryImpl profile;

    setUp(() {
      adapter = FakeHttpClientAdapter((RequestOptions options) {
        if (options.path == '/customer/profile') {
          return jsonReply(200, <String, Object?>{
            'data': <String, Object?>{
              'id': customerId,
              'phone': '+998901234567',
              'full_name': 'Aziza',
              'preferred_language': 'uz',
            },
          });
        }
        if (options.method == 'DELETE') {
          return emptyReply(204);
        }
        if (options.method == 'GET') {
          return jsonReply(200, <String, Object?>{
            'data': <Object?>[addressJson()],
            'meta': <String, Object?>{
              'pagination': <String, int>{
                'page': 1,
                'per_page': 100,
                'total': 1,
                'last_page': 1,
              },
            },
          });
        }
        return jsonReply(
          options.method == 'POST' ? 201 : 200,
          <String, Object?>{'data': addressJson()},
        );
      });
      addresses = AddressesRepositoryImpl(dioWith(adapter));
      profile = ProfileRepositoryImpl(dioWith(adapter));
    });

    SessionSlot? slotOf(RequestOptions options) =>
        RequestSlot.resolve(options, () => SessionSlot.staff);

    test(
      'every request goes on the Customer session to its own path',
      () async {
        const AddressDraft draft = AddressDraft(
          label: 'Uy',
          point: GeoPoint(latitude: '41.311081', longitude: '69.240562'),
          street: 'Amir Temur',
          house: '12',
          apartment: null,
          landmark: null,
          deliveryNote: 'Domofon 12',
        );

        final Address existing = (await addresses.addresses()).single;
        await addresses.create(draft);
        await addresses.update(existing, draft);
        await addresses.remove(addressId);
        final CustomerProfile current = await profile.profile();
        await profile.rename(current, 'Aziza Karimova');
        // Nothing changed, so nothing is sent.
        await addresses.update(existing, AddressDraft.fromAddress(existing));
        await profile.rename(current, 'Aziza');

        expect(
          adapter.requests.map((RequestOptions o) => '${o.method} ${o.path}'),
          <String>[
            'GET /customer/addresses',
            'POST /customer/addresses',
            'PATCH /customer/addresses/$addressId',
            'DELETE /customer/addresses/$addressId',
            'GET /customer/profile',
            'PATCH /customer/profile',
          ],
        );
        for (final RequestOptions request in adapter.requests) {
          expect(slotOf(request), SessionSlot.customer);
        }
        expect(adapter.requests[1].data, <String, Object?>{
          'label': 'Uy',
          'latitude': '41.311081',
          'longitude': '69.240562',
          'street': 'Amir Temur',
          'house': '12',
          'apartment': null,
          'landmark': null,
          'delivery_note': 'Domofon 12',
        });
        expect(adapter.requests[2].data, <String, Object?>{
          'label': 'Uy',
          'landmark': null,
          'delivery_note': 'Domofon 12',
        });
        expect(adapter.requests.last.data, <String, String>{
          'full_name': 'Aziza Karimova',
        });
        expect(adapter.requests.first.queryParameters, <String, Object>{
          'per_page': 100,
        });
      },
    );
  });
}
