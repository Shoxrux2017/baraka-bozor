import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/idempotency_key.dart';
import '../../../core/orders/unconfirmed_order.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/state/mutation_state.dart';
import '../../addresses/application/addresses_controllers.dart';
import '../../cart/application/cart_controllers.dart';
import '../data/checkout_api.dart';
import '../domain/checkout.dart';

final Provider<CheckoutRepository> checkoutRepositoryProvider =
    Provider<CheckoutRepository>(
      (Ref ref) =>
          CheckoutRepositoryImpl(CheckoutApi(ref.watch(apiClientProvider))),
    );

/// The preview the Customer is looking at, ready to confirm, with the key
/// its confirmation goes under: new for every preview, the same for every
/// retry of it (`docs/09` section 48). It outlives the checkout screen, so a
/// confirmation whose outcome is unknown can be sent again after the
/// Customer left and came back; another account starts it over.
class PreparedCheckoutController extends Notifier<PreparedCheckout?> {
  @override
  PreparedCheckout? build() {
    ref.watch(customerAccountProvider);
    return null;
  }

  void prepare(CheckoutRequest request, CheckoutPreview preview) => _set(
    PreparedCheckout(
      request: request,
      preview: preview,
      idempotencyKey: newIdempotencyKey(),
    ),
  );

  /// Drops the prepared checkout — never one whose confirmation may have
  /// placed the order.
  void clear() {
    if (state?.sent != true) {
      _set(null);
    }
  }

  /// The confirmation under [key] is on its way.
  void markSent(String key) {
    final PreparedCheckout? prepared = state;
    if (prepared != null && prepared.idempotencyKey == key) {
      _set(prepared.withSent(true));
    }
  }

  /// The confirmation under [key] was answered for sure: placed, or not.
  void markAnswered(String key, {required bool placed}) {
    final PreparedCheckout? prepared = state;
    if (prepared == null || prepared.idempotencyKey != key) {
      return;
    }
    _set(placed ? null : prepared.withSent(false));
  }

  void _set(PreparedCheckout? prepared) {
    state = prepared;
    ref.read(unconfirmedOrderProvider.notifier).set(prepared?.sent ?? false);
  }
}

final NotifierProvider<PreparedCheckoutController, PreparedCheckout?>
preparedCheckoutProvider =
    NotifierProvider<PreparedCheckoutController, PreparedCheckout?>(
      PreparedCheckoutController.new,
    );

/// Asking for a preview. The previous one goes as the request leaves, so a
/// refusal never leaves an old total to confirm. A refusal that may mean
/// the Customer's data moved on — an address gone, a product no longer
/// sold — loads the addresses and the cart again (`DL-28` (11)).
class CheckoutPreviewController extends CartMutation {
  CheckoutRepository get _checkout => ref.read(checkoutRepositoryProvider);

  Future<CheckoutPreview?> preview(CheckoutRequest request) {
    final PreparedCheckoutController prepared = ref.read(
      preparedCheckoutProvider.notifier,
    )..clear();
    return perform(
      () => _checkout.preview(request),
      reload: (CheckoutPreview? preview) {
        if (preview != null) {
          prepared.prepare(request, preview);
          return;
        }
        ref.invalidate(addressesProvider);
        showCart(null);
      },
    );
  }
}

final NotifierProvider<CheckoutPreviewController, MutationState>
checkoutPreviewProvider =
    NotifierProvider.autoDispose<CheckoutPreviewController, MutationState>(
      CheckoutPreviewController.new,
    );

/// Confirming a prepared checkout. The confirmation is marked sent before it
/// leaves and stays so until an answer says for sure whether it placed the
/// order: a lost answer, a server error or an order still being placed
/// leaves only the same confirmation to send again (`DL-50` (4)). The cart
/// becomes a new, empty one on the server, so it is asked for again after
/// the order is placed, and after an outcome that may have placed it.
class PlaceOrderController extends CartMutation {
  CheckoutRepository get _checkout => ref.read(checkoutRepositoryProvider);

  Future<PlacedOrder?> place(PreparedCheckout prepared) async {
    final PreparedCheckoutController checkout = ref.read(
      preparedCheckoutProvider.notifier,
    )..markSent(prepared.idempotencyKey);
    final PlacedOrder? order = await perform(
      () => _checkout.place(prepared.preview.token, prepared.idempotencyKey),
      reload: (PlacedOrder? order) {
        showCart(null);
        if (order != null) {
          checkout.markAnswered(prepared.idempotencyKey, placed: true);
        }
      },
    );
    if (order == null && ref.mounted) {
      final ApiFailure? failure = state.failure;
      if (failure != null && !isUncertain(failure)) {
        checkout.markAnswered(prepared.idempotencyKey, placed: false);
      }
    }
    return order;
  }

  /// Whether [failure] leaves open whether the order was placed.
  static bool isUncertain(ApiFailure failure) => switch (failure) {
    ApiRefusal(:final int status, :final String code) =>
      status >= 500 || code == 'idempotency_in_progress',
    _ => true,
  };
}

final NotifierProvider<PlaceOrderController, MutationState> placeOrderProvider =
    NotifierProvider.autoDispose<PlaceOrderController, MutationState>(
      PlaceOrderController.new,
    );
