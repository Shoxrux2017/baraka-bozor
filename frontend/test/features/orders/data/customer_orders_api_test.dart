import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/auth_interceptor.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/orders/data/customer_orders_api.dart';
import 'package:baraka_bozor/features/orders/domain/customer_orders.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_customer_orders_repository.dart';
import '../../../support/fake_http_client_adapter.dart';

/// The Customer's orders against `docs/09-api-contracts.md` sections 20 to
/// 22.
void main() {
  group('parsing', () {
    test('an order with its lines, totals, address and permissions', () {
      final CustomerOrder order = CustomerOrdersApi.parseOrder(
        customerOrderJson(
          lines: <Object?>[
            orderLineJson(),
            orderLineJson(
              id: lineMilk,
              productId: productMilk,
              unit: 'piece',
              quantity: '1',
              status: 'removed',
              removedReason: 'customer_removed',
            ),
          ],
        ),
      );
      expect(order.orderNumber, 1001);
      expect(order.canEdit, isTrue);
      expect(order.lines, hasLength(2));
      expect(order.openLines.single.id, lineTomato);
      expect(order.totalUzs, 55600);
      expect(order.deliveryTimeNote, 'Kechqurun');
      expect(order.address.apartment, '34');

      final CustomerOrder cancelled = CustomerOrdersApi.parseOrder(
        customerOrderJson(status: 'cancelled', changeable: false),
      );
      expect(cancelled.totalKind, TotalKind.none);
      expect(cancelled.totalUzs, isNull);
      expect(
        cancelled.cancellationReason,
        CancellationReason.customerCancelled,
      );
    });

    test('an order off the contract is refused', () {
      for (final Map<String, Object?> broken in <Map<String, Object?>>[
        customerOrderJson(lines: <Object?>[orderLineJson(status: 'removed')]),
        customerOrderJson(
          lines: <Object?>[orderLineJson(removedReason: 'unavailable')],
        ),
        <String, Object?>{
          ...customerOrderJson(),
          'cancellation_reason_code': 'customer_cancelled',
        },
        <String, Object?>{
          ...customerOrderJson(status: 'cancelled'),
          'cancellation_reason_code': null,
        },
        <String, Object?>{...customerOrderJson(), 'can_edit': 'yes'},
        customerOrderJson(lines: <Object?>[orderLineJson(quantity: '1.5')]),
      ]) {
        expect(
          () => CustomerOrdersApi.parseOrder(broken),
          throwsFormatException,
          reason: '$broken',
        );
      }
      expect(
        () => CustomerOrdersApi.parseSummary(<String, Object?>{
          ...orderSummaryJson(),
          'total_uzs': null,
        }),
        throwsFormatException,
      );
    });
  });

  group('requests', () {
    late FakeHttpClientAdapter adapter;
    late CustomerOrdersRepositoryImpl repository;
    Map<String, Object?>? answer;

    setUp(() {
      answer = null;
      adapter = FakeHttpClientAdapter((RequestOptions options) {
        if (options.path == '/customer/orders') {
          return jsonReply(200, <String, Object?>{
            'data': <Object?>[orderSummaryJson()],
            'meta': <String, Object?>{
              'pagination': <String, int>{
                'page': options.queryParameters['page']! as int,
                'per_page': 20,
                'total': 1,
                'last_page': 1,
              },
            },
          });
        }
        return jsonReply(200, <String, Object?>{
          'data': answer ?? customerOrderJson(),
        });
      });
      repository = CustomerOrdersRepositoryImpl(
        CustomerOrdersApi(dioWith(adapter)),
      );
    });

    test(
      'each call on the Customer session, with its verb, path and body',
      () async {
        await repository.orders(2);
        await repository.order(orderOne);
        answer = customerOrderJson(
          note: null,
          lines: <Object?>[orderLineJson(quantity: '2.000')],
        );
        await repository.edit(orderOne, const <OrderEditLine>[
          OrderEditLine(
            productId: productTomato,
            quantity: '2',
            customerNote: null,
            substitutionPolicy: SubstitutionPolicy.contactBefore,
          ),
        ], null);
        answer = customerOrderJson(status: 'cancelled', changeable: false);
        await repository.cancel(orderOne, 'Kerak emas', 'key-1');
        await repository.cancel(orderOne, null, 'key-2');

        expect(
          adapter.requests.map((RequestOptions o) => '${o.method} ${o.path}'),
          <String>[
            'GET /customer/orders',
            'GET /customer/orders/$orderOne',
            'PUT /customer/orders/$orderOne/items',
            'POST /customer/orders/$orderOne/cancel',
            'POST /customer/orders/$orderOne/cancel',
          ],
        );
        expect(adapter.requests[0].queryParameters, <String, Object>{
          'page': 2,
        });
        expect(adapter.requests[2].data, <String, Object?>{
          'items': <Map<String, Object?>>[
            <String, Object?>{
              'product_id': productTomato,
              'quantity': '2',
              'customer_note': null,
              'substitution_policy': 'contact_before_substitution',
            },
          ],
          'delivery_time_note': null,
        });
        expect(adapter.requests[3].data, <String, Object?>{
          'reason': 'Kerak emas',
        });
        expect(adapter.requests[3].headers['Idempotency-Key'], 'key-1');
        expect(adapter.requests[4].data, <String, Object?>{});
        for (final RequestOptions request in adapter.requests) {
          expect(
            RequestSlot.resolve(request, () => SessionSlot.staff),
            SessionSlot.customer,
          );
        }
      },
    );

    test('an answer that does not show the change is malformed', () async {
      answer = customerOrderJson();
      await expectLater(
        repository.edit(orderOne, const <OrderEditLine>[
          OrderEditLine(
            productId: productTomato,
            quantity: '2',
            customerNote: null,
            substitutionPolicy: SubstitutionPolicy.allowSimilar,
          ),
        ], null),
        throwsA(isA<MalformedResponseFailure>()),
      );

      answer = customerOrderJson();
      await expectLater(
        repository.cancel(orderOne, null, 'key'),
        throwsA(isA<MalformedResponseFailure>()),
      );

      answer = customerOrderJson(id: '0192f0a0-0000-7000-8000-00000000c002');
      await expectLater(
        repository.order(orderOne),
        throwsA(isA<MalformedResponseFailure>()),
      );
    });
  });
}
