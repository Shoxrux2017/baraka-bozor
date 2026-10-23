import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// A delivery point opened in the phone's own map app (`DL-54` (16)): the
/// route to the point in the Courier's Yandex app (`DL-84` item 3, `DL-86`
/// (6)); no staff screen embeds a map.
abstract interface class MapLinks {
  /// Opens the point at [latitude], [longitude] — six-decimal strings, as
  /// the API carries them; `false` when nothing on the device opens it, and
  /// the screen then says so.
  Future<bool> open(String latitude, String longitude);
}

Future<bool> _launchExternal(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

/// The route to the point in Yandex (`DL-86` (6)): Yandex Navigator first,
/// and, when it does not open, the same route on Yandex Maps, which the app
/// or the browser opens.
class YandexRouteLinks implements MapLinks {
  const YandexRouteLinks({this.launch = _launchExternal});

  /// Opens a link on the device, outside the app; for tests it is injected.
  final Future<bool> Function(Uri url) launch;

  @override
  Future<bool> open(String latitude, String longitude) async {
    if (await _tried(
      Uri.parse(
        'yandexnavi://build_route_on_map?lat_to=$latitude&lon_to=$longitude',
      ),
    )) {
      return true;
    }
    return _tried(
      Uri.parse(
        'https://yandex.uz/maps/?rtext=~$latitude%2C$longitude&rtt=auto',
      ),
    );
  }

  Future<bool> _tried(Uri url) async {
    try {
      return await launch(url);
    } on PlatformException {
      return false;
    }
  }
}

/// A point shown on Google Maps in a new tab or the device's map app (`DL-102`
/// (6)): a plain search link, with no key and no embedded map.
class GoogleMapsPointLinks implements MapLinks {
  const GoogleMapsPointLinks({this.launch = _launchExternal});

  /// Opens a link on the device, outside the app; for tests it is injected.
  final Future<bool> Function(Uri url) launch;

  @override
  Future<bool> open(String latitude, String longitude) async {
    try {
      return await launch(
        Uri.parse(
          'https://www.google.com/maps/search/?api=1'
          '&query=$latitude%2C$longitude',
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}

final Provider<MapLinks> mapLinksProvider = Provider<MapLinks>(
  (Ref ref) => const YandexRouteLinks(),
);

/// How the Admin's settings show the service centre on a map.
final Provider<MapLinks> mapPointLinksProvider = Provider<MapLinks>(
  (Ref ref) => const GoogleMapsPointLinks(),
);
