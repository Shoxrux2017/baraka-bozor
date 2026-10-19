import '../../../core/network/api_failure.dart';

/// The refusal code of an erasure while an order is unfinished
/// (`docs/09-api-contracts.md` section 67).
const String accountHasUnfinishedOrders = 'account_has_unfinished_orders';

/// A Customer account as the Admin finds it by phone
/// (`docs/09-api-contracts.md` section 66).
final class AdminCustomer {
  const AdminCustomer({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.status,
    required this.createdAt,
    required this.lastLoginAt,
    required this.orderCount,
    required this.unfinishedOrder,
  });

  final String id;
  final String phone;

  /// `null` while the Customer has not given a name.
  final String? fullName;

  /// `active` or `blocked`.
  final String status;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final int orderCount;

  /// The oldest order neither completed nor cancelled, which forbids the
  /// erasure.
  final ({String id, int number})? unfinishedOrder;

  bool get isBlocked => status == 'blocked';
}

/// What a `409 account_has_unfinished_orders` names: the order in the way.
extension UnfinishedOrderRefusal on ApiFailure {
  ({String id, int number})? get unfinishedOrder {
    final ApiFailure failure = this;
    if (failure is! ApiRefusal || failure.code != accountHasUnfinishedOrders) {
      return null;
    }
    final Object? id = failure.error.details['order_id'];
    final Object? number = failure.error.details['order_number'];
    if (id is String && number is int) {
      return (id: id, number: number);
    }
    return null;
  }
}
