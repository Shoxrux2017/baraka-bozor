import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show FutureProviderFamily, NotifierProviderFamily;

import '../../../app/providers.dart';
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
/// is (`DL-28` (11)).
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
