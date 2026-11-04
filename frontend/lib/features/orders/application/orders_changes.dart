import '../../../core/orders/order_values.dart';
import '../domain/customer_orders.dart';

/// What changed between two loads of «Текущие» (`DL-131`), by order.
typedef CurrentChanges = ({
  /// An order that had no question and now has some (0 → n).
  List<OrderSummary> questionsArrived,

  /// An order whose waiting questions grew (n → m > n).
  List<OrderSummary> questionsGrew,

  /// An order whose status changed, as it is now, with the status it left.
  List<({OrderSummary order, OrderStatus from})> moved,

  /// An order the earlier load did not have.
  List<OrderSummary> appeared,

  /// The last summary of each order that is gone, those the Customer took
  /// off the list themselves ([currentChanges]'s `dropped`) left out.
  List<OrderSummary> left,
});

/// Compares the rows of two successive loads of «Текущие». An order is the
/// same order by its id; [dropped] holds the ids that left on purpose, which
/// are not reported as gone (`DL-113`, `DL-131`).
CurrentChanges currentChanges(
  List<OrderSummary> before,
  List<OrderSummary> after, {
  Set<String> dropped = const <String>{},
}) {
  final Map<String, OrderSummary> was = <String, OrderSummary>{
    for (final OrderSummary order in before) order.id: order,
  };
  final Set<String> now = <String>{
    for (final OrderSummary order in after) order.id,
  };
  final List<OrderSummary> questionsArrived = <OrderSummary>[];
  final List<OrderSummary> questionsGrew = <OrderSummary>[];
  final List<({OrderSummary order, OrderStatus from})> moved =
      <({OrderSummary order, OrderStatus from})>[];
  final List<OrderSummary> appeared = <OrderSummary>[];

  for (final OrderSummary order in after) {
    final OrderSummary? earlier = was[order.id];
    if (earlier == null) {
      appeared.add(order);
      continue;
    }
    if (earlier.pendingApprovalCount == 0 && order.pendingApprovalCount > 0) {
      questionsArrived.add(order);
    } else if (order.pendingApprovalCount > earlier.pendingApprovalCount) {
      questionsGrew.add(order);
    }
    if (order.status != earlier.status) {
      moved.add((order: order, from: earlier.status));
    }
  }
  return (
    questionsArrived: questionsArrived,
    questionsGrew: questionsGrew,
    moved: moved,
    appeared: appeared,
    left: <OrderSummary>[
      for (final OrderSummary order in before)
        if (!now.contains(order.id) && !dropped.contains(order.id)) order,
    ],
  );
}
