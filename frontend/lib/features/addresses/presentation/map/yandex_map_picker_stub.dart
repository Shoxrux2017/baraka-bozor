import 'package:flutter/widgets.dart';

import '../../domain/addresses.dart';

/// The web build, where MapKit has no implementation and the addresses are
/// never shown: the map is not offered.
const bool yandexMapSupported = false;

Widget yandexMapPicker({
  required GeoPoint initial,
  required bool enabled,
  required ValueChanged<GeoPoint> onMoved,
}) => throw UnsupportedError('Yandex MapKit is not available on the web');
