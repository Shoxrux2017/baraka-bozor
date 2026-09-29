import '../../../core/catalog/catalog_values.dart';
import '../../../core/network/paged.dart';
import '../../../core/orders/order_values.dart';

/// The Shopper's own assignment to an order: when it was made, accepted and
/// started (`docs/09` section 28).
final class ShopperAssignment {
  const ShopperAssignment({
    required this.id,
    required this.assignedAt,
    required this.acceptedAt,
    required this.startedAt,
  });

  final String id;
  final DateTime assignedAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
}

/// One of the Shopper's current orders as their list shows it.
final class ShopperOrderRow {
  const ShopperOrderRow({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.itemCount,
    required this.openItemCount,
    required this.deliveryTimeNote,
    required this.assignment,
  });

  final String id;
  final int orderNumber;
  final OrderStatus status;

  /// The lines the Shopper sees: all but those the Customer removed before
  /// shopping.
  final int itemCount;

  /// Of those, the lines still waiting to be bought or answered.
  final int openItemCount;
  final String? deliveryTimeNote;
  final ShopperAssignment assignment;
}

/// How far a price may go without asking the Customer: the highest price
/// per unit the Customer may be billed, and the highest market price within
/// it under the line's markup (`DL-54` (6)).
final class PriceBound {
  const PriceBound({
    required this.customerUnitPriceUzs,
    required this.marketPriceUzs,
  });

  final int customerUnitPriceUzs;
  final int marketPriceUzs;
}

/// The replacement authorized on a line, with its market price now and its
/// own bound (`DL-57` (6)).
final class ShopperReplacement {
  const ShopperReplacement({
    required this.productId,
    required this.nameUz,
    required this.nameRu,
    required this.marketPriceUzs,
    required this.resolution,
    required this.bound,
  });

  final String productId;
  final String nameUz;
  final String nameRu;

  /// The product's market price now, when the answer gives it.
  final int? marketPriceUzs;
  final SubstitutionResolution resolution;
  final PriceBound bound;
}

/// What the Shopper bought for a line.
final class ShopperPurchase {
  const ShopperPurchase({
    required this.productId,
    required this.purchasedQuantity,
    required this.billableQuantity,
    required this.actualMarketPriceUzs,
    required this.billableUnitPriceUzs,
    required this.lineTotalUzs,
  });

  /// The product bought: the line's own, or its replacement.
  final String productId;

  /// Decimal strings, as the API gives them.
  final String purchasedQuantity;
  final String billableQuantity;

  /// The price paid per unit; a fixed line bought as itself may not say it.
  final int? actualMarketPriceUzs;
  final int billableUnitPriceUzs;
  final int lineTotalUzs;
}

/// A question to the Customer about a line, still open.
final class OpenQuestion {
  const OpenQuestion({
    required this.id,
    required this.type,
    required this.expiresAt,
  });

  final String id;
  final ApprovalType type;
  final DateTime expiresAt;
}

/// One line of an order as the Shopper sees it (`docs/09` section 28): what
/// to buy, how far its price may go, and what became of it. It never
/// carries what the order owes (`docs/02` section 11).
final class ShopperLine {
  const ShopperLine({
    required this.id,
    required this.productId,
    required this.nameUz,
    required this.nameRu,
    required this.unit,
    required this.priceMode,
    required this.quantity,
    required this.approvedQuantityCap,
    required this.customerNote,
    required this.substitutionPolicy,
    required this.status,
    required this.marketPriceUzs,
    required this.customerUnitPriceUzs,
    required this.bound,
    required this.replacement,
    required this.purchase,
    required this.removedReason,
    required this.openQuestion,
  });

  final String id;
  final String productId;
  final String nameUz;
  final String nameRu;
  final UnitCode unit;
  final PriceMode priceMode;

  /// Decimal strings, as the API gives them; the cap is the smaller
  /// quantity the Customer approved.
  final String quantity;
  final String? approvedQuantityCap;
  final String? customerNote;
  final SubstitutionPolicy substitutionPolicy;
  final OrderItemStatus status;

  /// The market price and the Customer's price per unit when the order was
  /// placed.
  final int marketPriceUzs;
  final int customerUnitPriceUzs;

  /// The original's bound; `null` for a fixed line bought as itself.
  final PriceBound? bound;
  final ShopperReplacement? replacement;

  /// Set exactly when the line is bought.
  final ShopperPurchase? purchase;

  /// Set exactly when the line is removed.
  final ItemRemovedReason? removedReason;
  final OpenQuestion? openQuestion;
}

/// One of the Shopper's current orders, whole (`docs/09` section 28): no
/// address, no Customer name and no amount owed; the Customer's phone only
/// while shopping (interview 7.3).
final class ShopperOrder {
  const ShopperOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.deliveryTimeNote,
    required this.customerPhone,
    required this.assignment,
    required this.canAccept,
    required this.canStart,
    required this.items,
  });

  final String id;
  final int orderNumber;
  final OrderStatus status;
  final String? deliveryTimeNote;

  /// Set exactly while the order is `shopping`.
  final String? customerPhone;

  /// The Shopper's current assignment; `null` once it ended.
  final ShopperAssignment? assignment;
  final bool canAccept;
  final bool canStart;

  /// Oldest first.
  final List<ShopperLine> items;
}

/// The Shopper's orders on the staff session (`docs/09` sections 28 and 29).
/// Every method throws an `ApiFailure`.
abstract interface class ShopperOrdersRepository {
  /// The current orders, the longest-waiting assignment first.
  Future<Paged<ShopperOrderRow>> orders(int page);

  Future<ShopperOrder> order(String id);

  /// Accepts the assignment; again is a natural repeat.
  Future<ShopperOrder> accept(String id);

  /// Starts shopping, after which the Customer can no longer edit or cancel
  /// the order directly; again is a natural repeat.
  Future<ShopperOrder> start(String id);
}
