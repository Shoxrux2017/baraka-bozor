import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../../app/providers.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/state/account_mutation.dart';
import '../../../core/state/mutation_state.dart';
import '../data/cart_api.dart';
import '../domain/cart.dart';

final Provider<CartRepository> cartRepositoryProvider =
    Provider<CartRepository>(
      (Ref ref) => CartRepositoryImpl(CartApi(ref.watch(apiClientProvider))),
    );

/// The signed-in Customer's cart, as the server last answered it: loaded
/// once for the account, and replaced by the whole cart every change
/// answers, so the badge, the cart screen and the product screen agree
/// without asking again. Another account starts it over.
class CartController extends AsyncNotifier<Cart> {
  @override
  Future<Cart> build() {
    if (ref.watch(customerAccountProvider) == null) {
      return Completer<Cart>().future;
    }
    return ref.watch(cartRepositoryProvider).cart();
  }

  /// The cart as a change answered it.
  void show(Cart cart) => state = AsyncData<Cart>(cart);
}

final AsyncNotifierProvider<CartController, Cart> cartProvider =
    AsyncNotifierProvider<CartController, Cart>(CartController.new);

/// A change to the cart from one of the Customer's surfaces. Its answer
/// becomes the cart; a failure that may leave the cart stale — a conflict,
/// a line gone, an uncertain outcome — loads it again (`DL-28` (11)).
abstract class CartMutation extends AccountMutation {
  @override
  Provider<String?> get account => customerAccountProvider;

  CartRepository get carts => ref.read(cartRepositoryProvider);

  void showCart(Cart? cart) {
    if (cart == null) {
      ref.invalidate(cartProvider);
    } else {
      ref.read(cartProvider.notifier).show(cart);
    }
  }
}

/// "Add to cart" on one product's screen.
class AddToCartController extends CartMutation {
  AddToCartController(this.productId);

  final String productId;

  Future<Cart?> add(NewCartLine line) =>
      perform(() => carts.add(line), reload: showCart);
}

final NotifierProviderFamily<AddToCartController, MutationState, String>
addToCartProvider = NotifierProvider.autoDispose
    .family<AddToCartController, MutationState, String>(
      AddToCartController.new,
    );

/// The editor of one line.
class CartLineController extends CartMutation {
  CartLineController(this.lineId);

  final String lineId;

  Future<Cart?> change(CartLinePatch patch) =>
      perform(() => carts.change(lineId, patch), reload: showCart);
}

final NotifierProviderFamily<CartLineController, MutationState, String>
cartLineProvider = NotifierProvider.autoDispose
    .family<CartLineController, MutationState, String>(CartLineController.new);

/// The cart screen's removals.
class CartListActions extends CartMutation {
  Future<Cart?> remove(String lineId) =>
      perform(() => carts.remove(lineId), reload: showCart);
}

final NotifierProvider<CartListActions, MutationState> cartListActionsProvider =
    NotifierProvider.autoDispose<CartListActions, MutationState>(
      CartListActions.new,
    );
