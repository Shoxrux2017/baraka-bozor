import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/state/account_mutation.dart';
import '../../../core/state/mutation_state.dart';
import '../data/profile_api.dart';
import '../domain/profile.dart';

final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>(
      (Ref ref) => ProfileRepositoryImpl(ref.watch(apiClientProvider)),
    );

/// The Customer's profile while the profile screen is open.
class ProfileController extends AsyncNotifier<CustomerProfile> {
  @override
  Future<CustomerProfile> build() async {
    final String? account = ref.watch(customerAccountProvider);
    if (account == null) {
      return Completer<CustomerProfile>().future;
    }
    final CustomerProfile profile = await ref
        .read(profileRepositoryProvider)
        .profile();
    // The profile of another Customer than the one signed in is malformed.
    if (profile.id != account) {
      throw const MalformedResponseFailure();
    }
    return profile;
  }

  void showSaved(CustomerProfile saved) =>
      state = AsyncData<CustomerProfile>(saved);
}

final AsyncNotifierProvider<ProfileController, CustomerProfile>
profileControllerProvider =
    AsyncNotifierProvider.autoDispose<ProfileController, CustomerProfile>(
      ProfileController.new,
    );

/// Saves the Customer's name: the profile shows the answer, or reloads
/// after a conflict or an uncertain outcome.
class RenameController extends AccountMutation {
  @override
  Provider<String?> get account => customerAccountProvider;

  Future<CustomerProfile?> rename(CustomerProfile profile, String fullName) =>
      perform(
        () => ref.read(profileRepositoryProvider).rename(profile, fullName),
        reload: (CustomerProfile? saved) => saved == null
            ? ref.invalidate(profileControllerProvider)
            : ref.read(profileControllerProvider.notifier).showSaved(saved),
      );
}

final NotifierProvider<RenameController, MutationState>
renameControllerProvider =
    NotifierProvider.autoDispose<RenameController, MutationState>(
      RenameController.new,
    );
