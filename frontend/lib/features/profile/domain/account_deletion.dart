import '../../../core/network/api_failure.dart';
import '../../../core/orders/order_values.dart';
import '../../auth/domain/app_user.dart';

/// The order that stops an account from being deleted.
final class UnfinishedOrder {
  const UnfinishedOrder({
    required this.id,
    required this.number,
    this.status,
    this.itemCount = 0,
  });

  final String id;
  final int number;

  /// `null` when the server named a status this client does not know.
  final OrderStatus? status;
  final int itemCount;
}

/// The order named by `409 account_has_unfinished_orders`
/// (`docs/09-api-contracts.md` section 65), or `null` for any other failure
/// or a refusal whose details do not name one.
UnfinishedOrder? unfinishedOrderOf(ApiFailure failure) {
  if (failure is! ApiRefusal ||
      failure.status != 409 ||
      failure.code != 'account_has_unfinished_orders') {
    return null;
  }
  final Object? id = failure.error.details['order_id'];
  final Object? number = failure.error.details['order_number'];
  if (id is String && id.isNotEmpty && number is int) {
    final Object? status = failure.error.details['status'];
    final Object? itemCount = failure.error.details['item_count'];
    return UnfinishedOrder(
      id: id,
      number: number,
      status: status is String ? OrderStatus.tryParse(status) : null,
      itemCount: itemCount is int ? itemCount : 0,
    );
  }
  return null;
}

/// Deleting the Customer's own account behind a code sent to the phone.
/// Every method throws an `ApiFailure`.
abstract interface class AccountDeletionRepository {
  Future<RequestedCode> requestCode();

  Future<void> delete(String code);

  /// Whether the Customer's token still opens the account: `false` when the
  /// server refuses it as `authentication_required`, which after a deletion
  /// whose answer was lost means the account is gone (`DL-140`).
  Future<bool> stillExists();
}
