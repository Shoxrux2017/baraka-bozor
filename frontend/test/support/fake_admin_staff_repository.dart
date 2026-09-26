import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/paged.dart';
import 'package:baraka_bozor/features/admin/domain/admin_staff.dart';
import 'package:baraka_bozor/features/admin/domain/admin_staff_repository.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';

StaffMember staffMember({
  String id = 's-1',
  UserRole role = UserRole.shopper,
  String phone = '+998901112233',
  String? fullName = 'Dilnoza Karimova',
  AccountStatus status = AccountStatus.active,
  bool mustChangePassword = false,
  DateTime? lastLoginAt,
}) => StaffMember(
  id: id,
  role: role,
  phone: phone,
  fullName: fullName,
  status: status,
  mustChangePassword: mustChangePassword,
  lastLoginAt: lastLoginAt,
  blockedAt: status == AccountStatus.blocked ? DateTime.utc(2026, 9, 26) : null,
  createdAt: DateTime.utc(2026, 9, 26, 5),
  updatedAt: DateTime.utc(2026, 9, 26, 5),
);

/// Staff accounts in memory, filtered and paginated like the API. Each
/// issued password is new, so a test can tell them apart. A change is
/// recorded when it is asked for and answered once [hold], when set,
/// completes.
class FakeAdminStaffRepository implements AdminStaffRepository {
  FakeAdminStaffRepository({List<StaffMember>? members})
    : members = members ?? <StaffMember>[staffMember()];

  List<StaffMember> members;
  final List<StaffQuery> queries = <StaffQuery>[];
  final List<NewStaffMember> created = <NewStaffMember>[];
  final List<String> actions = <String>[];
  final List<String> issued = <String>[];

  ApiFailure? changeFailure;

  /// While set, every change waits for it before it answers.
  Completer<void>? hold;

  int _next = 0;

  @override
  Future<Paged<StaffMember>> staff(StaffQuery query) async {
    queries.add(query);
    final List<StaffMember> matching = members
        .where(
          (StaffMember m) =>
              (query.role == null || m.role == query.role) &&
              (query.status == null || m.status == query.status),
        )
        .toList();
    return Paged<StaffMember>(
      items: matching,
      page: 1,
      perPage: 20,
      total: matching.length,
      lastPage: 1,
    );
  }

  @override
  Future<IssuedPassword> create(NewStaffMember member) async {
    created.add(member);
    await _answer();
    final StaffMember added = staffMember(
      id: 's-new-${_next++}',
      role: member.role,
      phone: member.phone,
      fullName: member.fullName,
      mustChangePassword: true,
    );
    members = <StaffMember>[added, ...members];
    return _issue(added);
  }

  @override
  Future<IssuedPassword> resetPassword(String id) async {
    actions.add('reset $id');
    await _answer();
    return _issue(
      _replace(
        id,
        (StaffMember m) => staffMember(
          id: m.id,
          role: m.role,
          phone: m.phone,
          fullName: m.fullName,
          status: m.status,
          mustChangePassword: true,
        ),
      ),
    );
  }

  @override
  Future<StaffMember> rename(StaffMember member, String fullName) async {
    actions.add('rename ${member.id} $fullName');
    await _answer();
    return _replace(
      member.id,
      (StaffMember m) => staffMember(
        id: m.id,
        role: m.role,
        phone: m.phone,
        fullName: fullName,
        status: m.status,
      ),
    );
  }

  @override
  Future<StaffMember> block(String id) async {
    actions.add('block $id');
    await _answer();
    return _replace(
      id,
      (StaffMember m) => staffMember(
        id: m.id,
        role: m.role,
        phone: m.phone,
        fullName: m.fullName,
        status: AccountStatus.blocked,
      ),
    );
  }

  @override
  Future<StaffMember> activate(String id) async {
    actions.add('activate $id');
    await _answer();
    return _replace(
      id,
      (StaffMember m) => staffMember(
        id: m.id,
        role: m.role,
        phone: m.phone,
        fullName: m.fullName,
      ),
    );
  }

  IssuedPassword _issue(StaffMember member) {
    final String password = 'Tmp${_next++}pQx9KmT3';
    issued.add(password);
    return IssuedPassword(staff: member, password: password);
  }

  StaffMember _replace(String id, StaffMember Function(StaffMember) change) {
    final StaffMember changed = change(
      members.firstWhere((StaffMember m) => m.id == id),
    );
    members = <StaffMember>[
      for (final StaffMember m in members) m.id == id ? changed : m,
    ];
    return changed;
  }

  Future<void> _answer() async {
    await hold?.future;
    final ApiFailure? failure = changeFailure;
    if (failure != null) {
      changeFailure = null;
      throw failure;
    }
  }
}
