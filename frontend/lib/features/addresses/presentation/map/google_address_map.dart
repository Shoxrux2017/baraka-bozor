import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/kit_colors.dart';
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

/// The drawing's pin: its tip marks the point, so the icon sits above the
/// centre, with a small shadow under the tip. A drag that starts on it moves
/// the map.
class _CentrePin extends StatelessWidget {
  const _CentrePin({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      alignment: Alignment.center,
      children: <Widget>[
        const SizedBox(
          width: 14,
          height: 6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0x40151D16),
              borderRadius: BorderRadius.all(Radius.elliptical(14, 6)),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: size),
          child: Icon(Icons.location_on, size: size, color: KitColors.primary),
        ),
      ],
    ),
  );
}

/// Tells the application's own camera moves from the Customer's, so the
/// app's move never rounds a stored point (`DL-23` (3)). The plugin's
/// `animateCamera` completes when the call is dispatched, not when the
/// animation ends, so the start of the move is what is classified.
class CameraMoveClassifier {
  CameraMoveClassifier(GeoPoint initial) : _centre = initial;

  GeoPoint _centre;
  bool _appMoveExpected = false;
  bool _customerMove = false;

  /// Whether the camera should be animated to [target]; false when it is
  /// already there, since no camera move would follow.
  bool appMoveRequested(GeoPoint target) {
    if (target == _centre) {
      return false;
    }
    _appMoveExpected = true;
    return true;
  }

  /// A camera move started: the Customer's unless the app asked for it.
  void moveStarted() {
    _customerMove = !_appMoveExpected;
    _appMoveExpected = false;
  }

  /// The camera is at [latitude], [longitude].
  void moved(double latitude, double longitude) {
    _centre = GeoPoint.fromDegrees(latitude, longitude);
  }

  /// The camera came to rest: the point to report, or `null` when the move
  /// was not the Customer's.
  GeoPoint? idle() {
    if (!_customerMove) {
      return null;
    }
    _customerMove = false;
    return _centre;
  }
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
  late final CameraMoveClassifier _moves = CameraMoveClassifier(widget.initial);

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
    if (target == null ||
        controller == null ||
        !_moves.appMoveRequested(target)) {
      return;
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(_latLng(target), 17),
    );
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
            onCameraMoveStarted: _moves.moveStarted,
            onCameraMove: (CameraPosition position) => _moves.moved(
              position.target.latitude,
              position.target.longitude,
            ),
            onCameraIdle: () {
              final GeoPoint? point = _moves.idle();
              if (point != null) {
                widget.onMoved(point);
              }
            },
          ),
          const _CentrePin(size: 48),
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
          const _CentrePin(size: 36),
        ],
      ),
    );
  }
}
