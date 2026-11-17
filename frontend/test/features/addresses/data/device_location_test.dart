import 'dart:async';

import 'package:baraka_bozor/features/addresses/data/device_location.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class _FakeGeolocator extends Fake implements GeolocatorPlatform {
  bool servicesOn = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission afterRequest = LocationPermission.whileInUse;
  Exception? positionError;
  Exception? requestError;
  int requests = 0;
  int appSettingsOpened = 0;
  int locationSettingsOpened = 0;
  LocationSettings? settings;

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
  Future<bool> openAppSettings() async {
    appSettingsOpened++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened++;
    return true;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    settings = locationSettings;
    return positionError != null
        ? Future<Position>.error(positionError!)
        : Future<Position>.value(_position);
  }
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

  Future<void> expectFailure(LocationFailure reason) async {
    final LocationOutcome outcome = await location.current();
    expect(outcome, isA<LocationFailed>());
    expect((outcome as LocationFailed).reason, reason);
  }

  test('granted gives the point', () async {
    final LocationOutcome outcome = await location.current();

    expect(outcome, isA<LocationFound>());
    expect((outcome as LocationFound).point, GeoPoint.fromDegrees(41.3, 69.25));
    expect(platform.requests, 0);
  });

  test('asked and granted gives the point', () async {
    platform.permission = LocationPermission.denied;
    platform.afterRequest = LocationPermission.whileInUse;

    expect(await location.current(), isA<LocationFound>());
    expect(platform.requests, 1);
  });

  test('service off is said as off', () async {
    platform.servicesOn = false;

    await expectFailure(LocationFailure.serviceOff);
    expect(platform.requests, 0);
  });

  test('services switched off during the reading are said as off', () async {
    platform.positionError = const LocationServiceDisabledException();

    await expectFailure(LocationFailure.serviceOff);
  });

  test('a refusal forever is said as such, also after asking', () async {
    platform.permission = LocationPermission.deniedForever;
    await expectFailure(LocationFailure.deniedForever);
    expect(platform.requests, 0);

    platform.permission = LocationPermission.denied;
    platform.afterRequest = LocationPermission.deniedForever;
    await expectFailure(LocationFailure.deniedForever);
    expect(platform.requests, 1);
  });

  test('a refusal now is denied', () async {
    platform.permission = LocationPermission.denied;
    platform.afterRequest = LocationPermission.denied;

    await expectFailure(LocationFailure.denied);
    expect(platform.requests, 1);
  });

  test('ten seconds without a fix is timed out', () async {
    platform.positionError = TimeoutException('too long');

    await expectFailure(LocationFailure.timedOut);
  });

  test('the reading asks for a ten-second limit', () async {
    await location.current();

    expect(platform.settings?.timeLimit, const Duration(seconds: 10));
  });

  test('any other failure is failed', () async {
    platform.positionError = PlatformException(code: 'boom');
    await expectFailure(LocationFailure.failed);

    platform.positionError = const PositionUpdateException('lost');
    await expectFailure(LocationFailure.failed);

    platform.positionError = null;
    platform.permission = LocationPermission.denied;
    platform.requestError = const PermissionRequestInProgressException('busy');
    await expectFailure(LocationFailure.failed);
  });

  test('the silent read never asks', () async {
    platform.permission = LocationPermission.denied;

    expect(await location.currentIfAllowed(), isNull);
    expect(platform.requests, 0);
  });

  test('the silent read answers when already allowed', () async {
    expect(
      await location.currentIfAllowed(),
      GeoPoint.fromDegrees(41.3, 69.25),
    );
    expect(platform.requests, 0);
  });

  test('the silent read gives null for every failure', () async {
    platform.servicesOn = false;
    expect(await location.currentIfAllowed(), isNull);

    platform.servicesOn = true;
    platform.positionError = TimeoutException('too long');
    expect(await location.currentIfAllowed(), isNull);
  });

  test('settings open through the platform', () async {
    await location.openAppSettings();
    await location.openLocationSettings();

    expect(platform.appSettingsOpened, 1);
    expect(platform.locationSettingsOpened, 1);
  });
}
