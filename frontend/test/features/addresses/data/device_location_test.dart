import 'dart:async';

import 'package:baraka_bozor/features/addresses/data/device_location.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class _FakeGeolocator extends Fake implements GeolocatorPlatform {
  bool servicesOn = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission afterRequest = LocationPermission.whileInUse;
  Completer<Position>? pending;
  Exception? positionError;
  Exception? requestError;
  int requests = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => servicesOn;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    if (requestError != null) {
      throw requestError!;
    }
    return afterRequest;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      positionError != null
      ? Future<Position>.error(positionError!)
      : pending?.future ?? Future<Position>.value(_position);
}

final Position _position = Position(
  latitude: 41.3,
  longitude: 69.25,
  timestamp: DateTime.utc(2026, 10, 17),
  accuracy: 1,
  altitude: 0,
  altitudeAccuracy: 1,
  heading: 0,
  headingAccuracy: 1,
  speed: 0,
  speedAccuracy: 1,
);

void main() {
  late _FakeGeolocator platform;
  late GeolocatorDeviceLocation location;

  setUp(() {
    platform = _FakeGeolocator();
    location = GeolocatorDeviceLocation(platform: platform);
  });

  test('granted gives the point', () async {
    expect(await location.current(), GeoPoint.fromDegrees(41.3, 69.25));
    expect(platform.requests, 0);
  });

  test('asked and denied gives null', () async {
    platform.permission = LocationPermission.denied;
    platform.afterRequest = LocationPermission.denied;

    expect(await location.current(), isNull);
    expect(platform.requests, 1);
  });

  test('asked and granted gives the point', () async {
    platform.permission = LocationPermission.denied;
    platform.afterRequest = LocationPermission.whileInUse;

    expect(await location.current(), GeoPoint.fromDegrees(41.3, 69.25));
  });

  test('denied forever gives null without asking', () async {
    platform.permission = LocationPermission.deniedForever;

    expect(await location.current(), isNull);
    expect(platform.requests, 0);
  });

  test('services off gives null without asking', () async {
    platform.servicesOn = false;

    expect(await location.current(), isNull);
    expect(platform.requests, 0);
  });

  test('services switched off during the reading give null', () async {
    platform.positionError = const LocationServiceDisabledException();

    expect(await location.current(), isNull);
  });

  test('a permission request already in progress gives null', () async {
    platform.permission = LocationPermission.denied;
    platform.requestError = const PermissionRequestInProgressException(
      'in progress',
    );

    expect(await location.current(), isNull);
  });

  testWidgets('a reading over ten seconds gives null', (
    WidgetTester tester,
  ) async {
    platform.pending = Completer<Position>();
    GeoPoint? result = const GeoPoint(latitude: '0', longitude: '0');
    bool done = false;
    unawaited(
      location.current().then((GeoPoint? point) {
        result = point;
        done = true;
      }),
    );

    await tester.pump(const Duration(seconds: 9));
    expect(done, isFalse);
    await tester.pump(const Duration(seconds: 2));

    expect(done, isTrue);
    expect(result, isNull);
  });
}
