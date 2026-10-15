import '../../../core/catalog/catalog_values.dart';
import '../../../core/orders/quantity_rules.dart';

/// The steps of the product card's quantity buttons. Any exact quantity is
/// still typed in the cart (`DL-80` (2)).
abstract final class CardQuantity {
  /// Half for units that take fractions, one otherwise.
  static String step(UnitCode unit) => unit.takesFraction ? '0.5' : '1';

  /// [current] plus a step, capped at [QuantityRules.maxWhole].
  static String? next(UnitCode unit, String current) {
    final int now = QuantityRules.thousandths(current);
    // At or past the cap a plus never takes the quantity down.
    if (now >= QuantityRules.maxWhole * 1000) {
      return current;
    }
    final int sum = now + QuantityRules.thousandths(step(unit));
    if (sum >= QuantityRules.maxWhole * 1000) {
      return '${QuantityRules.maxWhole}';
    }
    return _text(unit, sum);
  }

  /// [current] minus a step, or `null` when nothing positive is left: the
  /// line is removed.
  static String? previous(UnitCode unit, String current) {
    final int rest =
        QuantityRules.thousandths(current) -
        QuantityRules.thousandths(step(unit));
    return rest <= 0 ? null : _text(unit, rest);
  }

  static String? _text(UnitCode unit, int thousandths) {
    final int whole = thousandths ~/ 1000;
    final int fraction = thousandths % 1000;
    final String text = fraction == 0
        ? '$whole'
        : '$whole.${fraction.toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '')}';
    return QuantityRules.normalize(unit, text);
  }
}
