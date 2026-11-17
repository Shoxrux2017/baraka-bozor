import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/features/addresses/domain/address_search.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/google_address_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  const ServiceArea zone = ServiceArea(
    centre: GeoPoint(latitude: '41.311081', longitude: '69.240562'),
    radiusKm: '12.5',
  );

  GeoPoint at(LatLng p) => GeoPoint.fromDegrees(p.latitude, p.longitude);

  test('the zone is a dimmed world with a hole and a dashed green edge', () {
    final overlay = zoneOverlay(zone);

    expect(overlay.dim.holes, hasLength(1));
    final List<LatLng> hole = overlay.dim.holes.single;
    expect(hole, hasLength(72));
    for (final LatLng p in hole) {
      expect(
        zone.distanceKmTo(at(p)),
        closeTo(12.5, 0.001),
        reason: 'within one metre of the radius',
      );
    }
    final List<double> lats = overlay.dim.points
        .map((LatLng p) => p.latitude)
        .toList();
    final List<double> lngs = overlay.dim.points
        .map((LatLng p) => p.longitude)
        .toList();
    for (final LatLng p in hole) {
      expect(
        p.latitude,
        inExclusiveRange(
          lats.reduce((a, b) => a < b ? a : b),
          lats.reduce((a, b) => a > b ? a : b),
        ),
      );
      expect(
        p.longitude,
        inExclusiveRange(
          lngs.reduce((a, b) => a < b ? a : b),
          lngs.reduce((a, b) => a > b ? a : b),
        ),
      );
    }
    expect(overlay.dim.fillColor, const Color(0x21151D16));
    expect(overlay.dim.strokeWidth, 0);

    expect(overlay.edge.points, hasLength(73));
    expect(overlay.edge.points.first, overlay.edge.points.last);
    expect(overlay.edge.color, KitColors.primary);
    expect(overlay.edge.width, 3);
    expect(
      overlay.edge.patterns.map((PatternItem p) => p.toJson()).toList(),
      <Object>[PatternItem.dash(12).toJson(), PatternItem.gap(8).toJson()],
    );
  });
}
