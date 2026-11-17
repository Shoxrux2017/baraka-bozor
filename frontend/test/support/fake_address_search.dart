import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/features/addresses/domain/address_search.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';

/// An address search for widget tests: answers set per query. A query in
/// [held] waits for [release]; one in [failures] throws. The address under a
/// point is answered from [places], or waits when the point is in
/// [heldPlaces], or throws [placeFailure]; the zone is [area] or throws
/// [areaFailure].
class FakeAddressSearch implements AddressSearchRepository {
  final Map<String, GeoPoint?> answers = <String, GeoPoint?>{};
  final Map<String, ApiFailure> failures = <String, ApiFailure>{};
  final Set<String> held = <String>{};
  final Map<String, Completer<GeoPoint?>> _pending =
      <String, Completer<GeoPoint?>>{};

  /// Every query sent, in order.
  final List<String> queries = <String>[];

  /// What lies under a point, set per point; a missing point is unknown.
  final Map<GeoPoint, PointAddress?> places = <GeoPoint, PointAddress?>{};

  /// Points whose lookup waits for [releasePlace].
  final Set<GeoPoint> heldPlaces = <GeoPoint>{};
  final Map<GeoPoint, Completer<PointAddress?>> _pendingPlaces =
      <GeoPoint, Completer<PointAddress?>>{};

  /// A failure every lookup under a point throws.
  ApiFailure? placeFailure;

  /// Every lookup sent, with the language it carried.
  final List<(GeoPoint, String)> lookups = <(GeoPoint, String)>[];

  /// The delivery zone; `null` while unset.
  ServiceArea? area;

  /// A failure the zone read throws.
  ApiFailure? areaFailure;

  /// Whether the zone read waits for [releaseArea].
  bool holdArea = false;
  Completer<ServiceArea?>? _pendingArea;

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

  @override
  Future<PointAddress?> addressAt(GeoPoint point, {required String language}) {
    lookups.add((point, language));
    if (placeFailure != null) {
      return Future<PointAddress?>.error(placeFailure!);
    }
    if (heldPlaces.contains(point)) {
      return (_pendingPlaces[point] = Completer<PointAddress?>()).future;
    }
    return Future<PointAddress?>.value(places[point]);
  }

  /// Answers the held lookup under [point].
  void releasePlace(GeoPoint point, PointAddress? answer) =>
      _pendingPlaces[point]!.complete(answer);

  /// Answers the held zone read.
  void releaseArea(ServiceArea? answer) => _pendingArea!.complete(answer);

  @override
  Future<ServiceArea?> serviceArea() => holdArea
      ? (_pendingArea = Completer<ServiceArea?>()).future
      : areaFailure != null
      ? Future<ServiceArea?>.error(areaFailure!)
      : Future<ServiceArea?>.value(area);
}
