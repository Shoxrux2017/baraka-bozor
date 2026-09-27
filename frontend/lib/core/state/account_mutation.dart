import 'package:flutter/foundation.dart' show protected;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;

import '../network/api_failure.dart';
import 'mutation_state.dart';

/// A change made for one signed-in account from one surface of the
/// application — a list's row actions, a dialog, a form. Each surface has a
/// controller of its own, so a failure is shown where it happened and
/// nowhere else, and a surface that is left takes its pending change with it
/// (`frontend/AGENTS.md` sections 4 and 5, `DL-28` (10)).
///
/// After the change, [perform] reloads what it touched: on success, and also
/// after a conflict, a record gone, or an uncertain outcome, when the screen
/// may be showing a state the server no longer has (`docs/09` section 50) —
/// but not after a refused field, which the form still holds. The surface
/// stays alive until its change has answered, so a change the person left
/// still reloads what it touched; whether it may still navigate or confirm
/// is the widget's to decide. An answer that arrives for another account
/// counts as cancelled (`DL-27` (2)).
abstract class AccountMutation extends MutationNotifier {
  /// The id of the account the change is made for, `null` while there is
  /// none; watched, so another account starts the surface over.
  @protected
  Provider<String?> get account;

  @override
  MutationState build() {
    ref.watch(account);
    return super.build();
  }

  /// Runs [change]; its answer, or `null` when it failed, was refused
  /// because another change of this surface runs, or no longer matters.
  @protected
  Future<T?> perform<T>(
    Future<T> Function() change, {
    required void Function(T? result) reload,
  }) async {
    final String? before = ref.read(account);
    bool current() => ref.mounted && ref.read(account) == before;
    final KeepAliveLink alive = ref.keepAlive();

    T? result;
    try {
      final bool done = await run(() async {
        try {
          result = await change();
        } on ApiFailure catch (failure) {
          final bool mayBeStale =
              failure is! ApiRefusal ||
              failure.status == 404 ||
              failure.status == 409;
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
    } finally {
      alive.close();
    }
  }
}
