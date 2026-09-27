import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/addresses.dart';
import 'point_fields.dart';
import 'yandex_map_picker_stub.dart'
    if (dart.library.io) 'yandex_map_picker.dart';

/// Builds the widget where the Customer puts the pin: [initial] where it
/// starts, [onMoved] each time it comes to rest somewhere else, and
/// [enabled] false while the form is saving. It sizes itself.
typedef MapPickerBuilder = Widget Function({
  required GeoPoint initial,
  required bool enabled,
  required ValueChanged<GeoPoint> onMoved,
});

/// The MapKit key given to the build (`--dart-define`), never committed.
const String mapKitApiKey = String.fromEnvironment('YANDEX_MAPKIT_API_KEY');

/// Where the pin starts when the Customer has no address yet: the centre of
/// Tashkent.
const GeoPoint defaultMapCentre = GeoPoint(
  latitude: '41.311081',
  longitude: '69.240562',
);

/// The picker in use: the Yandex map on a phone built with a key; without
/// one — a development build, the web panel's compile — the coordinates as
/// two fields, so an address can still be saved (`DL-33`). Tests put a fake
/// here.
final Provider<MapPickerBuilder> mapPickerProvider = Provider<MapPickerBuilder>(
  (Ref ref) => mapKitApiKey.isNotEmpty && yandexMapSupported
      ? yandexMapPicker
      : pointFieldsPicker,
);
