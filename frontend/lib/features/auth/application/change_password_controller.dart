import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/state/mutation_state.dart';

/// The first-login password change of `docs/04-user-flows.md` section 3.
/// The confirmation is sent as the person typed it; the server compares.
class ChangePasswordController extends MutationNotifier {
  Future<bool> submit({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) => run(
    () => ref
        .read(sessionControllerProvider.notifier)
        .changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
          newPasswordConfirmation: newPasswordConfirmation,
        ),
  );
}

final NotifierProvider<ChangePasswordController, MutationState>
changePasswordControllerProvider =
    NotifierProvider.autoDispose<ChangePasswordController, MutationState>(
      ChangePasswordController.new,
    );
