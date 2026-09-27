import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

import '../../../app/providers.dart';
import '../../../core/network/paged.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/session/staff_account.dart';
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

  void filterByPaymentMethod(PaymentMethod? method) =>
      state = state.copyWith(paymentMethod: () => method);

  /// The days of placement, both or neither.
  void filterByDays(DateTime? from, DateTime? to) =>
      state = state.copyWith(from: () => from, to: () => to);

  void selfOrdersOnly(bool only) =>
      state = state.copyWith(selfOrdersOnly: only);

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
final FutureProvider<List<ShopperChoice>> shopperOptionsProvider =
    FutureProvider.autoDispose<List<ShopperChoice>>((Ref ref) {
      if (ref.watch(staffAccountProvider) == null) {
        return Completer<List<ShopperChoice>>().future;
      }
      return ref.watch(operationsRepositoryProvider).shoppers();
    });

/// One order as the board shows it.
final FutureProviderFamily<BoardOrder, String> boardOrderProvider =
    FutureProvider.autoDispose.family<BoardOrder, String>((Ref ref, String id) {
      if (ref.watch(staffAccountProvider) == null) {
        return Completer<BoardOrder>().future;
      }
      return ref.watch(operationsRepositoryProvider).order(id);
    });

/// Loads the board again — its page, the summary and the attention list —
/// as they are on the server now.
void refreshBoard(WidgetRef ref) {
  ref
    ..invalidate(boardPageProvider)
    ..invalidate(boardSummaryProvider)
    ..invalidate(attentionProvider);
}
