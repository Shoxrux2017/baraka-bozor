import '../../../core/localization/app_language.dart';
import '../../../core/storage/token_store.dart';
import 'app_user.dart';

/// The authentication endpoints of `docs/09-api-contracts.md` sections 6 to
/// 11, as typed operations. Every method throws an `ApiFailure` on refusal or
/// transport failure; nothing above this contract sees a transport detail.
abstract interface class AuthRepository {
  Future<RequestedCode> requestCustomerCode(String phone);

  Future<IssuedSession> verifyCustomerCode({
    required String phone,
    required String code,
  });

  Future<IssuedSession> staffLogin({
    required String phone,
    required String password,
  });

  /// The identity behind the token in [slot].
  Future<AppUser> me(SessionSlot slot);

  Future<AppUser> updateLanguage(SessionSlot slot, AppLanguage language);

  Future<void> changePassword(
    SessionSlot slot, {
    required String currentPassword,
    required String newPassword,
  });

  /// Revokes the token in [slot] on the server. The caller clears the slot
  /// whatever the outcome; a token the server never hears about again is
  /// merely one that expires in 30 days.
  Future<void> logout(SessionSlot slot);
}
