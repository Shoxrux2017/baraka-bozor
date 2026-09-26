import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/state/mutation_state.dart';

/// The staff login of `docs/04-user-flows.md` section 3. On success the
/// session changes and the router moves on to the password change or the
/// role shell.
class StaffLoginController extends MutationNotifier {
  Future<bool> login({required String phone, required String password}) => run(
    () => ref
        .read(sessionControllerProvider.notifier)
        .staffLogin(phone: phone, password: password),
  );
}

final NotifierProvider<StaffLoginController, MutationState>
staffLoginControllerProvider =
    NotifierProvider.autoDispose<StaffLoginController, MutationState>(
      StaffLoginController.new,
    );
