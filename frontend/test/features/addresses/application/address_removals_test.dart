import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/features/addresses/application/address_removals.dart';
import 'package:baraka_bozor/features/addresses/application/addresses_controllers.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_customer_repositories.dart';

/// The signed-in Customer, switchable by the test.
class _Account extends Notifier<String?> {
  @override
  String? build() => 'customer-a';

  void signIn(String? id) => state = id;
}

final NotifierProvider<_Account, String?> _account =
    NotifierProvider<_Account, String?>(_Account.new);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAddressesRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeAddressesRepository(
      rows: <Address>[
        address(id: 'a-3', label: 'Ish'),
        address(id: 'a-2', label: null),
        address(id: 'a-1'),
      ],
    );
    container = ProviderContainer(
      retry: (int retryCount, Object error) => null,
      overrides: [
        customerAccountProvider.overrideWith((Ref ref) => ref.watch(_account)),
        addressesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    container.listen(addressRemovalsProvider, (_, _) {});
    container.listen(shownAddressesProvider, (_, _) {});
  });

  AddressRemovals removals() =>
      container.read(addressRemovalsProvider.notifier);

  AddressRemovalsState state() => container.read(addressRemovalsProvider);

  Future<List<String>> shownIds() async {
    // Let the list settle; it is a future provider.
    for (
      int i = 0;
      i < 20 && container.read(shownAddressesProvider).isLoading;
      i++
    ) {
      await Future<void>.delayed(Duration.zero);
    }
    return container
        .read(shownAddressesProvider)
        .requireValue
        .map((Address a) => a.id)
        .toList();
  }

  Future<AddressRemoval> hold(String id, {VoidCallback? closeBar}) async {
    await shownIds();
    final Address held = repository.rows.firstWhere((Address a) => a.id == id);
    final AddressRemoval removal = AddressRemoval(held);
    removals().hold(removal, closeBar: closeBar ?? () {});
    return removal;
  }

  test('a held address is off the shown list at once', () async {
    expect(await shownIds(), <String>['a-3', 'a-2', 'a-1']);
    await hold('a-2');

    expect(await shownIds(), <String>['a-3', 'a-1']);
    expect(state().hidden, <String>{'a-2'});
    expect(repository.removed, isEmpty);
  });

  test('undo brings it back and sends nothing', () async {
    final AddressRemoval removal = await hold('a-2');

    expect(removals().undo(removal), isTrue);
    expect(await removals().commit(removal), isNull);

    expect(await shownIds(), <String>['a-3', 'a-2', 'a-1']);
    expect(repository.removed, isEmpty);
    expect(state().held, isNull);
  });

  test('the bar\'s end sends one delete and keeps it hidden', () async {
    final AddressRemoval removal = await hold('a-2');
    final Completer<void> hold0 = Completer<void>();
    repository.hold = hold0;

    final Future<ApiFailure?> sending = removals().commit(removal);
    await Future<void>.delayed(Duration.zero);
    expect(state().held, isNull);
    expect(state().hidden, <String>{'a-2'});
    expect(await shownIds(), <String>['a-3', 'a-1']);

    hold0.complete();
    expect(await sending, isNull);

    expect(state().hidden, <String>{'a-2'});
    expect(await shownIds(), <String>['a-3', 'a-1']);
    expect(repository.rows.map((Address a) => a.id), <String>['a-3', 'a-1']);
    expect(repository.removed, <String>['a-2']);
    expect(await removals().commit(removal), isNull);
    expect(repository.removed, <String>['a-2']);
  });

  test('a second hold sends the first at once and ends its bar', () async {
    int firstClosed = 0;
    int secondClosed = 0;
    final AddressRemoval first = await hold(
      'a-2',
      closeBar: () => firstClosed++,
    );
    final AddressRemoval second = await hold(
      'a-1',
      closeBar: () => secondClosed++,
    );
    await removals().flush();

    expect(firstClosed, 1);
    expect(secondClosed, 1);
    expect(repository.removed, <String>['a-2', 'a-1']);
    expect(await removals().commit(first), isNull);
    expect(await removals().commit(second), isNull);
    expect(repository.removed, <String>['a-2', 'a-1']);
    expect(await shownIds(), <String>['a-3']);
  });

  test('undo after the send brings nothing back', () async {
    final AddressRemoval removal = await hold('a-2');
    await removals().commit(removal);

    expect(removals().undo(removal), isFalse);
    expect(state().hidden, <String>{'a-2'});
    expect(await shownIds(), <String>['a-3', 'a-1']);
    expect(repository.removed, <String>['a-2']);
  });

  test('a lost delete brings the address back with why', () async {
    final AddressRemoval removal = await hold('a-2');
    repository.removeFailure = const NetworkFailure();

    final ApiFailure? failure = await removals().commit(removal);

    expect(failure, isA<NetworkFailure>());
    expect(state().hidden, isEmpty);
    expect(state().notRemoved?.id, 'a-2');
    expect(state().notRemoved?.failure, isA<NetworkFailure>());
    expect(await shownIds(), <String>['a-3', 'a-2', 'a-1']);

    await hold('a-1');
    expect(state().notRemoved, isNull);
  });

  test('an address already gone counts as removed', () async {
    final AddressRemoval removal = await hold('a-2');
    repository.removeFailure = const ApiRefusal(
      ApiError(status: 404, code: 'resource_not_found'),
    );

    expect(await removals().commit(removal), isNull);

    expect(state().hidden, <String>{'a-2'});
    expect(state().notRemoved, isNull);
    expect(await shownIds(), <String>['a-3', 'a-1']);
  });

  test('a removal held when the account changes is dropped unsent', () async {
    int closed = 0;
    final AddressRemoval removal = await hold('a-2', closeBar: () => closed++);

    container.read(_account.notifier).signIn('customer-b');
    await Future<void>.delayed(Duration.zero);

    expect(closed, 1);
    expect(await removals().commit(removal), isNull);
    expect(repository.removed, isEmpty);
    expect(state().hidden, isEmpty);
    expect(state().held, isNull);
  });

  test('an answer for the previous account changes nothing', () async {
    final AddressRemoval removal = await hold('a-2');
    repository.hold = Completer<void>();
    repository.removeFailure = const NetworkFailure();
    final Future<ApiFailure?> sending = removals().commit(removal);
    await Future<void>.delayed(Duration.zero);
    expect(repository.removed, <String>['a-2']);

    container.read(_account.notifier).signIn('customer-b');
    await Future<void>.delayed(Duration.zero);
    repository.hold!.complete();

    expect(await sending, isNull);
    expect(state().notRemoved, isNull);
    expect(state().hidden, isEmpty);
  });

  test('hiding the app sends the held removal', () async {
    int closed = 0;
    await hold('a-2', closeBar: () => closed++);

    TestWidgetsFlutterBinding.instance
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await removals().flush();

    expect(repository.removed, <String>['a-2']);
    expect(closed, 1);
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });

  test(
    'a reload keeps its loading flag and the list without the held address',
    () async {
      await hold('a-2');
      await shownIds();
      repository.loadHold = Completer<void>();

      container.invalidate(addressesProvider);
      await Future<void>.delayed(Duration.zero);

      final AsyncValue<List<Address>> shown = container.read(
        shownAddressesProvider,
      );
      expect(shown.isLoading, isTrue);
      expect(shown.value?.map((Address a) => a.id), <String>['a-3', 'a-1']);
      repository.loadHold!.complete();
    },
  );

  test('a delete that may have arrived reloads the list', () async {
    final AddressRemoval removal = await hold('a-2');
    final int before = repository.loads;
    repository.removeFailure = const NetworkFailure();

    await removals().commit(removal);
    await shownIds();

    expect(repository.loads, before + 1);
    expect(state().notRemoved?.id, 'a-2');
  });

  test('a delete that never left reloads nothing', () async {
    final AddressRemoval removal = await hold('a-2');
    final int before = repository.loads;
    repository.removeFailure = const NetworkFailure(mayHaveArrived: false);

    await removals().commit(removal);
    await shownIds();

    expect(repository.loads, before);
    expect(state().notRemoved?.id, 'a-2');
  });

  test('a reloaded list without the address keeps it gone', () async {
    final AddressRemoval removal = await hold('a-2');
    repository.rows = repository.rows
        .where((Address a) => a.id != 'a-2')
        .toList();
    repository.removeFailure = const NetworkFailure();

    await removals().commit(removal);

    expect(await shownIds(), <String>['a-3', 'a-1']);
  });
}
