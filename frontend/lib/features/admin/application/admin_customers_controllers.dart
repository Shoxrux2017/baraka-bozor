import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/session/staff_account.dart';
import '../../../core/state/mutation_state.dart';
import '../data/admin_customers_api.dart';
import '../domain/admin_customers.dart';
import 'admin_mutation.dart';

final Provider<AdminCustomersApi> adminCustomersApiProvider =
    Provider<AdminCustomersApi>(
      (Ref ref) => AdminCustomersApi(ref.watch(apiClientProvider)),
    );

/// The accounts the Admin found by phone: `null` until the first search.
/// A search that is overtaken by a newer one, or that outlives the staff
/// account, is dropped.
class CustomerSearchController
    extends Notifier<AsyncValue<List<AdminCustomer>>?> {
  int _generation = 0;
  String? _phone;

  @override
  AsyncValue<List<AdminCustomer>>? build() {
    ref.watch(staffAccountProvider);
    _phone = null;
    return null;
  }

  Future<void> find(String phone) async {
    final String? account = ref.read(staffAccountProvider);
    final int generation = ++_generation;
    _phone = phone;
    state = const AsyncLoading<List<AdminCustomer>>();

    final AsyncValue<List<AdminCustomer>> answer = await AsyncValue.guard(
      () => ref.read(adminCustomersApiProvider).find(phone),
    );
    if (!ref.mounted ||
        generation != _generation ||
        ref.read(staffAccountProvider) != account) {
      return;
    }
    state = answer;
  }

  /// Asks the server again for the last phone, once what is shown may be
  /// out of date.
  Future<void> refresh() async {
    final String? phone = _phone;
    if (phone != null) {
      await find(phone);
    }
  }

  /// Takes an erased account off the list.
  void remove(String id) {
    final List<AdminCustomer>? current = state?.value;
    if (current == null) {
      return;
    }
    state = AsyncData<List<AdminCustomer>>(<AdminCustomer>[
      for (final AdminCustomer customer in current)
        if (customer.id != id) customer,
    ]);
  }
}

final NotifierProvider<
  CustomerSearchController,
  AsyncValue<List<AdminCustomer>>?
>
customerSearchProvider =
    NotifierProvider.autoDispose<
      CustomerSearchController,
      AsyncValue<List<AdminCustomer>>?
    >(CustomerSearchController.new);

/// Erases a Customer account. A refusal or an uncertain outcome asks the
/// server again, because the card on screen may no longer be true.
class EraseCustomerController extends AdminMutation {
  /// `true` when the server erased the account.
  Future<bool> erase(String id) async {
    final bool? done = await perform<bool>(
      () async {
        await ref.read(adminCustomersApiProvider).erase(id);
        return true;
      },
      reload: (bool? erased) {
        final CustomerSearchController search = ref.read(
          customerSearchProvider.notifier,
        );
        if (erased ?? false) {
          search.remove(id);
        } else {
          search.refresh();
        }
      },
    );
    return done ?? false;
  }
}

final NotifierProvider<EraseCustomerController, MutationState>
eraseCustomerControllerProvider =
    NotifierProvider.autoDispose<EraseCustomerController, MutationState>(
      EraseCustomerController.new,
    );
