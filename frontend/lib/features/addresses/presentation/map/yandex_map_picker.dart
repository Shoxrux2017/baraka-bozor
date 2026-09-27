import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../../domain/addresses.dart';

/// Android and iOS have the MapKit SDK.
bool get yandexMapSupported => Platform.isAndroid || Platform.isIOS;

/// The Yandex map with a pin fixed at its centre: the Customer moves the map
/// until the pin stands on the door, and the point under the pin is read
/// back when the map comes to rest.
Widget yandexMapPicker({
  required GeoPoint initial,
  required bool enabled,
  required ValueChanged<GeoPoint> onMoved,
}) => _YandexMapPicker(initial: initial, enabled: enabled, onMoved: onMoved);

class _YandexMapPicker extends StatelessWidget {
  const _YandexMapPicker({
    required this.initial,
    required this.enabled,
    required this.onMoved,
  });

  static const double height = 280;

  final GeoPoint initial;
  final bool enabled;
  final ValueChanged<GeoPoint> onMoved;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: AbsorbPointer(
        absorbing: !enabled,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            YandexMap(
              // The map takes every drag that starts on it: inside the
              // form's list, a vertical one would otherwise scroll the form.
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  EagerGestureRecognizer.new,
                ),
              },
              onMapCreated: (YandexMapController controller) =>
                  controller.moveCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: Point(
                          latitude: initial.latitudeDegrees,
                          longitude: initial.longitudeDegrees,
                        ),
                        zoom: 16,
                      ),
                    ),
                  ),
              onCameraPositionChanged:
                  (
                    CameraPosition position,
                    CameraUpdateReason reason,
                    bool finished,
                  ) {
                    // Only the Customer's own moves count: the first camera
                    // move, the application's, must not change a stored
                    // point by a rounding (`DL-23` (3)).
                    if (finished && reason == CameraUpdateReason.gestures) {
                      onMoved(
                        GeoPoint.fromDegrees(
                          position.target.latitude,
                          position.target.longitude,
                        ),
                      );
                    }
                  },
            ),
            // The pin's tip marks the point, so the icon sits above the
            // centre; a drag that starts on it moves the map.
            const IgnorePointer(
              child: Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Icon(Icons.location_pin, size: 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
