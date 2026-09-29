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

/// A line's actions at the market (`docs/09` sections 30 to 34), one at a
/// time: the purchase, the line not to be found, a replacement, and the
/// questions to the Customer. After each — and after a refusal an order
/// changed meanwhile may explain — the order and the list load again
/// (`DL-28` (11)).
///
/// The purchase is keyed: the key and what was sent are kept until an
/// answer says for sure whether the purchase was recorded, so a retry sends
/// the same purchase again under the same key (`docs/09` section 48,
/// `DL-70`). The line's card watches this, so they last while the order is
/// shown.
class ShopperLineController extends AccountMutation {
  ShopperLineController(this.line);

  final ShopperLineRef line;

  String? _key;
  PurchaseEntry? _sent;

  @override
  Provider<String?> get account => staffAccountProvider;

  ShopperOrdersRepository get _orders =>
      ref.read(shopperOrdersRepositoryProvider);

  /// The purchase sent without a sure answer, which a retry sends again.
  PurchaseEntry? get unconfirmed => _key == null ? null : _sent;

  /// Records [entry]; while an earlier purchase is unconfirmed, sends that
  /// one again instead.
  Future<ShopperOrder?> purchase(PurchaseEntry entry) async {
    // A tap while a purchase runs is not another attempt, and leaves the key.
    if (state.isBusy) {
      return null;
    }
    if (_key == null) {
      _key = newIdempotencyKey();
      _sent = entry;
    }
    final String key = _key!;
    final PurchaseEntry sent = _sent!;
    final ShopperOrder? order = await perform(
      () => _orders.purchase(line.orderId, line.itemId, sent, key),
      reload: _reload,
    );
    if (!leavesOutcomeUnknown(ref.mounted ? state.failure : null)) {
      _key = null;
      _sent = null;
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

  void _reload(Object? _) => ref
    ..invalidate(shopperOrderProvider(line.orderId))
    ..invalidate(shopperOrdersProvider);
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
/// the purchase is. A completed order leaves the Shopper, so only the list
/// loads again after it; a refusal loads the order again too.
class ShopperCompleteController extends AccountMutation {
  ShopperCompleteController(this.orderId);

  final String orderId;
  String? _key;

  @override
  Provider<String?> get account => staffAccountProvider;

  /// Whether a completion was sent without a sure answer; a retry sends it
  /// again under the same key.
  bool get unconfirmed => _key != null;

  Future<ShopperOrder?> complete() async {
    if (state.isBusy) {
      return null;
    }
    final String key = _key ??= newIdempotencyKey();
    final ShopperOrder? order = await perform(
      () => ref.read(shopperOrdersRepositoryProvider).complete(orderId, key),
      reload: (ShopperOrder? completed) {
        if (completed == null) {
          ref.invalidate(shopperOrderProvider(orderId));
        }
        ref.invalidate(shopperOrdersProvider);
      },
    );
    if (!leavesOutcomeUnknown(ref.mounted ? state.failure : null)) {
      _key = null;
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
