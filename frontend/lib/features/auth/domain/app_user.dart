import '../../../core/localization/app_language.dart';

/// The six roles of `docs/02-user-roles.md` section 1, with the surface each
/// works on (section 10). The machine value is what the API sends; the label a
/// person sees comes from the localized strings.
enum UserRole {
  customer('customer', Surface.mobile),
  shopper('shopper', Surface.mobile),
  courier('courier', Surface.mobile),
  operator('operator', Surface.web),
  admin('admin', Surface.web),
  manager('manager', Surface.web);

  const UserRole(this.code, this.surface);

  final String code;

  /// Where this role works. A role that opens the other surface sees a screen
  /// naming the right one; the backend does not enforce surfaces.
  final Surface surface;

  bool get isStaff => this != UserRole.customer;

  static UserRole? tryParse(String? code) {
    for (final UserRole role in values) {
      if (role.code == code) {
        return role;
      }
    }
    return null;
  }
}

enum Surface { mobile, web }

enum AccountStatus {
  active('active'),
  blocked('blocked');

  const AccountStatus(this.code);

  final String code;

  static AccountStatus? tryParse(String? code) {
    for (final AccountStatus status in values) {
      if (status.code == code) {
        return status;
      }
    }
    return null;
  }
}

/// The identity object of `docs/09-api-contracts.md` sections 7 and 9.
final class AppUser {
  const AppUser({
    required this.id,
    required this.role,
    required this.phone,
    required this.fullName,
    required this.status,
    required this.mustChangePassword,
    required this.preferredLanguage,
  });

  final String id;
  final UserRole role;
  final String phone;
  final String? fullName;
  final AccountStatus status;
  final bool mustChangePassword;
  final AppLanguage preferredLanguage;

  AppUser copyWith({bool? mustChangePassword, AppLanguage? preferredLanguage}) {
    return AppUser(
      id: id,
      role: role,
      phone: phone,
      fullName: fullName,
      status: status,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    );
  }
}

/// What the client learns after requesting a login code: the channel that
/// carried it and the two timers — never the code.
final class RequestedCode {
  const RequestedCode({
    required this.channel,
    required this.expiresInSeconds,
    required this.resendAvailableInSeconds,
  });

  /// `telegram`, `sms`, `fake` or `test`, per `docs/09` section 6.
  final String channel;
  final int expiresInSeconds;
  final int resendAvailableInSeconds;
}

/// A token freshly issued for a user. The token goes into its slot at once
/// and is never kept anywhere else.
final class IssuedSession {
  const IssuedSession({required this.token, required this.user});

  final String token;
  final AppUser user;
}
