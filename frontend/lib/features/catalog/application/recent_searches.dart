import 'dart:convert';

import 'package:flutter/services.dart' show PlatformException;
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

  /// The apostrophe forms Uzbek is typed with (U+02BB, U+2018, U+2019 and the
  /// grave accent), all read as the plain apostrophe.
  static final RegExp _apostrophes = RegExp(
    '[${String.fromCharCodes(<int>[0x2BB, 0x2018, 0x2019, 0x60])}]',
  );

  /// A query as the catalog search reads it: lower case, `ё` as `е` and every
  /// apostrophe form as one (`DL-20`).
  static String _fold(String query) =>
      query.toLowerCase().replaceAll('ё', 'е').replaceAll(_apostrophes, "'");

  @override
  Future<List<String>> build() async {
    final String? raw;
    try {
      raw = await ref
          .read(preferenceStoreProvider)
          .read(preferenceKey(account));
    } on PlatformException {
      // The device storage cannot be read: start with nothing.
      return const <String>[];
    }
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
    await future;
    if (!ref.mounted) {
      return;
    }
    // Taken after the wait, so a remember started meanwhile is kept.
    final List<String> current = state.value ?? const <String>[];
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
    try {
      await ref
          .read(preferenceStoreProvider)
          .write(preferenceKey(account), jsonEncode(list));
    } on PlatformException {
      // Not saved on the device: the list stays right for this run.
    }
  }
}

/// Per account and not auto-disposed, so a screen may call `remember` from
/// `dispose` through a notifier it captured earlier.
final AsyncNotifierProviderFamily<RecentSearches, List<String>, String>
recentSearchesProvider =
    AsyncNotifierProvider.family<RecentSearches, List<String>, String>(
      RecentSearches.new,
    );
