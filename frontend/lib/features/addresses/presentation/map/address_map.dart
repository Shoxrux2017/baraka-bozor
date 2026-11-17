import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/address_search.dart';
import '../../domain/addresses.dart';
import 'google_address_map.dart';
import 'point_fields_address_map.dart';

/// Asks a shown map to move: the typed-address search and "где я" use it.
class PointMapMover extends ChangeNotifier {
  GeoPoint? _target;

  GeoPoint? get target => _target;

  void moveTo(GeoPoint point) {
    _target = point;
    notifyListeners();
  }
}

/// Where the Customer puts the delivery point: a real map, or, where there is
/// none, the coordinates as fields. Tests put a fake here.
abstract interface class AddressMap {
  /// A real map the camera of which can be moved; false for the coordinate
  /// fields.
  bool get movable;

  /// Fills its parent and draws no pin: the step owns it. [onMoveStarted]
  /// fires when the Customer's own move starts, never for a move [mover]
  /// asked for; [onMoved] reports the point under the pin each time such a
  /// move comes to rest. The [zone], when given, is drawn on the map
  /// (`DL-138`).
  Widget picker({
    required GeoPoint initial,
    required PointMapMover mover,
    required bool enabled,
    required VoidCallback onMoveStarted,
    required ValueChanged<GeoPoint> onMoved,
    ServiceArea? zone,
  });

  /// A still map centred on [point] with the pin, sized by its parent.
  Widget preview({required GeoPoint point});
}

/// The Google Maps key given to the build (`--dart-define`), never committed.
const String googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

/// Where the pin starts when the Customer has no address yet: the centre of
/// Tashkent.
const GeoPoint defaultMapCentre = GeoPoint(
  latitude: '41.311081',
  longitude: '69.240562',
);

/// Google Maps is wired for Android only; the web and iOS take the point as
/// coordinates (`DL-86` (2)).
bool get _googleMapSupported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// The map in use: Google when the build has a key and runs on Android, the
/// coordinate fields otherwise, so an address can still be saved.
final Provider<AddressMap> addressMapProvider = Provider<AddressMap>(
  (Ref ref) => googleMapsApiKey.isNotEmpty && _googleMapSupported
      ? const GoogleAddressMap()
      : const PointFieldsAddressMap(),
);
