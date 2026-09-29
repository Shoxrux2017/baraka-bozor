import '../../../core/catalog/catalog_values.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/network/paged.dart';
import '../../../core/orders/order_values.dart';

/// One of the Customer's orders as their list shows it (`docs/09` section
/// 20).
final class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentMethod,
    required this.itemCount,
    required this.totalUzs,
    required this.totalKind,
    required this.createdAt,
  });

  final String id;
  final int orderNumber;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final int itemCount;

  /// `null` exactly when [totalKind] is [TotalKind.none].
  final int? totalUzs;
  final TotalKind totalKind;
  final DateTime createdAt;
}

/// One line of the Customer's order, at the price it was placed at.
final class CustomerOrderLine {
  const CustomerOrderLine({
    required this.id,
    required this.productId,
    required this.nameUz,
    required this.nameRu,
    required this.unit,
    required this.priceMode,
    required this.quantity,
    required this.customerNote,
    required this.substitutionPolicy,
    required this.status,
    required this.customerUnitPriceUzs,
    required this.lineTotalUzs,
    required this.removedReason,
  });

  final String id;
  final String productId;
  final String nameUz;
  final String nameRu;
  final UnitCode unit;
  final PriceMode priceMode;

  /// The ordered quantity, a decimal string as the API gives it.
  final String quantity;
  final String? customerNote;
  final SubstitutionPolicy substitutionPolicy;
  final OrderItemStatus status;
  final int customerUnitPriceUzs;
  final int lineTotalUzs;

  /// Set exactly when [status] is [OrderItemStatus.removed].
  final ItemRemovedReason? removedReason;

  bool get removed => status == OrderItemStatus.removed;

  String name(AppLanguage language) =>
      language == AppLanguage.ru ? nameRu : nameUz;
}

/// Where the order goes, as it was placed.
final class OrderAddress {
  const OrderAddress({
    required this.street,
    required this.house,
    required this.apartment,
    required this.landmark,
    required this.deliveryNote,
  });

  final String street;
  final String house;
  final String? apartment;
  final String? landmark;
  final String? deliveryNote;
}

/// The Customer's order (`docs/09` section 20): its lines, totals and
/// their kind, the address, the delivery wish, and what the Customer may do
/// with it now, as the server says.
final class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentMethod,
    required this.deliveryTimeNote,
    required this.canEdit,
    required this.canCancelDirectly,
    required this.lines,
    required this.merchandiseSubtotalUzs,
    required this.serviceFeeUzs,
    required this.deliveryFeeUzs,
    required this.totalUzs,
    required this.totalKind,
    required this.address,
    required this.cancellationReason,
    required this.cancellationRequest,
    required this.createdAt,
  });

  final String id;
  final int orderNumber;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final String? deliveryTimeNote;
  final bool canEdit;
  final bool canCancelDirectly;

  /// Every line, removed ones included, in the order they were added.
  final List<CustomerOrderLine> lines;

  /// Every amount is `null` exactly when [totalKind] is [TotalKind.none].
  final int? merchandiseSubtotalUzs;
  final int? serviceFeeUzs;
  final int? deliveryFeeUzs;
  final int? totalUzs;
  final TotalKind totalKind;
  final OrderAddress address;
  final CancellationReason? cancellationReason;

  /// Where the order's latest cancellation request stands, or `null` when it
  /// has none; the screens for requests are W3-17's.
  final CancellationRequestStatus? cancellationRequest;
  final DateTime createdAt;

  /// The lines the Customer still orders.
  List<CustomerOrderLine> get openLines =>
      lines.where((CustomerOrderLine line) => !line.removed).toList();
}

/// The most lines an edit may send (`docs/09` section 21).
const int orderMaxLines = 100;

/// One line of an edit: every line the order is to keep, as the Customer
/// wants it (`docs/09` section 21).
final class OrderEditLine {
  const OrderEditLine({
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

/// The Customer's orders (`docs/09` sections 20 to 22), on the Customer
/// session. Every method throws an `ApiFailure`.
abstract interface class CustomerOrdersRepository {
  Future<Paged<OrderSummary>> orders(int page);

  Future<CustomerOrder> order(String id);

  /// Replaces the order's lines with [lines] and its wish with
  /// [deliveryTimeNote].
  Future<CustomerOrder> edit(
    String id,
    List<OrderEditLine> lines,
    String? deliveryTimeNote,
  );

  /// Cancels the order, under [idempotencyKey].
  Future<CustomerOrder> cancel(
    String id,
    String? reason,
    String idempotencyKey,
  );
}
