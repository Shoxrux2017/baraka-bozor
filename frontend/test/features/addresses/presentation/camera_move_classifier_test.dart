import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/google_address_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const GeoPoint start = GeoPoint(
    latitude: '41.311081',
    longitude: '69.240562',
  );
  const GeoPoint other = GeoPoint(
    latitude: '41.300000',
    longitude: '69.250000',
  );
  late CameraMoveClassifier moves;

  setUp(() => moves = CameraMoveClassifier(start));

  test(
    'an app move whose start arrives after the call returned is not reported',
    () {
      expect(moves.appMoveRequested(other), isTrue);
      // animateCamera returned here; the start comes later.
      moves.moveStarted();
      moves.moved(41.3, 69.25);

      expect(moves.idle(), isNull);
    },
  );

  test('a customer drag after an app move is reported', () {
    moves.appMoveRequested(other);
    moves.moveStarted();
    moves.moved(41.3, 69.25);
    expect(moves.idle(), isNull);

    moves.moveStarted();
    moves.moved(41.31, 69.26);

    expect(moves.idle(), GeoPoint.fromDegrees(41.31, 69.26));
  });

  test('an app move to the current centre is skipped and the next drag is reported', () {
    expect(moves.appMoveRequested(start), isFalse);

    moves.moveStarted();
    moves.moved(41.32, 69.27);

    expect(moves.idle(), GeoPoint.fromDegrees(41.32, 69.27));
  });

  test('a drag is reported with six decimals', () {
    moves.moveStarted();
    moves.moved(41.31234567891, 69.24056249999);

    final GeoPoint? point = moves.idle();

    expect(point?.latitude, '41.312346');
    expect(point?.longitude, '69.240562');
    expect(moves.idle(), isNull);
  });
}
