import 'package:baraka_bozor/core/layout/text_width.dart';
import 'package:baraka_bozor/features/catalog/presentation/category_tile.dart';
import 'package:baraka_bozor/features/catalog/presentation/recommended_row.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/nonlinear_text_scaler.dart';

/// Layout sizes that follow the text read the factor at the text's own size
/// (`DL-126`).
void main() {
  const NonlinearTextScaler android = NonlinearTextScaler(2);

  test('the factor is read at the font size given', () {
    expect(textScaleAt(const TextScaler.linear(2), 12), 2);
    expect(textScaleAt(const TextScaler.linear(2), 150), 2);
    expect(textScaleAt(android, 12), closeTo(1.88, 0.001));
    expect(textScaleAt(android, 150), 1);
    expect(textScaleAt(TextScaler.noScaling, 12), 1);
  });

  test(
    'categories stand in two columns at 200 % on Android, four at 100 %',
    () {
      expect(categoryColumns(375, android), 2);
      expect(categoryColumns(375, TextScaler.noScaling), 4);
      expect(categoryColumns(375, const NonlinearTextScaler(1)), 4);
      expect(categoryColumns(375, const TextScaler.linear(2)), 2);
    },
  );

  test('recommended cards are 260 wide at 200 % on Android, 150 at 100 %', () {
    expect(RecommendedRow.cardWidth(android), 260);
    expect(RecommendedRow.cardWidth(TextScaler.noScaling), 150);
    expect(RecommendedRow.cardWidth(const TextScaler.linear(2)), 260);
  });
}
