import '../../../core/network/paged.dart';
import '../../../core/orders/order_values.dart';

/// The Courier's own assignment to an order: when it was made, accepted and
/// set off, and when the delivery is late (`docs/09` section 36).
final class CourierAssignment {
  const CourierAssignment({
    required this.id,
    required this.assignedAt,
    required this.acceptedAt,
    required this.deliveryStartedAt,
    required this.delayAt,
  });

  final String id;
  final DateTime assignedAt;
  final DateTime? acceptedAt;
  final DateTime? deliveryStartedAt;

  /// Set exactly with [deliveryStartedAt]: past it, the delivery is late and
  /// an Operator is told (`BR-DEL-002`).
  final DateTime? delayAt;
}

/// Who receives the order, as it was placed.
final class Recipient {
  const Recipient({required this.fullName, required this.phone});

  final String fullName;

  /// E.164, `+998` and nine digits.
  final String phone;
}

/// Where the order goes, as it was placed: the point as six-decimal
/// strings, and the address as the Customer wrote it.
final class DeliveryAddress {
  const DeliveryAddress({
    required this.latitude,
    required this.longitude,
    required this.street,
    required this.house,
    required this.apartment,
    required this.landmark,
  });

  final String latitude;
  final String longitude;
  final String street;
  final String house;
  final String? apartment;
  final String? landmark;
}

/// One of the Courier's deliveries, in the list and alone (`docs/09`
/// section 36): who receives it and where, the wishes, the payment method
/// and the cash to collect, whether a cancellation request holds it, and the
/// Courier's assignment with what may be done next. Never the lines, the
/// prices or the Customer's account.
///
/// Once the Courier's assignment has ended — every answer of delivered and
/// not delivered — the order tells the outcome only: [recipient],
/// [address], the notes and [shopperPhone] are `null` (`DL-64` (7)).
final class CourierOrder {
  const CourierOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.recipient,
    required this.address,
    required this.deliveryNote,
    required this.deliveryTimeNote,
    required this.paymentMethod,
    required this.amountToCollectUzs,
    required this.cancellationRequestPending,
    required this.assignment,
    required this.canAccept,
    required this.canStart,
    required this.shopperPhone,
  });

  final String id;
  final int orderNumber;
  final OrderStatus status;
  final Recipient? recipient;
  final DeliveryAddress? address;
  final String? deliveryNote;
  final String? deliveryTimeNote;
  final PaymentMethod paymentMethod;

  /// The final total for a cash order, `null` for an online one.
  final int? amountToCollectUzs;

  /// A Customer's request to cancel waits for an Operator: the Courier may
  /// not set off meanwhile (`DL-54` (12)).
  final bool cancellationRequestPending;
  final CourierAssignment assignment;
  final bool canAccept;
  final bool canStart;

  /// The phone of the Shopper who bought the order, while the business runs
  /// without a handoff point (`BR-DEL-006`); `null` otherwise, and also when
  /// the server knows no such Shopper.
  final String? shopperPhone;

  /// Whether the Courier still holds the delivery.
  bool get held => recipient != null;
}

/// The Courier's deliveries on the staff session (`docs/09` sections 36 and
/// 37). Every method throws an `ApiFailure`.
abstract interface class CourierOrdersRepository {
  /// The current deliveries, the longest-waiting assignment first.
  Future<Paged<CourierOrder>> orders(int page);

  Future<CourierOrder> order(String id);

  /// Accepts the delivery; again is a natural repeat.
  Future<CourierOrder> accept(String id);

  /// Sets off with the order, which is then on the way; again is a natural
  /// repeat.
  Future<CourierOrder> start(String id);

  /// Hands the order over, taking [cashReceivedUzs] for a cash order, under
  /// [idempotencyKey], which a retry sends again (`docs/09` section 48).
  Future<CourierOrder> delivered(
    String id,
    int? cashReceivedUzs,
    String idempotencyKey,
  );

  /// Could not hand the order over, for [reason], with a [note] required
  /// with [DeliveryFailureReason.other]; the order goes back to an Operator.
  /// Again is a natural repeat.
  Future<CourierOrder> notDelivered(
    String id,
    DeliveryFailureReason reason,
    String? note,
  );
}
