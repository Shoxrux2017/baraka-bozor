import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_failure.dart';

/// The state of one server mutation as a form shows it: idle, busy, or
/// failed with the failure to explain. Success needs no state of its own —
/// what a successful mutation changes lives with the thing it changed, and
/// the form moves on.
sealed class MutationState {
  const MutationState();

  bool get isBusy => this is MutationBusy;

  ApiFailure? get failure => switch (this) {
    final MutationFailed failed => failed.failure,
    _ => null,
  };
}

final class MutationIdle extends MutationState {
  const MutationIdle();
}

final class MutationBusy extends MutationState {
  const MutationBusy();
}

final class MutationFailed extends MutationState {
  const MutationFailed(this.failure);

  @override
  final ApiFailure failure;
}

/// A notifier that runs one mutation at a time.
///
/// A second submission while one runs is refused, so a double tap cannot
/// send twice (`frontend/AGENTS.md` section 10). A completion that belongs
/// to a run this notifier has since superseded is discarded
/// (`docs/07-architecture.md` section 28), so a late answer never overwrites
/// a newer state.
abstract class MutationNotifier extends Notifier<MutationState> {
  int _generation = 0;

  @override
  MutationState build() => const MutationIdle();

  /// Runs [action]; `true` when it completed, `false` when it failed, was
  /// refused because another run is active, or was superseded.
  @protected
  Future<bool> run(Future<void> Function() action) async {
    if (state.isBusy) {
      return false;
    }

    final int generation = ++_generation;
    state = const MutationBusy();

    try {
      await action();
    } on ApiFailure catch (failure) {
      if (generation == _generation) {
        state = MutationFailed(failure);
      }
      return false;
    }

    if (generation != _generation) {
      return false;
    }
    state = const MutationIdle();
    return true;
  }

  /// Forgets a failure, for example when the person edits the form again.
  void reset() {
    _generation++;
    state = const MutationIdle();
  }
}
