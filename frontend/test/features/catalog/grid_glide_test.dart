import 'package:baraka_bozor/features/catalog/presentation/grid_glide.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gridCellPlace puts a card by its row and column', () {
    final GridCellPlace place = gridCellPlace(
      columns: 2,
      cellWidth: 100,
      rowExtent: 200,
    );
    expect(place(0), const Offset(0, 0));
    expect(place(1), const Offset(100, 0));
    expect(place(2), const Offset(0, 200));
    expect(place(5), const Offset(100, 400));
  });

  test('not-sold cards start a row under the heading', () {
    final GridCellPlace place = gridCellPlace(
      columns: 2,
      cellWidth: 100,
      rowExtent: 200,
      tailStart: 3,
      tailTop: 50,
    );
    // Three sold cards fill two rows; the tail starts under the heading.
    expect(place(2), const Offset(0, 200));
    expect(place(3), const Offset(0, 450));
    expect(place(4), const Offset(100, 450));
    expect(place(5), const Offset(0, 650));
  });

  test('glideOffsets gives each moved card its old place less its new one', () {
    final GridCellPlace place = gridCellPlace(
      columns: 2,
      cellWidth: 100,
      rowExtent: 200,
    );
    final Map<String, Offset> offsets = glideOffsets(
      before: <String>['a', 'b', 'c', 'd'],
      after: <String>['a', 'c', 'd'],
      placeBefore: place,
      placeAfter: place,
    );
    expect(offsets['c'], const Offset(0, 200) - const Offset(100, 0));
    expect(offsets['d'], const Offset(100, 200) - const Offset(0, 200));
    expect(offsets.containsKey('b'), isFalse);
  });

  test('a card that kept its place gets no offset', () {
    final GridCellPlace place = gridCellPlace(
      columns: 2,
      cellWidth: 100,
      rowExtent: 200,
    );
    final Map<String, Offset> offsets = glideOffsets(
      before: <String>['a', 'b', 'c'],
      after: <String>['a', 'b', 'x', 'c'],
      placeBefore: place,
      placeAfter: place,
    );
    expect(offsets.containsKey('a'), isFalse);
    expect(offsets.containsKey('b'), isFalse);
    expect(offsets.containsKey('x'), isFalse, reason: 'a new card arrives');
  });
}
