import 'package:flutter/widgets.dart';

import '../../domain/address_search.dart';
import '../../domain/addresses.dart';
import 'address_map.dart';
import 'point_fields.dart';

/// The point as two fields (`DL-33`): the map for a build without a key, the
/// web and iOS.
final class PointFieldsAddressMap implements AddressMap {
  const PointFieldsAddressMap();

  @override
  bool get movable => false;

  @override
  Widget picker({
    required GeoPoint initial,
    required PointMapMover mover,
    required bool enabled,
    required VoidCallback onMoveStarted,
    required ValueChanged<GeoPoint> onMoved,
    ServiceArea? zone,
  }) => pointFieldsPicker(initial: initial, enabled: enabled, onMoved: onMoved);

  @override
  Widget preview({required GeoPoint point}) =>
      Text('${point.latitude}, ${point.longitude}');
}
