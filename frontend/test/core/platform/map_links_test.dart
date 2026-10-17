import 'package:baraka_bozor/core/platform/map_links.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Courier's route (`DL-86` (6)): Yandex Navigator first, the same route
/// on Yandex Maps when the Navigator does not open, and `false` only when
/// neither opens, never an error.
void main() {
  const String navigator =
      'yandexnavi://build_route_on_map?lat_to=41.311081&lon_to=69.240562';
  const String maps =
      'https://yandex.uz/maps/?rtext=~41.311081%2C69.240562&rtt=auto';

  test('the Navigator gets a route to the point', () async {
    final List<Uri> opened = <Uri>[];
    final YandexRouteLinks links = YandexRouteLinks(
      launch: (Uri url) async {
        opened.add(url);
        return true;
      },
    );

    expect(await links.open('41.311081', '69.240562'), isTrue);
    expect(opened.map((Uri url) => url.toString()), <String>[navigator]);
  });

  test('without the Navigator the Yandex Maps link opens', () async {
    final List<Uri> opened = <Uri>[];
    final YandexRouteLinks links = YandexRouteLinks(
      launch: (Uri url) async {
        opened.add(url);
        return opened.length > 1;
      },
    );

    expect(await links.open('41.311081', '69.240562'), isTrue);
    expect(opened.map((Uri url) => url.toString()), <String>[navigator, maps]);
  });

  test('a PlatformException counts as not opened', () async {
    final List<Uri> opened = <Uri>[];
    final YandexRouteLinks links = YandexRouteLinks(
      launch: (Uri url) async {
        opened.add(url);
        if (opened.length == 1) {
          throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
        }
        return true;
      },
    );

    expect(await links.open('41.311081', '69.240562'), isTrue);
    expect(opened.last.toString(), maps);
  });

  test('nothing opens either: false', () async {
    expect(
      await YandexRouteLinks(launch: (Uri _) async => false)
          .open('41.311081', '69.240562'),
      isFalse,
    );
    expect(
      await YandexRouteLinks(
        launch: (Uri _) async =>
            throw PlatformException(code: 'ACTIVITY_NOT_FOUND'),
      ).open('41.311081', '69.240562'),
      isFalse,
    );
  });
}
