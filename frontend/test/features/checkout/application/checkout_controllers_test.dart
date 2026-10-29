import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/orders/unconfirmed_order.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/features/cart/application/cart_controllers.dart';
import 'package:baraka_bozor/features/checkout/application/checkout_controllers.dart';
import 'package:baraka_bozor/features/checkout/domain/checkout.dart';
import 'package:baraka_bozor/features/orders/application/customer_orders_controllers.dart';
import 'package:baraka_bozor/features/orders/domain/customer_orders.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_cart_repository.dart';
import '../../../support/fake_checkout_repository.dart';
import '../../../support/fake_customer_orders_repository.dart';

/// The signed-in Customer, switchable by the test.
class _Account extends Notifier<String?> {
  @override
  String? build() => 'customer-a';

  void signIn(String? id) => state = id;
}

final NotifierProvider<_Account, String?> _account =
    NotifierProvider<_Account, String?>(_Account.new);

const CheckoutRequest _request = CheckoutRequest(
  addressId: 'a-1',
  paymentMethod: PaymentMethod.cash,
  deliveryTimeNote: null,
);

/// A container with the providers the checkout uses kept alive, as its
/// screens keep them.
ProviderContainer _container(
  FakeCheckoutRepository checkout, {
  FakeCustomerOrdersRepository? orders,
}) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      customerOrdersRepositoryProvider.overrideWithValue(
        orders ?? FakeCustomerOrdersRepository(),
      ),
      customerAccountProvider.overrideWith((Ref ref) => ref.watch(_account)),
      checkoutRepositoryProvider.overrideWithValue(checkout),
      cartRepositoryProvider.overrideWithValue(FakeCartRepository()),
    ],
  );
  container.listen(preparedCheckoutProvider, (_, _) {});
  container.listen(unconfirmedOrderProvider, (_, _) {});
  container.listen(checkoutPreviewProvider, (_, _) {});
  container.listen(placeOrderProvider, (_, _) {});
  container.listen(checkoutWishDraftProvider, (_, _) {});
  return container;
}

void main() {
  test(
    'while a confirmation is unknown nothing replaces it, whatever the taps',
    () async {
      final FakeCheckoutRepository checkout = FakeCheckoutRepository();
      final ProviderContainer container = _container(checkout);
      addTearDown(container.dispose);

      await container
          .read(checkoutPreviewProvider.notifier)
          .preview(_request, addressLine: 'Amir Temur, 12');
      final PreparedCheckout first = container.read(preparedCheckoutProvider)!;
      checkout.placeFailure = const NetworkFailure();
      await container.read(placeOrderProvider.notifier).place(first);
      expect(container.read(preparedCheckoutProvider)?.sent, isTrue);
      expect(container.read(unconfirmedOrderProvider), isTrue);

      // A preview asked for meanwhile is not even sent.
      await container
          .read(checkoutPreviewProvider.notifier)
          .preview(_request, addressLine: 'Amir Temur, 12');
      expect(checkout.previews, hasLength(1));

      // Nor is another checkout prepared or cleared over it.
      container.read(preparedCheckoutProvider.notifier)
        ..prepare(_request, first.preview, addressLine: 'Navoiy, 5')
        ..clear();
      expect(
        container.read(preparedCheckoutProvider)?.idempotencyKey,
        first.idempotencyKey,
      );
    },
  );

  test('a checkout that is no longer the prepared one is not sent', () async {
    final FakeCheckoutRepository checkout = FakeCheckoutRepository();
    final ProviderContainer container = _container(checkout);
    addTearDown(container.dispose);

    await container
        .read(checkoutPreviewProvider.notifier)
        .preview(_request, addressLine: 'Amir Temur, 12');
    final PreparedCheckout first = container.read(preparedCheckoutProvider)!;
    await container
        .read(checkoutPreviewProvider.notifier)
        .preview(_request, addressLine: 'Amir Temur, 12');

    final PlacedOrder? placed = await container
        .read(placeOrderProvider.notifier)
        .place(first);

    expect(placed, isNull);
    expect(checkout.placements, isEmpty);
  });

  test(
    'another account starts the checkout and the cart notice over',
    () async {
      final FakeCheckoutRepository checkout = FakeCheckoutRepository();
      final ProviderContainer container = _container(checkout);
      addTearDown(container.dispose);

      await container
          .read(checkoutPreviewProvider.notifier)
          .preview(_request, addressLine: 'Amir Temur, 12');
      checkout.placeFailure = const NetworkFailure();
      await container
          .read(placeOrderProvider.notifier)
          .place(container.read(preparedCheckoutProvider)!);
      expect(container.read(unconfirmedOrderProvider), isTrue);

      container.read(_account.notifier).signIn('customer-b');

      expect(container.read(preparedCheckoutProvider), isNull);
      expect(container.read(unconfirmedOrderProvider), isFalse);
    },
  );

  test(
    'the wish draft outlives the screen and starts over for another account',
    () {
      final ProviderContainer container = _container(FakeCheckoutRepository());
      addTearDown(container.dispose);
      expect(container.read(checkoutWishDraftProvider), '');

      container.read(checkoutWishDraftProvider.notifier).set('после 18:00');
      expect(container.read(checkoutWishDraftProvider), 'после 18:00');

      container.read(_account.notifier).signIn('customer-b');
      expect(container.read(checkoutWishDraftProvider), '');
    },
  );

  test('a placed order clears the draft', () async {
    final ProviderContainer container = _container(FakeCheckoutRepository());
    addTearDown(container.dispose);
    await container
        .read(checkoutPreviewProvider.notifier)
        .preview(_request, addressLine: 'Amir Temur, 12');
    container.read(checkoutWishDraftProvider.notifier).set('после 18:00');

    await container
        .read(placeOrderProvider.notifier)
        .place(container.read(preparedCheckoutProvider)!);

    expect(container.read(checkoutWishDraftProvider), '');
  });

  test('a refused or unknown placement keeps the draft', () async {
    final FakeCheckoutRepository checkout = FakeCheckoutRepository();
    final ProviderContainer container = _container(checkout);
    addTearDown(container.dispose);
    await container
        .read(checkoutPreviewProvider.notifier)
        .preview(_request, addressLine: 'Amir Temur, 12');
    container.read(checkoutWishDraftProvider.notifier).set('после 18:00');

    checkout.placeFailure = const ApiRefusal(
      ApiError(status: 409, code: 'product_unavailable'),
    );
    await container
        .read(placeOrderProvider.notifier)
        .place(container.read(preparedCheckoutProvider)!);
    expect(container.read(checkoutWishDraftProvider), 'после 18:00');

    await container
        .read(checkoutPreviewProvider.notifier)
        .preview(_request, addressLine: 'Amir Temur, 12');
    checkout.placeFailure = const NetworkFailure();
    await container
        .read(placeOrderProvider.notifier)
        .place(container.read(preparedCheckoutProvider)!);
    expect(container.read(checkoutWishDraftProvider), 'после 18:00');
  });

  group('a kept orders list is asked for again', () {
    int listLoads(FakeCustomerOrdersRepository orders) =>
        orders.loads.where((String l) => l.startsWith('orders:')).length;

    Future<
      (
        ProviderContainer,
        FakeCheckoutRepository,
        FakeCustomerOrdersRepository,
        int,
      )
    >
    kept() async {
      final FakeCheckoutRepository checkout = FakeCheckoutRepository();
      final FakeCustomerOrdersRepository orders =
          FakeCustomerOrdersRepository();
      final ProviderContainer container = _container(checkout, orders: orders);
      addTearDown(container.dispose);
      container.listen(customerOrdersProvider(OrdersTab.current), (_, _) {});
      await container.read(customerOrdersProvider(OrdersTab.current).future);
      await container
          .read(checkoutPreviewProvider.notifier)
          .preview(_request, addressLine: 'Amir Temur, 12');
      return (container, checkout, orders, listLoads(orders));
    }

    test('after an order is placed', () async {
      final (container, _, orders, before) = await kept();

      await container
          .read(placeOrderProvider.notifier)
          .place(container.read(preparedCheckoutProvider)!);
      await container.read(customerOrdersProvider(OrdersTab.current).future);

      expect(listLoads(orders), before + 1);
    });

    test('after an outcome that may have placed it', () async {
      final (container, checkout, orders, before) = await kept();
      checkout.placeFailure = const NetworkFailure();

      await container
          .read(placeOrderProvider.notifier)
          .place(container.read(preparedCheckoutProvider)!);
      await container.read(customerOrdersProvider(OrdersTab.current).future);

      expect(listLoads(orders), before + 1);
    });

    test('but not after a refusal that placed nothing', () async {
      final (container, checkout, orders, before) = await kept();
      checkout.placeFailure = const ApiRefusal(
        ApiError(status: 409, code: 'product_unavailable'),
      );

      await container
          .read(placeOrderProvider.notifier)
          .place(container.read(preparedCheckoutProvider)!);
      await container.read(customerOrdersProvider(OrdersTab.current).future);

      expect(listLoads(orders), before);
    });
  });
}
