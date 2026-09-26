import 'package:dio/dio.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/storage/token_store.dart';
import '../domain/app_user.dart';
import 'user_dto.dart';

/// The data source for `docs/09-api-contracts.md` sections 6 to 11. It owns
/// paths, bodies and which session each request is made on behalf of, and it
/// returns parsed models. Transport failures leave as `DioException` and are
/// mapped by the repository.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<RequestedCode> requestCustomerCode(String phone) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/auth/customer/code/request',
      data: <String, String>{'phone': phone},
      options: RequestSlot.of(null),
    );
    return UserDto.parseRequestedCode(ApiEnvelope.unwrap(response.data));
  }

  Future<IssuedSession> verifyCustomerCode({
    required String phone,
    required String code,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/auth/customer/code/verify',
      data: <String, String>{'phone': phone, 'code': code},
      options: RequestSlot.of(null),
    );
    return UserDto.parseIssuedSession(ApiEnvelope.unwrap(response.data));
  }

  Future<IssuedSession> staffLogin({
    required String phone,
    required String password,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/auth/staff/login',
      data: <String, String>{'phone': phone, 'password': password},
      options: RequestSlot.of(null),
    );
    return UserDto.parseIssuedSession(ApiEnvelope.unwrap(response.data));
  }

  Future<AppUser> me(SessionSlot slot) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/auth/me',
      options: RequestSlot.of(slot),
    );
    return UserDto.parse(ApiEnvelope.unwrap(response.data));
  }

  Future<AppUser> updateLanguage(SessionSlot slot, AppLanguage language) async {
    final Response<dynamic> response = await _dio.patch<dynamic>(
      '/auth/me',
      data: <String, String>{'preferred_language': language.code},
      options: RequestSlot.of(slot),
    );
    return UserDto.parse(ApiEnvelope.unwrap(response.data));
  }

  /// The confirmation is what the person typed a second time, sent as typed:
  /// the server's confirmation check is real only if the client does not
  /// fabricate it.
  Future<void> changePassword(
    SessionSlot slot, {
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    await _dio.post<dynamic>(
      '/auth/change-password',
      data: <String, String>{
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPasswordConfirmation,
      },
      options: RequestSlot.of(slot),
    );
  }

  Future<void> logout(SessionSlot slot) async {
    await _dio.post<dynamic>('/auth/logout', options: RequestSlot.of(slot));
  }
}
