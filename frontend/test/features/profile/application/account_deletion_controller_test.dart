import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/features/profile/application/account_deletion_controller.dart';
import 'package:baraka_bozor/features/profile/application/profile_controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_account_deletion_repository.dart';

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

  test('a wrong code is refused with its failure', () async {
    await controller().requestCode();
    repository.deleteFailures.add(wrongCodeRefusal());

    expect(await controller().delete('111111'), DeletionOutcome.refused);

    expect((state().failure as ApiRefusal).code, 'code_invalid');
    expect(state().entryOpen, isTrue);
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
