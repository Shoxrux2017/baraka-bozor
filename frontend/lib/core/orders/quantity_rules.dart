import '../catalog/catalog_values.dart';

/// The quantity a Customer may ask for, as the API takes it (`DL-37` (6),
/// `docs/09` section 17): for `kg`, `liter` and `meter` up to four digits
/// and three decimals, otherwise a whole number of up to four digits, and
/// always above zero. The client checks it to say so early; the server
/// decides. Quantities stay strings end to end, never floating point.
abstract final class QuantityRules {
  static final RegExp _fraction = RegExp(r'^\d{1,4}(\.\d{1,3})?$');
  static final RegExp _whole = RegExp(r'^\d{1,4}$');

  /// The largest whole quantity.
  static const int maxWhole = 9999;

  /// [text] as the API takes it — trimmed, the decimal comma of an Uzbek or
  /// Russian keyboard read as a point — or `null` when it is no quantity of
  /// [unit].
  static String? normalize(UnitCode unit, String text) {
    final String value = text.trim().replaceAll(',', '.');
    final RegExp shape = unit.takesFraction ? _fraction : _whole;
    if (!shape.hasMatch(value) || thousandths(value) == 0) {
      return null;
    }
    return value;
  }

  /// [quantity] as a person reads it in Uzbek and Russian: the decimal
  /// comma, and no trailing zeros — `1.500` is `1,5`, `2.000` is `2`.
  static String display(String quantity) {
    if (!quantity.contains('.')) {
      return quantity;
    }
    final String trimmed = quantity.replaceFirst(RegExp(r'\.?0+$'), '');
    return trimmed.replaceAll('.', ',');
  }

  /// [quantity], a decimal string of this shape, in thousandths.
  static int thousandths(String quantity) {
    final List<String> parts = quantity.split('.');
    final int whole = int.parse(parts[0]);
    final String fraction = parts.length > 1 ? parts[1].padRight(3, '0') : '0';
    return whole * 1000 + int.parse(fraction);
  }
}
