import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/paged.dart';
import '../../../core/state/mutation_state.dart';
import '../../auth/domain/app_user.dart';
import '../data/admin_staff_api.dart';
import '../data/admin_staff_repository_impl.dart';
import '../domain/admin_staff.dart';
import '../domain/admin_staff_repository.dart';
import 'admin_mutation.dart';
import 'admin_providers.dart';

final Provider<AdminStaffRepository> adminStaffRepositoryProvider =
    Provider<AdminStaffRepository>(
      (Ref ref) =>
          AdminStaffRepositoryImpl(AdminStaffApi(ref.watch(apiClientProvider))),
    );

/// What the staff list shows: the page and the role and status filters.
/// Like the catalog lists' (`DL-28` (1)), it outlives the screen and starts
/// over for another account.
class StaffQueryController extends Notifier<StaffQuery> {
  @override
  StaffQuery build() {
    ref.watch(staffAccountProvider);
    return const StaffQuery();
  }

  void filterByRole(UserRole? role) =>
      state = StaffQuery(role: role, status: state.status);

  void filterByStatus(AccountStatus? status) =>
      state = StaffQuery(role: state.role, status: status);

  void goToPage(int page) =>
      state = StaffQuery(page: page, role: state.role, status: state.status);
}

final NotifierProvider<StaffQueryController, StaffQuery> staffQueryProvider =
    NotifierProvider<StaffQueryController, StaffQuery>(
      StaffQueryController.new,
    );

/// The staff page for the current query.
final FutureProvider<Paged<StaffMember>> staffPageProvider =
    FutureProvider.autoDispose<Paged<StaffMember>>((Ref ref) {
      if (ref.watch(staffAccountProvider) == null) {
        return Completer<Paged<StaffMember>>().future;
      }
      return ref
          .watch(adminStaffRepositoryProvider)
          .staff(ref.watch(staffQueryProvider));
    });

/// A change to a staff account, from one of the staff surfaces. A temporary
/// password a create or a reset answers is handed to the dialog that asked
/// for it and kept by nothing else: the controller's state is only idle,
/// busy or failed (`DL-29` (1)).
abstract class StaffMutation extends AdminMutation {
  AdminStaffRepository get staff => ref.read(adminStaffRepositoryProvider);

  void reloadList(Object? _) => ref.invalidate(staffPageProvider);
}

/// Block and activate from the staff list.
class StaffListActions extends StaffMutation {
  Future<void> block(String id) =>
      perform<StaffMember>(() => staff.block(id), reload: reloadList);

  Future<void> activate(String id) =>
      perform<StaffMember>(() => staff.activate(id), reload: reloadList);
}

final NotifierProvider<StaffListActions, MutationState>
staffListActionsProvider =
    NotifierProvider.autoDispose<StaffListActions, MutationState>(
      StaffListActions.new,
    );

/// The new-staff dialog's create.
class NewStaffController extends StaffMutation {
  Future<IssuedPassword?> create(NewStaffMember member) =>
      perform(() => staff.create(member), reload: reloadList);
}

final NotifierProvider<NewStaffController, MutationState>
newStaffControllerProvider =
    NotifierProvider.autoDispose<NewStaffController, MutationState>(
      NewStaffController.new,
    );

/// The rename dialog's save.
class RenameStaffController extends StaffMutation {
  Future<StaffMember?> rename(StaffMember member, String fullName) =>
      perform(() => staff.rename(member, fullName), reload: reloadList);
}

final NotifierProvider<RenameStaffController, MutationState>
renameStaffControllerProvider =
    NotifierProvider.autoDispose<RenameStaffController, MutationState>(
      RenameStaffController.new,
    );

/// The reset dialog's password reset.
class ResetPasswordController extends StaffMutation {
  Future<IssuedPassword?> reset(String id) =>
      perform(() => staff.resetPassword(id), reload: reloadList);
}

final NotifierProvider<ResetPasswordController, MutationState>
resetPasswordControllerProvider =
    NotifierProvider.autoDispose<ResetPasswordController, MutationState>(
      ResetPasswordController.new,
    );
