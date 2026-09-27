import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/state/account_mutation.dart';
import '../../../core/state/mutation_state.dart';
import '../data/addresses_api.dart';
import '../domain/addresses.dart';

final Provider<AddressesRepository> addressesRepositoryProvider =
    Provider<AddressesRepository>(
      (Ref ref) => AddressesRepositoryImpl(ref.watch(apiClientProvider)),
    );

/// The Customer's active addresses.
final FutureProvider<List<Address>> addressesProvider =
    FutureProvider.autoDispose<List<Address>>((Ref ref) {
      if (ref.watch(customerAccountProvider) == null) {
        return Completer<List<Address>>().future;
      }
      return ref.watch(addressesRepositoryProvider).addresses();
    });

/// A change to the Customer's addresses, from one of their surfaces; it
/// reloads the list.
abstract class AddressMutation extends AccountMutation {
  @override
  Provider<String?> get account => customerAccountProvider;

  AddressesRepository get addresses => ref.read(addressesRepositoryProvider);

  void reloadList(Object? _) => ref.invalidate(addressesProvider);
}

/// Removal from the address list.
class AddressListActions extends AddressMutation {
  Future<void> remove(String id) =>
      perform<void>(() => addresses.remove(id), reload: reloadList);
}

final NotifierProvider<AddressListActions, MutationState>
addressListActionsProvider =
    NotifierProvider.autoDispose<AddressListActions, MutationState>(
      AddressListActions.new,
    );

/// The address form's save.
class AddressFormController extends AddressMutation {
  /// Creates an address, or saves what [draft] changed from [address].
  Future<Address?> save(Address? address, AddressDraft draft) => perform(
    () => address == null
        ? addresses.create(draft)
        : addresses.update(address, draft),
    reload: reloadList,
  );
}

final NotifierProvider<AddressFormController, MutationState>
addressFormControllerProvider =
    NotifierProvider.autoDispose<AddressFormController, MutationState>(
      AddressFormController.new,
    );
