import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/addresses.dart';

/// Where the device is, read only when the Customer asks.
abstract interface class DeviceLocation {
  /// The device's position; `null` when location services are off, the
  /// permission is refused, the reading takes over ten seconds, or the
  /// platform fails. The permission is asked here and nowhere else.
  Future<GeoPoint?> current();
}

final class GeolocatorDeviceLocation implements DeviceLocation {
  GeolocatorDeviceLocation({GeolocatorPlatform? platform})
    : _platform = platform ?? GeolocatorPlatform.instance;

  static const Duration _limit = Duration(seconds: 10);

  final GeolocatorPlatform _platform;

  @override
  Future<GeoPoint?> current() async {
    try {
      if (!await _platform.isLocationServiceEnabled()) {
        return null;
      }
      LocationPermission permission = await _platform.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _platform.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final Position position = await _platform.getCurrentPosition().timeout(
        _limit,
      );
      return GeoPoint.fromDegrees(position.latitude, position.longitude);
    } on TimeoutException {
      return null;
    } on PlatformException {
      return null;
    } on LocationServiceDisabledException {
      return null;
    } on PermissionDeniedException {
      return null;
    } on PermissionRequestInProgressException {
      return null;
    } on PermissionDefinitionsNotFoundException {
      return null;
    } on ActivityMissingException {
      return null;
    } on PositionUpdateException {
      return null;
    }
  }
}

final Provider<DeviceLocation> deviceLocationProvider =
    Provider<DeviceLocation>((Ref ref) => GeolocatorDeviceLocation());
