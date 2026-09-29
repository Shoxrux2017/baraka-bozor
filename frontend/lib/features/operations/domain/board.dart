import '../../../core/catalog/catalog_values.dart';
import '../../../core/orders/order_values.dart';
import '../../auth/domain/app_user.dart';

/// What the board lists (`docs/09` section 38, `DL-37` (16)): the page and
/// the filters — a status, the Shopper and the Courier a row names, the
/// payment method, the first and last day of placement in `Asia/Tashkent`,
/// the self-order attention filter, the orders waiting on the Customer, and
/// a search over the number, the phone and the name.
final class BoardQuery {
  const BoardQuery({
    this.page = 1,
    this.status,
    this.shopperId,
    this.courierId,
    this.paymentMethod,
    this.from,
    this.to,
    this.selfOrdersOnly = false,
    this.awaitingCustomerOnly = false,
    this.search = '',
  });

  /// The longest search the API takes (`DL-44` (4)).
  static const int searchMaxLength = 100;

  final int page;
  final OrderStatus? status;
  final String? shopperId;
  final String? courierId;
  final PaymentMethod? paymentMethod;

  /// Days, as the calendar date of their year, month and day; the time of
  /// day is not used.
  final DateTime? from;
  final DateTime? to;
  final bool selfOrdersOnly;

  /// Only the orders with a question the Customer has not answered yet
  /// (`DL-60` (4)).
  final bool awaitingCustomerOnly;
  final String search;

  /// The same filters on another page, or other filters from the first.
  BoardQuery copyWith({
    int? page,
    OrderStatus? Function()? status,
    String? Function()? shopperId,
    String? Function()? courierId,
    PaymentMethod? Function()? paymentMethod,
    DateTime? Function()? from,
    DateTime? Function()? to,
    bool? selfOrdersOnly,
    bool? awaitingCustomerOnly,
    String? search,
  }) => BoardQuery(
    page: page ?? 1,
    status: status != null ? status() : this.status,
    shopperId: shopperId != null ? shopperId() : this.shopperId,
    courierId: courierId != null ? courierId() : this.courierId,
    paymentMethod: paymentMethod != null ? paymentMethod() : this.paymentMethod,
    from: from != null ? from() : this.from,
    to: to != null ? to() : this.to,
    selfOrdersOnly: selfOrdersOnly ?? this.selfOrdersOnly,
    awaitingCustomerOnly: awaitingCustomerOnly ?? this.awaitingCustomerOnly,
    search: search ?? this.search,
  );

  bool get isFiltered =>
      status != null ||
      shopperId != null ||
      courierId != null ||
      paymentMethod != null ||
      from != null ||
      to != null ||
      selfOrdersOnly ||
      awaitingCustomerOnly ||
      search.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is BoardQuery &&
      other.page == page &&
      other.status == status &&
      other.shopperId == shopperId &&
      other.courierId == courierId &&
      other.paymentMethod == paymentMethod &&
      other.from == from &&
      other.to == to &&
      other.selfOrdersOnly == selfOrdersOnly &&
      other.awaitingCustomerOnly == awaitingCustomerOnly &&
      other.search == search;

  @override
  int get hashCode => Object.hash(
    page,
    status,
    shopperId,
    courierId,
    paymentMethod,
    from,
    to,
    selfOrdersOnly,
    awaitingCustomerOnly,
    search,
  );
}

/// A person as the board names them: the id and the name, which a staff
/// account may not have set.
final class PersonRef {
  const PersonRef({required this.id, required this.fullName});

  final String id;
  final String? fullName;
}

/// One order as a row of the board.
final class BoardRow {
  const BoardRow({
    required this.id,
    required this.orderNumber,
    required this.createdAt,
    required this.status,
    required this.paymentMethod,
    required this.customerName,
    required this.customerPhone,
    required this.itemCount,
    required this.pendingApprovalCount,
    required this.totalUzs,
    required this.totalKind,
    required this.shopper,
    required this.courier,
    required this.isSelfOrder,
  });

  final String id;
  final int orderNumber;
  final DateTime createdAt;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final String customerName;
  final String customerPhone;
  final int itemCount;

  /// The Customer's questions still open (`DL-60` (4)).
  final int pendingApprovalCount;

  /// `null` exactly when [totalKind] is [TotalKind.none].
  final int? totalUzs;
  final TotalKind totalKind;

  /// The current Shopper, or else the one who completed the shopping
  /// (`DL-62` (4)).
  final PersonRef? shopper;

  /// The current Courier, or else the one who delivered.
  final PersonRef? courier;

  /// The Owner's audit flag: a self-order assignment current, or whose
  /// assignee started work (`DL-54` (14)).
  final bool isSelfOrder;
}

/// The strip above the board, for the day in `Asia/Tashkent`.
final class BoardSummary {
  const BoardSummary({
    required this.day,
    required this.openByStatus,
    required this.completedToday,
    required this.cancelledToday,
    required this.salesTodayUzs,
    required this.attentionCount,
  });

  /// `YYYY-MM-DD`.
  final String day;

  /// Every open status, in [OrderStatus.open]'s order, zero included.
  final Map<OrderStatus, int> openByStatus;
  final int completedToday;
  final int cancelledToday;
  final int salesTodayUzs;
  final int attentionCount;
}

/// The kinds of attention item of `docs/09` section 38 (`DL-44` (7),
/// `DL-60` (5)).
enum AttentionType {
  approvalPending('approval_pending'),
  approvalExpired('approval_expired'),
  paymentOverdue('payment_overdue'),
  refundOutstanding('refund_outstanding'),
  courierDelayed('courier_delayed'),
  deliveryFailed('delivery_failed'),
  cancellationRequest('cancellation_request'),
  staffBlocked('staff_blocked'),
  selfOrder('self_order'),

  /// A type this client does not know yet: a later wave's, shown in general
  /// words rather than refusing the whole list (`DL-54` (21), `DL-60`).
  other('');

  const AttentionType(this.code);

  final String code;

  /// The type of [code]; one this client does not know is [other].
  static AttentionType of(String code) {
    for (final AttentionType type in values) {
      if (type != other && type.code == code) {
        return type;
      }
    }
    return other;
  }
}

/// Something on an open order an Operator should look at.
final class AttentionItem {
  const AttentionItem({
    required this.type,
    required this.code,
    required this.orderId,
    required this.orderNumber,
    required this.since,
    required this.shopper,
    required this.courier,
  });

  final AttentionType type;

  /// The type as the server named it, which keeps apart two items of types
  /// this client does not know.
  final String code;
  final String orderId;
  final int orderNumber;
  final DateTime since;

  /// The Shopper and the Courier concerned, when the item names them
  /// (`DL-54` (13)).
  final PersonRef? shopper;
  final PersonRef? courier;
}

/// An order as the Operator and the Admin see it (`docs/09` section 38).
final class BoardOrder {
  const BoardOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentMethod,
    required this.deliveryTimeNote,
    required this.customer,
    required this.address,
    required this.items,
    required this.totals,
    required this.shopperAssignments,
    required this.courierAssignments,
    required this.approvals,
    required this.cancellationRequests,
    required this.payment,
    required this.history,
    required this.cancellationReason,
    required this.createdAt,
    required this.completedAt,
    required this.cancelledAt,
  });

  final String id;
  final int orderNumber;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final String? deliveryTimeNote;
  final BoardCustomer customer;
  final BoardAddress address;
  final List<BoardItem> items;
  final BoardTotals totals;

  /// Oldest first; at most one has not ended.
  final List<ShopperAssignment> shopperAssignments;

  /// Oldest first; at most one has not ended.
  final List<CourierAssignment> courierAssignments;

  /// The questions to the Customer, oldest first, each about one of [items].
  final List<BoardApproval> approvals;

  /// Oldest first; at most one is pending.
  final List<BoardCancellationRequest> cancellationRequests;

  /// `null` until a payment is made.
  final BoardPayment? payment;

  /// Oldest first.
  final List<HistoryEntry> history;
  final CancellationReason? cancellationReason;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  /// The Shopper assignment that has not ended, if any.
  ShopperAssignment? get currentAssignment {
    for (final ShopperAssignment assignment in shopperAssignments) {
      if (assignment.endedAt == null) {
        return assignment;
      }
    }
    return null;
  }

  /// The line [itemId] names, if it is one of the order's.
  BoardItem? item(String itemId) {
    for (final BoardItem item in items) {
      if (item.id == itemId) {
        return item;
      }
    }
    return null;
  }

  /// The cancellation request waiting for a decision, if any.
  BoardCancellationRequest? get pendingCancellationRequest {
    for (final BoardCancellationRequest request in cancellationRequests) {
      if (request.status == CancellationRequestStatus.pending) {
        return request;
      }
    }
    return null;
  }

  /// Whether staff may cancel the order: it is back at the market after its
  /// latest delivery failed, and no request asks for the same (`docs/09`
  /// section 41, `DL-65` (3)).
  bool get cancellableAfterFailedDelivery =>
      status == OrderStatus.readyForDelivery &&
      courierAssignments.isNotEmpty &&
      courierAssignments.last.endedReason ==
          AssignmentEndReason.deliveryFailed &&
      pendingCancellationRequest == null;

  /// Whether the Admin may correct a line's price: a cash order the Courier
  /// has not set off with, not completed nor cancelled (`docs/09` section
  /// 45); online orders wait for Wave 5.
  bool get pricesCorrectable =>
      paymentMethod == PaymentMethod.cash &&
      status != OrderStatus.onTheWay &&
      status != OrderStatus.completed &&
      status != OrderStatus.cancelled;

  /// The Courier assignment that has not ended, if any.
  CourierAssignment? get currentCourierAssignment {
    for (final CourierAssignment assignment in courierAssignments) {
      if (assignment.endedAt == null) {
        return assignment;
      }
    }
    return null;
  }
}

/// The Customer as the order was placed: the name and phone to call.
final class BoardCustomer {
  const BoardCustomer({
    required this.id,
    required this.fullName,
    required this.phone,
  });

  final String id;
  final String fullName;
  final String phone;
}

/// The delivery address as the order was placed.
final class BoardAddress {
  const BoardAddress({
    required this.latitude,
    required this.longitude,
    required this.street,
    required this.house,
    required this.apartment,
    required this.landmark,
    required this.deliveryNote,
  });

  final String latitude;
  final String longitude;
  final String street;
  final String house;
  final String? apartment;
  final String? landmark;
  final String? deliveryNote;
}

/// One line of the order, with the prices it was placed at.
final class BoardItem {
  const BoardItem({
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
    required this.marketPriceUzs,
    required this.customerUnitPriceUzs,
    required this.markupPercent,
    required this.lineTotalUzs,
    required this.removedReason,
    required this.purchasedQuantity,
    required this.billableQuantity,
    required this.actualMarketPriceUzs,
    required this.billableUnitPriceUzs,
    required this.replacement,
    required this.replacementResolution,
  });

  final String id;
  final String productId;
  final String nameUz;
  final String nameRu;
  final UnitCode unit;
  final PriceMode priceMode;

  /// A decimal string, as the API gives it.
  final String quantity;
  final String? customerNote;
  final SubstitutionPolicy substitutionPolicy;
  final OrderItemStatus status;
  final int marketPriceUzs;
  final int customerUnitPriceUzs;

  /// A decimal string with two places.
  final String markupPercent;
  final int lineTotalUzs;

  /// Set exactly when [status] is [OrderItemStatus.removed].
  final ItemRemovedReason? removedReason;

  /// The quantity bought, set once the line is bought; a decimal string.
  final String? purchasedQuantity;

  /// The quantity billed, `null` while the line is open; a decimal string.
  final String? billableQuantity;

  /// The price the Shopper paid per unit, which staff judge the Shopper by
  /// and the Customer never sees (`BR-PRICE-001`, `DL-44` (5)).
  final int? actualMarketPriceUzs;

  /// The price per unit the Customer is billed, set once the line is bought.
  final int? billableUnitPriceUzs;

  /// The product bought, or to be bought, instead of the line's own
  /// (`DL-57` (6)); `null` for a removed line.
  final NamedProduct? replacement;

  /// How [replacement] was authorized; set exactly with it.
  final SubstitutionResolution? replacementResolution;

  /// Whether the line is billed from the price paid — an estimate original,
  /// or any replacement — which only the Admin may correct (`DL-54` (18)).
  bool get billedFromPricePaid =>
      status == OrderItemStatus.purchased &&
      (priceMode == PriceMode.estimate || replacement != null);
}

/// A product named as the order keeps it.
final class NamedProduct {
  const NamedProduct({
    required this.id,
    required this.nameUz,
    required this.nameRu,
  });

  final String id;
  final String nameUz;
  final String nameRu;
}

/// A question put to the Customer about one line (`docs/09` section 38,
/// `DL-58` (4)), with its proposal and its timers.
final class BoardApproval {
  const BoardApproval({
    required this.id,
    required this.itemId,
    required this.type,
    required this.status,
    required this.proposedCustomerUnitPriceUzs,
    required this.proposedActualMarketPriceUzs,
    required this.proposedQuantity,
    required this.replacement,
    required this.requestNote,
    required this.requestedBy,
    required this.attentionAt,
    required this.expiresAt,
    required this.resolution,
    required this.resolvedBy,
    required this.resolvedAt,
    required this.createdAt,
  });

  final String id;
  final String itemId;
  final ApprovalType type;
  final ApprovalStatus status;

  /// The price per unit the Customer would pay, for a price or a
  /// substitution question.
  final int? proposedCustomerUnitPriceUzs;

  /// The price the Shopper would pay per unit, for the same questions.
  final int? proposedActualMarketPriceUzs;

  /// The smaller quantity proposed, for a quantity question; a decimal
  /// string.
  final String? proposedQuantity;

  /// The replacement proposed, for a substitution question.
  final NamedProduct? replacement;
  final String? requestNote;
  final PersonRef requestedBy;

  /// When the question joins the attention list, and when it expires.
  final DateTime attentionAt;
  final DateTime expiresAt;
  final ApprovalResolution? resolution;
  final PersonRef? resolvedBy;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  /// Whether staff may remove the line the question is about: it expired
  /// and nothing resolved it yet (`BR-APP-007`, `DL-60` (2)).
  bool get awaitsRemoval =>
      status == ApprovalStatus.expired && resolution == null;
}

/// A request to cancel the order (`docs/09` section 40, `DL-65` (4)).
final class BoardCancellationRequest {
  const BoardCancellationRequest({
    required this.id,
    required this.origin,
    required this.status,
    required this.reason,
    required this.requestedBy,
    required this.createdAt,
    required this.resolvedBy,
    required this.resolvedAt,
    required this.resolutionNote,
  });

  final String id;
  final CancellationRequestOrigin origin;
  final CancellationRequestStatus status;
  final String reason;
  final PersonRef requestedBy;
  final DateTime createdAt;
  final PersonRef? resolvedBy;
  final DateTime? resolvedAt;
  final String? resolutionNote;
}

/// A decision on a pending cancellation request.
enum CancellationDecision {
  approve('approve'),
  reject('reject');

  const CancellationDecision(this.code);

  final String code;
}

/// The order's payment, once one is made (`DL-64` (4)).
final class BoardPayment {
  const BoardPayment({
    required this.id,
    required this.method,
    required this.status,
    required this.amountUzs,
    required this.paidAt,
    required this.recordedBy,
  });

  final String id;
  final PaymentMethod method;
  final PaymentStatus status;
  final int amountUzs;

  /// Set when [status] is [PaymentStatus.paid].
  final DateTime? paidAt;

  /// The Courier who took a cash payment.
  final PersonRef? recordedBy;
}

/// The order's totals (`DL-37` (10)); every amount is `null` exactly when
/// [kind] is [TotalKind.none].
final class BoardTotals {
  const BoardTotals({
    required this.merchandiseSubtotalUzs,
    required this.serviceFeeUzs,
    required this.deliveryFeeUzs,
    required this.totalUzs,
    required this.kind,
  });

  final int? merchandiseSubtotalUzs;
  final int? serviceFeeUzs;
  final int? deliveryFeeUzs;
  final int? totalUzs;
  final TotalKind kind;
}

/// Why a Shopper's or a Courier's assignment ended (`docs/08` section 16);
/// only a Courier's ends `delivery_failed`.
enum AssignmentEndReason {
  completed('completed'),
  reassigned('reassigned'),
  deliveryFailed('delivery_failed'),
  orderCancelled('order_cancelled');

  const AssignmentEndReason(this.code);

  final String code;

  static AssignmentEndReason? tryParse(String code) {
    for (final AssignmentEndReason reason in values) {
      if (reason.code == code) {
        return reason;
      }
    }
    return null;
  }
}

/// One Shopper's assignment to the order.
final class ShopperAssignment {
  const ShopperAssignment({
    required this.id,
    required this.shopper,
    required this.shopperPhone,
    required this.assignedBy,
    required this.isSelfOrder,
    required this.assignedAt,
    required this.acceptedAt,
    required this.startedAt,
    required this.completedAt,
    required this.endedAt,
    required this.endedReason,
  });

  final String id;
  final PersonRef shopper;
  final String shopperPhone;
  final PersonRef assignedBy;
  final bool isSelfOrder;
  final DateTime assignedAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  /// Set exactly with [endedReason].
  final DateTime? endedAt;
  final AssignmentEndReason? endedReason;
}

/// Why the Courier could not deliver (`BR-DEL-003`).
enum DeliveryFailureReason {
  noAnswer('no_answer'),
  refused('refused'),
  wrongAddress('wrong_address'),
  other('other');

  const DeliveryFailureReason(this.code);

  final String code;

  static DeliveryFailureReason? tryParse(String code) {
    for (final DeliveryFailureReason reason in values) {
      if (reason.code == code) {
        return reason;
      }
    }
    return null;
  }
}

/// One Courier's assignment to the order (`DL-62` (4)).
final class CourierAssignment {
  const CourierAssignment({
    required this.id,
    required this.courier,
    required this.courierPhone,
    required this.assignedBy,
    required this.isSelfOrder,
    required this.assignedAt,
    required this.acceptedAt,
    required this.deliveryStartedAt,
    required this.delayAt,
    required this.completedAt,
    required this.endedAt,
    required this.endedReason,
    required this.failedReason,
    required this.failedNote,
  });

  final String id;
  final PersonRef courier;
  final String courierPhone;
  final PersonRef assignedBy;
  final bool isSelfOrder;
  final DateTime assignedAt;
  final DateTime? acceptedAt;
  final DateTime? deliveryStartedAt;
  final DateTime? delayAt;
  final DateTime? completedAt;

  /// Set exactly with [endedReason].
  final DateTime? endedAt;
  final AssignmentEndReason? endedReason;

  /// Set exactly when the assignment ended [AssignmentEndReason.deliveryFailed].
  final DeliveryFailureReason? failedReason;
  final String? failedNote;
}

/// What happened to an order (`docs/08` section 15), with the events of
/// Wave 3's actions (`DL-54` (2)).
enum OrderHistoryEvent {
  statusChanged('status_changed'),
  edited('edited'),
  paymentMethodSwitched('payment_method_switched'),
  priceCorrected('price_corrected'),
  shopperAssigned('shopper_assigned'),
  shopperReassigned('shopper_reassigned'),
  courierAssigned('courier_assigned'),
  courierReassigned('courier_reassigned'),
  deliveryFailed('delivery_failed'),
  approvalRequested('approval_requested'),
  approvalDecided('approval_decided'),
  approvalExpired('approval_expired'),
  approvalResolved('approval_resolved'),
  shopperAccepted('shopper_accepted'),
  courierAccepted('courier_accepted'),
  itemPurchased('item_purchased'),
  itemUnavailable('item_unavailable'),
  itemSubstituted('item_substituted'),
  cancellationRequested('cancellation_requested'),
  cancellationRequestDecided('cancellation_request_decided'),
  paymentRecorded('payment_recorded');

  const OrderHistoryEvent(this.code);

  final String code;

  static OrderHistoryEvent? tryParse(String code) {
    for (final OrderHistoryEvent event in values) {
      if (event.code == code) {
        return event;
      }
    }
    return null;
  }
}

/// Who or what caused a history entry.
enum HistoryActorType {
  user('user'),
  system('system'),
  paymentProvider('payment_provider');

  const HistoryActorType(this.code);

  final String code;

  static HistoryActorType? tryParse(String code) {
    for (final HistoryActorType type in values) {
      if (type.code == code) {
        return type;
      }
    }
    return null;
  }
}

/// The person behind a history entry made by a user.
final class HistoryActor {
  const HistoryActor({
    required this.id,
    required this.role,
    required this.fullName,
  });

  final String id;
  final UserRole role;
  final String? fullName;
}

/// One entry of the order's history.
final class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.event,
    required this.fromStatus,
    required this.toStatus,
    required this.actorType,
    required this.actor,
    required this.reason,
    required this.note,
    required this.details,
    required this.createdAt,
  });

  final String id;
  final OrderHistoryEvent event;
  final OrderStatus? fromStatus;
  final OrderStatus? toStatus;
  final HistoryActorType actorType;

  /// Set exactly when [actorType] is [HistoryActorType.user].
  final HistoryActor? actor;
  final CancellationReason? reason;
  final String? note;
  final HistoryDetails? details;
  final DateTime createdAt;
}

/// The structured facts an entry carries, for the events the board shows
/// them for (`DL-37` (9), `DL-43` (4), `DL-45` (5)).
sealed class HistoryDetails {
  const HistoryDetails();
}

/// A Shopper or a Courier assigned or reassigned.
final class AssignmentDetails extends HistoryDetails {
  const AssignmentDetails({
    required this.role,
    required this.assignmentId,
    required this.staffId,
    required this.isSelfOrder,
    required this.previousAssignmentId,
    required this.previousStaffId,
  });

  /// [UserRole.shopper] or [UserRole.courier].
  final UserRole role;
  final String assignmentId;
  final String staffId;
  final bool isSelfOrder;
  final String? previousAssignmentId;
  final String? previousStaffId;
}

/// A price the Admin corrected (`DL-66`): the line, the price paid and the
/// price billed per unit before and after, and the line's new total.
final class PriceCorrectionDetails extends HistoryDetails {
  const PriceCorrectionDetails({
    required this.itemId,
    required this.oldActualMarketPriceUzs,
    required this.newActualMarketPriceUzs,
    required this.oldBillableUnitPriceUzs,
    required this.newBillableUnitPriceUzs,
    required this.lineTotalUzs,
  });

  final String itemId;
  final int oldActualMarketPriceUzs;
  final int newActualMarketPriceUzs;
  final int oldBillableUnitPriceUzs;
  final int newBillableUnitPriceUzs;
  final int lineTotalUzs;
}

/// An edit of the lines and the delivery wish.
final class EditDetails extends HistoryDetails {
  const EditDetails({
    required this.added,
    required this.removed,
    required this.changed,
    required this.deliveryTimeNoteChanged,
  });

  final int added;
  final int removed;
  final int changed;
  final bool deliveryTimeNoteChanged;
}

/// A Shopper or a Courier the Operator may assign (`docs/09` section 39).
final class StaffChoice {
  const StaffChoice({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.currentAssignmentCount,
  });

  final String id;
  final String? fullName;
  final String phone;
  final int currentAssignmentCount;
}
