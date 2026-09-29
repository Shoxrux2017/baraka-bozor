import '../orders/order_values.dart';
import 'generated/app_localizations.dart';

/// The words for an order's machine values, in the interface language.
abstract final class OrderLabels {
  static String status(AppLocalizations l10n, OrderStatus status) =>
      switch (status) {
        OrderStatus.newOrder => l10n.orderStatusNew,
        OrderStatus.shoppingAssigned => l10n.orderStatusShoppingAssigned,
        OrderStatus.shopping => l10n.orderStatusShopping,
        OrderStatus.finalPaymentPending => l10n.orderStatusFinalPaymentPending,
        OrderStatus.readyForDelivery => l10n.orderStatusReadyForDelivery,
        OrderStatus.deliveryAssigned => l10n.orderStatusDeliveryAssigned,
        OrderStatus.onTheWay => l10n.orderStatusOnTheWay,
        OrderStatus.completed => l10n.orderStatusCompleted,
        OrderStatus.cancelled => l10n.orderStatusCancelled,
      };

  /// A status as the Customer reads it about their own order.
  static String customerStatus(AppLocalizations l10n, OrderStatus status) =>
      switch (status) {
        OrderStatus.newOrder => l10n.customerStatusNew,
        OrderStatus.shoppingAssigned => l10n.customerStatusShoppingAssigned,
        OrderStatus.shopping => l10n.customerStatusShopping,
        OrderStatus.finalPaymentPending =>
          l10n.customerStatusFinalPaymentPending,
        OrderStatus.readyForDelivery => l10n.customerStatusReadyForDelivery,
        OrderStatus.deliveryAssigned => l10n.customerStatusDeliveryAssigned,
        OrderStatus.onTheWay => l10n.customerStatusOnTheWay,
        OrderStatus.completed => l10n.customerStatusCompleted,
        OrderStatus.cancelled => l10n.customerStatusCancelled,
      };

  static String paymentMethod(AppLocalizations l10n, PaymentMethod method) =>
      switch (method) {
        PaymentMethod.cash => l10n.paymentCash,
        PaymentMethod.online => l10n.paymentOnline,
      };

  static String itemStatus(AppLocalizations l10n, OrderItemStatus status) =>
      switch (status) {
        OrderItemStatus.pending => l10n.itemStatusPending,
        OrderItemStatus.awaitingCustomer => l10n.itemStatusAwaitingCustomer,
        OrderItemStatus.purchased => l10n.itemStatusPurchased,
        OrderItemStatus.removed => l10n.itemStatusRemoved,
      };

  static String substitution(
    AppLocalizations l10n,
    SubstitutionPolicy policy,
  ) => switch (policy) {
    SubstitutionPolicy.allowSimilar => l10n.substitutionAllowSimilar,
    SubstitutionPolicy.contactBefore => l10n.substitutionContactBefore,
    SubstitutionPolicy.removeIfUnavailable =>
      l10n.substitutionRemoveIfUnavailable,
  };

  static String removedReason(
    AppLocalizations l10n,
    ItemRemovedReason reason,
  ) => switch (reason) {
    ItemRemovedReason.unavailable => l10n.removedUnavailable,
    ItemRemovedReason.customerRejected => l10n.removedCustomerRejected,
    ItemRemovedReason.approvalExpired => l10n.removedApprovalExpired,
    ItemRemovedReason.customerRemoved => l10n.removedCustomerRemoved,
    ItemRemovedReason.operatorRemoved => l10n.removedOperatorRemoved,
    ItemRemovedReason.orderCancelled => l10n.removedOrderCancelled,
  };

  static String approvalType(AppLocalizations l10n, ApprovalType type) =>
      switch (type) {
        ApprovalType.priceOverTolerance => l10n.approvalTypePrice,
        ApprovalType.substitution => l10n.approvalTypeSubstitution,
        ApprovalType.reducedQuantity => l10n.approvalTypeReducedQuantity,
      };

  static String approvalStatus(AppLocalizations l10n, ApprovalStatus status) =>
      switch (status) {
        ApprovalStatus.pending => l10n.approvalStatusPending,
        ApprovalStatus.approved => l10n.approvalStatusApproved,
        ApprovalStatus.rejected => l10n.approvalStatusRejected,
        ApprovalStatus.expired => l10n.approvalStatusExpired,
        ApprovalStatus.cancelled => l10n.approvalStatusCancelled,
      };

  static String substitutionResolution(
    AppLocalizations l10n,
    SubstitutionResolution resolution,
  ) => switch (resolution) {
    SubstitutionResolution.automatic => l10n.replacementAutomatic,
    SubstitutionResolution.approved => l10n.replacementApproved,
  };

  static String requestStatus(
    AppLocalizations l10n,
    CancellationRequestStatus status,
  ) => switch (status) {
    CancellationRequestStatus.pending => l10n.requestStatusPending,
    CancellationRequestStatus.approved => l10n.requestStatusApproved,
    CancellationRequestStatus.rejected => l10n.requestStatusRejected,
    CancellationRequestStatus.closed => l10n.requestStatusClosed,
  };

  static String requestOrigin(
    AppLocalizations l10n,
    CancellationRequestOrigin origin,
  ) => switch (origin) {
    CancellationRequestOrigin.customer => l10n.requestOriginCustomer,
    CancellationRequestOrigin.staff => l10n.requestOriginStaff,
  };

  static String paymentStatus(AppLocalizations l10n, PaymentStatus status) =>
      switch (status) {
        PaymentStatus.unpaid => l10n.paymentStatusUnpaid,
        PaymentStatus.pending => l10n.paymentStatusPending,
        PaymentStatus.paid => l10n.paymentStatusPaid,
        PaymentStatus.cancelled => l10n.paymentStatusCancelled,
      };

  static String cancellationReason(
    AppLocalizations l10n,
    CancellationReason reason,
  ) => switch (reason) {
    CancellationReason.customerCancelled => l10n.cancelCustomerCancelled,
    CancellationReason.cancellationRequestApproved =>
      l10n.cancelRequestApproved,
    CancellationReason.unpaidOnline => l10n.cancelUnpaidOnline,
    CancellationReason.noItemsPurchased => l10n.cancelNoItemsPurchased,
    CancellationReason.deliveryFailed => l10n.cancelDeliveryFailed,
    CancellationReason.system => l10n.cancelSystem,
  };
}
