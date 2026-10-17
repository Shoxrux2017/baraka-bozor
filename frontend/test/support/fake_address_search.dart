import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/features/addresses/domain/address_search.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';

/// An address search for widget tests: answers set per query. A query in
/// [held] waits for [release]; one in [failures] throws.
class FakeAddressSearch implements AddressSearchRepository {
  final Map<String, GeoPoint?> answers = <String, GeoPoint?>{};
  final Map<String, ApiFailure> failures = <String, ApiFailure>{};
  final Set<String> held = <String>{};
  final Map<String, Completer<GeoPoint?>> _pending =
      <String, Completer<GeoPoint?>>{};

  /// Every query sent, in order.
  final List<String> queries = <String>[];

  @override
  Future<GeoPoint?> locate(String query) {
    queries.add(query);
    if (held.contains(query)) {
      return (_pending[query] = Completer<GeoPoint?>()).future;
    }
    final ApiFailure? failure = failures[query];
    if (failure != null) {
      return Future<GeoPoint?>.error(failure);
    }
    return Future<GeoPoint?>.value(answers[query]);
  }

  /// Answers the held [query].
  void release(String query, GeoPoint? answer) =>
      _pending[query]!.complete(answer);
}
