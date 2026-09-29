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

/// The map app through a `geo:` link, which Android hands to whichever map
/// app the Courier uses; the point is also the query, so the app puts a pin
/// on it rather than only centring there.
class GeoMapLinks implements MapLinks {
  const GeoMapLinks({this.launch = launchUrl});

  /// Opens a link on the device; `url_launcher`'s own, but for tests.
  final Future<bool> Function(Uri url) launch;

  @override
  Future<bool> open(String latitude, String longitude) async {
    try {
      return await launch(
        Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude'),
      );
    } on PlatformException {
      return false;
    }
  }
}

final Provider<MapLinks> mapLinksProvider = Provider<MapLinks>(
  (Ref ref) => const GeoMapLinks(),
);
