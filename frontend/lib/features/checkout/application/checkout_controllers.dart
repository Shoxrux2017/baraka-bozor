import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/idempotency_key.dart';
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
/// retry of it (`docs/09` section 48). Another account starts it over, and
/// so does any change to what was previewed.
class PreparedCheckoutController extends Notifier<PreparedCheckout?> {
  @override
  PreparedCheckout? build() {
    ref.watch(customerAccountProvider);
    return null;
  }

  void prepare(CheckoutRequest request, CheckoutPreview preview) =>
      state = PreparedCheckout(
        request: request,
        preview: preview,
        idempotencyKey: newIdempotencyKey(),
      );

  void clear() => state = null;
}

final NotifierProvider<PreparedCheckoutController, PreparedCheckout?>
preparedCheckoutProvider =
    NotifierProvider.autoDispose<PreparedCheckoutController, PreparedCheckout?>(
      PreparedCheckoutController.new,
    );

/// Asking for a preview. A refusal that may mean the Customer's data moved
/// on — an address gone, a product no longer sold — loads the addresses
/// and the cart again (`DL-28` (11)).
class CheckoutPreviewController extends CartMutation {
  CheckoutRepository get _checkout => ref.read(checkoutRepositoryProvider);

  Future<CheckoutPreview?> preview(CheckoutRequest request) => perform(
    () => _checkout.preview(request),
    reload: (CheckoutPreview? preview) {
      final PreparedCheckoutController prepared = ref.read(
        preparedCheckoutProvider.notifier,
      );
      if (preview != null) {
        prepared.prepare(request, preview);
        return;
      }
      prepared.clear();
      ref.invalidate(addressesProvider);
      showCart(null);
    },
  );
}

final NotifierProvider<CheckoutPreviewController, MutationState>
checkoutPreviewProvider =
    NotifierProvider.autoDispose<CheckoutPreviewController, MutationState>(
      CheckoutPreviewController.new,
    );

/// Confirming a prepared checkout. The cart becomes a new, empty one on the
/// server, so it is asked for again after the order is placed, and after
/// an outcome that may have placed it.
class PlaceOrderController extends CartMutation {
  CheckoutRepository get _checkout => ref.read(checkoutRepositoryProvider);

  Future<PlacedOrder?> place(PreparedCheckout prepared) => perform(
    () => _checkout.place(prepared.preview.token, prepared.idempotencyKey),
    reload: (PlacedOrder? order) {
      showCart(null);
      if (order != null) {
        ref.read(preparedCheckoutProvider.notifier).clear();
      }
    },
  );
}

final NotifierProvider<PlaceOrderController, MutationState> placeOrderProvider =
    NotifierProvider.autoDispose<PlaceOrderController, MutationState>(
      PlaceOrderController.new,
    );
