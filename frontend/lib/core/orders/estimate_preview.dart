import 'quantity_rules.dart';

/// A preview of what a line will cost, shown before the server prices it.
/// The cart and the order always keep the server's figures.
abstract final class EstimatePreview {
  /// `half_up(unitPriceUzs × quantity)` in whole sum (`BR-MONEY-003`),
  /// worked in integers: [quantity] is a decimal string of at most three
  /// decimals, so the product in thousandths is exact.
  static int lineUzs(int unitPriceUzs, String quantity) {
    final int thousandths = unitPriceUzs * QuantityRules.thousandths(quantity);
    return (thousandths + 500) ~/ 1000;
  }
}
