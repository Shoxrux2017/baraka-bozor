import 'dart:convert';

import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/features/catalog/application/recent_searches.dart';
import 'package:baraka_bozor/core/storage/preference_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_stores.dart';

void main() {
  late InMemoryPreferenceStore store;
  late ProviderContainer container;

  setUp(() {
    store = InMemoryPreferenceStore();
    container = ProviderContainer(
      overrides: [preferenceStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
  });

  Future<List<String>> read(String account) =>
      container.read(recentSearchesProvider(account).future);

  RecentSearches notifier(String account) =>
      container.read(recentSearchesProvider(account).notifier);

  List<String> stored(String account) =>
      (jsonDecode(store.values[RecentSearches.preferenceKey(account)]!) as List)
          .cast<String>();

  test(
    'remember trims, and a repeat in another case keeps one entry',
    () async {
      await read('a');
      await notifier('a').remember('  помидоры ');
      expect(stored('a'), <String>['помидоры']);
      await notifier('a').remember('Помидоры');
      expect(stored('a'), <String>['Помидоры']);
      expect(container.read(recentSearchesProvider('a')).value, <String>[
        'Помидоры',
      ]);
    },
  );

  test('ё is read as е when folding repeats', () async {
    await read('a');
    await notifier('a').remember('ежик');
    await notifier('a').remember('ёжик');
    expect(stored('a'), <String>['ёжик']);
  });

  test('every Uzbek apostrophe form folds to one entry', () async {
    await read('a');
    final String first = "qo'y";
    final String second = 'qo${String.fromCharCode(0x2BB)}y';
    final String third = 'qo${String.fromCharCode(0x2019)}y';
    await notifier('a').remember(first);
    await notifier('a').remember(second);
    await notifier('a').remember(third);
    await notifier('a').remember('qo${String.fromCharCode(0x2018)}y');
    await notifier('a').remember('qo${String.fromCharCode(0x60)}y');
    expect(stored('a'), <String>['qo${String.fromCharCode(0x60)}y']);
  });

  test('eleven different queries keep the newest ten', () async {
    await read('a');
    for (int i = 1; i <= 11; i++) {
      await notifier('a').remember('query $i');
    }
    final List<String> list = stored('a');
    expect(list, hasLength(RecentSearches.limit));
    expect(list.first, 'query 11');
    expect(list.last, 'query 2');
  });

  test('a query under two letters is ignored', () async {
    await read('a');
    await notifier('a').remember('a');
    expect(store.values, isEmpty);
  });

  test('accounts read separate lists', () async {
    await read('a');
    await read('b');
    await notifier('a').remember('sut');
    expect(await read('b'), isEmpty);
    expect(stored('a'), <String>['sut']);
  });

  test('clear empties the list', () async {
    await read('a');
    await notifier('a').remember('sut');
    await notifier('a').clear();
    expect(stored('a'), isEmpty);
    expect(container.read(recentSearchesProvider('a')).value, isEmpty);
  });

  test('an unreadable or non-array value reads as empty', () async {
    store.values[RecentSearches.preferenceKey('a')] = 'not json';
    store.values[RecentSearches.preferenceKey('b')] = '{"x":1}';
    expect(await read('a'), isEmpty);
    expect(await read('b'), isEmpty);
  });

  test('two remembers started together keep both entries', () async {
    await read('a');
    final Future<void> first = notifier('a').remember('olma');
    final Future<void> second = notifier('a').remember('nok');
    await Future.wait(<Future<void>>[first, second]);
    expect(container.read(recentSearchesProvider('a')).value, <String>[
      'nok',
      'olma',
    ]);
    expect(stored('a'), <String>['nok', 'olma']);
  });

  group('when the device storage fails', () {
    late ProviderContainer broken;
    late _ThrowingStore failing;

    setUp(() {
      failing = _ThrowingStore();
      broken = ProviderContainer(
        overrides: [preferenceStoreProvider.overrideWithValue(failing)],
      );
      addTearDown(broken.dispose);
    });

    test('a failing read gives an empty list', () async {
      failing.failRead = true;
      expect(await broken.read(recentSearchesProvider('a').future), isEmpty);
    });

    test('a failing write keeps the list for this run', () async {
      failing.failWrite = true;
      await broken.read(recentSearchesProvider('a').future);
      final RecentSearches recent = broken.read(
        recentSearchesProvider('a').notifier,
      );
      await recent.remember('olma');
      expect(broken.read(recentSearchesProvider('a')).value, <String>['olma']);
      await recent.clear();
      expect(broken.read(recentSearchesProvider('a')).value, isEmpty);
    });
  });
}

class _ThrowingStore implements PreferenceStore {
  bool failRead = false;
  bool failWrite = false;

  @override
  Future<String?> read(String key) async {
    if (failRead) {
      throw PlatformException(code: 'read');
    }
    return null;
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrite) {
      throw PlatformException(code: 'write');
    }
  }
}
