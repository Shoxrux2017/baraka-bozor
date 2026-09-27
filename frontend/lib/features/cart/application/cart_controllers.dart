import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, NotifierProviderFamily;

import '../../../app/providers.dart';
import '../../../core/errors/report_unexpected_error.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/state/account_mutation.dart';
import '../../../core/state/mutation_state.dart';
import '../data/cart_api.dart';
import '../domain/cart.dart';

final Provider<CartRepository> cartRepositoryProvider =
    Provider<CartRepository>(
      (Ref ref) => CartRepositoryImpl(CartApi(ref.watch(apiClientProvider))),
    );

/// One Customer account's cart, as the server last answered it. It is kept
/// per account, so another account never sees this one's lines, not even
/// while its own load is on the way, and it is let go when no screen shows
/// it. Every change's answer replaces it, so the badge, the cart screen and
/// the product screen agree without asking again; a load that started
/// before a newer answer never overwrites it.
class CartController extends AsyncNotifier<Cart> {
  CartController(this.account);

  /// The Customer account this cart belongs to.
  final String account;

  /// Counts the answers shown and the loads started, so only the newest
  /// lands.
  int _version = 0;

  CartRepository get _carts => ref.read(cartRepositoryProvider);

  @override
  Future<Cart> build() async {
    final int version = _version;
    final CartRepository carts = ref.watch(cartRepositoryProvider);
    try {
      final Cart cart = await carts.cart();
      return _newer(version) ?? cart;
    } on Object {
      // A newer answer stands, whether this load succeeded or not.
      final Cart? shown = _newer(version);
      if (shown != null) {
        return shown;
      }
      rethrow;
    }
  }

  /// The cart shown since the load of [version] started, if any.
  Cart? _newer(int version) => version != _version ? state.value : null;

  /// The cart as a change answered it.
  void show(Cart cart) {
    _version++;
    state = AsyncData<Cart>(cart);
  }

  /// Asks for the cart again, as the cart screen does when it opens and a
  /// change does when its outcome may have left the cart stale.
  Future<void> refresh() async {
    final int version = ++_version;
    // A retry after a failure shows progress (`DL-30` (11)); over a cart
    // already shown, the lines stay until the answer.
    if (state.hasError) {
      state = const AsyncLoading<Cart>();
    }
    try {
      final Cart cart = await _carts.cart();
      if (version == _version && ref.mounted) {
        state = AsyncData<Cart>(cart);
      }
    } on ApiFailure catch (failure, stackTrace) {
      if (version == _version && ref.mounted) {
        state = AsyncError<Cart>(failure, stackTrace);
      }
    } catch (error, stackTrace) {
      reportUnexpectedError(error, stackTrace, 'while loading the cart');
      if (version == _version && ref.mounted) {
        state = AsyncError<Cart>(const UnexpectedFailure(), stackTrace);
      }
    }
  }
}

final AsyncNotifierProviderFamily<CartController, Cart, String> cartProvider =
    AsyncNotifierProvider.autoDispose.family<CartController, Cart, String>(
      CartController.new,
    );

/// The signed-in Customer's cart, loading while there is no Customer.
final Provider<AsyncValue<Cart>> currentCartProvider =
    Provider.autoDispose<AsyncValue<Cart>>((Ref ref) {
      final String? account = ref.watch(customerAccountProvider);
      return account == null
          ? const AsyncLoading<Cart>()
          : ref.watch(cartProvider(account));
    });

/// A change to the cart from one of the Customer's surfaces. Its answer
/// becomes the cart; a failure that may leave the cart stale — a conflict,
/// a line gone, an uncertain outcome — asks for it again (`DL-28` (11)).
abstract class CartMutation extends AccountMutation {
  @override
  Provider<String?> get account => customerAccountProvider;

  CartRepository get carts => ref.read(cartRepositoryProvider);

  /// Called only while the account the change was made for is signed in.
  void showCart(Cart? cart) {
    final String? customer = ref.read(customerAccountProvider);
    // A cart no screen shows is loaded afresh when one opens; nothing to
    // update, and nothing to ask for now.
    if (customer == null || !ref.exists(cartProvider(customer))) {
      return;
    }
    final CartController controller = ref.read(cartProvider(customer).notifier);
    if (cart == null) {
      unawaited(controller.refresh());
    } else {
      controller.show(cart);
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
