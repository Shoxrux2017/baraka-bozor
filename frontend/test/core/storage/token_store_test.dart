import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The package's own in-memory platform, so the real SecureTokenStore is
  // exercised without a plugin method channel. The map is held by reference,
  // which is what lets these tests assert the key the token lands under.
  late Map<String, String> backing;
  late TokenStore store;

  setUp(() {
    backing = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(backing);
    store = const SecureTokenStore();
  });

  group('SecureTokenStore', () {
    test('reads null when no token has been stored', () async {
      expect(await store.read(), isNull);
    });

    test('reads back the token it wrote', () async {
      await store.write('token-abc');

      expect(await store.read(), 'token-abc');
    });

    test(
      'replaces the previous token instead of accumulating one per account',
      () async {
        await store.write('token-first');
        await store.write('token-second');

        expect(await store.read(), 'token-second');
        expect(backing.values, <String>['token-second']);
      },
    );

    test('clear removes the token', () async {
      await store.write('token-abc');

      await store.clear();

      expect(await store.read(), isNull);
      expect(backing, isEmpty);
    });

    test('clear on an empty store is not an error', () async {
      await store.clear();

      expect(await store.read(), isNull);
    });

    test('stores the token under one stable key', () async {
      await store.write('token-abc');

      // The key is part of the on-device contract: changing it signs every
      // installed client out silently, so it is asserted rather than assumed.
      expect(backing.keys, <String>['bb_auth_token']);
    });
  });
}
