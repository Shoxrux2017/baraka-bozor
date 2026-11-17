import 'package:baraka_bozor/features/addresses/domain/address_search.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/address_map.dart';
import 'package:flutter/material.dart';

/// The point [FakeAddressMap]'s move button reports.
const GeoPoint fakeDoor = GeoPoint(
  latitude: '41.300000',
  longitude: '69.250000',
);

/// The point [FakeAddressMap]'s far button reports: outside any city zone.
const GeoPoint fakeFar = GeoPoint(
  latitude: '41.311081',
  longitude: '69.380000',
);

/// A map for widget tests: it shows where the pin starts, moves the pin to
/// [fakeDoor] on a tap, and shows where it was asked to move.
class FakeAddressMap implements AddressMap {
  FakeAddressMap({this.movable = true});

  @override
  final bool movable;

  ValueChanged<GeoPoint>? _onMoved;

  /// The zone the step last gave the map.
  ServiceArea? zone;

  /// Reports a move the way a camera event does: no finger on the map.
  void emitMove(GeoPoint point) => _onMoved!(point);

  @override
  Widget picker({
    required GeoPoint initial,
    required PointMapMover mover,
    required bool enabled,
    required VoidCallback onMoveStarted,
    required ValueChanged<GeoPoint> onMoved,
    ServiceArea? zone,
  }) {
    _onMoved = onMoved;
    this.zone = zone;
    return ListenableBuilder(
      listenable: mover,
      builder: (BuildContext context, Widget? child) => Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${initial.latitude},${initial.longitude}',
                key: const ValueKey<String>('fake-map-initial'),
              ),
              TextButton(
                key: const ValueKey<String>('fake-map-move'),
                onPressed: enabled
                    ? () {
                        onMoveStarted();
                        onMoved(fakeDoor);
                      }
                    : null,
                child: const Text('move'),
              ),
              TextButton(
                key: const ValueKey<String>('fake-map-start'),
                onPressed: enabled ? onMoveStarted : null,
                child: const Text('start'),
              ),
              TextButton(
                key: const ValueKey<String>('fake-map-far'),
                onPressed: enabled
                    ? () {
                        onMoveStarted();
                        onMoved(fakeFar);
                      }
                    : null,
                child: const Text('far'),
              ),
              Text(
                mover.target == null
                    ? ''
                    : '${mover.target!.latitude},${mover.target!.longitude}',
                key: const ValueKey<String>('fake-map-target'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget preview({required GeoPoint point}) => Text(
    '${point.latitude},${point.longitude}',
    key: const ValueKey<String>('fake-map-preview'),
  );
}
