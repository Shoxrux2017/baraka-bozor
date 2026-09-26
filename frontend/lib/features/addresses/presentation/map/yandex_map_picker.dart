import 'dart:io' show Platform;

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
  required ValueChanged<GeoPoint> onMoved,
}) => _YandexMapPicker(initial: initial, onMoved: onMoved);

class _YandexMapPicker extends StatelessWidget {
  const _YandexMapPicker({required this.initial, required this.onMoved});

  final GeoPoint initial;
  final ValueChanged<GeoPoint> onMoved;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        YandexMap(
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
              (CameraPosition position, CameraUpdateReason _, bool finished) {
                if (finished) {
                  onMoved(
                    GeoPoint.fromDegrees(
                      position.target.latitude,
                      position.target.longitude,
                    ),
                  );
                }
              },
        ),
        // The pin's tip marks the point, so the icon sits above the centre.
        const Padding(
          padding: EdgeInsets.only(bottom: 40),
          child: Icon(Icons.location_pin, size: 48),
        ),
      ],
    );
  }
}
