import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../domain/addresses.dart';

/// The point as two fields, for a build without a MapKit key (`DL-33`).
Widget pointFieldsPicker({
  required GeoPoint initial,
  required ValueChanged<GeoPoint> onMoved,
}) => _PointFields(initial: initial, onMoved: onMoved);

class _PointFields extends StatefulWidget {
  const _PointFields({required this.initial, required this.onMoved});

  final GeoPoint initial;
  final ValueChanged<GeoPoint> onMoved;

  @override
  State<_PointFields> createState() => _PointFieldsState();
}

class _PointFieldsState extends State<_PointFields> {
  static final RegExp _latitude = RegExp(r'^-?\d{1,2}(\.\d{1,6})?$');
  static final RegExp _longitude = RegExp(r'^-?\d{1,3}(\.\d{1,6})?$');

  late final TextEditingController _lat = TextEditingController(
    text: widget.initial.latitude,
  );
  late final TextEditingController _lng = TextEditingController(
    text: widget.initial.longitude,
  );

  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  void _changed(String _) {
    final String lat = _lat.text.trim();
    final String lng = _lng.text.trim();
    if (_latitude.hasMatch(lat) && _longitude.hasMatch(lng)) {
      widget.onMoved(
        GeoPoint.fromDegrees(double.parse(lat), double.parse(lng)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    const TextInputType keyboard = TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.addressMapUnavailable),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('point-latitude'),
            controller: _lat,
            keyboardType: keyboard,
            decoration: InputDecoration(
              labelText: l10n.settingsCentreLatitude,
              border: const OutlineInputBorder(),
            ),
            onChanged: _changed,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('point-longitude'),
            controller: _lng,
            keyboardType: keyboard,
            decoration: InputDecoration(
              labelText: l10n.settingsCentreLongitude,
              border: const OutlineInputBorder(),
            ),
            onChanged: _changed,
          ),
        ],
      ),
    );
  }
}
