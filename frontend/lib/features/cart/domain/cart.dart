import '../../../core/catalog/catalog_values.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';

/// The Customer's active cart (`docs/09` section 17): its lines at the
/// current prices and the estimate of their subtotal, as the server
/// computed it — the client never sums money (`DL-37` (19)).
final class Cart {
  const Cart({
    required this.id,
    required this.lines,
    required this.estimatedSubtotalUzs,
  });

  final String id;
  final List<CartLine> lines;
  final int estimatedSubtotalUzs;

  int get itemCount => lines.length;

  /// The line of [id], if the cart holds it.
  CartLine? line(String id) {
    for (final CartLine line in lines) {
      if (line.id == id) {
        return line;
      }
    }
    return null;
  }
}

/// One line of the cart.
final class CartLine {
  const CartLine({
    required this.id,
    required this.productId,
    required this.nameUz,
    required this.nameRu,
    required this.unit,
    required this.priceMode,
    required this.imageUrl,
    required this.quantity,
    required this.customerNote,
    required this.substitutionPolicy,
    required this.isAvailable,
    required this.customerUnitPriceUzs,
    required this.estimatedLineTotalUzs,
  });

  final String id;
  final String productId;
  final String nameUz;
  final String nameRu;
  final UnitCode unit;
  final PriceMode priceMode;
  final String? imageUrl;

  /// A decimal string, as the API gives it.
  final String quantity;
  final String? customerNote;
  final SubstitutionPolicy substitutionPolicy;

  /// A line whose product is no longer sold stays, outside the subtotal,
  /// until the Customer removes it (`DL-37` (20)).
  final bool isAvailable;

  /// `null` exactly when the line is not available.
  final int? customerUnitPriceUzs;
  final int? estimatedLineTotalUzs;

  String name(AppLanguage language) =>
      language == AppLanguage.ru ? nameRu : nameUz;
}

/// A product to add, with the Customer's quantity, note and rule.
final class NewCartLine {
  const NewCartLine({
    required this.productId,
    required this.quantity,
    required this.customerNote,
    required this.substitutionPolicy,
  });

  final String productId;
  final String quantity;
  final String? customerNote;
  final SubstitutionPolicy substitutionPolicy;
}

/// What a change of a line sends: only what differs from the line as the
/// Customer saw it (`DL-28` (9)).
final class CartLinePatch {
  const CartLinePatch._({
    required this.quantity,
    required this.noteChanged,
    required this.customerNote,
    required this.substitutionPolicy,
  });

  /// The difference between [line] and what the Customer set; quantities
  /// are compared as amounts, so `1.5` is no change from `1.500`.
  factory CartLinePatch.between(
    CartLine line, {
    required String quantity,
    required String? customerNote,
    required SubstitutionPolicy substitutionPolicy,
  }) => CartLinePatch._(
    quantity:
        QuantityRules.thousandths(quantity) ==
            QuantityRules.thousandths(line.quantity)
        ? null
        : quantity,
    noteChanged: customerNote != line.customerNote,
    customerNote: customerNote,
    substitutionPolicy: substitutionPolicy == line.substitutionPolicy
        ? null
        : substitutionPolicy,
  );

  final String? quantity;
  final bool noteChanged;
  final String? customerNote;
  final SubstitutionPolicy? substitutionPolicy;

  bool get isEmpty =>
      quantity == null && !noteChanged && substitutionPolicy == null;
}

/// The Customer's cart (`docs/09` section 17), on the Customer session.
/// Every method answers the whole cart and throws an `ApiFailure`.
abstract interface class CartRepository {
  Future<Cart> cart();

  Future<Cart> add(NewCartLine line);

  /// Sends [patch], which is not empty, for the line [lineId].
  Future<Cart> change(String lineId, CartLinePatch patch);

  Future<Cart> remove(String lineId);
}
