import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The bearer token as the rest of the application sees it.
///
/// Features depend on this port, never on the storage plugin, so the session
/// task can test against it and the platform implementation can change without
/// reaching into feature code.
abstract interface class TokenStore {
  /// The stored token, or `null` when no session is present.
  Future<String?> read();

  /// Stores [token], replacing any token already present.
  Future<void> write(String token);

  /// Removes the stored token.
  Future<void> clear();
}

/// The [TokenStore] backed by platform-secured storage, as
/// `docs/07-architecture.md` section 8 requires.
///
/// Every MVP target provides one: the Android KeyStore, the iOS keychain and
/// the Windows Credential Manager. That all three do is part of why `02`
/// section 10 rules out a browser surface.
class SecureTokenStore implements TokenStore {
  // flutter_secure_storage 11 already encrypts on Android by default, with
  // AES-GCM under a KeyStore-wrapped key, so no option is passed to request it.
  // The `encryptedSharedPreferences` flag earlier versions needed no longer
  // exists. The parameter is positional because a named one cannot carry an
  // initializing formal for a private field.
  const SecureTokenStore([this._storage = const FlutterSecureStorage()]);

  /// The on-device key the token lives under. Changing it signs every
  /// installed client out, so it is treated as a contract.
  static const String tokenKey = 'bb_auth_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: tokenKey);

  @override
  Future<void> write(String token) =>
      _storage.write(key: tokenKey, value: token);

  @override
  Future<void> clear() => _storage.delete(key: tokenKey);
}
