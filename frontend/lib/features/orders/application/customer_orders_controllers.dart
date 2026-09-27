import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show FutureProviderFamily, NotifierProviderFamily;

import '../../../app/providers.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/idempotency_key.dart';
import '../../../core/network/paged.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/state/account_mutation.dart';
import '../../../core/state/mutation_state.dart';
import '../data/customer_orders_api.dart';
import '../domain/customer_orders.dart';

final Provider<CustomerOrdersRepository> customerOrdersRepositoryProvider =
    Provider<CustomerOrdersRepository>(
      (Ref ref) => CustomerOrdersRepositoryImpl(
        CustomerOrdersApi(ref.watch(apiClientProvider)),
      ),
    );

/// The page of the Customer's orders shown while the list is open; the
/// list opens on the newest orders again, and another account starts over.
class OrdersPageController extends Notifier<int> {
  @override
  int build() {
    ref.watch(customerAccountProvider);
    return 1;
  }

  void goToPage(int page) => state = page;
}

final NotifierProvider<OrdersPageController, int> ordersPageProvider =
    NotifierProvider.autoDispose<OrdersPageController, int>(
      OrdersPageController.new,
    );

/// The Customer's orders, newest first, one page at a time.
final FutureProvider<Paged<OrderSummary>> customerOrdersProvider =
    FutureProvider.autoDispose<Paged<OrderSummary>>((Ref ref) {
      if (ref.watch(customerAccountProvider) == null) {
        return Completer<Paged<OrderSummary>>().future;
      }
      return ref
          .watch(customerOrdersRepositoryProvider)
          .orders(ref.watch(ordersPageProvider));
    });

/// One of the Customer's orders.
final FutureProviderFamily<CustomerOrder, String> customerOrderProvider =
    FutureProvider.autoDispose.family<CustomerOrder, String>((
      Ref ref,
      String id,
    ) {
      if (ref.watch(customerAccountProvider) == null) {
        return Completer<CustomerOrder>().future;
      }
      return ref.watch(customerOrdersRepositoryProvider).order(id);
    });

/// A change to one order from its screens. After it — and after a conflict,
/// the order gone, or an uncertain outcome — the order and the list load
/// again, so a `409` shows the order as it now is (`DL-28` (11)).
abstract class OrderMutation extends AccountMutation {
  OrderMutation(this.orderId);

  final String orderId;

  @override
  Provider<String?> get account => customerAccountProvider;

  CustomerOrdersRepository get orders =>
      ref.read(customerOrdersRepositoryProvider);

  void reload(Object? _) => ref
    ..invalidate(customerOrderProvider(orderId))
    ..invalidate(customerOrdersProvider);
}

/// The order's edit: every line it keeps and the delivery wish.
class OrderEditController extends OrderMutation {
  OrderEditController(super.orderId);

  Future<CustomerOrder?> edit(
    List<OrderEditLine> lines,
    String? deliveryTimeNote,
  ) => perform(
    () => orders.edit(orderId, lines, deliveryTimeNote),
    reload: reload,
  );
}

final NotifierProviderFamily<OrderEditController, MutationState, String>
orderEditProvider = NotifierProvider.autoDispose
    .family<OrderEditController, MutationState, String>(
      OrderEditController.new,
    );

/// The order's direct cancellation, under an `Idempotency-Key` kept until
/// an answer says for sure whether it cancelled (`docs/09` sections 22 and
/// 48); a cancelled order is a natural repeat anyway.
class OrderCancelController extends OrderMutation {
  OrderCancelController(super.orderId);

  String? _key;
  String? _reason;

  /// Whether a cancel was sent and no answer has said for sure what it did;
  /// a retry then sends [unconfirmedReason] again, under the same key, so the
  /// server sees the same request.
  bool get unconfirmed => _key != null;

  String? get unconfirmedReason => _reason;

  Future<CustomerOrder?> cancel(String? reason) async {
    // A tap while a cancel runs is not another attempt, and leaves the key.
    if (state.isBusy) {
      return null;
    }
    if (_key == null) {
      _key = newIdempotencyKey();
      _reason = reason;
    }
    final String key = _key!;
    final String? sent = _reason;
    final CustomerOrder? order = await perform(
      () => orders.cancel(orderId, sent, key),
      reload: reload,
    );
    final ApiFailure? failure = ref.mounted ? state.failure : null;
    final bool uncertain =
        failure != null &&
        (failure is! ApiRefusal ||
            failure.status >= 500 ||
            failure.code == 'idempotency_in_progress');
    if (!uncertain) {
      _key = null;
      _reason = null;
    }
    return order;
  }
}

final NotifierProviderFamily<OrderCancelController, MutationState, String>
orderCancelProvider = NotifierProvider.autoDispose
    .family<OrderCancelController, MutationState, String>(
      OrderCancelController.new,
    );
