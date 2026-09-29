import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show FutureProviderFamily, NotifierProviderFamily;

import '../../../app/providers.dart';
import '../../../core/network/paged.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/session/staff_account.dart';
import '../../../core/state/account_mutation.dart';
import '../../../core/state/mutation_state.dart';
import '../data/operations_api.dart';
import '../data/operations_repository_impl.dart';
import '../domain/board.dart';
import '../domain/operations_repository.dart';

final Provider<OperationsRepository> operationsRepositoryProvider =
    Provider<OperationsRepository>(
      (Ref ref) =>
          OperationsRepositoryImpl(OperationsApi(ref.watch(apiClientProvider))),
    );

/// What the board shows: the page and the filters. Kept apart from the page
/// itself, so a change of filter starts a new load and a load for an older
/// query is discarded. It outlives the board — an Operator who opens an
/// order and comes back finds the board as they left it — and starts over
/// for another account (`DL-28` (1)).
class BoardQueryController extends Notifier<BoardQuery> {
  @override
  BoardQuery build() {
    ref.watch(staffAccountProvider);
    return const BoardQuery();
  }

  void goToPage(int page) => state = state.copyWith(page: page);

  void filterByStatus(OrderStatus? status) =>
      state = state.copyWith(status: () => status);

  void filterByShopper(String? shopperId) =>
      state = state.copyWith(shopperId: () => shopperId);

  void filterByCourier(String? courierId) =>
      state = state.copyWith(courierId: () => courierId);

  void filterByPaymentMethod(PaymentMethod? method) =>
      state = state.copyWith(paymentMethod: () => method);

  /// The days of placement, both or neither.
  void filterByDays(DateTime? from, DateTime? to) =>
      state = state.copyWith(from: () => from, to: () => to);

  void selfOrdersOnly(bool only) =>
      state = state.copyWith(selfOrdersOnly: only);

  void awaitingCustomerOnly(bool only) =>
      state = state.copyWith(awaitingCustomerOnly: only);

  void search(String text) => state = state.copyWith(search: text.trim());

  void clear() => state = const BoardQuery();
}

final NotifierProvider<BoardQueryController, BoardQuery> boardQueryProvider =
    NotifierProvider<BoardQueryController, BoardQuery>(
      BoardQueryController.new,
    );

/// The board's page for the current query.
final FutureProvider<Paged<BoardRow>> boardPageProvider =
    FutureProvider.autoDispose<Paged<BoardRow>>((Ref ref) {
      if (ref.watch(staffAccountProvider) == null) {
        return Completer<Paged<BoardRow>>().future;
      }
      return ref
          .watch(operationsRepositoryProvider)
          .orders(ref.watch(boardQueryProvider));
    });

/// The summary strip.
final FutureProvider<BoardSummary> boardSummaryProvider =
    FutureProvider.autoDispose<BoardSummary>((Ref ref) {
      if (ref.watch(staffAccountProvider) == null) {
        return Completer<BoardSummary>().future;
      }
      return ref.watch(operationsRepositoryProvider).summary();
    });

/// The attention list.
final FutureProvider<List<AttentionItem>> attentionProvider =
    FutureProvider.autoDispose<List<AttentionItem>>((Ref ref) {
      if (ref.watch(staffAccountProvider) == null) {
        return Completer<List<AttentionItem>>().future;
      }
      return ref.watch(operationsRepositoryProvider).attention();
    });

/// The active Shoppers, for the board's Shopper filter.
final FutureProvider<List<StaffChoice>> shopperOptionsProvider =
    FutureProvider.autoDispose<List<StaffChoice>>((Ref ref) {
      if (ref.watch(staffAccountProvider) == null) {
        return Completer<List<StaffChoice>>().future;
      }
      return ref.watch(operationsRepositoryProvider).shoppers();
    });

/// The active Couriers, for the board's Courier filter and the Courier
/// picker.
final FutureProvider<List<StaffChoice>> courierOptionsProvider =
    FutureProvider.autoDispose<List<StaffChoice>>((Ref ref) {
      if (ref.watch(staffAccountProvider) == null) {
        return Completer<List<StaffChoice>>().future;
      }
      return ref.watch(operationsRepositoryProvider).couriers();
    });

/// One order as the board shows it.
final FutureProviderFamily<BoardOrder, String> boardOrderProvider =
    FutureProvider.autoDispose.family<BoardOrder, String>((Ref ref, String id) {
      if (ref.watch(staffAccountProvider) == null) {
        return Completer<BoardOrder>().future;
      }
      return ref.watch(operationsRepositoryProvider).order(id);
    });

/// The Shopper or the Courier assignment of one order, from its page
/// (`docs/09` section 39, `DL-54` (10)): one change at a time, shown on that
/// order's page only. After it, and after a conflict — the order changed
/// under the Operator — the order, the board and the role's counts are
/// loaded again (`DL-28` (11)).
sealed class StaffAssignmentController extends AccountMutation {
  StaffAssignmentController(this.orderId);

  final String orderId;

  @override
  Provider<String?> get account => staffAccountProvider;

  /// The role's picker, whose counts a change moves. It is loaded afresh
  /// whenever it opens; invalidating it reaches whatever still shows it.
  FutureProvider<List<StaffChoice>> get _options;

  /// Assigns [staffId], or reassigns to them when [replacesAssignmentId]
  /// names the assignment they replace.
  Future<BoardOrder> _send(
    OperationsRepository operations,
    String staffId,
    String? replacesAssignmentId,
  );

  Future<BoardOrder?> assign(String staffId) => _change(staffId, null);

  Future<BoardOrder?> reassign(String staffId, String replacesAssignmentId) =>
      _change(staffId, replacesAssignmentId);

  Future<BoardOrder?> _change(String staffId, String? replacesAssignmentId) =>
      perform(
        () => _send(
          ref.read(operationsRepositoryProvider),
          staffId,
          replacesAssignmentId,
        ),
        reload: (BoardOrder? _) => ref
          ..invalidate(boardOrderProvider(orderId))
          ..invalidate(boardPageProvider)
          ..invalidate(boardSummaryProvider)
          ..invalidate(attentionProvider)
          ..invalidate(_options),
      );
}

class ShopperAssignmentController extends StaffAssignmentController {
  ShopperAssignmentController(super.orderId);

  @override
  FutureProvider<List<StaffChoice>> get _options => shopperOptionsProvider;

  @override
  Future<BoardOrder> _send(
    OperationsRepository operations,
    String staffId,
    String? replacesAssignmentId,
  ) => replacesAssignmentId == null
      ? operations.assignShopper(orderId, staffId)
      : operations.reassignShopper(orderId, staffId, replacesAssignmentId);
}

final NotifierProviderFamily<ShopperAssignmentController, MutationState, String>
shopperAssignmentProvider = NotifierProvider.autoDispose
    .family<ShopperAssignmentController, MutationState, String>(
      ShopperAssignmentController.new,
    );

class CourierAssignmentController extends StaffAssignmentController {
  CourierAssignmentController(super.orderId);

  @override
  FutureProvider<List<StaffChoice>> get _options => courierOptionsProvider;

  @override
  Future<BoardOrder> _send(
    OperationsRepository operations,
    String staffId,
    String? replacesAssignmentId,
  ) => replacesAssignmentId == null
      ? operations.assignCourier(orderId, staffId)
      : operations.reassignCourier(orderId, staffId, replacesAssignmentId);
}

final NotifierProviderFamily<CourierAssignmentController, MutationState, String>
courierAssignmentProvider = NotifierProvider.autoDispose
    .family<CourierAssignmentController, MutationState, String>(
      CourierAssignmentController.new,
    );

/// The Operator's and the Admin's actions on one order from its page
/// (`docs/09` sections 40, 41 and 45, `DL-68`): removing the line of an
/// expired question, deciding a cancellation request, cancelling after a
/// failed delivery, and the Admin's price correction. One at a time; after
/// one, and after a refusal an order changed meanwhile may explain, the
/// order, the board, the summary and the attention list are loaded again
/// (`DL-28` (11)).
class OrderActionController extends AccountMutation {
  OrderActionController(this.orderId);

  final String orderId;

  @override
  Provider<String?> get account => staffAccountProvider;

  OperationsRepository get _operations =>
      ref.read(operationsRepositoryProvider);

  Future<BoardOrder?> removeExpiredLine(String approvalId, String? note) =>
      _act(() => _operations.resolveExpiredApproval(orderId, approvalId, note));

  Future<BoardOrder?> decide(
    String requestId,
    CancellationDecision decision,
    String? note,
  ) => _act(
    () => _operations.decideCancellationRequest(
      orderId,
      requestId,
      decision,
      note,
    ),
  );

  Future<BoardOrder?> cancelAfterFailedDelivery(String? note) =>
      _act(() => _operations.cancelAfterFailedDelivery(orderId, note));

  Future<BoardOrder?> correctPrice(
    String itemId,
    int actualMarketPriceUzs,
    String reason,
  ) => _act(
    () =>
        _operations.correctPrice(orderId, itemId, actualMarketPriceUzs, reason),
  );

  Future<BoardOrder?> _act(Future<BoardOrder> Function() change) => perform(
    change,
    reload: (BoardOrder? _) => ref
      ..invalidate(boardOrderProvider(orderId))
      ..invalidate(boardPageProvider)
      ..invalidate(boardSummaryProvider)
      ..invalidate(attentionProvider),
  );
}

final NotifierProviderFamily<OrderActionController, MutationState, String>
orderActionProvider = NotifierProvider.autoDispose
    .family<OrderActionController, MutationState, String>(
      OrderActionController.new,
    );

/// Loads the board again — its page, the summary and the attention list —
/// as they are on the server now.
void refreshBoard(WidgetRef ref) {
  ref
    ..invalidate(boardPageProvider)
    ..invalidate(boardSummaryProvider)
    ..invalidate(attentionProvider);
}
