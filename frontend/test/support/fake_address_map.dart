import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/address_map.dart';
import 'package:flutter/material.dart';

/// The point [FakeAddressMap]'s move button reports.
const GeoPoint fakeDoor = GeoPoint(
  latitude: '41.300000',
  longitude: '69.250000',
);

/// A map for widget tests: it shows where the pin starts, moves the pin to
/// [fakeDoor] on a tap, and shows where it was asked to move.
class FakeAddressMap implements AddressMap {
  FakeAddressMap({this.movable = true});

  @override
  final bool movable;

  ValueChanged<GeoPoint>? _onMoved;

  /// Reports a move the way a camera event does: no finger on the map.
  void emitMove(GeoPoint point) => _onMoved!(point);

  @override
  Widget picker({
    required GeoPoint initial,
    required PointMapMover mover,
    required bool enabled,
    required ValueChanged<GeoPoint> onMoved,
  }) {
    _onMoved = onMoved;
    return ListenableBuilder(
      listenable: mover,
      builder: (BuildContext context, Widget? child) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            '${initial.latitude},${initial.longitude}',
            key: const ValueKey<String>('fake-map-initial'),
          ),
          TextButton(
            key: const ValueKey<String>('fake-map-move'),
            onPressed: enabled ? () => onMoved(fakeDoor) : null,
            child: const Text('move'),
          ),
          Text(
            mover.target == null
                ? ''
                : '${mover.target!.latitude},${mover.target!.longitude}',
            key: const ValueKey<String>('fake-map-target'),
          ),
        ],
      ),
    );
  }

  @override
  Widget preview({required GeoPoint point}) => Text(
    '${point.latitude},${point.longitude}',
    key: const ValueKey<String>('fake-map-preview'),
  );
}
