import '../../../core/localization/app_language.dart';
import '../../../core/network/api_call.dart';
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
      guardApiCall(() => _api.requestCustomerCode(phone));

  @override
  Future<IssuedSession> verifyCustomerCode({
    required String phone,
    required String code,
  }) => guardApiCall(() => _api.verifyCustomerCode(phone: phone, code: code));

  @override
  Future<IssuedSession> staffLogin({
    required String phone,
    required String password,
  }) => guardApiCall(() => _api.staffLogin(phone: phone, password: password));

  @override
  Future<AppUser> me(SessionSlot slot) => guardApiCall(() => _api.me(slot));

  @override
  Future<AppUser> updateLanguage(SessionSlot slot, AppLanguage language) =>
      guardApiCall(() => _api.updateLanguage(slot, language));

  @override
  Future<void> changePassword(
    SessionSlot slot, {
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) => guardApiCall(
    () => _api.changePassword(
      slot,
      currentPassword: currentPassword,
      newPassword: newPassword,
      newPasswordConfirmation: newPasswordConfirmation,
    ),
  );

  @override
  Future<void> logout(SessionSlot slot) =>
      guardApiCall(() => _api.logout(slot));
}
