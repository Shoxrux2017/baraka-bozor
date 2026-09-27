import '../../../core/catalog/catalog_values.dart';
import '../../../core/orders/order_values.dart';
import '../../auth/domain/app_user.dart';

/// What the board lists (`docs/09` section 38, `DL-37` (16)): the page and
/// the filters — a status, the current Shopper, the payment method, the
/// first and last day of placement in `Asia/Tashkent`, the self-order
/// attention filter, and a search over the number, the phone and the name.
final class BoardQuery {
  const BoardQuery({
    this.page = 1,
    this.status,
    this.shopperId,
    this.paymentMethod,
    this.from,
    this.to,
    this.selfOrdersOnly = false,
    this.search = '',
  });

  /// The longest search the API takes (`DL-44` (4)).
  static const int searchMaxLength = 100;

  final int page;
  final OrderStatus? status;
  final String? shopperId;
  final PaymentMethod? paymentMethod;

  /// Days, as the calendar date of their year, month and day; the time of
  /// day is not used.
  final DateTime? from;
  final DateTime? to;
  final bool selfOrdersOnly;
  final String search;

  /// The same filters on another page, or other filters from the first.
  BoardQuery copyWith({
    int? page,
    OrderStatus? Function()? status,
    String? Function()? shopperId,
    PaymentMethod? Function()? paymentMethod,
    DateTime? Function()? from,
    DateTime? Function()? to,
    bool? selfOrdersOnly,
    String? search,
  }) => BoardQuery(
    page: page ?? 1,
    status: status != null ? status() : this.status,
    shopperId: shopperId != null ? shopperId() : this.shopperId,
    paymentMethod: paymentMethod != null ? paymentMethod() : this.paymentMethod,
    from: from != null ? from() : this.from,
    to: to != null ? to() : this.to,
    selfOrdersOnly: selfOrdersOnly ?? this.selfOrdersOnly,
    search: search ?? this.search,
  );

  bool get isFiltered =>
      status != null ||
      shopperId != null ||
      paymentMethod != null ||
      from != null ||
      to != null ||
      selfOrdersOnly ||
      search.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is BoardQuery &&
      other.page == page &&
      other.status == status &&
      other.shopperId == shopperId &&
      other.paymentMethod == paymentMethod &&
      other.from == from &&
      other.to == to &&
      other.selfOrdersOnly == selfOrdersOnly &&
      other.search == search;

  @override
  int get hashCode => Object.hash(
    page,
    status,
    shopperId,
    paymentMethod,
    from,
    to,
    selfOrdersOnly,
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
    required this.totalUzs,
    required this.totalKind,
    required this.shopper,
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

  /// `null` exactly when [totalKind] is [TotalKind.none].
  final int? totalUzs;
  final TotalKind totalKind;

  /// The current Shopper, or `null` while none is assigned.
  final PersonRef? shopper;
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

/// The kinds of attention item the backend produces; each later wave adds
/// its own (`DL-44` (7)).
enum AttentionType {
  selfOrder('self_order');

  const AttentionType(this.code);

  final String code;

  static AttentionType? tryParse(String code) {
    for (final AttentionType type in values) {
      if (type.code == code) {
        return type;
      }
    }
    return null;
  }
}

/// Something on an open order an Operator should look at.
final class AttentionItem {
  const AttentionItem({
    required this.type,
    required this.orderId,
    required this.orderNumber,
    required this.since,
    required this.shopper,
  });

  final AttentionType type;
  final String orderId;
  final int orderNumber;
  final DateTime since;
  final PersonRef shopper;
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

  /// Oldest first.
  final List<HistoryEntry> history;
  final CancellationReason? cancellationReason;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  /// The assignment that has not ended, if any.
  ShopperAssignment? get currentAssignment {
    for (final ShopperAssignment assignment in shopperAssignments) {
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

/// Why a Shopper's assignment ended (`docs/08` section 16).
enum AssignmentEndReason {
  completed('completed'),
  reassigned('reassigned'),
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

/// What happened to an order (`docs/08` section 15).
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
  approvalResolved('approval_resolved');

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

/// A Shopper assigned or reassigned.
final class AssignmentDetails extends HistoryDetails {
  const AssignmentDetails({
    required this.assignmentId,
    required this.shopperId,
    required this.isSelfOrder,
    required this.previousAssignmentId,
    required this.previousShopperId,
  });

  final String assignmentId;
  final String shopperId;
  final bool isSelfOrder;
  final String? previousAssignmentId;
  final String? previousShopperId;
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

/// A Shopper the Operator may assign (`docs/09` section 39).
final class ShopperChoice {
  const ShopperChoice({
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
