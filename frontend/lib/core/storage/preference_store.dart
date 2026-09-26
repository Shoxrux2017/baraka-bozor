import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small per-device preferences the app remembers between launches, such as
/// the chosen language. Not secrets, but kept in the same platform storage as
/// the tokens so the client depends on one storage plugin rather than two.
abstract interface class PreferenceStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class SecurePreferenceStore implements PreferenceStore {
  const SecurePreferenceStore([this._storage = const FlutterSecureStorage()]);

  /// Prefixed so a preference can never collide with a session slot.
  static const String prefix = 'bb_pref_';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: '$prefix$key');

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: '$prefix$key', value: value);
}
