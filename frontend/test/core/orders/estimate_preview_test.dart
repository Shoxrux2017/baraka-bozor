import 'package:baraka_bozor/core/orders/estimate_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('previews price times quantity, rounded half up', () {
    expect(EstimatePreview.lineUzs(12075, '1'), 12075);
    expect(EstimatePreview.lineUzs(12075, '1.5'), 18113);
    expect(EstimatePreview.lineUzs(21850, '2'), 43700);
    expect(EstimatePreview.lineUzs(999, '0.001'), 1);
    expect(EstimatePreview.lineUzs(1, '0.499'), 0);
    expect(EstimatePreview.lineUzs(4945, '3'), 14835);
  });
}
