import '../../auth/domain/app_user.dart';

/// A staff account as the Admin manages it (`docs/09-api-contracts.md`
/// section 43). The password is never part of it.
final class StaffMember {
  const StaffMember({
    required this.id,
    required this.role,
    required this.phone,
    required this.fullName,
    required this.status,
    required this.mustChangePassword,
    required this.lastLoginAt,
    required this.blockedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final UserRole role;
  final String phone;
  final String? fullName;
  final AccountStatus status;
  final bool mustChangePassword;
  final DateTime? lastLoginAt;
  final DateTime? blockedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// A new staff account as its form submits it.
final class NewStaffMember {
  const NewStaffMember({
    required this.fullName,
    required this.phone,
    required this.role,
  });

  final String fullName;

  /// E.164, `+998` and nine digits.
  final String phone;
  final UserRole role;
}

/// What the Admin asks of the staff list.
final class StaffQuery {
  const StaffQuery({this.page = 1, this.role, this.status});

  final int page;
  final UserRole? role;
  final AccountStatus? status;

  @override
  bool operator ==(Object other) =>
      other is StaffQuery &&
      other.page == page &&
      other.role == role &&
      other.status == status;

  @override
  int get hashCode => Object.hash(page, role, status);
}

/// A staff account with the temporary password just set on it. It exists
/// only between the answer and the dialog that shows the password once; no
/// provider keeps it.
final class IssuedPassword {
  const IssuedPassword({required this.staff, required this.password});

  final StaffMember staff;
  final String password;
}
