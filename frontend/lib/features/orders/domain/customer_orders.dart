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
    required this.pendingApprovalCount,
    required this.totalUzs,
    required this.totalKind,
    required this.createdAt,
  });

  final String id;
  final int orderNumber;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final int itemCount;

  /// The questions waiting for the Customer's answer, those past their
  /// expiry left out (`DL-54` (8)).
  final int pendingApprovalCount;

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
    required this.billableQuantity,
    required this.billableUnitPriceUzs,
    required this.replacement,
    required this.question,
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

  /// The quantity billed once the line is bought, or `0` when removed;
  /// `null` while it is open. A decimal string.
  final String? billableQuantity;

  /// What the Customer pays for one unit once the line is bought — never
  /// the price paid at the market (`BR-PRICE-001`).
  final int? billableUnitPriceUzs;

  /// The product authorized or bought instead of the line's own.
  final ProductNames? replacement;

  /// The line's question waiting for the Customer's answer.
  final CustomerQuestion? question;

  bool get removed => status == OrderItemStatus.removed;

  /// A line waiting for an answer whose question's time ran out: nothing
  /// asks the Customer any more, and staff remove it (`BR-APP-007`).
  bool get questionExpired =>
      status == OrderItemStatus.awaitingCustomer && question == null;

  String name(AppLanguage language) =>
      language == AppLanguage.ru ? nameRu : nameUz;
}

/// A product's two names.
final class ProductNames {
  const ProductNames({required this.nameUz, required this.nameRu});

  final String nameUz;
  final String nameRu;

  String name(AppLanguage language) =>
      language == AppLanguage.ru ? nameRu : nameUz;
}

/// A question put to the Customer about a line, as they read it
/// (`docs/09` section 20): what is proposed, in their prices only.
final class CustomerQuestion {
  const CustomerQuestion({
    required this.id,
    required this.type,
    required this.proposedCustomerUnitPriceUzs,
    required this.proposedQuantity,
    required this.replacement,
    required this.requestNote,
    required this.expiresAt,
  });

  final String id;
  final ApprovalType type;

  /// The price per unit proposed, for a price or a substitution question.
  final int? proposedCustomerUnitPriceUzs;

  /// The smaller quantity proposed, a decimal string.
  final String? proposedQuantity;

  /// The replacement a substitution proposes, or the one a price question
  /// is about.
  final ProductNames? replacement;
  final String? requestNote;
  final DateTime expiresAt;
}

/// The order's latest cancellation request, as the Customer sees it; the
/// Operator's note is not theirs (`DL-65` (5)).
final class CustomerCancellationRequest {
  const CustomerCancellationRequest({
    required this.id,
    required this.status,
    required this.reason,
    required this.createdAt,
    required this.resolvedAt,
  });

  final String id;
  final CancellationRequestStatus status;
  final String reason;
  final DateTime createdAt;

  /// Set exactly once the request is no longer pending.
  final DateTime? resolvedAt;
}

/// The payment made for the order: in Wave 3, the cash the Courier took.
final class CustomerPayment {
  const CustomerPayment({
    required this.method,
    required this.status,
    required this.amountUzs,
    required this.paidAt,
  });

  final PaymentMethod method;
  final PaymentStatus status;
  final int amountUzs;
  final DateTime? paidAt;
}

/// The Customer's answer to a question.
enum ApprovalDecision {
  approve('approve'),
  reject('reject');

  const ApprovalDecision(this.code);

  final String code;
}

/// A question as the decision answers it (`docs/09` section 23).
final class CustomerApproval {
  const CustomerApproval({
    required this.id,
    required this.orderId,
    required this.type,
    required this.status,
  });

  final String id;
  final String orderId;
  final ApprovalType type;
  final ApprovalStatus status;
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
    required this.canRequestCancellation,
    required this.pendingApprovalCount,
    required this.lines,
    required this.merchandiseSubtotalUzs,
    required this.serviceFeeUzs,
    required this.deliveryFeeUzs,
    required this.totalUzs,
    required this.totalKind,
    required this.address,
    required this.cancellationReason,
    required this.cancellationRequest,
    required this.payment,
    required this.createdAt,
  });

  final String id;
  final int orderNumber;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final String? deliveryTimeNote;
  final bool canEdit;
  final bool canCancelDirectly;

  /// From shopping to a Courier's assignment, while no request is pending,
  /// the Customer asks an Operator to cancel (`DL-65` (1)).
  final bool canRequestCancellation;

  /// The questions waiting for the Customer's answer.
  final int pendingApprovalCount;

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

  /// The order's latest cancellation request, or `null` when it has none.
  final CustomerCancellationRequest? cancellationRequest;

  /// `null` until a payment is made.
  final CustomerPayment? payment;
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

/// The Customer's orders (`docs/09` sections 20 to 23), on the Customer
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

  /// Answers the question [approvalId] of order [orderId] under
  /// [idempotencyKey], which a retry sends again (`docs/09` section 23).
  Future<CustomerApproval> decide(
    String orderId,
    String approvalId,
    ApprovalDecision decision,
    String idempotencyKey,
  );
}
