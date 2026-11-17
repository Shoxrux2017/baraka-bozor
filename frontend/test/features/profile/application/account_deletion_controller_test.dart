import 'dart:async';

import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/addresses/application/delivery_address.dart';
import 'package:baraka_bozor/features/catalog/application/recent_searches.dart';
import 'package:baraka_bozor/features/profile/application/account_deletion_controller.dart';
import 'package:baraka_bozor/features/profile/application/profile_controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_account_deletion_repository.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/in_memory_stores.dart';

void main() {
  late FakeAccountDeletionRepository repository;
  late ProviderContainer container;

  AccountDeletionState state() =>
      container.read(accountDeletionControllerProvider);
  AccountDeletionController controller() =>
      container.read(accountDeletionControllerProvider.notifier);

  setUp(() {
    repository = FakeAccountDeletionRepository();
    container = ProviderContainer(
      overrides: [
        accountDeletionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  testWidgets('a sent code is kept with its resend wait', (tester) async {
    expect(await controller().requestCode(), isTrue);

    expect(state().requested?.channel, 'telegram');
    expect(state().resendInSeconds, 60);
    expect(state().canResend, isFalse);

    await tester.pump(const Duration(seconds: 60));

    expect(state().resendInSeconds, 0);
    expect(state().canResend, isTrue);
  });

  test('a 409 at the request names the unfinished order', () async {
    repository.requestFailures.add(unfinishedRefusal());

    expect(await controller().requestCode(), isFalse);

    expect(state().unfinished?.number, 1021);
    expect(state().requested, isNull);
  });

  test('another failure at the request is kept', () async {
    repository.requestFailures.add(const NetworkFailure());

    expect(await controller().requestCode(), isFalse);

    expect(state().failure, isA<NetworkFailure>());
    expect(state().unfinished, isNull);
  });

  test('a wrong code counts a miss with the tries left', () async {
    await controller().requestCode();
    repository.deleteFailures.add(
      const ApiRefusal(
        ApiError(
          status: 422,
          code: 'code_invalid',
          details: <String, Object?>{'attempts_left': 2},
        ),
      ),
    );

    expect(await controller().delete('111111'), DeletionOutcome.refused);

    expect(state().wrongCode, isTrue);
    expect(state().attemptsLeft, 2);
    expect(state().misses, 1);
    expect(state().failure, isNull);
    expect(state().running, isNull);
    expect(state().entryOpen, isTrue);
  });

  test('a lost answer runs the check', () async {
    await controller().requestCode();
    repository.deleteFailures.add(const NetworkFailure());
    repository.exists = false;
    final List<DeletionAction?> seen = <DeletionAction?>[];
    container.listen(
      accountDeletionControllerProvider,
      (_, next) => seen.add(next.running),
    );

    expect(await controller().delete('123456'), DeletionOutcome.deleted);

    expect(repository.checks, 1);
    expect(seen, contains(DeletionAction.check));
    expect(state().running, isNull);
  });

  test('a lost answer on a living account keeps the code and fails '
      'offline', () async {
    await controller().requestCode();
    repository.deleteFailures.add(const NetworkFailure());
    repository.exists = true;

    expect(await controller().delete('123456'), DeletionOutcome.refused);

    expect(state().offline, isTrue);
    expect(state().failedAction, DeletionAction.delete);
    expect(state().running, isNull);
    expect(state().entryOpen, isTrue);
  });

  test('a check that fails is offline too', () async {
    await controller().requestCode();
    repository.deleteFailures.add(const NetworkFailure());
    repository.existsFailures.add(const NetworkFailure());

    expect(await controller().delete('123456'), DeletionOutcome.refused);

    expect(state().offline, isTrue);
    expect(state().failedAction, DeletionAction.delete);
  });

  test('a request that never left skips the check', () async {
    await controller().requestCode();
    repository.deleteFailures.add(const NetworkFailure(mayHaveArrived: false));

    expect(await controller().delete('123456'), DeletionOutcome.refused);

    expect(repository.checks, 0);
    expect(state().offline, isTrue);
    expect(state().failedAction, DeletionAction.delete);
  });

  test('a retry answered 401 is a deletion', () async {
    await controller().requestCode();
    repository.deleteFailures.add(
      const ApiRefusal(ApiError(status: 401, code: 'authentication_required')),
    );

    expect(await controller().delete('123456'), DeletionOutcome.deleted);
    expect(repository.checks, 0);
  });

  test('a 409 on request keeps the order with its status', () async {
    repository.requestFailures.add(
      const ApiRefusal(
        ApiError(
          status: 409,
          code: 'account_has_unfinished_orders',
          details: <String, Object?>{
            'order_id': 'o-9',
            'order_number': 1021,
            'status': 'shopping',
            'item_count': 7,
          },
        ),
      ),
    );

    expect(await controller().requestCode(), isFalse);

    expect(state().unfinished?.id, 'o-9');
    expect(state().unfinished?.status, OrderStatus.shopping);
    expect(state().unfinished?.itemCount, 7);
  });

  test('reset drops a request in flight', () async {
    final Completer<void> hold = Completer<void>();
    repository.hold = hold;

    final Future<bool> first = controller().requestCode();
    controller().reset();
    hold.complete();

    expect(await first, isFalse);
    expect(state().requested, isNull);
    expect(state().running, isNull);

    repository.hold = null;
    expect(await controller().requestCode(), isTrue);
    expect(state().requested, isNotNull);
  });

  test('forgetAccount removes both keys and drops the Customer '
      'session', () async {
    final InMemoryTokenStore tokens = InMemoryTokenStore();
    tokens.tokens[SessionSlot.customer] = 'c';
    final FakeAuthRepository auth = FakeAuthRepository();
    auth.identities[SessionSlot.customer] = user(id: 'c');
    final InMemoryPreferenceStore preferences = InMemoryPreferenceStore(
      <String, String>{
        RecentSearches.preferenceKey('c'): '["sut"]',
        DeliveryAddressChoice.preferenceKey('c'): 'a-1',
        'language': 'ru',
      },
    );
    final ProviderContainer own = ProviderContainer(
      overrides: [
        accountDeletionRepositoryProvider.overrideWithValue(repository),
        tokenStoreProvider.overrideWithValue(tokens),
        authRepositoryProvider.overrideWithValue(auth),
        preferenceStoreProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(own.dispose);
    await own.read(sessionControllerProvider.future);

    await own
        .read(accountDeletionControllerProvider.notifier)
        .forgetAccount('c');

    expect(preferences.values.keys, <String>['language']);
    expect(tokens.tokens.containsKey(SessionSlot.customer), isFalse);
    expect(own.read(sessionControllerProvider).value, isA<SignedOut>());
  });

  test('a right code deletes', () async {
    await controller().requestCode();

    expect(await controller().delete('123456'), DeletionOutcome.deleted);
    expect(repository.deletes, <String>['123456']);
  });

  test('a 409 on delete names the unfinished order', () async {
    await controller().requestCode();
    repository.deleteFailures.add(unfinishedRefusal(number: 7));

    expect(await controller().delete('123456'), DeletionOutcome.unfinished);
    expect(state().unfinished?.number, 7);
  });

  testWidgets('a lock counts down, then closes the entry until a new code', (
    tester,
  ) async {
    await controller().requestCode();
    repository.deleteFailures.add(lockedRefusal(retryAfter: 30));

    expect(await controller().delete('000000'), DeletionOutcome.refused);

    expect(state().lockedSeconds, 30);
    expect(state().failure, isNull);
    expect(state().entryOpen, isFalse);

    await tester.pump(const Duration(seconds: 10));
    expect(state().lockedSeconds, 20);

    await tester.pump(const Duration(seconds: 20));
    expect(state().lockedSeconds, 0);
    expect(state().lockOver, isTrue);
    expect(state().entryOpen, isFalse);

    await controller().resend();

    expect(state().lockOver, isFalse);
    expect(state().entryOpen, isTrue);
    expect(repository.requests, 2);
    await tester.pump(const Duration(seconds: 60));
  });

  testWidgets('a lock without a wait lasts 60 seconds', (tester) async {
    await controller().requestCode();
    repository.deleteFailures.add(lockedRefusal());

    await controller().delete('000000');

    expect(state().lockedSeconds, 60);
    await tester.pump(const Duration(seconds: 60));
  });

  testWidgets('a call while busy returns at once', (tester) async {
    final Completer<void> hold = Completer<void>();
    repository.hold = hold;

    final Future<bool> first = controller().requestCode();
    final bool second = await controller().requestCode();
    hold.complete();

    expect(second, isFalse);
    expect(await first, isTrue);
    expect(repository.requests, 1);

    final Completer<void> deleteHold = Completer<void>();
    repository.hold = deleteHold;
    final Future<DeletionOutcome> one = controller().delete('123456');
    final DeletionOutcome two = await controller().delete('123456');
    deleteHold.complete();

    expect(two, DeletionOutcome.refused);
    expect(await one, DeletionOutcome.deleted);
    expect(repository.deletes, <String>['123456']);
    await tester.pump(const Duration(seconds: 60));
  });

  testWidgets('reset forgets the flow', (tester) async {
    await controller().requestCode();

    controller().reset();

    expect(state().requested, isNull);
    expect(state().resendInSeconds, 0);
    await tester.pump(const Duration(seconds: 60));
  });
}
