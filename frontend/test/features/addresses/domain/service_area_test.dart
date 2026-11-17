import 'package:baraka_bozor/features/addresses/domain/address_search.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:flutter_test/flutter_test.dart';

const GeoPoint _centre = GeoPoint(
  latitude: '41.311081',
  longitude: '69.240562',
);

void main() {
  test('a point within the radius is inside, one 20 m beyond is outside', () {
    const ServiceArea area = ServiceArea(centre: _centre, radiusKm: '10.00');
    // One degree of latitude is about 111.195 km, so 10 km is 0.089932 deg.
    final GeoPoint within = GeoPoint.fromDegrees(41.311081 + 0.0899, 69.240562);
    final GeoPoint beyond = GeoPoint.fromDegrees(
      41.311081 + 0.0899 + 0.00036,
      69.240562,
    );

    expect(area.contains(_centre), isTrue);
    expect(area.contains(within), isTrue);
    expect(area.contains(beyond), isFalse);
  });

  test('the distance is rounded up to tenths with a comma', () {
    const ServiceArea area = ServiceArea(centre: _centre, radiusKm: '10.00');
    final GeoPoint far = GeoPoint.fromDegrees(41.311081, 69.38);

    expect(area.distanceLabel(far), '11,7');
    expect(area.contains(far), isFalse);
  });

  test('the great-circle distance is symmetric and zero on the spot', () {
    final GeoPoint far = GeoPoint.fromDegrees(41.311081, 69.38);

    expect(greatCircleKm(_centre, _centre), 0);
    expect(greatCircleKm(_centre, far), greatCircleKm(far, _centre));
    expect(greatCircleKm(_centre, far), closeTo(11.646, 0.001));
    // One degree of latitude is about 111.195 km.
    expect(
      greatCircleKm(GeoPoint.fromDegrees(41, 69), GeoPoint.fromDegrees(42, 69)),
      closeTo(earthRadiusKm * 3.141592653589793 / 180, 1e-6),
    );
  });

  test('the radius drops trailing zeros', () {
    ServiceArea of(String radius) =>
        ServiceArea(centre: _centre, radiusKm: radius);

    expect(of('10.00').radiusLabel, '10');
    expect(of('7.50').radiusLabel, '7,5');
    expect(of('12.25').radiusLabel, '12,25');
  });
}
