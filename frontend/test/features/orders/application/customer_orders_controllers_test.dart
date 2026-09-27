import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/features/orders/application/customer_orders_controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_customer_orders_repository.dart';

/// A container with the cancel of [orderOne] kept alive, as its screen keeps
/// it.
ProviderContainer _container(FakeCustomerOrdersRepository orders) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      customerAccountProvider.overrideWith((Ref ref) => 'customer-a'),
      customerOrdersRepositoryProvider.overrideWithValue(orders),
    ],
  );
  container.listen(orderCancelProvider(orderOne), (_, _) {});
  return container;
}

void main() {
  test(
    'a cancel keeps its key while the answer is unknown, and only then',
    () async {
      final FakeCustomerOrdersRepository orders =
          FakeCustomerOrdersRepository();
      final ProviderContainer container = _container(orders);
      addTearDown(container.dispose);
      final OrderCancelController cancelling = container.read(
        orderCancelProvider(orderOne).notifier,
      );

      Future<String> attempt(ApiFailure? failure) async {
        orders.failure = failure;
        if (failure == null) {
          orders.answer = customerOrderJson(
            status: 'cancelled',
            changeable: false,
          );
        }
        await cancelling.cancel(null);
        return orders.cancels.last.$3;
      }

      final String first = await attempt(const NetworkFailure());
      expect(
        <String>[
          await attempt(
            const ApiRefusal(ApiError(status: 503, code: 'server_error')),
          ),
          await attempt(
            const ApiRefusal(
              ApiError(status: 409, code: 'idempotency_in_progress'),
            ),
          ),
          await attempt(
            const ApiRefusal(
              ApiError(status: 409, code: 'order_cancellation_not_allowed'),
            ),
          ),
        ],
        everyElement(first),
        reason: 'the same attempt until the server says for sure',
      );

      final String afterRefusal = await attempt(null);
      expect(afterRefusal, isNot(first), reason: 'a refusal is final');
      final String afterSuccess = await attempt(null);
      expect(afterSuccess, isNot(afterRefusal), reason: 'a success is final');
    },
  );
}
