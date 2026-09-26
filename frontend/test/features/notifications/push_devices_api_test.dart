import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/auth_interceptor.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/notifications/data/push_devices_api.dart';
import 'package:baraka_bozor/features/notifications/domain/push.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_client_adapter.dart';

const String deviceId = '1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d';

/// `docs/09-api-contracts.md` section 27 on the wire.
void main() {
  late FakeHttpClientAdapter adapter;
  late PushDevicesRepositoryImpl devices;
  late Map<String, Object?> answer;

  const PushToken token = PushToken(
    platform: PushPlatform.android,
    value: 'fcm-token',
  );

  setUp(() {
    answer = <String, Object?>{
      'id': deviceId,
      'platform': 'android',
      'last_seen_at': '2026-09-27T05:00:00Z',
      'created_at': '2026-09-27T05:00:00Z',
    };
    adapter = FakeHttpClientAdapter(
      (RequestOptions options) => options.method == 'DELETE'
          ? emptyReply(204)
          : jsonReply(200, <String, Object?>{'data': answer}),
    );
    devices = PushDevicesRepositoryImpl(dioWith(adapter));
  });

  SessionSlot? slotOf(RequestOptions options) =>
      RequestSlot.resolve(options, () => SessionSlot.staff);

  test('a device is registered and revoked on the session named', () async {
    final String id = await devices.register(SessionSlot.customer, token);
    await devices.revoke(SessionSlot.customer, id);

    expect(id, deviceId);
    expect(
      adapter.requests.map((RequestOptions o) => '${o.method} ${o.path}'),
      <String>['POST /push-devices', 'DELETE /push-devices/$deviceId'],
    );
    expect(adapter.requests.first.data, <String, String>{
      'platform': 'android',
      'token': 'fcm-token',
    });
    expect(adapter.requests.last.data, isNull);
    for (final RequestOptions request in adapter.requests) {
      expect(slotOf(request), SessionSlot.customer);
    }
  });

  test(
    'an answer off the contract or about another platform is refused',
    () async {
      for (final Map<String, Object?> broken in <Map<String, Object?>>[
        <String, Object?>{...answer, 'id': 'd-1'},
        <String, Object?>{...answer, 'platform': 'ios'},
        <String, Object?>{...answer, 'last_seen_at': 'today'},
        <String, Object?>{...answer}..remove('created_at'),
      ]) {
        answer = broken;
        await expectLater(
          devices.register(SessionSlot.staff, token),
          throwsA(isA<MalformedResponseFailure>()),
        );
      }
    },
  );
}
