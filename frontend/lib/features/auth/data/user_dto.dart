import '../../../core/localization/app_language.dart';
import '../../../core/network/json_fields.dart';
import '../domain/app_user.dart';

/// Strict parsing of the identity object — `frontend/AGENTS.md` section 8: a
/// malformed success payload is a failure, never a half-filled model. The
/// readers are the shared `JsonFields`: keys the contract names are required,
/// others are ignored.
abstract final class UserDto {
  static AppUser parse(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'user');

    return AppUser(
      id: json.string('id'),
      role: json.choice('role', UserRole.tryParse),
      phone: json.string('phone'),
      fullName: json.nullableString('full_name'),
      status: json.choice('status', AccountStatus.tryParse),
      mustChangePassword: json.boolean('must_change_password'),
      preferredLanguage: json.choice(
        'preferred_language',
        AppLanguage.tryParse,
      ),
    );
  }

  static RequestedCode parseRequestedCode(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'requested code');
    return RequestedCode(
      channel: json.string('channel'),
      expiresInSeconds: json.integer('expires_in_seconds'),
      resendAvailableInSeconds: json.integer('resend_available_in_seconds'),
    );
  }

  static IssuedSession parseIssuedSession(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'session');
    return IssuedSession(
      token: json.string('token'),
      user: parse(json.member('user')),
    );
  }
}
