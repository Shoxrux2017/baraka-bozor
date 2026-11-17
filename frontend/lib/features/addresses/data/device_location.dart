import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/addresses.dart';

/// Why the device gave no position (`DL-138`).
enum LocationFailure { denied, deniedForever, serviceOff, timedOut, failed }

/// What a reading of the device's position came to.
sealed class LocationOutcome {
  const LocationOutcome();
}

final class LocationFound extends LocationOutcome {
  const LocationFound(this.point);

  final GeoPoint point;
}

final class LocationFailed extends LocationOutcome {
  const LocationFailed(this.reason);

  final LocationFailure reason;
}

/// Where the device is, read only when the Customer asks.
abstract interface class DeviceLocation {
  /// The device's position, or why there is none. The permission is asked
  /// here when it is only denied, and nowhere else.
  Future<LocationOutcome> current();

  /// The position only when the permission is already given and the service
  /// is on; otherwise `null`, every failure included. It never asks.
  Future<GeoPoint?> currentIfAllowed();

  /// Opens this app's page in the system settings.
  Future<void> openAppSettings();

  /// Opens the system's location settings.
  Future<void> openLocationSettings();
}

final class GeolocatorDeviceLocation implements DeviceLocation {
  GeolocatorDeviceLocation({GeolocatorPlatform? platform})
    : _platform = platform ?? GeolocatorPlatform.instance;

  static const Duration _limit = Duration(seconds: 10);

  final GeolocatorPlatform _platform;

  @override
  Future<LocationOutcome> current() async {
    try {
      if (!await _platform.isLocationServiceEnabled()) {
        return const LocationFailed(LocationFailure.serviceOff);
      }
      LocationPermission permission = await _platform.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _platform.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationFailed(LocationFailure.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationFailed(LocationFailure.denied);
      }
      return LocationFound(await _read());
    } on TimeoutException {
      return const LocationFailed(LocationFailure.timedOut);
    } on LocationServiceDisabledException {
      return const LocationFailed(LocationFailure.serviceOff);
    } on PermissionDeniedException {
      return const LocationFailed(LocationFailure.denied);
    } on PlatformException {
      return const LocationFailed(LocationFailure.failed);
    } on PermissionRequestInProgressException {
      return const LocationFailed(LocationFailure.failed);
    } on PermissionDefinitionsNotFoundException {
      return const LocationFailed(LocationFailure.failed);
    } on ActivityMissingException {
      return const LocationFailed(LocationFailure.failed);
    } on PositionUpdateException {
      return const LocationFailed(LocationFailure.failed);
    }
  }

  @override
  Future<GeoPoint?> currentIfAllowed() async {
    try {
      if (!await _platform.isLocationServiceEnabled()) {
        return null;
      }
      final LocationPermission permission = await _platform.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }
      return await _read();
    } on Object {
      return null;
    }
  }

  @override
  Future<void> openAppSettings() async {
    await _platform.openAppSettings();
  }

  @override
  Future<void> openLocationSettings() async {
    await _platform.openLocationSettings();
  }

  Future<GeoPoint> _read() async {
    final Position position = await _platform.getCurrentPosition(
      locationSettings: const LocationSettings(timeLimit: _limit),
    );
    return GeoPoint.fromDegrees(position.latitude, position.longitude);
  }
}

final Provider<DeviceLocation> deviceLocationProvider =
    Provider<DeviceLocation>((Ref ref) => GeolocatorDeviceLocation());
