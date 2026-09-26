import 'package:dio/dio.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/storage/token_store.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import 'auth_api.dart';

/// Turns the data source's transport failures and malformed payloads into the
/// `ApiFailure` the application layer handles.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api);

  final AuthApi _api;

  @override
  Future<RequestedCode> requestCustomerCode(String phone) =>
      _guard(() => _api.requestCustomerCode(phone));

  @override
  Future<IssuedSession> verifyCustomerCode({
    required String phone,
    required String code,
  }) => _guard(() => _api.verifyCustomerCode(phone: phone, code: code));

  @override
  Future<IssuedSession> staffLogin({
    required String phone,
    required String password,
  }) => _guard(() => _api.staffLogin(phone: phone, password: password));

  @override
  Future<AppUser> me(SessionSlot slot) => _guard(() => _api.me(slot));

  @override
  Future<AppUser> updateLanguage(SessionSlot slot, AppLanguage language) =>
      _guard(() => _api.updateLanguage(slot, language));

  @override
  Future<void> changePassword(
    SessionSlot slot, {
    required String currentPassword,
    required String newPassword,
  }) => _guard(
    () => _api.changePassword(
      slot,
      currentPassword: currentPassword,
      newPassword: newPassword,
    ),
  );

  @override
  Future<void> logout(SessionSlot slot) => _guard(() => _api.logout(slot));

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    } on FormatException catch (exception) {
      throw MalformedResponseFailure(reason: exception.message);
    }
  }
}
