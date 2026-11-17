import 'dart:async';

import 'package:baraka_bozor/features/addresses/data/device_location.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';

/// A device location for widget tests: it answers [outcome] at once, or, with
/// [hold], waits for [release]. The silent read answers [silent], or, with
/// [holdSilent], waits for [releaseSilent].
class FakeDeviceLocation implements DeviceLocation {
  /// What the device reports; a failure by default.
  LocationOutcome outcome = const LocationFailed(LocationFailure.failed);

  /// Whether the next reading waits for [release].
  bool hold = false;

  /// How many readings were asked for.
  int calls = 0;

  /// What the silent read answers; `null` when nothing is allowed.
  GeoPoint? silent;

  /// Whether the next silent read waits for [releaseSilent].
  bool holdSilent = false;

  /// How many silent reads were asked for.
  int silentCalls = 0;

  /// How many times the app settings were opened.
  int settingsOpened = 0;

  /// How many times the device location settings were opened.
  int locationSettingsOpened = 0;

  Completer<LocationOutcome>? _pending;
  Completer<GeoPoint?>? _pendingSilent;

  @override
  Future<LocationOutcome> current() {
    calls++;
    if (!hold) {
      return Future<LocationOutcome>.value(outcome);
    }
    return (_pending = Completer<LocationOutcome>()).future;
  }

  /// Answers the held reading.
  void release(LocationOutcome answer) => _pending!.complete(answer);

  @override
  Future<GeoPoint?> currentIfAllowed() {
    silentCalls++;
    if (!holdSilent) {
      return Future<GeoPoint?>.value(silent);
    }
    return (_pendingSilent = Completer<GeoPoint?>()).future;
  }

  /// Answers the held silent read.
  void releaseSilent(GeoPoint? answer) => _pendingSilent!.complete(answer);

  @override
  Future<void> openAppSettings() async => settingsOpened++;

  @override
  Future<void> openLocationSettings() async => locationSettingsOpened++;
}
