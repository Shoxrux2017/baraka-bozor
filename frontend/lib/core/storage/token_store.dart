import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// One device may hold two sessions for one person: the staff session and
/// the customer session of a Shopper or Courier who also shops here
/// (`docs/07-architecture.md` section 8). Each lives in its own slot and the
/// two are never exchanged for one another.
enum SessionSlot { staff, customer }

/// The bearer tokens as the rest of the application sees them.
///
/// Features depend on this port, never on the storage plugin, so the session
/// controller can be tested against it and the platform implementation can
/// change without reaching into feature code.
abstract interface class TokenStore {
  /// The stored token for [slot], or `null` when that session is absent.
  Future<String?> read(SessionSlot slot);

  /// Stores [token] in [slot], replacing any token already there.
  Future<void> write(SessionSlot slot, String token);

  /// Removes the token in [slot]; the other slot is untouched.
  Future<void> clear(SessionSlot slot);
}

/// The [TokenStore] backed by platform-secured storage, as
/// `docs/07-architecture.md` section 8 requires: the Android KeyStore and the
/// iOS keychain on mobile. On the web panel the plugin keeps the token in
/// browser storage through the same port (`docs/DECISIONS.md` DL-3, Sanctum
/// row), which is the accepted trade-off for an internal panel behind a login.
class SecureTokenStore implements TokenStore {
  // flutter_secure_storage 11 encrypts on Android by default, with AES-GCM
  // under a KeyStore-wrapped key, so no option is passed to request it.
  const SecureTokenStore([this._storage = const FlutterSecureStorage()]);

  /// The on-device keys, one per slot. Changing one signs every installed
  /// client out of that session, so they are treated as a contract.
  static const Map<SessionSlot, String> keys = <SessionSlot, String>{
    SessionSlot.staff: 'bb_session_staff',
    SessionSlot.customer: 'bb_session_customer',
  };

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(SessionSlot slot) => _storage.read(key: keys[slot]!);

  @override
  Future<void> write(SessionSlot slot, String token) =>
      _storage.write(key: keys[slot]!, value: token);

  @override
  Future<void> clear(SessionSlot slot) => _storage.delete(key: keys[slot]!);
}
