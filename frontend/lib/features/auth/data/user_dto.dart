import '../../../core/localization/app_language.dart';
import '../domain/app_user.dart';

/// Strict parsing of the identity object — `frontend/AGENTS.md` section 8: a
/// malformed success payload is a failure, never a half-filled model.
abstract final class UserDto {
  static AppUser parse(Object? raw) {
    final Map<String, dynamic> json = _object(raw, 'user');

    final UserRole? role = UserRole.tryParse(_string(json, 'role'));
    if (role == null) {
      throw FormatException('user.role is not a known role: ${json['role']}');
    }

    final AccountStatus? status = AccountStatus.tryParse(
      _string(json, 'status'),
    );
    if (status == null) {
      throw FormatException(
        'user.status is not a known status: ${json['status']}',
      );
    }

    final AppLanguage? language = AppLanguage.tryParse(
      _string(json, 'preferred_language'),
    );
    if (language == null) {
      throw FormatException(
        'user.preferred_language is not a known language: '
        '${json['preferred_language']}',
      );
    }

    return AppUser(
      id: _string(json, 'id'),
      role: role,
      phone: _string(json, 'phone'),
      fullName: _nullableString(json, 'full_name'),
      status: status,
      mustChangePassword: _bool(json, 'must_change_password'),
      preferredLanguage: language,
    );
  }

  static RequestedCode parseRequestedCode(Object? raw) {
    final Map<String, dynamic> json = _object(raw, 'requested code');
    return RequestedCode(
      channel: _string(json, 'channel'),
      expiresInSeconds: _int(json, 'expires_in_seconds'),
      resendAvailableInSeconds: _int(json, 'resend_available_in_seconds'),
    );
  }

  static IssuedSession parseIssuedSession(Object? raw) {
    final Map<String, dynamic> json = _object(raw, 'session');
    return IssuedSession(
      token: _string(json, 'token'),
      user: parse(json['user']),
    );
  }

  /// The `data` member of a success envelope, `docs/09` section 2.
  static Object? unwrap(Object? body) {
    final Map<String, dynamic> json = _object(body, 'envelope');
    if (!json.containsKey('data')) {
      throw const FormatException('envelope has no data member');
    }
    return json['data'];
  }

  static Map<String, dynamic> _object(Object? raw, String what) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    throw FormatException('$what is not an object: ${raw.runtimeType}');
  }

  static String _string(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw FormatException('$key is missing or not a non-empty string');
  }

  static String? _nullableString(Map<String, dynamic> json, String key) {
    if (!json.containsKey(key)) {
      throw FormatException('$key is missing');
    }
    final Object? value = json[key];
    if (value == null || value is String) {
      return value as String?;
    }
    throw FormatException('$key is not a string or null');
  }

  static bool _bool(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    if (value is bool) {
      return value;
    }
    throw FormatException('$key is missing or not a boolean');
  }

  static int _int(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    if (value is int) {
      return value;
    }
    throw FormatException('$key is missing or not an integer');
  }
}
