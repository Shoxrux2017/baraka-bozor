import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/network/paged.dart';
import '../../../core/storage/token_store.dart';
import '../../auth/domain/app_user.dart';
import '../domain/admin_staff.dart';

/// The data source for `docs/09-api-contracts.md` section 43, on the staff
/// session, with its strict parsing.
class AdminStaffApi {
  AdminStaffApi(this._dio);

  final Dio _dio;

  static final Options _staff = RequestSlot.of(SessionSlot.staff);

  Future<Paged<StaffMember>> staff(StaffQuery query) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/admin/staff',
      queryParameters: <String, Object>{
        'page': query.page,
        if (query.role != null) 'role': query.role!.code,
        if (query.status != null) 'status': query.status!.code,
      },
      options: _staff,
    );
    return Paged.parse(response.data, parseMember);
  }

  Future<IssuedPassword> create(NewStaffMember member) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/admin/staff',
      data: <String, String>{
        'full_name': member.fullName,
        'phone': member.phone,
        'role': member.role.code,
      },
      options: _staff,
    );
    return parseIssued(ApiEnvelope.unwrap(response.data));
  }

  /// Sends the new name; an unchanged one is not sent, and the account is
  /// answered as it is (`DL-28` (9)).
  Future<StaffMember> rename(StaffMember member, String fullName) async {
    if (member.fullName == fullName) {
      return member;
    }
    final Response<dynamic> response = await _dio.patch<dynamic>(
      '/admin/staff/${Uri.encodeComponent(member.id)}',
      data: <String, String>{'full_name': fullName},
      options: _staff,
    );
    return parseMember(ApiEnvelope.unwrap(response.data));
  }

  Future<StaffMember> block(String id) => _action(id, 'block');

  Future<StaffMember> activate(String id) => _action(id, 'activate');

  Future<IssuedPassword> resetPassword(String id) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/admin/staff/${Uri.encodeComponent(id)}/reset-password',
      options: _staff,
    );
    return parseIssued(ApiEnvelope.unwrap(response.data));
  }

  Future<StaffMember> _action(String id, String action) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/admin/staff/${Uri.encodeComponent(id)}/$action',
      options: _staff,
    );
    return parseMember(ApiEnvelope.unwrap(response.data));
  }

  static final RegExp _phone = RegExp(r'^\+998\d{9}$');

  /// A staff account, held to its contract: a staff role, never
  /// `customer`; the phone as `+998` and nine digits; and a blocked account
  /// has the time it was blocked, as the database requires.
  static StaffMember parseMember(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'staff member');
    final UserRole role = json.choice('role', UserRole.tryParse);
    if (!role.isStaff) {
      throw const FormatException('a staff member cannot be a customer');
    }
    final String phone = json.string('phone');
    if (!_phone.hasMatch(phone)) {
      throw const FormatException('a staff phone is +998 and nine digits');
    }

    final StaffMember member = StaffMember(
      id: json.uuid('id'),
      role: role,
      phone: phone,
      fullName: json.nullableString('full_name'),
      status: json.choice('status', AccountStatus.tryParse),
      mustChangePassword: json.boolean('must_change_password'),
      lastLoginAt: json.nullableInstant('last_login_at'),
      blockedAt: json.nullableInstant('blocked_at'),
      createdAt: json.instant('created_at'),
      updatedAt: json.instant('updated_at'),
    );
    if (member.status == AccountStatus.blocked && member.blockedAt == null) {
      throw const FormatException('a blocked account has no blocked_at');
    }
    return member;
  }

  /// `{"user":{...},"temporary_password":"..."}`, the answer of create and
  /// reset.
  static IssuedPassword parseIssued(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'issued password');
    return IssuedPassword(
      staff: parseMember(json.member('user')),
      password: json.string('temporary_password'),
    );
  }
}
