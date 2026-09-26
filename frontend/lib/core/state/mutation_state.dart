import 'package:flutter/foundation.dart' show protected;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/report_unexpected_error.dart';
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
/// to a run this notifier has since superseded, or that arrives after the
/// notifier was disposed with its screen, is discarded
/// (`docs/07-architecture.md` section 28). Whatever the action throws, the
/// form is usable again afterwards: a failure the application knows is
/// shown as itself, anything else as the generic failure, and reported.
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
      _settle(generation, MutationFailed(failure));
      return false;
    } catch (error, stackTrace) {
      _settle(generation, const MutationFailed(UnexpectedFailure()));
      reportUnexpectedError(error, stackTrace, 'while running a form mutation');
      return false;
    }

    return _settle(generation, const MutationIdle());
  }

  /// Applies [next] only while this run is the current one and the notifier
  /// is still alive; a form that was left while its request ran has nothing
  /// to update.
  bool _settle(int generation, MutationState next) {
    if (generation != _generation || !ref.mounted) {
      return false;
    }
    state = next;
    return true;
  }
}
