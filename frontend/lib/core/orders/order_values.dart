/// The machine values of an order that the panel's board and the Customer's
/// orders both show, as `docs/08-database.md` sections 13 and 14 name them.
/// Labels come from the localized strings, never from these.
enum OrderStatus {
  newOrder('new'),
  shoppingAssigned('shopping_assigned'),
  shopping('shopping'),
  finalPaymentPending('final_payment_pending'),
  readyForDelivery('ready_for_delivery'),
  deliveryAssigned('delivery_assigned'),
  onTheWay('on_the_way'),
  completed('completed'),
  cancelled('cancelled');

  const OrderStatus(this.code);

  final String code;

  /// The states an order is still being worked in, in the order it passes
  /// through them.
  static const List<OrderStatus> open = <OrderStatus>[
    newOrder,
    shoppingAssigned,
    shopping,
    finalPaymentPending,
    readyForDelivery,
    deliveryAssigned,
    onTheWay,
  ];

  static OrderStatus? tryParse(String code) {
    for (final OrderStatus status in values) {
      if (status.code == code) {
        return status;
      }
    }
    return null;
  }
}

/// How the Customer pays: cash to the Courier, or online (`docs/05`
/// section 11).
enum PaymentMethod {
  cash('cash'),
  online('online');

  const PaymentMethod(this.code);

  final String code;

  static PaymentMethod? tryParse(String code) {
    for (final PaymentMethod method in values) {
      if (method.code == code) {
        return method;
      }
    }
    return null;
  }
}

/// What an order's total is (`DL-37` (10)): an `estimate` while any line's
/// price is one, `final` when every price is guaranteed or shopping is
/// done, and `none` for a cancelled order, which owes nothing.
enum TotalKind {
  estimate('estimate'),
  finalTotal('final'),
  none('none');

  const TotalKind(this.code);

  final String code;

  static TotalKind? tryParse(String code) {
    for (final TotalKind kind in values) {
      if (kind.code == code) {
        return kind;
      }
    }
    return null;
  }
}

/// Where one line of an order stands (`docs/08` section 14).
enum OrderItemStatus {
  pending('pending'),
  awaitingCustomer('awaiting_customer'),
  purchased('purchased'),
  removed('removed');

  const OrderItemStatus(this.code);

  final String code;

  static OrderItemStatus? tryParse(String code) {
    for (final OrderItemStatus status in values) {
      if (status.code == code) {
        return status;
      }
    }
    return null;
  }
}

/// What the Shopper does when a line's product is not there
/// (`BR-SUB-001`).
enum SubstitutionPolicy {
  allowSimilar('allow_similar_substitution'),
  contactBefore('contact_before_substitution'),
  removeIfUnavailable('remove_if_unavailable');

  const SubstitutionPolicy(this.code);

  final String code;

  static SubstitutionPolicy? tryParse(String code) {
    for (final SubstitutionPolicy policy in values) {
      if (policy.code == code) {
        return policy;
      }
    }
    return null;
  }
}

/// Why a line left the order (`DL-3` S-9).
enum ItemRemovedReason {
  unavailable('unavailable'),
  customerRejected('customer_rejected'),
  approvalExpired('approval_expired'),
  customerRemoved('customer_removed'),
  operatorRemoved('operator_removed'),
  orderCancelled('order_cancelled');

  const ItemRemovedReason(this.code);

  final String code;

  static ItemRemovedReason? tryParse(String code) {
    for (final ItemRemovedReason reason in values) {
      if (reason.code == code) {
        return reason;
      }
    }
    return null;
  }
}

/// Where the Customer's cancellation request stands (`docs/09` section 20,
/// `DL-65` (5)).
enum CancellationRequestStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  closed('closed');

  const CancellationRequestStatus(this.code);

  final String code;

  static CancellationRequestStatus? tryParse(String code) {
    for (final CancellationRequestStatus status in values) {
      if (status.code == code) {
        return status;
      }
    }
    return null;
  }
}

/// Why an order was cancelled (`DL-3` S-9).
enum CancellationReason {
  customerCancelled('customer_cancelled'),
  cancellationRequestApproved('cancellation_request_approved'),
  unpaidOnline('unpaid_online'),
  noItemsPurchased('no_items_purchased'),
  deliveryFailed('delivery_failed'),
  system('system');

  const CancellationReason(this.code);

  final String code;

  static CancellationReason? tryParse(String code) {
    for (final CancellationReason reason in values) {
      if (reason.code == code) {
        return reason;
      }
    }
    return null;
  }
}
