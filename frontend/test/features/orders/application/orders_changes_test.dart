import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/features/orders/application/orders_changes.dart';
import 'package:baraka_bozor/features/orders/data/customer_orders_api.dart';
import 'package:baraka_bozor/features/orders/domain/customer_orders.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_customer_orders_repository.dart';

/// An order's id: a UUID ending in the hex digit [name].
String _id(String name) => '0192f0a0-0000-7000-8000-00000000000$name';

OrderSummary _order(String name, {String status = 'new', int waiting = 0}) =>
    CustomerOrdersApi.parseSummary(
      orderSummaryJson(id: _id(name), status: status, waiting: waiting),
    );

List<String> _names(List<OrderSummary> orders) => <String>[
  for (final OrderSummary order in orders) order.id.substring(35),
];

void main() {
  test('a question on an order with none arrives, more grow, a status change moves, a new order appears, a gone one leaves unless dropped', () {
    final List<OrderSummary> before = <OrderSummary>[
      _order('a'),
      _order('b', waiting: 1),
      _order('c', status: 'shopping'),
      _order('d'),
      _order('e'),
      _order('f', waiting: 2),
    ];
    final List<OrderSummary> after = <OrderSummary>[
      _order('9'),
      _order('a', waiting: 1),
      _order('b', waiting: 3),
      _order('c', status: 'on_the_way'),
      _order('f', waiting: 1),
    ];

    final CurrentChanges changes = currentChanges(
      before,
      after,
      dropped: <String>{_id('e')},
    );

    expect(_names(changes.questionsArrived), <String>['a']);
    expect(_names(changes.questionsGrew), <String>['b']);
    expect(changes.moved, hasLength(1));
    expect(changes.moved.single.order.id, _id('c'));
    expect(changes.moved.single.from, OrderStatus.shopping);
    expect(changes.moved.single.order.status, OrderStatus.onTheWay);
    expect(_names(changes.appeared), <String>['9']);
    expect(_names(changes.left), <String>[
      'd',
    ], reason: 'e was dropped by the Customer, f only has fewer questions');
    expect(
      identical(changes.left.single, before[3]),
      isTrue,
      reason: 'the last summary the list had',
    );
  });
}
