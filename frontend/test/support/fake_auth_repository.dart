import 'dart:async';

import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/auth/domain/auth_repository.dart';

AppUser user({
  String id = 'u-1',
  UserRole role = UserRole.customer,
  String phone = '+998901234567',
  String? fullName,
  bool mustChangePassword = false,
  AppLanguage language = AppLanguage.uz,
}) {
  return AppUser(
    id: id,
    role: role,
    phone: phone,
    fullName: fullName,
    status: AccountStatus.active,
    mustChangePassword: mustChangePassword,
    preferredLanguage: language,
  );
}

ApiRefusal refusal(int status, String code) =>
    ApiRefusal(ApiError(status: status, code: code));

/// An [AuthRepository] whose every answer a test sets up front and whose
/// every call a test can read back.
class FakeAuthRepository implements AuthRepository {
  /// What `me` answers per slot: an [AppUser], or an [ApiFailure] to throw.
  final Map<SessionSlot, Object> identities = <SessionSlot, Object>{};

  IssuedSession? staffLoginResult;
  ApiFailure? staffLoginFailure;
  IssuedSession? verifyResult;
  ApiFailure? verifyFailure;
  RequestedCode requestResult = const RequestedCode(
    channel: 'fake',
    expiresInSeconds: 300,
    resendAvailableInSeconds: 60,
  );
  ApiFailure? changePasswordFailure;
  ApiFailure? logoutFailure;

  /// What `updateLanguage` throws for a slot, when the test wants the server
  /// to fail for that session.
  final Map<SessionSlot, ApiFailure> updateLanguageFailures =
      <SessionSlot, ApiFailure>{};

  /// While set and not completed, `updateLanguage` and `changePassword` wait
  /// for it before answering, so a test can change the session while the
  /// call is in flight.
  Completer<void>? holdAnswers;

  final List<String> calls = <String>[];
  final List<(SessionSlot, AppLanguage)> reportedLanguages =
      <(SessionSlot, AppLanguage)>[];

  @override
  Future<RequestedCode> requestCustomerCode(String phone) async {
    calls.add('request:$phone');
    return requestResult;
  }

  @override
  Future<IssuedSession> verifyCustomerCode({
    required String phone,
    required String code,
  }) async {
    calls.add('verify:$phone:$code');
    if (verifyFailure != null) {
      throw verifyFailure!;
    }
    return verifyResult!;
  }

  @override
  Future<IssuedSession> staffLogin({
    required String phone,
    required String password,
  }) async {
    calls.add('login:$phone');
    if (staffLoginFailure != null) {
      throw staffLoginFailure!;
    }
    return staffLoginResult!;
  }

  @override
  Future<AppUser> me(SessionSlot slot) async {
    calls.add('me:${slot.name}');
    final Object? answer = identities[slot];
    if (answer is AppUser) {
      return answer;
    }
    if (answer is ApiFailure) {
      throw answer;
    }
    throw StateError('no identity configured for ${slot.name}');
  }

  @override
  Future<AppUser> updateLanguage(SessionSlot slot, AppLanguage language) async {
    calls.add('language:${slot.name}:${language.code}');
    await _held();
    final ApiFailure? failure = updateLanguageFailures[slot];
    if (failure != null) {
      throw failure;
    }
    reportedLanguages.add((slot, language));
    final Object? current = identities[slot];
    return (current is AppUser ? current : user()).copyWith(
      preferredLanguage: language,
    );
  }

  @override
  Future<void> changePassword(
    SessionSlot slot, {
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    calls.add('change-password:${slot.name}');
    await _held();
    if (changePasswordFailure != null) {
      throw changePasswordFailure!;
    }
  }

  @override
  Future<void> logout(SessionSlot slot) async {
    calls.add('logout:${slot.name}');
    if (logoutFailure != null) {
      throw logoutFailure!;
    }
  }

  Future<void> _held() async {
    final Completer<void>? hold = holdAnswers;
    if (hold != null) {
      await hold.future;
    }
  }
}
