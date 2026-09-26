import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The package's own in-memory platform, so the real SecureTokenStore is
  // exercised without a plugin method channel. The map is held by reference,
  // which is what lets these tests assert the keys the tokens land under.
  late Map<String, String> backing;
  late TokenStore store;

  setUp(() {
    backing = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(backing);
    store = const SecureTokenStore();
  });

  group('SecureTokenStore', () {
    test('reads null from an empty slot', () async {
      expect(await store.read(SessionSlot.staff), isNull);
      expect(await store.read(SessionSlot.customer), isNull);
    });

    test('keeps the two sessions apart', () async {
      await store.write(SessionSlot.staff, 'staff-token');
      await store.write(SessionSlot.customer, 'customer-token');

      expect(await store.read(SessionSlot.staff), 'staff-token');
      expect(await store.read(SessionSlot.customer), 'customer-token');
    });

    test('replaces the token in a slot instead of accumulating', () async {
      await store.write(SessionSlot.staff, 'first');
      await store.write(SessionSlot.staff, 'second');

      expect(await store.read(SessionSlot.staff), 'second');
      expect(backing.values, <String>['second']);
    });

    test('clearing one slot leaves the other alone', () async {
      await store.write(SessionSlot.staff, 'staff-token');
      await store.write(SessionSlot.customer, 'customer-token');

      await store.clear(SessionSlot.staff);

      expect(await store.read(SessionSlot.staff), isNull);
      expect(await store.read(SessionSlot.customer), 'customer-token');
    });

    test('clearing an empty slot is not an error', () async {
      await store.clear(SessionSlot.customer);

      expect(await store.read(SessionSlot.customer), isNull);
    });

    test('stores each session under its stable key', () async {
      await store.write(SessionSlot.staff, 'a');
      await store.write(SessionSlot.customer, 'b');

      // The keys are part of the on-device contract: changing one signs
      // every installed client out of that session, so they are asserted.
      expect(
        backing.keys,
        containsAll(<String>['bb_session_staff', 'bb_session_customer']),
      );
      expect(backing['bb_session_staff'], 'a');
      expect(backing['bb_session_customer'], 'b');
    });
  });
}
