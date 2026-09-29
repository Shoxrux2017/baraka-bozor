import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show FutureProviderFamily, NotifierProviderFamily;

import '../../../app/providers.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/idempotency_key.dart';
import '../../../core/network/paged.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/session/staff_account.dart';
import '../../../core/state/account_mutation.dart';
import '../../../core/state/mutation_state.dart';
import '../data/courier_orders_api.dart';
import '../domain/courier_orders.dart';

final Provider<CourierOrdersRepository> courierOrdersRepositoryProvider =
    Provider<CourierOrdersRepository>(
      (Ref ref) => CourierOrdersRepositoryImpl(
        CourierOrdersApi(ref.watch(apiClientProvider)),
      ),
    );

/// The page of the Courier's deliveries shown while the list is open; it
/// opens on the first page again, and another account starts over.
class CourierOrdersPageController extends Notifier<int> {
  @override
  int build() {
    ref.watch(staffAccountProvider);
    return 1;
  }

  void goToPage(int page) => state = page;
}

final NotifierProvider<CourierOrdersPageController, int>
courierOrdersPageProvider =
    NotifierProvider.autoDispose<CourierOrdersPageController, int>(
      CourierOrdersPageController.new,
    );

/// The Courier's current deliveries, the longest-waiting assignment first.
final FutureProvider<Paged<CourierOrder>> courierOrdersProvider =
    FutureProvider.autoDispose<Paged<CourierOrder>>((Ref ref) {
      if (ref.watch(staffAccountProvider) == null) {
        return Completer<Paged<CourierOrder>>().future;
      }
      return ref
          .watch(courierOrdersRepositoryProvider)
          .orders(ref.watch(courierOrdersPageProvider));
    });

/// One of the Courier's current deliveries.
final FutureProviderFamily<CourierOrder, String> courierOrderProvider =
    FutureProvider.autoDispose.family<CourierOrder, String>((
      Ref ref,
      String id,
    ) {
      if (ref.watch(staffAccountProvider) == null) {
        return Completer<CourierOrder>().future;
      }
      return ref.watch(courierOrdersRepositoryProvider).order(id);
    });

/// The Courier's acceptance and start of one delivery, one at a time. After
/// either — and after a conflict, the order gone, or an uncertain outcome —
/// the order and the list load again, so a `409` shows the order as it now
/// is (`DL-28` (11)). Both repeat harmlessly, as the Shopper's do (`DL-69`
/// (4)).
class CourierOrderController extends AccountMutation {
  CourierOrderController(this.orderId);

  final String orderId;

  @override
  Provider<String?> get account => staffAccountProvider;

  CourierOrdersRepository get _orders =>
      ref.read(courierOrdersRepositoryProvider);

  Future<CourierOrder?> accept() =>
      perform(() => _orders.accept(orderId), reload: _reload);

  Future<CourierOrder?> start() =>
      perform(() => _orders.start(orderId), reload: _reload);

  void _reload(Object? _) => ref
    ..invalidate(courierOrderProvider(orderId))
    ..invalidate(courierOrdersProvider);
}

final NotifierProviderFamily<CourierOrderController, MutationState, String>
courierOrderActionProvider = NotifierProvider.autoDispose
    .family<CourierOrderController, MutationState, String>(
      CourierOrderController.new,
    );

/// A delivery's handover sent without a sure answer: its key and the cash
/// sent, which a retry sends again as it was (`docs/09` section 48,
/// `DL-72`). It enters only once an answer failed to say what it did, and
/// leaves at the first sure answer; the delivery's screen watches it, so it
/// lasts while the delivery is shown, and another account starts over.
class UnansweredHandoverController extends Notifier<UnansweredRequest<int?>?> {
  UnansweredHandoverController(this.orderId);

  final String orderId;

  @override
  UnansweredRequest<int?>? build() {
    ref.watch(staffAccountProvider);
    return null;
  }

  void set(UnansweredRequest<int?>? request) => state = request;
}

final NotifierProviderFamily<
  UnansweredHandoverController,
  UnansweredRequest<int?>?,
  String
>
unansweredHandoverProvider = NotifierProvider.autoDispose
    .family<UnansweredHandoverController, UnansweredRequest<int?>?, String>(
      UnansweredHandoverController.new,
    );

/// The outcome of a delivery (`docs/09` section 37): delivered, keyed, with
/// the cash taken; or not delivered, a natural repeat, with its reason.
/// Either ends the Courier's assignment, after which the order is theirs to
/// read no more: only the list loads again. After a sure refusal the order
/// loads again too, so the Courier sees it as it now is; after an answer
/// that did not say what it did, the order's page keeps what it shows, and
/// the handover is offered again under its key (`DL-72`).
class CourierOutcomeController extends AccountMutation {
  CourierOutcomeController(this.orderId);

  final String orderId;

  @override
  Provider<String?> get account => staffAccountProvider;

  CourierOrdersRepository get _orders =>
      ref.read(courierOrdersRepositoryProvider);

  /// Hands the order over with [cashReceivedUzs]; while an earlier handover
  /// has no sure answer, sends that one again instead, under its key.
  Future<CourierOrder?> delivered(int? cashReceivedUzs) async {
    // A tap while an outcome is sent is not another one.
    if (state.isBusy) {
      return null;
    }
    final UnansweredRequest<int?>? unanswered = ref.read(
      unansweredHandoverProvider(orderId),
    );
    final String key = unanswered?.key ?? newIdempotencyKey();
    final int? sent = unanswered == null ? cashReceivedUzs : unanswered.sent;
    final CourierOrder? order = await perform(
      () => _orders.delivered(orderId, sent, key),
      reload: _reload,
    );
    if (ref.mounted) {
      final bool unknown = leavesOutcomeUnknown(state.failure);
      ref
          .read(unansweredHandoverProvider(orderId).notifier)
          .set(unknown ? UnansweredRequest<int?>(key, sent) : null);
      _afterRefusal(unknown);
    }
    return order;
  }

  Future<CourierOrder?> notDelivered(
    DeliveryFailureReason reason,
    String? note,
  ) async {
    final CourierOrder? order = await perform(
      () => _orders.notDelivered(orderId, reason, note),
      reload: _reload,
    );
    if (ref.mounted) {
      final bool unknown = leavesOutcomeUnknown(state.failure);
      // Unlike a handover, a failure sent again changes nothing, so an
      // answer that did not say what it did loads the order again at once:
      // gone, it was recorded, and the page no longer offers a handover.
      if (unknown) {
        ref.invalidate(courierOrderProvider(orderId));
      }
      _afterRefusal(unknown);
    }
    return order;
  }

  void _reload(CourierOrder? _) => ref.invalidate(courierOrdersProvider);

  /// A conflict or the order gone: the order has moved on meanwhile —
  /// handed to another Courier, cancelled, or its outcome recorded from
  /// another device — and loads again. A cash mismatch is the Courier's own
  /// count, since a price correction is locked once they set off (`docs/09`
  /// section 45). A refused field stays with the form that holds it.
  void _afterRefusal(bool unknown) {
    final ApiFailure? failure = state.failure;
    if (!unknown &&
        failure is ApiRefusal &&
        (failure.status == 404 || failure.status == 409)) {
      ref.invalidate(courierOrderProvider(orderId));
    }
  }
}

final NotifierProviderFamily<CourierOutcomeController, MutationState, String>
courierOutcomeProvider = NotifierProvider.autoDispose
    .family<CourierOutcomeController, MutationState, String>(
      CourierOutcomeController.new,
    );
