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

  /// The verify answer: the customer session, and `staff_step` as an object
  /// or an explicit `null` — a missing member is malformed.
  static VerifiedLogin parseVerifiedLogin(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'verified login');
    final Object? step = json.member('staff_step');
    return VerifiedLogin(
      customer: parseIssuedSession(raw),
      staffStep: step == null ? null : _parseStaffStep(step),
    );
  }

  static StaffStep _parseStaffStep(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'staff step');
    final String token = json.string('token');
    if (token.length != 64) {
      throw const FormatException('a staff step token is 64 characters');
    }
    return StaffStep(token: token, expiresAt: json.instant('expires_at'));
  }

  static IssuedSession parseIssuedSession(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'session');
    return IssuedSession(
      token: json.string('token'),
      user: parse(json.member('user')),
    );
  }
}
