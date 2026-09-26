import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/state/mutation_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A mutation whose completion the test controls.
class _HeldMutation extends MutationNotifier {
  Completer<void> gate = Completer<void>();
  int started = 0;

  Future<bool> submit() => run(() async {
    started++;
    await gate.future;
  });
}

final NotifierProvider<_HeldMutation, MutationState> _provider =
    NotifierProvider<_HeldMutation, MutationState>(_HeldMutation.new);

void main() {
  late ProviderContainer container;
  late _HeldMutation notifier;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    notifier = container.read(_provider.notifier);
  });

  test('is busy while the mutation runs and idle once it completed', () async {
    expect(container.read(_provider), isA<MutationIdle>());

    final Future<bool> result = notifier.submit();
    expect(container.read(_provider).isBusy, isTrue);

    notifier.gate.complete();
    expect(await result, isTrue);
    expect(container.read(_provider), isA<MutationIdle>());
  });

  test('a failure is kept with its cause and cleared by reset', () async {
    notifier.gate.completeError(const NetworkFailure());

    expect(await notifier.submit(), isFalse);
    expect(container.read(_provider).failure, isA<NetworkFailure>());
    expect(container.read(_provider).isBusy, isFalse);

    notifier.reset();
    expect(container.read(_provider), isA<MutationIdle>());
  });

  test('a second submission while one runs is refused, not queued', () async {
    final Future<bool> first = notifier.submit();

    expect(await notifier.submit(), isFalse);
    expect(notifier.started, 1);

    notifier.gate.complete();
    expect(await first, isTrue);
  });

  test('a completion superseded by a reset changes nothing', () async {
    final Future<bool> stale = notifier.submit();
    notifier.reset();
    notifier.gate.completeError(const NetworkFailure());

    expect(await stale, isFalse);
    expect(
      container.read(_provider),
      isA<MutationIdle>(),
      reason: 'the failure of an abandoned run is not shown',
    );
  });
}
