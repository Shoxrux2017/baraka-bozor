import '../../../core/formatting/address_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/orders/order_values.dart';
import '../domain/courier_orders.dart';

/// Where a delivery stands for the Courier: handed to them and not yet
/// accepted, accepted and not yet set off, on the way, or anything else.
enum CourierStage { assigned, accepted, onTheWay, other }

/// The stage of [order]. A waiting cancellation request does not change it:
/// an accepted delivery stays accepted, though it may not be started
/// (`DL-54` (12)).
CourierStage courierStage(CourierOrder order) {
  if (order.status == OrderStatus.deliveryAssigned) {
    return order.assignment.acceptedAt == null
        ? CourierStage.assigned
        : CourierStage.accepted;
  }
  if (order.status == OrderStatus.onTheWay) {
    return CourierStage.onTheWay;
  }
  return CourierStage.other;
}

/// The address as one line: the street, the house and the apartment.
String addressLine(AppLocalizations l10n, DeliveryAddress address) =>
    addressFullLine(
      l10n,
      street: address.street,
      house: address.house,
      apartment: address.apartment,
    );
