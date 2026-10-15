import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/session/session_state.dart';
import '../../../core/state/mutation_state.dart';
import '../domain/app_user.dart';
import '../../profile/application/profile_controllers.dart';
import '../../profile/domain/profile.dart';

/// Saves the name a new Customer gives after the first sign-in. The profile
/// repository does the saving; the session then takes the refreshed user,
/// and only for the account the name was saved for.
///
/// [rename] and [finish] are the two halves of [save]: the screen that shows
/// a welcome between them keeps the session, and so its own place in the
/// router, until the person has read it.
class CustomerNameController extends MutationNotifier {
  AppUser? _renamed;

  /// Saves the name on the profile; the session is untouched until [finish].
  Future<bool> rename(String fullName) => run(() async {
    final SessionState? before = ref.read(sessionControllerProvider).value;
    final AppUser? customer = before is SignedIn ? before.customerUser : null;
    if (customer == null) {
      throw StateError('no customer session');
    }
    final ProfileRepository profiles = ref.read(profileRepositoryProvider);
    final CustomerProfile loaded = await profiles.profile();
    if (loaded.id != customer.id) {
      throw const MalformedResponseFailure();
    }
    final CustomerProfile saved = await profiles.rename(loaded, fullName);
    _renamed = customer.copyWith(fullName: saved.fullName);
  });

  /// Hands the renamed user to the session, which opens the Customer area.
  void finish() {
    final AppUser? renamed = _renamed;
    if (renamed != null) {
      _renamed = null;
      ref.read(sessionControllerProvider.notifier).replaceCustomerUser(renamed);
    }
  }

  Future<bool> save(String fullName) async {
    final bool renamed = await rename(fullName);
    if (renamed) {
      finish();
    }
    return renamed;
  }
}

final NotifierProvider<CustomerNameController, MutationState>
customerNameControllerProvider =
    NotifierProvider.autoDispose<CustomerNameController, MutationState>(
      CustomerNameController.new,
    );
