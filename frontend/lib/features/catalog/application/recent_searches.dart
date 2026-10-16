import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;

import '../../../app/providers.dart';
import '../domain/catalog.dart';

/// The queries a Customer searched for last, kept on this device for their
/// account (`DL-83` item 1). They never reach the server.
class RecentSearches extends AsyncNotifier<List<String>> {
  RecentSearches(this.account);

  final String account;

  /// How many queries are kept.
  static const int limit = 10;

  /// The shortest query worth remembering, in letters.
  static const int _minLength = 2;

  /// Per account, so a second Customer on the same phone never sees the
  /// first one's queries.
  static String preferenceKey(String account) => 'recent_searches.$account';

  /// A query as the catalog search reads it: lower case, `ё` as `е` (`DL-20`).
  static String _fold(String query) => query.toLowerCase().replaceAll('ё', 'е');

  @override
  Future<List<String>> build() async {
    final String? raw = await ref
        .read(preferenceStoreProvider)
        .read(preferenceKey(account));
    if (raw == null) {
      return const <String>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List<Object?>) {
        return List<String>.unmodifiable(decoded.whereType<String>());
      }
    } on FormatException {
      return const <String>[];
    }
    return const <String>[];
  }

  Future<void> remember(String query) async {
    final String text = ProductListQuery.searchOf(query);
    if (text.runes.length < _minLength) {
      return;
    }
    final List<String> current = await future;
    final String folded = _fold(text);
    final List<String> next = <String>[
      text,
      ...current.where((String entry) => _fold(entry) != folded),
    ].take(limit).toList(growable: false);
    await _save(next);
  }

  Future<void> clear() => _save(const <String>[]);

  Future<void> _save(List<String> list) async {
    state = AsyncData<List<String>>(List<String>.unmodifiable(list));
    await ref
        .read(preferenceStoreProvider)
        .write(preferenceKey(account), jsonEncode(list));
  }
}

/// Per account and not auto-disposed, so a screen may call `remember` from
/// `dispose` through a notifier it captured earlier.
final AsyncNotifierProviderFamily<RecentSearches, List<String>, String>
recentSearchesProvider =
    AsyncNotifierProvider.family<RecentSearches, List<String>, String>(
      RecentSearches.new,
    );
