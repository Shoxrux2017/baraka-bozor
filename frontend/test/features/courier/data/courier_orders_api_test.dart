import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/auth_interceptor.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/courier/data/courier_orders_api.dart';
import 'package:baraka_bozor/features/courier/domain/courier_orders.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_courier_orders_repository.dart';
import '../../../support/fake_http_client_adapter.dart';

/// The Courier's deliveries against `docs/09-api-contracts.md` sections 36
/// and 37.
void main() {
  group('parsing', () {
    test('a delivery the Courier holds: who, where, when and what to take', () {
      final CourierOrder order = CourierOrdersApi.parseOrder(
        courierOrderJson(status: 'on_the_way', shopperPhone: '+998907654321'),
      );
      expect(order.id, courierOrderA);
      expect(order.orderNumber, 1001);
      expect(order.status, OrderStatus.onTheWay);
      expect(order.held, isTrue);
      expect(order.recipient!.fullName, 'Dilnoza Karimova');
      expect(order.recipient!.phone, '+998901234567');
      final DeliveryAddress address = order.address!;
      expect(
        <String?>[
          address.latitude,
          address.longitude,
          address.street,
          address.house,
          address.apartment,
          address.landmark,
        ],
        <String>[
          '41.311081',
          '69.240562',
          'Amir Temur',
          '12',
          '34',
          'Maktab qarshisida',
        ],
      );
      expect(order.deliveryNote, "Podyezdda qo'ng'iroq qiling");
      expect(order.deliveryTimeNote, 'Kechqurun');
      expect(order.paymentMethod, PaymentMethod.cash);
      expect(order.amountToCollectUzs, 55600);
      expect(order.cancellationRequestPending, isFalse);
      expect(order.assignment.id, courierAssignment);
      expect(
        order.assignment.deliveryStartedAt,
        DateTime.utc(2026, 9, 28, 9, 10),
      );
      expect(order.assignment.delayAt, DateTime.utc(2026, 9, 28, 10, 10));
      expect(order.canAccept, isFalse);
      expect(order.canStart, isFalse);
      expect(order.shopperPhone, '+998907654321');

      // With a handoff point the Shopper's phone is absent; the server may
      // know no Shopper to name.
      expect(
        CourierOrdersApi.parseOrder(courierOrderJson()).shopperPhone,
        isNull,
      );
      expect(
        CourierOrdersApi.parseOrder(courierOrderJson(shopperPhone: null))
            .shopperPhone,
        isNull,
      );
      final CourierOrder fresh = CourierOrdersApi.parseOrder(
        courierOrderJson(),
      );
      expect(fresh.canAccept, isTrue);
      expect(fresh.canStart, isFalse);
      expect(
        CourierOrdersApi.parseOrder(courierOrderJson(accepted: true)).canStart,
        isTrue,
      );
      final CourierOrder online = CourierOrdersApi.parseOrder(
        courierOrderJson(cash: false),
      );
      expect(online.amountToCollectUzs, isNull);
    });

    test('an ended delivery tells the outcome only', () {
      for (final String status in <String>[
        'completed',
        'ready_for_delivery',
        'cancelled',
      ]) {
        final CourierOrder order = CourierOrdersApi.parseOrder(
          courierOrderJson(status: status, ended: true),
        );
        expect(order.held, isFalse, reason: status);
        expect(order.address, isNull);
        expect(order.deliveryNote, isNull);
        expect(order.deliveryTimeNote, isNull);
        expect(order.shopperPhone, isNull);
      }
    });

    test('a delivery off the contract is refused', () {
      final Map<String, Object?> held = courierOrderJson();
      final Map<String, Object?> onTheWay = courierOrderJson(
        status: 'on_the_way',
      );
      final Map<String, Object?> ended = courierOrderJson(
        status: 'completed',
        ended: true,
      );
      Map<String, Object?> assignment(Map<String, Object?> changes) =>
          <String, Object?>{
            ...onTheWay,
            'assignment': <String, Object?>{
              ...onTheWay['assignment']! as Map<String, Object?>,
              ...changes,
            },
          };
      final Map<String, Map<String, Object?>> broken =
          <String, Map<String, Object?>>{
            'a recipient without an address': <String, Object?>{
              ...held,
              'address': null,
            },
            'an address without a recipient': <String, Object?>{
              ...held,
              'recipient': null,
            },
            'held in a state no Courier holds': courierOrderJson(
              status: 'ready_for_delivery',
            ),
            'ended but with its notes': <String, Object?>{
              ...ended,
              'delivery_note': 'Qo\'ng\'iroq',
            },
            'ended but with its wish': <String, Object?>{
              ...ended,
              'delivery_time_note': 'Kechqurun',
            },
            'ended but with the Shopper\'s phone': <String, Object?>{
              ...ended,
              'shopper_phone': '+998907654321',
            },
            'cash without the amount': <String, Object?>{
              ...held,
              'amount_to_collect_uzs': null,
            },
            'online with an amount': <String, Object?>{
              ...courierOrderJson(cash: false),
              'amount_to_collect_uzs': 55600,
            },
            'nothing to collect in cash': <String, Object?>{
              ...held,
              'amount_to_collect_uzs': 0,
            },
            'accept offered once accepted': <String, Object?>{
              ...courierOrderJson(accepted: true),
              'can_accept': true,
            },
            'accept withheld before acceptance': <String, Object?>{
              ...held,
              'can_accept': false,
            },
            'start offered while a request waits': <String, Object?>{
              ...courierOrderJson(accepted: true, pending: true),
              'can_start': true,
            },
            'start offered on the way': <String, Object?>{
              ...onTheWay,
              'can_start': true,
            },
            'start withheld when it may go': <String, Object?>{
              ...courierOrderJson(accepted: true),
              'can_start': false,
            },
            'set off before the acceptance': <String, Object?>{
              ...assignment(<String, Object?>{'accepted_at': null}),
              'can_accept': true,
            },
            'set off without a delay': assignment(<String, Object?>{
              'delay_at': null,
            }),
            'a delay without the start': <String, Object?>{
              ...courierOrderJson(accepted: true),
              'assignment': <String, Object?>{
                ...courierAssignmentJson(accepted: true),
                'delay_at': '2026-09-28T10:10:00Z',
              },
            },
            'a recipient phone out of its form': <String, Object?>{
              ...held,
              'recipient': <String, Object?>{
                'full_name': 'Dilnoza',
                'phone': '901234567',
              },
            },
            'a Shopper phone out of its form': courierOrderJson(
              shopperPhone: '907654321',
            ),
            'coordinates off the globe': <String, Object?>{
              ...held,
              'address': <String, Object?>{
                ...held['address']! as Map<String, Object?>,
                'latitude': '91.000000',
              },
            },
            'coordinates out of their form': <String, Object?>{
              ...held,
              'address': <String, Object?>{
                ...held['address']! as Map<String, Object?>,
                'longitude': '69.24',
              },
            },
            'no assignment': <String, Object?>{...held, 'assignment': null},
            'no order number': <String, Object?>{...held, 'order_number': 0},
          };
      broken.forEach((String what, Map<String, Object?> json) {
        expect(
          () => CourierOrdersApi.parseOrder(json),
          throwsFormatException,
          reason: what,
        );
      });
      // As the fixtures build them, the same deliveries parse.
      for (final Map<String, Object?> json in <Map<String, Object?>>[
        held,
        onTheWay,
        ended,
        courierOrderJson(accepted: true, pending: true),
        courierOrderJson(cash: false),
      ]) {
        expect(CourierOrdersApi.parseOrder(json), isNotNull);
      }
    });
  });

  group('requests', () {
    late FakeHttpClientAdapter adapter;
    late CourierOrdersRepositoryImpl repository;
    Map<String, Object?>? answer;
    List<Object?> rows = <Object?>[];
    int answeredPage = 1;

    setUp(() {
      answer = null;
      rows = <Object?>[courierOrderJson()];
      answeredPage = 1;
      adapter = FakeHttpClientAdapter((RequestOptions options) {
        if (options.path == '/courier/orders') {
          return jsonReply(200, <String, Object?>{
            'data': rows,
            'meta': <String, Object?>{
              'pagination': <String, int>{
                'page': answeredPage,
                'per_page': 20,
                'total': rows.length,
                'last_page': 1,
              },
            },
          });
        }
        return jsonReply(200, <String, Object?>{
          'data': answer ?? courierOrderJson(),
        });
      });
      repository = CourierOrdersRepositoryImpl(
        CourierOrdersApi(dioWith(adapter)),
      );
    });

    test(
      'each call on the staff session, with its verb, path, body and key',
      () async {
        await repository.orders(1);
        await repository.order(courierOrderA);
        answer = courierOrderJson(accepted: true);
        await repository.accept(courierOrderA);
        answer = courierOrderJson(status: 'on_the_way');
        await repository.start(courierOrderA);
        answer = courierOrderJson(status: 'completed', ended: true);
        await repository.delivered(courierOrderA, 55600, 'key-1');
        await repository.delivered(courierOrderA, null, 'key-2');
        answer = courierOrderJson(status: 'ready_for_delivery', ended: true);
        await repository.notDelivered(
          courierOrderA,
          DeliveryFailureReason.other,
          'Podyezd yopiq',
        );
        await repository.notDelivered(
          courierOrderA,
          DeliveryFailureReason.noAnswer,
          null,
        );

        final String path = '/courier/orders/$courierOrderA';
        expect(
          adapter.requests.map((RequestOptions o) => '${o.method} ${o.path}'),
          <String>[
            'GET /courier/orders',
            'GET $path',
            'POST $path/accept',
            'POST $path/start',
            'POST $path/delivered',
            'POST $path/delivered',
            'POST $path/not-delivered',
            'POST $path/not-delivered',
          ],
        );
        expect(adapter.requests[0].queryParameters, <String, Object>{
          'page': 1,
        });
        expect(adapter.requests[4].data, <String, Object?>{
          'cash_received_uzs': 55600,
        });
        expect(adapter.requests[4].headers['Idempotency-Key'], 'key-1');
        expect(adapter.requests[5].data, <String, Object?>{});
        expect(adapter.requests[5].headers['Idempotency-Key'], 'key-2');
        expect(adapter.requests[6].data, <String, Object?>{
          'reason_code': 'other',
          'note': 'Podyezd yopiq',
        });
        expect(adapter.requests[7].data, <String, Object?>{
          'reason_code': 'no_answer',
        });
        expect(
          adapter.requests[6].headers.containsKey('Idempotency-Key'),
          isFalse,
          reason: 'a natural repeat, unkeyed',
        );
        for (final RequestOptions request in adapter.requests) {
          expect(
            RequestSlot.resolve(request, () => SessionSlot.customer),
            SessionSlot.staff,
          );
        }
      },
    );

    test('an answer that does not show the action is malformed', () async {
      Future<void> refused(Future<Object?> Function() call) =>
          expectLater(call(), throwsA(isA<MalformedResponseFailure>()));

      // A read, an acceptance and a start answer a delivery still held.
      answer = courierOrderJson(status: 'completed', ended: true);
      await refused(() => repository.order(courierOrderA));
      await refused(() => repository.accept(courierOrderA));
      answer = courierOrderJson();
      await refused(() => repository.accept(courierOrderA));
      answer = courierOrderJson(accepted: true);
      await refused(() => repository.start(courierOrderA));
      // On the way but not set off, or set off but not on the way.
      answer = <String, Object?>{
        ...courierOrderJson(accepted: true),
        'status': 'on_the_way',
        'can_start': false,
      };
      await refused(() => repository.start(courierOrderA));
      answer = <String, Object?>{
        ...courierOrderJson(status: 'on_the_way'),
        'status': 'delivery_assigned',
      };
      await refused(() => repository.start(courierOrderA));
      // Delivered answers the order completed through the ended assignment.
      answer = courierOrderJson(status: 'on_the_way');
      await refused(() => repository.delivered(courierOrderA, 55600, 'k'));
      answer = courierOrderJson(status: 'ready_for_delivery', ended: true);
      await refused(() => repository.delivered(courierOrderA, 55600, 'k'));
      // Not delivered answers the order back with an Operator.
      answer = courierOrderJson(status: 'on_the_way');
      await refused(
        () => repository.notDelivered(
          courierOrderA,
          DeliveryFailureReason.refused,
          null,
        ),
      );
      answer = courierOrderJson(status: 'completed', ended: true);
      await refused(
        () => repository.notDelivered(
          courierOrderA,
          DeliveryFailureReason.refused,
          null,
        ),
      );
      // Another order than the one asked about.
      answer = courierOrderJson(id: courierOrderB);
      await refused(() => repository.order(courierOrderA));

      // A repeat after an Operator cancelled the failed order answers it.
      answer = courierOrderJson(status: 'cancelled', ended: true);
      expect(
        (await repository.notDelivered(
          courierOrderA,
          DeliveryFailureReason.refused,
          null,
        )).status,
        OrderStatus.cancelled,
      );
      // Ids are compared as the server writes them.
      answer = courierOrderJson();
      expect(
        (await repository.order(courierOrderA.toUpperCase())).id,
        courierOrderA,
      );
    });

    test(
      'a list holds the Courier\'s current deliveries of the page asked',
      () async {
        rows = <Object?>[courierOrderJson(status: 'completed', ended: true)];
        await expectLater(
          repository.orders(1),
          throwsA(isA<MalformedResponseFailure>()),
        );
        rows = <Object?>[courierOrderJson()];
        answeredPage = 2;
        await expectLater(
          repository.orders(1),
          throwsA(isA<MalformedResponseFailure>()),
        );
      },
    );
  });
}
