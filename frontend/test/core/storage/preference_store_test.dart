import 'package:baraka_bozor/core/storage/preference_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, String> backing;

  setUp(() {
    backing = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(backing);
  });

  test(
    'a preference is stored under a prefixed key, apart from the sessions',
    () async {
      const PreferenceStore store = SecurePreferenceStore();

      await store.write('language', 'ru');

      expect(await store.read('language'), 'ru');
      expect(backing.keys, <String>['bb_pref_language']);
      expect(await store.read('missing'), isNull);
    },
  );
}
