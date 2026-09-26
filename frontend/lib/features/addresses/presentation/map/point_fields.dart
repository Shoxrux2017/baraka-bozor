import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../domain/addresses.dart';

/// The point as two fields, for a build without a MapKit key (`DL-33`).
/// They belong to the address form: a field that is empty or not a
/// coordinate stops the save, so the point sent is always the one shown.
Widget pointFieldsPicker({
  required GeoPoint initial,
  required bool enabled,
  required ValueChanged<GeoPoint> onMoved,
}) => _PointFields(initial: initial, enabled: enabled, onMoved: onMoved);

class _PointFields extends StatefulWidget {
  const _PointFields({
    required this.initial,
    required this.enabled,
    required this.onMoved,
  });

  final GeoPoint initial;
  final bool enabled;
  final ValueChanged<GeoPoint> onMoved;

  @override
  State<_PointFields> createState() => _PointFieldsState();
}

class _PointFieldsState extends State<_PointFields> {
  static final RegExp _number = RegExp(r'^-?\d{1,3}(\.\d+)?$');

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

  /// [text] as degrees within [limit], written with a dot or with the comma
  /// an Uzbek or Russian keyboard gives; `null` when it is not one.
  static double? _degrees(String text, double limit) {
    final String value = text.trim().replaceAll(',', '.');
    if (!_number.hasMatch(value)) {
      return null;
    }
    final double degrees = double.parse(value);
    return degrees.abs() <= limit ? degrees : null;
  }

  void _changed(String _) {
    final double? lat = _degrees(_lat.text, 90);
    final double? lng = _degrees(_lng.text, 180);
    if (lat != null && lng != null) {
      // Written with six decimals, as the API keeps it.
      widget.onMoved(GeoPoint.fromDegrees(lat, lng));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    const TextInputType keyboard = TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    );

    Widget field(
      String key,
      TextEditingController controller,
      String label,
      double limit,
      String invalid,
    ) {
      return TextFormField(
        key: ValueKey<String>(key),
        controller: controller,
        enabled: widget.enabled,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: _changed,
        validator: (String? text) => (text ?? '').trim().isEmpty
            ? l10n.fieldRequired
            : _degrees(text!, limit) == null
            ? invalid
            : null,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.addressMapUnavailable),
        const SizedBox(height: 12),
        field(
          'point-latitude',
          _lat,
          l10n.addressLatitude,
          90,
          l10n.addressLatitudeInvalid,
        ),
        const SizedBox(height: 12),
        field(
          'point-longitude',
          _lng,
          l10n.addressLongitude,
          180,
          l10n.addressLongitudeInvalid,
        ),
      ],
    );
  }
}
