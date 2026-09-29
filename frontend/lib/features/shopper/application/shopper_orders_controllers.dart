import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show FutureProviderFamily, NotifierProviderFamily;

import '../../../app/providers.dart';
import '../../../core/network/idempotency_key.dart';
import '../../../core/network/paged.dart';
import '../../../core/session/staff_account.dart';
import '../../../core/state/account_mutation.dart';
import '../../../core/state/mutation_state.dart';
import '../data/shopper_orders_api.dart';
import '../domain/shopper_orders.dart';

final Provider<ShopperOrdersRepository> shopperOrdersRepositoryProvider =
    Provider<ShopperOrdersRepository>(
      (Ref ref) => ShopperOrdersRepositoryImpl(
        ShopperOrdersApi(ref.watch(apiClientProvider)),
      ),
    );

/// The page of the Shopper's orders shown while the list is open; it opens
/// on the first page again, and another account starts over.
class ShopperOrdersPageController extends Notifier<int> {
  @override
  int build() {
    ref.watch(staffAccountProvider);
    return 1;
  }

  void goToPage(int page) => state = page;
}

final NotifierProvider<ShopperOrdersPageController, int>
shopperOrdersPageProvider =
    NotifierProvider.autoDispose<ShopperOrdersPageController, int>(
      ShopperOrdersPageController.new,
    );

/// The Shopper's current orders, the longest-waiting assignment first.
final FutureProvider<Paged<ShopperOrderRow>> shopperOrdersProvider =
    FutureProvider.autoDispose<Paged<ShopperOrderRow>>((Ref ref) {
      if (ref.watch(staffAccountProvider) == null) {
        return Completer<Paged<ShopperOrderRow>>().future;
      }
      return ref
          .watch(shopperOrdersRepositoryProvider)
          .orders(ref.watch(shopperOrdersPageProvider));
    });

/// One of the Shopper's current orders.
final FutureProviderFamily<ShopperOrder, String> shopperOrderProvider =
    FutureProvider.autoDispose.family<ShopperOrder, String>((
      Ref ref,
      String id,
    ) {
      if (ref.watch(staffAccountProvider) == null) {
        return Completer<ShopperOrder>().future;
      }
      return ref.watch(shopperOrdersRepositoryProvider).order(id);
    });

/// The Shopper's acceptance and start of one order, one at a time. After
/// either — and after a conflict, the order gone, or an uncertain outcome —
/// the order and the list load again, so a `409` shows the order as it now
/// is (`DL-28` (11)). Both repeat harmlessly and name nothing but the
/// order, so nothing waits for that reload (`DL-69` (4)).
class ShopperOrderController extends AccountMutation {
  ShopperOrderController(this.orderId);

  final String orderId;

  @override
  Provider<String?> get account => staffAccountProvider;

  ShopperOrdersRepository get _orders =>
      ref.read(shopperOrdersRepositoryProvider);

  Future<ShopperOrder?> accept() =>
      perform(() => _orders.accept(orderId), reload: _reload);

  Future<ShopperOrder?> start() =>
      perform(() => _orders.start(orderId), reload: _reload);

  void _reload(Object? _) => ref
    ..invalidate(shopperOrderProvider(orderId))
    ..invalidate(shopperOrdersProvider);
}

final NotifierProviderFamily<ShopperOrderController, MutationState, String>
shopperOrderActionProvider = NotifierProvider.autoDispose
    .family<ShopperOrderController, MutationState, String>(
      ShopperOrderController.new,
    );

/// An order's line, as the actions at the market name it.
typedef ShopperLineRef = ({String orderId, String itemId});

/// A keyed request sent without a sure answer: its `Idempotency-Key` and
/// what was sent, which a retry sends again as it was (`docs/09` section
/// 48).
final class UnansweredRequest<T> {
  const UnansweredRequest(this.key, this.sent);

  final String key;
  final T sent;
}

/// One order's keyed requests still without a sure answer: each line's
/// purchase and the completion (`DL-70` (5)). A request enters only once an
/// answer failed to say what it did — no answer, a server error, the same
/// key still running — and leaves at the first sure answer. The order's
/// screen watches this, so it lasts while the order is shown, whatever its
/// lines' cards and its loads do; another account starts over.
final class UnansweredRequests {
  const UnansweredRequests({
    this.purchases = const <String, UnansweredRequest<PurchaseEntry>>{},
    this.completion,
  });

  /// By line id.
  final Map<String, UnansweredRequest<PurchaseEntry>> purchases;
  final UnansweredRequest<void>? completion;
}

class UnansweredRequestsController extends Notifier<UnansweredRequests> {
  UnansweredRequestsController(this.orderId);

  final String orderId;

  @override
  UnansweredRequests build() {
    ref.watch(staffAccountProvider);
    return const UnansweredRequests();
  }

  void purchase(String itemId, UnansweredRequest<PurchaseEntry>? request) {
    final Map<String, UnansweredRequest<PurchaseEntry>> purchases =
        <String, UnansweredRequest<PurchaseEntry>>{...state.purchases};
    if (request == null) {
      purchases.remove(itemId);
    } else {
      purchases[itemId] = request;
    }
    state = UnansweredRequests(
      purchases: purchases,
      completion: state.completion,
    );
  }

  void completion(UnansweredRequest<void>? request) => state =
      UnansweredRequests(purchases: state.purchases, completion: request);
}

final NotifierProviderFamily<
  UnansweredRequestsController,
  UnansweredRequests,
  String
>
unansweredRequestsProvider = NotifierProvider.autoDispose
    .family<UnansweredRequestsController, UnansweredRequests, String>(
      UnansweredRequestsController.new,
    );

/// A line's actions at the market (`docs/09` sections 30 to 34), one at a
/// time: the purchase, the line not to be found, a replacement, and the
/// questions to the Customer. After each — and after a refusal an order
/// changed meanwhile may explain — the order and the list load again
/// (`DL-28` (11)); an answer whose order left the Shopper — the last line
/// not found cancels it — is not loaded again, since the Shopper may no
/// longer read it (`DL-70` (6)).
///
/// The purchase is keyed: without a sure answer its key and what was sent
/// wait in [unansweredRequestsProvider], and a retry sends them again.
class ShopperLineController extends AccountMutation {
  ShopperLineController(this.line);

  final ShopperLineRef line;

  @override
  Provider<String?> get account => staffAccountProvider;

  ShopperOrdersRepository get _orders =>
      ref.read(shopperOrdersRepositoryProvider);

  /// Records [entry]; while an earlier purchase of the line has no sure
  /// answer, sends that one again instead, under its key.
  Future<ShopperOrder?> purchase(PurchaseEntry entry) async {
    // A tap while a purchase runs is not another attempt.
    if (state.isBusy) {
      return null;
    }
    final UnansweredRequest<PurchaseEntry>? unanswered = ref
        .read(unansweredRequestsProvider(line.orderId))
        .purchases[line.itemId];
    final String key = unanswered?.key ?? newIdempotencyKey();
    final PurchaseEntry sent = unanswered?.sent ?? entry;
    final ShopperOrder? order = await perform(
      () => _orders.purchase(line.orderId, line.itemId, sent, key),
      reload: _reload,
    );
    if (ref.mounted) {
      ref
          .read(unansweredRequestsProvider(line.orderId).notifier)
          .purchase(
            line.itemId,
            leavesOutcomeUnknown(state.failure)
                ? UnansweredRequest<PurchaseEntry>(key, sent)
                : null,
          );
    }
    return order;
  }

  Future<ShopperOrder?> markUnavailable(String? note) => perform(
    () => _orders.markUnavailable(line.orderId, line.itemId, note),
    reload: _reload,
  );

  Future<ShopperOrder?> askAboutPrice(
    int actualMarketPriceUzs,
    String? productId,
    String? note,
  ) => perform(
    () => _orders.askAboutPrice(
      line.orderId,
      line.itemId,
      actualMarketPriceUzs,
      productId,
      note,
    ),
    reload: _reload,
  );

  Future<ShopperOrder?> substitute(
    String replacementId,
    int actualMarketPriceUzs,
    String? note,
  ) => perform(
    () => _orders.substitute(
      line.orderId,
      line.itemId,
      replacementId,
      actualMarketPriceUzs,
      note,
    ),
    reload: _reload,
  );

  Future<ShopperOrder?> askAboutQuantity(String quantity, String? note) =>
      perform(
        () =>
            _orders.askAboutQuantity(line.orderId, line.itemId, quantity, note),
        reload: _reload,
      );

  void _reload(ShopperOrder? answered) {
    if (answered == null || answered.assignment != null) {
      ref.invalidate(shopperOrderProvider(line.orderId));
    }
    ref.invalidate(shopperOrdersProvider);
  }
}

final NotifierProviderFamily<
  ShopperLineController,
  MutationState,
  ShopperLineRef
>
shopperLineActionProvider = NotifierProvider.autoDispose
    .family<ShopperLineController, MutationState, ShopperLineRef>(
      ShopperLineController.new,
    );

/// The completion of an order's shopping (`docs/09` section 35), keyed as
/// the purchase is. The order's screen watches it, and stops its refresh
/// while it runs.
///
/// Only the list loads again after it: a completed order is the Shopper's
/// no more, and after a completion without a sure answer the order may not
/// be either, so its page keeps what it shows and offers to send the
/// completion again. A sure refusal loads the order again too.
class ShopperCompleteController extends AccountMutation {
  ShopperCompleteController(this.orderId);

  final String orderId;

  @override
  Provider<String?> get account => staffAccountProvider;

  Future<ShopperOrder?> complete() async {
    if (state.isBusy) {
      return null;
    }
    final String key =
        ref.read(unansweredRequestsProvider(orderId)).completion?.key ??
        newIdempotencyKey();
    final ShopperOrder? order = await perform(
      () => ref.read(shopperOrdersRepositoryProvider).complete(orderId, key),
      reload: (ShopperOrder? _) => ref.invalidate(shopperOrdersProvider),
    );
    if (ref.mounted) {
      final bool unknown = leavesOutcomeUnknown(state.failure);
      ref
          .read(unansweredRequestsProvider(orderId).notifier)
          .completion(unknown ? UnansweredRequest<void>(key, null) : null);
      if (state.failure != null && !unknown) {
        ref.invalidate(shopperOrderProvider(orderId));
      }
    }
    return order;
  }
}

final NotifierProviderFamily<ShopperCompleteController, MutationState, String>
shopperCompleteProvider = NotifierProvider.autoDispose
    .family<ShopperCompleteController, MutationState, String>(
      ShopperCompleteController.new,
    );

/// A page of the products a line may be replaced with, matching a search.
typedef ReplacementQuery = ({
  String orderId,
  String itemId,
  String search,
  int page,
});

final FutureProviderFamily<Paged<ReplacementChoice>, ReplacementQuery>
replacementChoicesProvider = FutureProvider.autoDispose
    .family<Paged<ReplacementChoice>, ReplacementQuery>((
      Ref ref,
      ReplacementQuery query,
    ) {
      if (ref.watch(staffAccountProvider) == null) {
        return Completer<Paged<ReplacementChoice>>().future;
      }
      return ref
          .watch(shopperOrdersRepositoryProvider)
          .replacements(query.orderId, query.itemId, query.search, query.page);
    });
