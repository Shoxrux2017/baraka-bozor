import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/state/mutation_state.dart';
import 'package:flutter/foundation.dart';
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
    NotifierProvider.autoDispose<_HeldMutation, MutationState>(
      _HeldMutation.new,
    );

void main() {
  late ProviderContainer container;
  late _HeldMutation notifier;
  late ProviderSubscription<MutationState> subscription;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    // A listener keeps the autoDispose notifier alive, as a screen would.
    subscription = container.listen<MutationState>(_provider, (_, _) {});
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

  test(
    'a known failure is kept with its cause and the form is usable',
    () async {
      notifier.gate.completeError(const NetworkFailure());

      expect(await notifier.submit(), isFalse);
      expect(container.read(_provider).failure, isA<NetworkFailure>());
      expect(container.read(_provider).isBusy, isFalse);
    },
  );

  test('an error the application cannot explain re-enables the form, shows the generic failure and is reported', () async {
    final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
    final FlutterExceptionHandler? previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    notifier.gate.completeError(StateError('storage is gone'));

    expect(await notifier.submit(), isFalse);

    expect(container.read(_provider).isBusy, isFalse);
    expect(container.read(_provider).failure, isA<UnexpectedFailure>());
    expect(reported.single.exception, isA<StateError>());
  });

  test('a second submission while one runs is refused, not queued', () async {
    final Future<bool> first = notifier.submit();

    expect(await notifier.submit(), isFalse);
    expect(notifier.started, 1);

    notifier.gate.complete();
    expect(await first, isTrue);
  });

  test('a completion after the screen left and the notifier was disposed writes nothing and throws nothing', () async {
    final Future<bool> late = notifier.submit();
    subscription.close();
    // autoDispose runs after the current event; let it.
    await Future<void>.delayed(Duration.zero);

    notifier.gate.complete();

    expect(await late, isFalse);
    expect(
      () => container.read(_provider),
      returnsNormally,
      reason: 'a fresh notifier is created; the old completion left no trace',
    );
    expect(container.read(_provider), isA<MutationIdle>());
  });
}
