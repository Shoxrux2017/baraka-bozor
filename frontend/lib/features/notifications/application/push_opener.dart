import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/routing/visible_location.dart';
import '../../../core/session/session_state.dart';
import '../../auth/domain/app_user.dart';
import '../domain/push_event.dart';

/// Opens the order a tapped push or banner names, in the mode that owns it
/// (`DL-115` (7)).
///
/// A tap that starts the app arrives before the session is known, and the
/// router is still on the bootstrap screen, so the latest target waits until
/// the session answers. It is then opened once or dropped, never kept: a
/// person who signs in later is not taken to an order a tap named earlier.
class PushOpener {
  PushOpener(this._ref) {
    _ref.listen<AsyncValue<SessionState>>(
      sessionControllerProvider,
      (AsyncValue<SessionState>? previous, AsyncValue<SessionState> next) =>
          _settle(next),
    );
  }

  final Ref _ref;
  PushTarget? _pending;

  /// Keeps [target] as the one to open and opens it when the session allows.
  void open(PushTarget target) {
    _pending = target;
    _settle(_ref.read(sessionControllerProvider));
  }

  void _settle(AsyncValue<SessionState> session) {
    final PushTarget? target = _pending;
    if (target == null) {
      return;
    }
    final SessionState? state = session.value;
    if (state == null || state is SessionUnreachable) {
      return;
    }
    _pending = null;
    if (state is SignedIn && _mayOpen(state, target)) {
      _navigate(state, target);
    }
  }

  /// Only the session the push belongs to may open it: its slot holds a user
  /// of the recipient's role, past the gates that hold the interface back.
  bool _mayOpen(SignedIn state, PushTarget target) {
    final AppUser? user = state.userIn(target.mode);
    if (user == null || user.role != target.role || user.mustChangePassword) {
      return false;
    }
    return switch (target.mode) {
      SessionMode.staff => state.staffStep == null,
      SessionMode.customer => user.fullName != null,
    };
  }

  void _navigate(SignedIn state, PushTarget target) {
    if (state.activeMode != target.mode) {
      _ref.read(sessionControllerProvider.notifier).switchMode(target.mode);
    }
    final GoRouter router = _ref.read(routerProvider);
    if (router.visiblePath == target.path) {
      return;
    }
    // The order opens over its list, so Back returns to the list.
    router.go(target.listPath);
    router.push<void>(target.path);
  }
}

/// The one opener of the process.
final Provider<PushOpener> pushOpenerProvider = Provider<PushOpener>(
  PushOpener.new,
);
