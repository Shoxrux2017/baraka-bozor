import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/report_unexpected_error.dart';
import '../../../core/session/session_state.dart';
import '../../../core/storage/preference_store.dart';
import '../../auth/domain/app_user.dart';
import '../domain/push.dart';
import 'push_ports.dart';

/// Asks for the notification permission once per install, at the first moment
/// a person who can receive pushes is past every gate (`DL-115` (8)).
///
/// Android 13 and later show nothing until it is granted, so asking at launch
/// would put the dialog over the sign-in; instead it waits for the first-login
/// password change, the staff step and the Customer's name, and never comes
/// for a panel role. The mark is written before the dialog, so one that was
/// interrupted is not shown twice, and a build without push neither asks nor
/// marks, which leaves the next start with push to ask.
class PushPermissionPrompt {
  PushPermissionPrompt(this._ref) {
    _subscription = _ref.listen<AsyncValue<SessionState>>(
      sessionControllerProvider,
      (AsyncValue<SessionState>? previous, AsyncValue<SessionState> next) =>
          unawaited(_check(next)),
      fireImmediately: true,
    );
  }

  /// The preference that remembers the question was put (stored with the
  /// store's own prefix).
  static const String preferenceKey = 'push_permission_asked';

  final Ref _ref;
  late final ProviderSubscription<AsyncValue<SessionState>> _subscription;
  bool _checking = false;
  bool _finished = false;

  Future<void> _check(AsyncValue<SessionState> session) async {
    if (_finished || _checking) {
      return;
    }
    final SessionState? state = session.value;
    if (state is! SignedIn || !_ready(state)) {
      return;
    }
    final PushInbox inbox = _ref.read(pushInboxProvider);
    if (!inbox.receivesPushes) {
      return;
    }

    _checking = true;
    try {
      final PreferenceStore store = _ref.read(preferenceStoreProvider);
      if (await store.read(preferenceKey) == null) {
        await store.write(preferenceKey, 'yes');
        await inbox.requestPermission();
      }
    } catch (error, stackTrace) {
      reportUnexpectedError(error, stackTrace, 'while asking for push');
    } finally {
      _checking = false;
      // Asked, found asked, or failed: one check per process.
      _finished = true;
      _subscription.close();
    }
  }

  /// A Customer, Shopper or Courier the interface lets in: the same gates the
  /// router holds back, in the same order.
  bool _ready(SignedIn state) {
    final AppUser user = state.activeUser;
    final bool receives =
        user.role == UserRole.customer ||
        user.role == UserRole.shopper ||
        user.role == UserRole.courier;
    if (!receives || user.mustChangePassword || state.staffStep != null) {
      return false;
    }
    return state.activeMode != SessionMode.customer || user.fullName != null;
  }
}

/// The one permission prompt of the process.
final Provider<PushPermissionPrompt> pushPermissionProvider =
    Provider<PushPermissionPrompt>(PushPermissionPrompt.new);
