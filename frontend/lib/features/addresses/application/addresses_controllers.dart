import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/state/account_mutation.dart';
import '../../../core/state/mutation_state.dart';
import '../data/address_search_api.dart';
import '../data/addresses_api.dart';
import '../domain/address_search.dart';
import '../domain/addresses.dart';
import 'address_removals.dart';

final Provider<AddressesRepository> addressesRepositoryProvider =
    Provider<AddressesRepository>(
      (Ref ref) => AddressesRepositoryImpl(ref.watch(apiClientProvider)),
    );

final Provider<AddressSearchRepository> addressSearchRepositoryProvider =
    Provider<AddressSearchRepository>(
      (Ref ref) => AddressSearchRepositoryImpl(ref.watch(apiClientProvider)),
    );

/// The delivery zone, previewed on the map; `null` while none is set
/// (`DL-138`).
final FutureProvider<ServiceArea?> serviceAreaProvider =
    FutureProvider.autoDispose<ServiceArea?>(
      (Ref ref) => ref.watch(addressSearchRepositoryProvider).serviceArea(),
    );

/// The Customer's active addresses.
final FutureProvider<List<Address>> addressesProvider =
    FutureProvider.autoDispose<List<Address>>((Ref ref) {
      if (ref.watch(customerAccountProvider) == null) {
        return Completer<List<Address>>().future;
      }
      return ref.watch(addressesRepositoryProvider).addresses();
    });

/// The addresses the Customer still sees: [addressesProvider] without the
/// ones being removed, so the list, the delivery address and checkout agree
/// until the server has answered (`DL-137`). Its loading and error flags and
/// its previous value are those of the list itself.
final Provider<AsyncValue<List<Address>>> shownAddressesProvider =
    Provider.autoDispose<AsyncValue<List<Address>>>((Ref ref) {
      final AsyncValue<List<Address>> addresses = ref.watch(addressesProvider);
      final Set<String> hidden = ref.watch(
        addressRemovalsProvider.select(
          (AddressRemovalsState removals) => removals.hidden,
        ),
      );
      if (hidden.isEmpty) {
        return addresses;
      }
      final List<Address>? list = addresses.value;
      if (list == null) {
        return addresses;
      }
      // The filtered value keeps the list's loading and error flags, so a
      // reload that fails or is under way still shows the cards.
      final AsyncValue<List<Address>> filtered = AsyncData<List<Address>>(
        <Address>[
          for (final Address a in list)
            if (!hidden.contains(a.id)) a,
        ],
      );
      return _withFlagsOf(addresses, filtered);
    });

// riverpod keeps the only way to build a value that carries a loading or error
// flag next to its data in an internal member.
AsyncValue<List<Address>> _withFlagsOf(
  AsyncValue<List<Address>> source,
  AsyncValue<List<Address>> data,
) {
  AsyncValue<List<Address>> shown = data;
  if (source.hasError) {
    final AsyncValue<List<Address>> failed = AsyncError<List<Address>>(
      source.error!,
      source.stackTrace!,
    );
    // ignore: invalid_use_of_internal_member
    shown = failed.copyWithPrevious(shown);
  }
  if (source.isLoading) {
    const AsyncValue<List<Address>> loading = AsyncLoading<List<Address>>();
    // ignore: invalid_use_of_internal_member
    shown = loading.copyWithPrevious(shown);
  }
  return shown;
}

/// A change to the Customer's addresses, from one of their surfaces; it
/// reloads the list.
abstract class AddressMutation extends AccountMutation {
  @override
  Provider<String?> get account => customerAccountProvider;

  AddressesRepository get addresses => ref.read(addressesRepositoryProvider);

  void reloadList(Object? _) => ref.invalidate(addressesProvider);
}

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
