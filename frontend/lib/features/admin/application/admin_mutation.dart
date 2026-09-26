import 'package:flutter/foundation.dart' show protected;

import '../../../core/network/api_failure.dart';
import '../../../core/state/mutation_state.dart';
import 'admin_providers.dart';

/// The base of every change the Admin makes in the panel. One surface — a
/// list's row actions, a dialog, a form, an image — has a controller of its
/// own, so a failure is shown where it happened and nowhere else, and a
/// surface that is left takes its pending change with it
/// (`frontend/AGENTS.md` sections 4 and 5, `DL-28` (10)).
///
/// After the change, [perform] reloads what it touched: on success, and also
/// after a conflict or an uncertain outcome, when the screen may be showing a
/// state the server no longer has (`docs/09` section 50) — but not after a
/// refused field, which the form still holds. An answer that arrives for
/// another account counts as cancelled (`DL-27` (2)).
abstract class AdminMutation extends MutationNotifier {
  @override
  MutationState build() {
    ref.watch(staffAccountProvider);
    return super.build();
  }

  /// Runs [change]; its answer, or `null` when it failed, was refused
  /// because another change of this surface runs, or no longer matters.
  @protected
  Future<T?> perform<T>(
    Future<T> Function() change, {
    required void Function(T? result) reload,
  }) async {
    final String? account = ref.read(staffAccountProvider);
    bool current() => ref.mounted && ref.read(staffAccountProvider) == account;

    T? result;
    final bool done = await run(() async {
      try {
        result = await change();
      } on ApiFailure catch (failure) {
        final bool mayBeStale = failure is! ApiRefusal || failure.status == 409;
        if (mayBeStale && current()) {
          reload(null);
        }
        rethrow;
      }
      if (!current()) {
        throw const CancelledFailure();
      }
      reload(result);
    });
    return done ? result : null;
  }
}
