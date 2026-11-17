import 'dart:math' as math;

import 'addresses.dart';

/// Finds on the map an address the Customer typed in words
/// (`docs/09-api-contracts.md` section 13). It only gives a point to look
/// at; nothing the provider says is kept (`DL-84` (2)).
abstract interface class AddressSearchRepository {
  /// The point of [query], or `null` when nothing was found. Throws an
  /// `ApiFailure`: `provider_unavailable`, `rate_limited`, or the network.
  Future<GeoPoint?> locate(String query);

  /// The address under [point] in [language] (`uz` or `ru`), or `null` when
  /// the provider knows nothing there. Throws an `ApiFailure`:
  /// `provider_unavailable`, `rate_limited`, or the network (`DL-138`).
  Future<PointAddress?> addressAt(GeoPoint point, {required String language});

  /// The delivery zone, or `null` while none is set. Throws an `ApiFailure`
  /// (`DL-138`).
  Future<ServiceArea?> serviceArea();
}

/// The address a map point stands on, as the provider words it; it is shown
/// beside the map and never kept (`DL-138`).
final class PointAddress {
  const PointAddress({required this.line, required this.houseKnown});

  final String line;

  /// Whether the answer reaches a house number.
  final bool houseKnown;
}

/// The circle the company delivers within (`DL-138`). The phone only
/// previews it: the server still refuses a saved point outside.
final class ServiceArea {
  const ServiceArea({required this.centre, required this.radiusKm});

  final GeoPoint centre;

  /// The radius as the server writes it, one to four digits and up to two
  /// decimals.
  final String radiusKm;

  /// Mean Earth radius in kilometres, as the server's `ServiceAreaPolicy`.
  static const double _earthKm = 6371.0088;

  /// The great-circle distance from the centre to [point], by haversine.
  double distanceKmTo(GeoPoint point) {
    double rad(double degrees) => degrees * math.pi / 180;
    final double lat1 = rad(centre.latitudeDegrees);
    final double lat2 = rad(point.latitudeDegrees);
    final double dLat = lat2 - lat1;
    final double dLon = rad(point.longitudeDegrees - centre.longitudeDegrees);
    final double a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
    return 2 * _earthKm * math.asin(math.min(1, math.sqrt(a)));
  }

  /// Whether [point] lies within the radius, the edge included.
  bool contains(GeoPoint point) =>
      distanceKmTo(point) <= double.parse(radiusKm);

  /// The distance to [point] rounded up to tenths, with a decimal comma.
  String distanceLabel(GeoPoint point) {
    final double tenths = (distanceKmTo(point) * 10).ceilToDouble();
    return (tenths / 10).toStringAsFixed(1).replaceFirst('.', ',');
  }

  /// The radius without trailing zeros, with a decimal comma.
  String get radiusLabel {
    final String trimmed = radiusKm.contains('.')
        ? radiusKm.replaceFirst(RegExp(r'\.?0+$'), '')
        : radiusKm;
    return trimmed.replaceFirst('.', ',');
  }
}
