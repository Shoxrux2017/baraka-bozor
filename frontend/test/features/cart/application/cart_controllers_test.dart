import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/features/cart/application/cart_controllers.dart';
import 'package:baraka_bozor/features/cart/domain/cart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_cart_repository.dart';

/// The signed-in Customer, switchable by the test.
class _Account extends Notifier<String?> {
  @override
  String? build() => 'customer-a';

  void signIn(String? id) => state = id;
}

final NotifierProvider<_Account, String?> _account =
    NotifierProvider<_Account, String?>(_Account.new);

void main() {
  test(
    'the cart follows the answers and starts over for another account',
    () async {
      final FakeCartRepository carts = FakeCartRepository(
        cart: cartOf(<Map<String, Object?>>[cartLineJson()]),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          customerAccountProvider.overrideWith(
            (Ref ref) => ref.watch(_account),
          ),
          cartRepositoryProvider.overrideWithValue(carts),
        ],
      );
      addTearDown(container.dispose);

      expect((await container.read(cartProvider.future)).itemCount, 1);

      container
          .read(cartProvider.notifier)
          .show(cartOf(<Map<String, Object?>>[]));
      expect(
        container.read(cartProvider).value?.itemCount,
        0,
        reason: 'the answer',
      );

      carts.current = cartOf(<Map<String, Object?>>[
        cartLineJson(),
        cartLineJson(
          id: breadLine,
          productId: breadProduct,
          unit: 'piece',
          quantity: '2',
        ),
      ]);
      container.read(_account.notifier).signIn('customer-b');

      final Cart other = await container.read(cartProvider.future);
      expect(other.itemCount, 2, reason: 'loaded again for the other account');
      expect(carts.calls.where((String call) => call == 'cart'), hasLength(2));
    },
  );
}
