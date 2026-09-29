import 'package:baraka_bozor/core/platform/map_links.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The map app's link (`DL-54` (16), `DL-72`): a `geo:` link to the point
/// as the API gives it, pinned by its query, and a phone that cannot open it
/// answered as `false`, never as an error.
void main() {
  test('the point is a geo: link that pins it', () async {
    final List<Uri> opened = <Uri>[];
    final GeoMapLinks maps = GeoMapLinks(
      launch: (Uri url) async {
        opened.add(url);
        return true;
      },
    );

    expect(await maps.open('41.311081', '-69.240562'), isTrue);
    expect(
      opened.single.toString(),
      'geo:41.311081,-69.240562?q=41.311081,-69.240562',
    );
    expect(opened.single.scheme, 'geo');
  });

  test('a phone that cannot open it answers false', () async {
    expect(
      await GeoMapLinks(launch: (Uri _) async => false)
          .open('41.311081', '69.240562'),
      isFalse,
    );
    expect(
      await GeoMapLinks(
        launch: (Uri _) async =>
            throw PlatformException(code: 'ACTIVITY_NOT_FOUND'),
      ).open('41.311081', '69.240562'),
      isFalse,
    );
  });
}
