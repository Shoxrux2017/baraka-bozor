import 'package:dio/dio.dart';

import '../../../core/localization/app_language.dart';
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
        final CustomerProfile saved = parse(ApiEnvelope.unwrap(response.data));
        // An answer about another Customer, or without the new name, is
        // malformed (`DL-27` (6)).
        if (saved.id != profile.id || saved.fullName != fullName) {
          throw const FormatException('the profile does not match the request');
        }
        return saved;
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
    json.choice('preferred_language', AppLanguage.tryParse);
    return CustomerProfile(
      id: json.uuid('id'),
      phone: phone,
      fullName: json.nullableString('full_name'),
    );
  }
}
