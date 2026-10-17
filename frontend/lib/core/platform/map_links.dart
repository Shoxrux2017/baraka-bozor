import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// A delivery point opened in the phone's own map app (`DL-54` (16)); no
/// staff screen embeds a map (`DL-36` (2)).
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

final Provider<MapLinks> mapLinksProvider = Provider<MapLinks>(
  (Ref ref) => const YandexRouteLinks(),
);
