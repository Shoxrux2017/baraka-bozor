import 'package:dio/dio.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/storage/token_store.dart';
import '../domain/push.dart';

/// `POST /push-devices` and `DELETE /push-devices/{device}`, each on the
/// session named, so a device registered for the Customer account of a
/// phone that also holds a staff one is revoked on the Customer session.
class PushDevicesRepositoryImpl implements PushDevicesRepository {
  PushDevicesRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<String> register(SessionSlot slot, PushToken token) =>
      guardApiCall(() async {
        final Response<dynamic> response = await _dio.post<dynamic>(
          '/push-devices',
          data: <String, String>{
            'platform': token.platform.code,
            'token': token.value,
          },
          options: RequestSlot.of(slot),
        );
        // The device's id, from an answer about the platform just sent
        // (`DL-27` (6)); the token itself is never echoed.
        final JsonFields json = JsonFields.of(
          ApiEnvelope.unwrap(response.data),
          'push device',
        );
        if (json.string('platform') != token.platform.code) {
          throw const FormatException('the device does not match the request');
        }
        json
          ..nullableInstant('last_seen_at')
          ..instant('created_at');
        return json.uuid('id');
      });

  @override
  Future<void> revoke(SessionSlot slot, String deviceId) => guardApiCall(
    () => _dio.delete<dynamic>(
      '/push-devices/${Uri.encodeComponent(deviceId)}',
      options: RequestSlot.of(slot),
    ),
  );
}
