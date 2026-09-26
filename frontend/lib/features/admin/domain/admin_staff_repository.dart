import '../../../core/network/paged.dart';
import 'admin_staff.dart';

/// The staff operations of the panel (`docs/09-api-contracts.md`
/// section 43), on the staff session. Every method throws an `ApiFailure`.
abstract interface class AdminStaffRepository {
  Future<Paged<StaffMember>> staff(StaffQuery query);

  Future<IssuedPassword> create(NewStaffMember member);

  /// Renames [member]; with the name unchanged nothing is sent.
  Future<StaffMember> rename(StaffMember member, String fullName);

  Future<StaffMember> block(String id);

  Future<StaffMember> activate(String id);

  Future<IssuedPassword> resetPassword(String id);
}
