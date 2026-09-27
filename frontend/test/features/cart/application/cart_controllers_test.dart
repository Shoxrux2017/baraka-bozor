import 'dart:async';

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
  late FakeCartRepository carts;
  late ProviderContainer container;

  setUp(() {
    carts = FakeCartRepository(
      cart: cartOf(<Map<String, Object?>>[cartLineJson()]),
    );
    container = ProviderContainer(
      overrides: [
        customerAccountProvider.overrideWith((Ref ref) => ref.watch(_account)),
        cartRepositoryProvider.overrideWithValue(carts),
      ],
    );
    addTearDown(container.dispose);
  });

  Map<String, Object?> bread() => cartLineJson(
    id: breadLine,
    productId: breadProduct,
    unit: 'piece',
    quantity: '2',
  );

  test('another account never sees the last one\'s lines, even while its own load runs', () async {
    container.listen(currentCartProvider, (_, _) {});
    await container.read(cartProvider('customer-a').future);
    expect(container.read(currentCartProvider).value?.itemCount, 1);

    final Completer<void> hold = Completer<void>();
    carts
      ..hold = hold
      ..current = cartOf(<Map<String, Object?>>[cartLineJson(), bread()]);
    container.read(_account.notifier).signIn('customer-b');

    expect(
      container.read(currentCartProvider).value,
      isNull,
      reason: "B's cart is on its way; A's is not B's",
    );

    carts.hold = null;
    hold.complete();
    expect(
      (await container.read(cartProvider('customer-b').future)).itemCount,
      2,
    );
  });

  test(
    'an answer shown while a load runs is not overwritten by that load',
    () async {
      final Completer<void> hold = Completer<void>();
      carts.hold = hold;
      container.listen(cartProvider('customer-a'), (_, _) {});

      // The first load is held; a change answers meanwhile.
      final Cart answered = cartOf(<Map<String, Object?>>[
        cartLineJson(),
        bread(),
      ]);
      container.read(cartProvider('customer-a').notifier).show(answered);
      carts.hold = null;
      hold.complete();
      await container.read(cartProvider('customer-a').future);

      expect(container.read(cartProvider('customer-a')).value?.itemCount, 2);

      // So is a refresh that started before a newer answer.
      final Completer<void> second = Completer<void>();
      carts
        ..hold = second
        ..current = cartOf(<Map<String, Object?>>[]);
      final CartController controller = container.read(
        cartProvider('customer-a').notifier,
      );
      final Future<void> refresh = controller.refresh();
      controller.show(answered);
      carts.hold = null;
      second.complete();
      await refresh;

      expect(container.read(cartProvider('customer-a')).value?.itemCount, 2);
    },
  );
}
