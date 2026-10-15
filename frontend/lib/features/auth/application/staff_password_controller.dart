import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/state/mutation_state.dart';

/// The password of the staff step: finishes the sign-in a Shopper or Courier
/// began with the Telegram code. A refused password keeps the step; a step
/// the server calls expired or invalid is gone from the session, and
/// [stepGone] says so, since the screen is taken away by then.
class StaffPasswordController extends MutationNotifier {
  bool _stepGone = false;

  bool get stepGone => _stepGone;

  Future<bool> submit(String password) => run(() async {
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .completeStaffStep(password);
    } on ApiRefusal catch (refusal) {
      if (refusal.code == 'staff_step_expired' ||
          refusal.code == 'staff_step_invalid') {
        _stepGone = true;
      }
      rethrow;
    }
  });
}

final NotifierProvider<StaffPasswordController, MutationState>
staffPasswordControllerProvider =
    NotifierProvider.autoDispose<StaffPasswordController, MutationState>(
      StaffPasswordController.new,
    );
