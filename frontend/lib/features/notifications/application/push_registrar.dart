import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/report_unexpected_error.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/session/session_end_hook.dart';
import '../../../core/session/session_state.dart';
import '../../../core/storage/token_store.dart';
import '../../auth/domain/app_user.dart';
import '../data/push_devices_api.dart';
import '../domain/push.dart';

final Provider<PushTokenSource> pushTokenSourceProvider =
    Provider<PushTokenSource>((Ref ref) => const NoPushTokenSource());

final Provider<PushDevicesRepository> pushDevicesRepositoryProvider =
    Provider<PushDevicesRepository>(
      (Ref ref) => PushDevicesRepositoryImpl(ref.watch(apiClientProvider)),
    );

/// Registers the device's push token once for each signed-in account and
/// revokes it when that account logs out (`docs/09-api-contracts.md`
/// section 27, `DL-26`, interview 7.0: a phone holding a Customer and a staff
/// account is registered for both).
///
/// It follows the session: an account that appears is registered — a staff
/// account only once past the first-login password change, which the server
/// requires; an account that is replaced is registered anew; an account that
/// is gone without a logout, its token refused or expired, is forgotten,
/// since its session can no longer revoke anything. A logout revokes first,
/// through the session-end hook, while the session still works.
class PushRegistrar implements SessionEndHook {
  PushRegistrar(this._ref) {
    final SessionEndHooks hooks = _ref.read(sessionEndHooksProvider)..add(this);
    _ref.onDispose(() => hooks.remove(this));
    _ref.listen<AsyncValue<SessionState>>(
      sessionControllerProvider,
      (AsyncValue<SessionState>? previous, AsyncValue<SessionState> next) =>
          _follow(next.value),
      fireImmediately: true,
    );
  }

  final Ref _ref;

  /// Per slot: the account a device is registered for, and the pending or
  /// finished registration that gives the device's id.
  final Map<SessionSlot, _Registration> _registrations =
      <SessionSlot, _Registration>{};

  void _follow(SessionState? state) {
    final SignedIn? session = state is SignedIn ? state : null;

    for (final SessionSlot slot in SessionSlot.values) {
      final AppUser? user = switch (slot) {
        SessionSlot.staff => session?.staffUser,
        SessionSlot.customer => session?.customerUser,
      };
      final bool eligible = user != null && !user.mustChangePassword;
      final _Registration? current = _registrations[slot];

      if (!eligible) {
        _registrations.remove(slot);
      } else if (current == null || current.accountId != user.id) {
        _registrations[slot] = _Registration(user.id, _register(slot));
      }
    }
  }

  /// The id of the device registered for [slot], or `null` when there is no
  /// token or the registration failed; a failure is retried at the next
  /// session change rather than in a loop.
  Future<String?> _register(SessionSlot slot) async {
    try {
      final PushToken? token = await _ref
          .read(pushTokenSourceProvider)
          .current();
      if (token == null) {
        return null;
      }
      return await _ref
          .read(pushDevicesRepositoryProvider)
          .register(slot, token);
    } on ApiFailure {
      return null;
    } catch (error, stackTrace) {
      reportUnexpectedError(error, stackTrace, 'while registering for push');
      return null;
    }
  }

  @override
  Future<void> beforeLogout(SessionSlot slot) async {
    final _Registration? registration = _registrations.remove(slot);
    final String? deviceId = await registration?.deviceId;
    if (deviceId == null) {
      return;
    }
    try {
      await _ref.read(pushDevicesRepositoryProvider).revoke(slot, deviceId);
    } on ApiFailure {
      // The logout goes on; the server prunes devices it no longer sees
      // (the wave's risk list, before the first push in Wave 4).
    }
  }
}

final class _Registration {
  _Registration(this.accountId, this.deviceId);

  final String accountId;
  final Future<String?> deviceId;
}

/// The one registrar of the process. The app root keeps it alive, and the
/// session controller runs it before a logout.
final Provider<PushRegistrar> pushRegistrarProvider = Provider<PushRegistrar>(
  PushRegistrar.new,
);
