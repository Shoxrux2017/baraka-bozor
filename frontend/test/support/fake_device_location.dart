import 'dart:async';

import 'package:baraka_bozor/features/addresses/data/device_location.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';

/// A device location for widget tests: it answers [point] at once, or, with
/// [hold], waits for [release].
class FakeDeviceLocation implements DeviceLocation {
  /// What the device reports; `null` is a refusal.
  GeoPoint? point;

  /// Whether the next reading waits for [release].
  bool hold = false;

  /// How many readings were asked for.
  int calls = 0;

  Completer<GeoPoint?>? _pending;

  @override
  Future<GeoPoint?> current() {
    calls++;
    if (!hold) {
      return Future<GeoPoint?>.value(point);
    }
    return (_pending = Completer<GeoPoint?>()).future;
  }

  /// Answers the held reading.
  void release(GeoPoint? answer) => _pending!.complete(answer);
}
