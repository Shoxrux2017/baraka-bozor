import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/idempotency_key.dart';
import 'package:baraka_bozor/core/platform/clock.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/features/cart/application/cart_controllers.dart';
import 'package:baraka_bozor/features/orders/application/customer_orders_controllers.dart';
import 'package:baraka_bozor/features/orders/domain/customer_orders.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_cart_repository.dart';
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

class _Account extends Notifier<String?> {
  @override
  String? build() => 'c-1';

  void signIn(String? id) => state = id;
}

final NotifierProvider<_Account, String?> _account =
    NotifierProvider<_Account, String?>(_Account.new);

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

      expect(
        orders.cancels.map(((String, String?, String) c) => c.$2).toSet(),
        <String?>{null},
        reason: 'no reason was given',
      );

      final String afterRefusal = await attempt(null);
      expect(afterRefusal, isNot(first), reason: 'a refusal is final');
      final String afterSuccess = await attempt(null);
      expect(afterSuccess, isNot(afterRefusal), reason: 'a success is final');
    },
  );

  test('a retry sends the reason of the attempt it repeats', () async {
    final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository();
    final ProviderContainer container = _container(orders);
    addTearDown(container.dispose);
    final OrderCancelController cancelling = container.read(
      orderCancelProvider(orderOne).notifier,
    );

    orders.failure = const NetworkFailure();
    await cancelling.cancel('Kerak emas');
    expect(cancelling.unconfirmed, isTrue);
    expect(cancelling.unconfirmedReason, 'Kerak emas');

    orders.answer = customerOrderJson(status: 'cancelled', changeable: false);
    await cancelling.cancel('Boshqa sabab');
    expect(orders.cancels[1].$2, 'Kerak emas');
    expect(orders.cancels[1].$3, orders.cancels[0].$3);
    expect(cancelling.unconfirmed, isFalse);
    expect(cancelling.unconfirmedReason, isNull);
  });

  test(
    'a cancel asked for while one runs neither goes nor drops the key',
    () async {
      final FakeCustomerOrdersRepository orders =
          FakeCustomerOrdersRepository();
      final ProviderContainer container = _container(orders);
      addTearDown(container.dispose);
      final OrderCancelController cancelling = container.read(
        orderCancelProvider(orderOne).notifier,
      );
      final Completer<void> hold = Completer<void>();
      orders
        ..hold = hold
        ..failure = const NetworkFailure();

      final Future<void> first = cancelling.cancel(null);
      expect(await cancelling.cancel(null), isNull);
      expect(orders.cancels, hasLength(1));
      orders.hold = null;
      hold.complete();
      await first;

      orders.answer = customerOrderJson(status: 'cancelled', changeable: false);
      await cancelling.cancel(null);
      expect(orders.cancels[1].$3, orders.cancels[0].$3);
    },
  );

  test(
    'a decision without a sure answer goes again as it was, until one comes',
    () async {
      final FakeCustomerOrdersRepository orders =
          FakeCustomerOrdersRepository();
      final ProviderContainer container = _container(orders);
      addTearDown(container.dispose);
      const OrderLineRef line = (orderId: orderOne, lineId: lineTomato);
      container
        ..listen(approvalDecisionProvider(line), (_, _) {})
        ..listen(unansweredDecisionsProvider(orderOne), (_, _) {});
      final ApprovalDecisionController deciding = container.read(
        approvalDecisionProvider(line).notifier,
      );

      Future<void> attempt(ApiFailure? failure, ApprovalDecision decision) {
        orders.decisionFailure = failure;
        return deciding.decide(approvalOne, decision);
      }

      await attempt(const NetworkFailure(), ApprovalDecision.reject);
      final UnansweredRequest<ApprovalDecision> kept = container.read(
        unansweredDecisionsProvider(orderOne),
      )[approvalOne]!;
      expect(kept.sent, ApprovalDecision.reject);
      expect(kept.key, orders.decisions.single.$3);

      // Whatever is asked for, the unanswered decision is what goes.
      await attempt(
        const ApiRefusal(ApiError(status: 503, code: 'server_error')),
        ApprovalDecision.approve,
      );
      await attempt(null, ApprovalDecision.approve);
      expect(
        orders.decisions.map(
          ((String, ApprovalDecision, String) d) => (d.$2, d.$3),
        ),
        everyElement((ApprovalDecision.reject, kept.key)),
      );
      expect(container.read(unansweredDecisionsProvider(orderOne)), isEmpty);

      await attempt(null, ApprovalDecision.approve);
      expect(orders.decisions.last.$2, ApprovalDecision.approve);
      expect(orders.decisions.last.$3, isNot(kept.key));
    },
  );

  group('the endless feed', () {
    late DateTime now;
    late FakeCustomerOrdersRepository orders;
    late ProviderContainer container;

    String idOf(int n) =>
        '0192f0a0-0000-7000-8000-${n.toRadixString(16).padLeft(12, '0')}';

    List<Map<String, Object?>> past(int count, {int from = 1}) =>
        <Map<String, Object?>>[
          for (int i = from; i < from + count; i++)
            orderSummaryJson(id: idOf(i), number: i, status: 'completed'),
        ];

    setUp(() {
      now = DateTime.utc(2026, 11, 5, 7);
      orders = FakeCustomerOrdersRepository()..summaries = past(45);
      container = ProviderContainer(
        retry: (int count, Object error) => null,
        overrides: [
          customerAccountProvider.overrideWith(
            (Ref ref) => ref.watch(_account),
          ),
          customerOrdersRepositoryProvider.overrideWithValue(orders),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      container.listen(customerOrdersProvider(OrdersTab.past), (_, _) {});
    });

    final AsyncNotifierProvider<CustomerOrdersFeed, OrdersFeed> pastFeed =
        customerOrdersProvider(OrdersTab.past);

    List<String> ids() => container
        .read(pastFeed)
        .requireValue
        .rows
        .map((OrderSummary row) => row.id)
        .toList();

    test('a reload asks again for every page it had and shows no order '
        'twice', () async {
      await container.read(pastFeed.future);
      await container.read(pastFeed.notifier).loadMore();
      expect(ids(), hasLength(40));

      orders
        ..loads.clear()
        ..summaries = <Map<String, Object?>>[
          orderSummaryJson(id: idOf(99), number: 99, status: 'completed'),
          ...past(45),
        ];
      container.invalidate(pastFeed);
      await container.read(pastFeed.future);

      expect(orders.loads, <String>['orders:past:1', 'orders:past:2']);
      expect(ids(), hasLength(40));
      expect(ids().first, idOf(99));
      expect(ids().toSet(), hasLength(40));
      expect(container.read(pastFeed).requireValue.pages, 2);
      expect(container.read(pastFeed).requireValue.total, 46);
    });

    test('a failed reload keeps the rows and their time', () async {
      await container.read(pastFeed.future);
      final DateTime first = container.read(pastFeed).requireValue.at;
      now = now.add(const Duration(minutes: 3));
      orders.listFailures[OrdersTab.past] = const NetworkFailure();

      container.invalidate(pastFeed);
      await expectLater(
        container.read(pastFeed.future),
        throwsA(isA<NetworkFailure>()),
      );

      final AsyncValue<OrdersFeed> value = container.read(pastFeed);
      expect(value.hasError, isTrue);
      expect(value.requireValue.rows, hasLength(20));
      expect(value.requireValue.at, first);
    });

    test('load more fails in place and loads on the next call', () async {
      await container.read(pastFeed.future);
      orders.listFailures[OrdersTab.past] = const NetworkFailure();

      await container.read(pastFeed.notifier).loadMore();
      OrdersFeed feed = container.read(pastFeed).requireValue;
      expect(feed.rows, hasLength(20));
      expect(feed.moreFailure, isA<NetworkFailure>());
      expect(feed.loadingMore, isFalse);
      expect(feed.nextPage, 2);

      await container.read(pastFeed.notifier).loadMore();
      feed = container.read(pastFeed).requireValue;
      expect(feed.rows, hasLength(40));
      expect(feed.moreFailure, isNull);
      expect(feed.nextPage, 3);
    });

    test('a page that lands after the account changed is dropped', () async {
      await container.read(pastFeed.future);
      final Completer<void> hold = Completer<void>();
      orders.holdList = hold;
      final Future<void> more = container.read(pastFeed.notifier).loadMore();
      expect(container.read(pastFeed).requireValue.loadingMore, isTrue);

      container.read(_account.notifier).signIn('c-2');
      await container.pump();
      orders.holdList = null;
      hold.complete();
      await more;
      await container.read(pastFeed.future);

      final OrdersFeed feed = container.read(pastFeed).requireValue;
      expect(feed.rows, hasLength(20));
      expect(feed.pages, 1);
      expect(feed.loadingMore, isFalse);
    });

    test('another account starts at page 1', () async {
      await container.read(pastFeed.future);
      await container.read(pastFeed.notifier).loadMore();
      orders.loads.clear();

      container.read(_account.notifier).signIn('c-2');
      await container.read(pastFeed.future);

      expect(orders.loads, <String>['orders:past:1']);
      expect(ids(), hasLength(20));
    });

    test(
      'drop takes the row off and names it dropped until the next load',
      () async {
        await container.read(pastFeed.future);
        final String id = idOf(3);

        container.read(pastFeed.notifier).drop(id.toUpperCase());
        OrdersFeed feed = container.read(pastFeed).requireValue;
        expect(feed.rows, hasLength(19));
        expect(ids(), isNot(contains(id)));
        expect(feed.total, 44);
        expect(feed.dropped, <String>{id});

        container.read(pastFeed.notifier).drop(idOf(500));
        expect(container.read(pastFeed).requireValue.total, 44);

        container.invalidate(pastFeed);
        await container.read(pastFeed.future);
        feed = container.read(pastFeed).requireValue;
        expect(feed.dropped, isEmpty);
        expect(feed.total, 45);
      },
    );

    test('drop does nothing during a reload', () async {
      await container.read(pastFeed.future);
      final Completer<void> hold = Completer<void>();
      orders.holdList = hold;
      container.invalidate(pastFeed);
      await container.pump();

      container.read(pastFeed.notifier).drop(idOf(3));
      orders.holdList = null;
      hold.complete();
      await container.read(pastFeed.future);

      expect(ids(), contains(idOf(3)));
    });
  });

  test('a sure cancellation drops the order from Текущие', () async {
    final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository();
    final ProviderContainer container = _container(orders);
    addTearDown(container.dispose);
    final AsyncNotifierProvider<CustomerOrdersFeed, OrdersFeed> current =
        customerOrdersProvider(OrdersTab.current);
    container.listen(current, (_, _) {});
    await container.read(current.future);
    expect(
      container.read(current).requireValue.rows.map((OrderSummary o) => o.id),
      contains(orderOne),
    );

    orders
      ..holdList = Completer<void>()
      ..answer = customerOrderJson(status: 'cancelled', changeable: false);
    await container.read(orderCancelProvider(orderOne).notifier).cancel(null);

    final OrdersFeed feed = container.read(current).requireValue;
    expect(feed.rows.map((OrderSummary o) => o.id), isNot(contains(orderOne)));
    expect(feed.dropped, <String>{orderOne});
  });

  Map<String, Object?> pending(String id, String expiresAt) =>
      <String, Object?>{
        'id': id,
        'order_id': orderOne,
        'order_number': 1001,
        'expires_at': expiresAt,
      };

  test('the earliest comes first', () async {
    final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository()
      ..pendingRows = <Map<String, Object?>>[
        pending(approvalOne, '2026-09-28T09:00:00Z'),
        pending('0192f0a0-0000-7000-8000-00000000c032', '2026-09-28T08:00:00Z'),
      ];
    final ProviderContainer container = _container(orders);
    addTearDown(container.dispose);
    container.listen(pendingQuestionsProvider, (_, _) {});

    final List<PendingQuestion> all = await container.read(
      pendingQuestionsProvider.future,
    );
    expect(all.map((PendingQuestion q) => q.approvalId), <String>[
      '0192f0a0-0000-7000-8000-00000000c032',
      approvalOne,
    ]);

    orders.pendingRows = <Map<String, Object?>>[];
    container.invalidate(pendingQuestionsProvider);
    expect(await container.read(pendingQuestionsProvider.future), isEmpty);
  });

  test('a decision reloads the questions', () async {
    final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository()
      ..pendingRows = <Map<String, Object?>>[
        pending(approvalOne, '2026-09-28T09:00:00Z'),
      ];
    final ProviderContainer container = _container(orders);
    addTearDown(container.dispose);
    container.listen(pendingQuestionsProvider, (_, _) {});
    final OrderLineRef line = (orderId: orderOne, lineId: lineTomato);
    container.listen(approvalDecisionProvider(line), (_, _) {});
    expect(await container.read(pendingQuestionsProvider.future), hasLength(1));

    orders.pendingRows = <Map<String, Object?>>[];
    await container
        .read(approvalDecisionProvider(line).notifier)
        .decide(approvalOne, ApprovalDecision.approve);

    expect(await container.read(pendingQuestionsProvider.future), isEmpty);
    expect(
      orders.loads.where((String load) => load == 'pending'),
      hasLength(2),
    );
  });

  group('open questions', () {
    late DateTime now;
    final DateTime start = DateTime.utc(2026, 9, 28, 7);

    ProviderContainer open(FakeCustomerOrdersRepository orders) {
      final ProviderContainer container = ProviderContainer(
        retry: (int count, Object error) => null,
        overrides: [
          customerAccountProvider.overrideWith((Ref ref) => 'customer-a'),
          customerOrdersRepositoryProvider.overrideWithValue(orders),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      container.listen(openQuestionsProvider, (_, _) {});
      return container;
    }

    setUp(() => now = start);

    testWidgets('open questions leave out the expired and drop one at its '
        'expiry', (WidgetTester tester) async {
      final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository()
        ..pendingRows = <Map<String, Object?>>[
          pending(approvalOne, '2026-09-28T07:10:00Z'),
          pending(
            '0192f0a0-0000-7000-8000-00000000c032',
            '2026-09-28T07:05:00Z',
          ),
          pending(
            '0192f0a0-0000-7000-8000-00000000c033',
            '2026-09-28T06:59:00Z',
          ),
        ];
      final ProviderContainer container = open(orders);
      await container.read(pendingQuestionsProvider.future);
      await tester.pump();

      expect(container.read(openQuestionsProvider), hasLength(2));
      expect(
        container.read(openQuestionsProvider).first.approvalId,
        '0192f0a0-0000-7000-8000-00000000c032',
      );

      now = start.add(const Duration(minutes: 5));
      await tester.pump(const Duration(minutes: 5));
      expect(container.read(openQuestionsProvider), hasLength(1));
      expect(
        container.read(openQuestionsProvider).single.approvalId,
        approvalOne,
      );
      container.dispose();
    });

    testWidgets('a failed refresh keeps the questions', (
      WidgetTester tester,
    ) async {
      final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository()
        ..pendingRows = <Map<String, Object?>>[
          pending(approvalOne, '2026-09-28T07:10:00Z'),
        ];
      final ProviderContainer container = open(orders);
      await container.read(pendingQuestionsProvider.future);
      await tester.pump();
      expect(container.read(openQuestionsProvider), hasLength(1));

      orders.pendingFailure = const NetworkFailure();
      container.invalidate(pendingQuestionsProvider);
      await expectLater(
        container.read(pendingQuestionsProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
      await tester.pump();

      expect(container.read(pendingQuestionsProvider).hasError, isTrue);
      expect(container.read(openQuestionsProvider), hasLength(1));
      container.dispose();
    });
  });

  test('a reorder keeps its key until a sure answer', () async {
    final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository();
    final ProviderContainer container = _container(orders);
    addTearDown(container.dispose);
    container.listen(reorderProvider(orderOne), (_, _) {});
    final ReorderController reordering = container.read(
      reorderProvider(orderOne).notifier,
    );

    Future<String> attempt(ApiFailure? failure) async {
      orders.reorderFailure = failure;
      await reordering.reorder();
      return orders.reorders.last.$2;
    }

    final String first = await attempt(const NetworkFailure());
    expect(await attempt(null), first, reason: 'the retry sends the same key');
    final String next = await attempt(
      const ApiRefusal(ApiError(status: 409, code: 'order_state_conflict')),
    );
    expect(next, isNot(first), reason: 'a sure answer ends the attempt');
    expect(await attempt(null), isNot(next), reason: 'a refusal is final');
  });

  test('a reorder reloads the cart', () async {
    final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository();
    final FakeCartRepository cart = FakeCartRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        customerAccountProvider.overrideWith((Ref ref) => 'customer-a'),
        customerOrdersRepositoryProvider.overrideWithValue(orders),
        cartRepositoryProvider.overrideWithValue(cart),
      ],
    );
    addTearDown(container.dispose);
    container.listen(cartProvider('customer-a'), (_, _) {});
    container.listen(reorderProvider(orderOne), (_, _) {});
    await container.read(cartProvider('customer-a').future);
    int loads() => cart.calls.where((String c) => c == 'cart').length;
    final int loaded = loads();

    await container.read(reorderProvider(orderOne).notifier).reorder();
    await container.read(cartProvider('customer-a').future);

    expect(loads(), loaded + 1);
  });

  test('an uncertain reorder loads the cart again and keeps its key', () async {
    final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository();
    final FakeCartRepository cart = FakeCartRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        customerAccountProvider.overrideWith((Ref ref) => 'customer-a'),
        customerOrdersRepositoryProvider.overrideWithValue(orders),
        cartRepositoryProvider.overrideWithValue(cart),
      ],
    );
    addTearDown(container.dispose);
    container.listen(cartProvider('customer-a'), (_, _) {});
    container.listen(reorderProvider(orderOne), (_, _) {});
    await container.read(cartProvider('customer-a').future);
    int loads() => cart.calls.where((String c) => c == 'cart').length;
    final int loaded = loads();

    orders.reorderFailure = const NetworkFailure();
    await container.read(reorderProvider(orderOne).notifier).reorder();
    await container.read(cartProvider('customer-a').future);

    expect(loads(), loaded + 1, reason: 'the cart is not left as it was');
    orders.reorderFailure = null;
    await container.read(reorderProvider(orderOne).notifier).reorder();
    expect(
      orders.reorders.map(((String, String) r) => r.$2).toSet(),
      hasLength(1),
      reason: 'the retry sends the same key',
    );
  });
}
