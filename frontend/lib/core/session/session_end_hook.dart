import '../storage/token_store.dart';

/// Work that must happen while a session still works, just before a logout
/// ends it: the push registrar revokes the device of that session, which
/// after the logout it could no longer do (`DL-26` (5)).
///
/// A hook never stops a logout: whatever it throws is reported and the
/// logout goes on, and a hook still running after [SessionEndHooks.limit]
/// is left to finish on its own.
abstract interface class SessionEndHook {
  Future<void> beforeLogout(SessionSlot slot);
}

/// The hooks the session controller runs before a logout. A feature adds
/// its hook when it starts and removes it when it ends; the controller only
/// reads the list, so no provider depends on the controller through it.
final class SessionEndHooks {
  SessionEndHooks({this.limit = const Duration(seconds: 5)});

  /// How long a logout waits for one hook. The registrar's hook waits for a
  /// pending registration, which waits for the push token; a token source
  /// that never answers must not hold the logout.
  final Duration limit;

  final List<SessionEndHook> _hooks = <SessionEndHook>[];

  List<SessionEndHook> get all => List<SessionEndHook>.unmodifiable(_hooks);

  void add(SessionEndHook hook) => _hooks.add(hook);

  void remove(SessionEndHook hook) => _hooks.remove(hook);
}
