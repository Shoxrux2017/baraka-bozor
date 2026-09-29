import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/idempotency_key.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/session/staff_account.dart';
import 'package:baraka_bozor/features/courier/application/courier_orders_controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_courier_orders_repository.dart';

/// A container with the outcome of [courierOrderA], its unanswered handover
/// and its order kept alive, as its screen keeps them.
ProviderContainer _container(FakeCourierOrdersRepository orders) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      staffAccountProvider.overrideWith((Ref ref) => 'courier-a'),
      courierOrdersRepositoryProvider.overrideWithValue(orders),
    ],
  );
  container
    ..listen(courierOutcomeProvider(courierOrderA), (_, _) {})
    ..listen(unansweredHandoverProvider(courierOrderA), (_, _) {})
    ..listen(courierOrderProvider(courierOrderA), (_, _) {});
  return container;
}

void main() {
  late FakeCourierOrdersRepository orders;
  late ProviderContainer container;
  late CourierOutcomeController outcome;

  setUp(() {
    orders = FakeCourierOrdersRepository(
      details: {courierOrderA: courierOrder(status: 'on_the_way')},
    );
    orders.afterAction[courierOrderA] = courierOrder(
      status: 'completed',
      ended: true,
    );
    container = _container(orders);
    addTearDown(container.dispose);
    outcome = container.read(courierOutcomeProvider(courierOrderA).notifier);
  });

  test(
    'a handover without a sure answer goes again as it was, until one comes',
    () async {
      Future<void> attempt(ApiFailure? failure, int cash) {
        orders.actionFailure = failure;
        return outcome.delivered(cash);
      }

      await attempt(const NetworkFailure(), 55600);
      final UnansweredRequest<int?> kept = container.read(
        unansweredHandoverProvider(courierOrderA),
      )!;
      expect(kept.sent, 55600);
      expect(kept.key, orders.keys.single);

      // Whatever is typed since, the handover that may have gone is what
      // goes, under its key.
      await attempt(
        const ApiRefusal(ApiError(status: 503, code: 'server_error')),
        1,
      );
      await attempt(
        const ApiRefusal(
          ApiError(status: 409, code: 'idempotency_in_progress'),
        ),
        2,
      );
      await attempt(null, 3);
      expect(orders.actions, everyElement('delivered:$courierOrderA:55600'));
      expect(orders.keys, everyElement(kept.key));
      expect(container.read(unansweredHandoverProvider(courierOrderA)), isNull);
    },
  );

  test('a sure refusal lets the key go and loads the order again', () async {
    orders.actionFailure = const ApiRefusal(
      ApiError(
        status: 409,
        code: 'cash_amount_mismatch',
        details: <String, Object?>{'expected_uzs': 57000},
      ),
    );
    await outcome.delivered(55600);
    await container.pump();
    expect(container.read(unansweredHandoverProvider(courierOrderA)), isNull);
    expect(
      orders.loads.where((String load) => load == 'order:$courierOrderA'),
      hasLength(2),
      reason: 'the corrected total is read again',
    );

    orders.actionFailure = null;
    await outcome.delivered(57000);
    expect(orders.keys[1], isNot(orders.keys[0]), reason: 'a new handover');
    expect(orders.actions.last, 'delivered:$courierOrderA:57000');
  });

  test('a refused field keeps the order as shown', () async {
    orders.actionFailure = const ApiRefusal(
      ApiError(
        status: 422,
        code: 'validation_failed',
        errors: <String, List<String>>{
          'note': <String>['The note is required.'],
        },
      ),
    );
    await outcome.notDelivered(DeliveryFailureReason.other, null);
    await container.pump();
    expect(
      orders.loads.where((String load) => load == 'order:$courierOrderA'),
      hasLength(1),
    );
  });

  test('a tap while a handover runs leaves its key where it is', () async {
    orders.actionFailure = const NetworkFailure();
    await outcome.delivered(55600);
    final UnansweredRequest<int?>? kept = container.read(
      unansweredHandoverProvider(courierOrderA),
    );
    expect(kept, isNotNull);

    final Completer<void> hold = Completer<void>();
    orders
      ..actionFailure = null
      ..hold = hold;
    final Future<void> first = outcome.delivered(1);
    expect(await outcome.delivered(2), isNull);
    expect(
      container.read(unansweredHandoverProvider(courierOrderA)),
      same(kept),
      reason: 'still unanswered while the handover runs',
    );
    orders.hold = null;
    hold.complete();
    await first;
    expect(container.read(unansweredHandoverProvider(courierOrderA)), isNull);
  });

  test('one outcome at a time', () async {
    final Completer<void> hold = Completer<void>();
    orders.hold = hold;
    final Future<void> first = outcome.delivered(55600);
    expect(await outcome.delivered(55600), isNull);
    expect(
      await outcome.notDelivered(DeliveryFailureReason.refused, null),
      isNull,
    );
    expect(orders.actions, hasLength(1));
    orders.hold = null;
    hold.complete();
    await first;
  });
}
