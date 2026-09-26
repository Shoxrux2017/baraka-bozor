import '../../../core/network/api_call.dart';
import '../../../core/network/paged.dart';
import '../domain/admin_staff.dart';
import '../domain/admin_staff_repository.dart';
import 'admin_staff_api.dart';

class AdminStaffRepositoryImpl implements AdminStaffRepository {
  AdminStaffRepositoryImpl(this._api);

  final AdminStaffApi _api;

  @override
  Future<Paged<StaffMember>> staff(StaffQuery query) =>
      guardApiCall(() => _api.staff(query));

  @override
  Future<IssuedPassword> create(NewStaffMember member) =>
      guardApiCall(() => _api.create(member));

  @override
  Future<StaffMember> rename(StaffMember member, String fullName) =>
      guardApiCall(() => _api.rename(member, fullName));

  @override
  Future<StaffMember> block(String id) => guardApiCall(() => _api.block(id));

  @override
  Future<StaffMember> activate(String id) =>
      guardApiCall(() => _api.activate(id));

  @override
  Future<IssuedPassword> resetPassword(String id) =>
      guardApiCall(() => _api.resetPassword(id));
}
