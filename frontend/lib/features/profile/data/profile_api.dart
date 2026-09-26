import 'package:dio/dio.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/storage/token_store.dart';
import '../domain/profile.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._dio);

  final Dio _dio;

  static final Options _customer = RequestSlot.of(SessionSlot.customer);

  @override
  Future<CustomerProfile> profile() => guardApiCall(() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/customer/profile',
      options: _customer,
    );
    return parse(ApiEnvelope.unwrap(response.data));
  });

  @override
  Future<CustomerProfile> rename(CustomerProfile profile, String fullName) =>
      guardApiCall(() async {
        if (profile.fullName == fullName) {
          return profile;
        }
        final Response<dynamic> response = await _dio.patch<dynamic>(
          '/customer/profile',
          data: <String, String>{'full_name': fullName},
          options: _customer,
        );
        return parse(ApiEnvelope.unwrap(response.data));
      });

  static final RegExp _phone = RegExp(r'^\+998\d{9}$');

  /// The profile, held to its contract: a UUID id and the phone as `+998`
  /// and nine digits (`docs/09` section 12).
  static CustomerProfile parse(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'profile');
    final String phone = json.string('phone');
    if (!_phone.hasMatch(phone)) {
      throw const FormatException('a phone is +998 and nine digits');
    }
    return CustomerProfile(
      id: json.uuid('id'),
      phone: phone,
      fullName: json.nullableString('full_name'),
    );
  }
}
