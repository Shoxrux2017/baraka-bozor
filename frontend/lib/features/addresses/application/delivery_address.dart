import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;

import '../../../app/providers.dart';
import '../../../core/session/customer_account.dart';
import '../domain/addresses.dart';
import 'addresses_controllers.dart';

/// The address the Customer last chose to deliver to, remembered on this
/// device for their account (`DL-75`). It holds the id only: the address
/// itself always comes from the current active list.
class DeliveryAddressChoice extends AsyncNotifier<String?> {
  DeliveryAddressChoice(this.account);

  final String account;

  /// Per account, so a second Customer on the same phone never starts from
  /// the first one's choice.
  static String preferenceKey(String account) => 'delivery_address.$account';

  @override
  Future<String?> build() =>
      ref.read(preferenceStoreProvider).read(preferenceKey(account));

  Future<void> choose(String addressId) async {
    state = AsyncData<String?>(addressId);
    await ref
        .read(preferenceStoreProvider)
        .write(preferenceKey(account), addressId);
  }
}

final AsyncNotifierProviderFamily<DeliveryAddressChoice, String?, String>
deliveryAddressChoiceProvider = AsyncNotifierProvider.autoDispose
    .family<DeliveryAddressChoice, String?, String>(DeliveryAddressChoice.new);

/// The signed-in Customer's delivery address: the one they chose while it
/// is still among their active addresses, otherwise the newest of them, or
/// `null` when they have none.
///
/// Loading while there is no Customer and while the list or the choice
/// loads or reloads — a reload may still carry another account's list — so
/// one account's address is never shown to another (`frontend/AGENTS.md`
/// section 5).
final Provider<AsyncValue<Address?>> deliveryAddressProvider =
    Provider.autoDispose<AsyncValue<Address?>>((Ref ref) {
      final String? account = ref.watch(customerAccountProvider);
      if (account == null) {
        return const AsyncLoading<Address?>();
      }
      final AsyncValue<List<Address>> addresses = ref.watch(addressesProvider);
      final AsyncValue<String?> chosen = ref.watch(
        deliveryAddressChoiceProvider(account),
      );
      if (addresses.isLoading || chosen.isLoading) {
        return const AsyncLoading<Address?>();
      }
      if (addresses.hasError) {
        return AsyncError<Address?>(addresses.error!, addresses.stackTrace!);
      }
      final List<Address> list = addresses.requireValue;
      final String? id = chosen.value;
      return AsyncData<Address?>(
        list.where((Address a) => a.id == id).firstOrNull ?? list.firstOrNull,
      );
    });
