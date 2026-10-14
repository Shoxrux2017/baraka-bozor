import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/features/addresses/application/addresses_controllers.dart';
import 'package:baraka_bozor/features/addresses/application/delivery_address.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_customer_repositories.dart';
import '../../../support/in_memory_stores.dart';

/// The signed-in Customer account, switchable in a test.
class _Account extends Notifier<String?> {
  @override
  String? build() => 'c';

  void set(String? account) => state = account;
}

final NotifierProvider<_Account, String?> _account =
    NotifierProvider<_Account, String?>(_Account.new);

void main() {
  late InMemoryPreferenceStore store;
  late FakeAddressesRepository addresses;

  setUp(() {
    store = InMemoryPreferenceStore();
    addresses = FakeAddressesRepository(
      rows: <Address>[
        address(id: 'a-new', street: 'Navoiy', house: '5'),
        address(id: 'a-old', label: null),
      ],
    );
  });

  ProviderContainer container() {
    final ProviderContainer c = ProviderContainer(
      retry: (int retryCount, Object error) => null,
      overrides: [
        preferenceStoreProvider.overrideWithValue(store),
        addressesRepositoryProvider.overrideWithValue(addresses),
        customerAccountProvider.overrideWith((Ref ref) => ref.watch(_account)),
      ],
    );
    addTearDown(c.dispose);
    c.listen(deliveryAddressProvider, (_, _) {});
    return c;
  }

  Future<AsyncValue<Address?>> settled(ProviderContainer c) async {
    for (int i = 0; i < 20 && c.read(deliveryAddressProvider).isLoading; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return c.read(deliveryAddressProvider);
  }

  test(
    'with no choice the newest active address is the delivery address',
    () async {
      expect((await settled(container())).value?.id, 'a-new');
    },
  );

  test('a choice is remembered on the device for that account', () async {
    final ProviderContainer first = container();
    await settled(first);
    await first
        .read(deliveryAddressChoiceProvider('c').notifier)
        .choose('a-old');
    expect((await settled(first)).value?.id, 'a-old');
    expect(store.values[DeliveryAddressChoice.preferenceKey('c')], 'a-old');

    // A later launch reads it back.
    expect((await settled(container())).value?.id, 'a-old');
  });

  test('a chosen address no longer active falls back to the newest', () async {
    store.values[DeliveryAddressChoice.preferenceKey('c')] = 'a-removed';
    expect((await settled(container())).value?.id, 'a-new');
  });

  test('no addresses is no delivery address', () async {
    addresses.rows = <Address>[];
    final AsyncValue<Address?> value = await settled(container());
    expect(value.hasValue, isTrue);
    expect(value.value, isNull);
  });

  test('another account never starts from the first one\'s choice', () async {
    final ProviderContainer c = container();
    await settled(c);
    await c.read(deliveryAddressChoiceProvider('c').notifier).choose('a-old');
    await settled(c);

    c.read(_account.notifier).set('d');
    // Until the list and d's choice are read again, nothing is shown.
    expect(c.read(deliveryAddressProvider).isLoading, isTrue);
    expect((await settled(c)).value?.id, 'a-new');
  });

  test('without a Customer the delivery address stays loading', () async {
    final ProviderContainer c = container();
    c.read(_account.notifier).set(null);
    expect(c.read(deliveryAddressProvider).isLoading, isTrue);
  });

  test('a list that fails to load is an error, not an address', () async {
    addresses.loadFailure = const UnexpectedFailure();
    final AsyncValue<Address?> value = await settled(container());
    expect(value.hasError, isTrue);
    expect(value.hasValue, isFalse);
  });
}
