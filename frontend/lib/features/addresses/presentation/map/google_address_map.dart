import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/addresses.dart';
import 'address_map.dart';

/// The Google map, on Android with a key. Google's SDK starts only when a map
/// is shown (`DL-86` (2)).
final class GoogleAddressMap implements AddressMap {
  const GoogleAddressMap();

  @override
  bool get movable => true;

  @override
  Widget picker({
    required GeoPoint initial,
    required PointMapMover mover,
    required bool enabled,
    required ValueChanged<GeoPoint> onMoved,
  }) => _GooglePicker(
    initial: initial,
    mover: mover,
    enabled: enabled,
    onMoved: onMoved,
  );

  @override
  Widget preview({required GeoPoint point}) => _GooglePreview(point: point);
}

LatLng _latLng(GeoPoint point) =>
    LatLng(point.latitudeDegrees, point.longitudeDegrees);

/// The pin's tip marks the point, so the icon sits above the centre; a drag
/// that starts on it moves the map.
class _CentrePin extends StatelessWidget {
  const _CentrePin();

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: Padding(
      padding: EdgeInsets.only(bottom: 40),
      child: Icon(Icons.location_pin, size: 48),
    ),
  );
}

/// The map with a pin fixed at its centre: the Customer moves the map until
/// the pin stands on the door, and the point under the pin is read back when
/// the map comes to rest.
class _GooglePicker extends StatefulWidget {
  const _GooglePicker({
    required this.initial,
    required this.mover,
    required this.enabled,
    required this.onMoved,
  });

  final GeoPoint initial;
  final PointMapMover mover;
  final bool enabled;
  final ValueChanged<GeoPoint> onMoved;

  @override
  State<_GooglePicker> createState() => _GooglePickerState();
}

class _GooglePickerState extends State<_GooglePicker> {
  GoogleMapController? _controller;
  LatLng? _centre;

  /// A move the application asked for is running: it is not the Customer's,
  /// so it never rounds a stored point (`DL-23` (3)).
  bool _appMoving = false;
  bool _customerMoving = false;

  @override
  void initState() {
    super.initState();
    widget.mover.addListener(_moverMoved);
  }

  @override
  void didUpdateWidget(_GooglePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mover != widget.mover) {
      oldWidget.mover.removeListener(_moverMoved);
      widget.mover.addListener(_moverMoved);
    }
  }

  @override
  void dispose() {
    widget.mover.removeListener(_moverMoved);
    super.dispose();
  }

  Future<void> _moverMoved() async {
    final GeoPoint? target = widget.mover.target;
    final GoogleMapController? controller = _controller;
    if (target == null || controller == null) {
      return;
    }
    _appMoving = true;
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(_latLng(target), 17),
      );
    } finally {
      _appMoving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: !widget.enabled,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _latLng(widget.initial),
              zoom: 16,
            ),
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            // The map takes every drag that starts on it: inside the form's
            // list, a vertical one would otherwise scroll the form.
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
            },
            onMapCreated: (GoogleMapController controller) =>
                _controller = controller,
            onCameraMoveStarted: () => _customerMoving = !_appMoving,
            onCameraMove: (CameraPosition position) =>
                _centre = position.target,
            onCameraIdle: () {
              final LatLng? centre = _centre;
              if (_customerMoving && centre != null) {
                _customerMoving = false;
                widget.onMoved(
                  GeoPoint.fromDegrees(centre.latitude, centre.longitude),
                );
              }
            },
          ),
          const _CentrePin(),
        ],
      ),
    );
  }
}

/// A still map centred on the point, with the pin; the Google logo is left
/// uncovered.
class _GooglePreview extends StatelessWidget {
  const _GooglePreview({required this.point});

  final GeoPoint point;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          GoogleMap(
            key: ValueKey<GeoPoint>(point),
            initialCameraPosition: CameraPosition(
              target: _latLng(point),
              zoom: 16,
            ),
            liteModeEnabled: true,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            scrollGesturesEnabled: false,
            zoomGesturesEnabled: false,
          ),
          const _CentrePin(),
        ],
      ),
    );
  }
}
