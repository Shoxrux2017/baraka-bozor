import 'package:baraka_bozor/core/storage/preference_store.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';

/// A [TokenStore] that lives in a map, for controller and interceptor tests.
class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([Map<SessionSlot, String>? initial])
    : tokens = Map<SessionSlot, String>.of(initial ?? <SessionSlot, String>{});

  final Map<SessionSlot, String> tokens;

  @override
  Future<String?> read(SessionSlot slot) async => tokens[slot];

  @override
  Future<void> write(SessionSlot slot, String token) async {
    tokens[slot] = token;
  }

  @override
  Future<void> clear(SessionSlot slot) async {
    tokens.remove(slot);
  }
}

/// A [PreferenceStore] that lives in a map.
class InMemoryPreferenceStore implements PreferenceStore {
  InMemoryPreferenceStore([Map<String, String>? initial])
    : values = Map<String, String>.of(initial ?? <String, String>{});

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
