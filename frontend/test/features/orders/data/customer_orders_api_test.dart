import 'package:baraka_bozor/core/localization/app_language.dart';
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

/// A question as the decision answers it (`docs/09` section 23).
Map<String, Object?> approvalJson({
  String id = approvalOne,
  String orderId = orderOne,
  String status = 'approved',
}) => <String, Object?>{
  'id': id,
  'order_id': orderId,
  'order_number': 1001,
  'type': 'price_over_tolerance',
  'status': status,
  'item': <String, Object?>{
    'id': lineTomato,
    'name_uz': 'Pomidor',
    'name_ru': 'Помидоры',
    'unit_code': 'kg',
    'price_mode': 'estimate',
    'quantity': '1.500',
    'customer_unit_price_uzs': 18400,
  },
  'proposed_customer_unit_price_uzs': 21850,
  'proposed_quantity': null,
  'replacement': null,
  'request_note': null,
  'expires_at': '2026-09-28T08:00:00Z',
  'resolved_at': status == 'pending' ? null : '2026-09-28T07:45:00Z',
  'created_at': '2026-09-28T07:30:00Z',
};

/// [line] with [changes] made to its question.
Map<String, Object?> questionWith(
  Map<String, Object?> line,
  Map<String, Object?> changes,
) => <String, Object?>{
  ...line,
  'pending_approval': <String, Object?>{
    ...line['pending_approval']! as Map<String, Object?>,
    ...changes,
  },
};

/// An order holding [line] alone.
Map<String, Object?> orderWith(Map<String, Object?> line) =>
    customerOrderJson(status: 'shopping', lines: <Object?>[line]);

/// The Customer's orders against `docs/09-api-contracts.md` sections 20 to
/// 23.
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

    test('a shopped order: what was bought, replaced, asked and paid', () {
      final CustomerOrder order = CustomerOrdersApi.parseOrder(
        customerOrderJson(
          status: 'shopping',
          changeable: false,
          canRequestCancellation: true,
          cancellationRequest: 'rejected',
          lines: <Object?>[
            orderLineJson(
              status: 'purchased',
              patch: <String, Object?>{
                'replacement': <String, Object?>{
                  'name_uz': 'Olcha pomidor',
                  'name_ru': 'Помидоры черри',
                },
              },
            ),
            questionLineJson('substitution'),
            orderLineJson(id: lineMilk, status: 'awaiting_customer'),
          ],
          payment: <String, Object?>{
            'method': 'cash',
            'status': 'paid',
            'amount_uzs': 55600,
            'paid_at': '2026-09-28T09:00:00Z',
          },
        ),
      );
      final CustomerOrderLine bought = order.lines[0];
      expect(bought.billableQuantity, '1.500');
      expect(bought.billableUnitPriceUzs, 18975);
      expect(bought.lineTotalUzs, 28463);
      expect(bought.replacement!.name(AppLanguage.ru), 'Помидоры черри');
      expect(bought.question, isNull);
      expect(bought.questionExpired, isFalse);

      final CustomerQuestion question = order.lines[1].question!;
      expect(question.id, approvalOne);
      expect(question.type, ApprovalType.substitution);
      expect(question.proposedCustomerUnitPriceUzs, 21850);
      expect(question.replacement!.name(AppLanguage.uz), 'Olcha pomidor');
      expect(question.requestNote, 'Qizili qolmadi');
      expect(question.expiresAt, DateTime.utc(2026, 9, 28, 8));
      expect(order.lines[1].billableQuantity, isNull);
      expect(order.lines[1].questionExpired, isFalse);

      // Waiting, with its question past its expiry.
      expect(order.lines[2].questionExpired, isTrue);
      expect(order.pendingApprovalCount, 1);
      expect(order.canRequestCancellation, isTrue);

      final CustomerCancellationRequest request = order.cancellationRequest!;
      expect(request.status, CancellationRequestStatus.rejected);
      expect(request.reason, 'Kerak emas');
      expect(request.resolvedAt, DateTime.utc(2026, 9, 28, 8, 30));

      final CustomerPayment payment = order.payment!;
      expect(payment.method, PaymentMethod.cash);
      expect(payment.status, PaymentStatus.paid);
      expect(payment.amountUzs, 55600);
      expect(payment.paidAt, DateTime.utc(2026, 9, 28, 9));

      final CustomerQuestion quantity = CustomerOrdersApi.parseOrder(
        orderWith(questionLineJson('reduced_quantity')),
      ).lines.single.question!;
      expect(quantity.proposedQuantity, '1.000');
      expect(quantity.proposedCustomerUnitPriceUzs, isNull);
      expect(
        CustomerOrdersApi.parseSummary(orderSummaryJson(waiting: 2))
            .pendingApprovalCount,
        2,
      );
    });

    test('a line, a question, a request or a payment off the contract', () {
      final Map<String, Object?> price = questionLineJson(
        'price_over_tolerance',
      );
      final Map<String, Object?> substitution = questionLineJson(
        'substitution',
      );
      final Map<String, Object?> quantity = questionLineJson(
        'reduced_quantity',
      );
      final Map<String, Object?> bought = orderLineJson(status: 'purchased');
      final Map<String, Object?> cash = <String, Object?>{
        'method': 'cash',
        'status': 'paid',
        'amount_uzs': 55600,
        'paid_at': '2026-09-28T09:00:00Z',
      };
      Map<String, Object?> request(String status) =>
          customerOrderJson(
                cancellationRequest: status,
              )['cancellation_request']!
              as Map<String, Object?>;
      final Map<String, Map<String, Object?>>
      broken = <String, Map<String, Object?>>{
        'an open line billed': orderWith(
          orderLineJson(patch: <String, Object?>{'billable_quantity': '1'}),
        ),
        'a bought line not billed': orderWith(<String, Object?>{
          ...bought,
          'billable_quantity': null,
        }),
        'a bought line billed nothing': orderWith(<String, Object?>{
          ...bought,
          'billable_quantity': '0.000',
        }),
        'a billed quantity out of its form': orderWith(<String, Object?>{
          ...bought,
          'billable_quantity': '1.5',
        }),
        'a bought line without its price': orderWith(<String, Object?>{
          ...bought,
          'billable_unit_price_uzs': null,
        }),
        'an open line priced as bought': orderWith(
          orderLineJson(
            patch: <String, Object?>{'billable_unit_price_uzs': 18975},
          ),
        ),
        'a removed line replaced': orderWith(
          orderLineJson(
            status: 'removed',
            removedReason: 'customer_rejected',
            patch: <String, Object?>{
              'replacement': <String, Object?>{
                'name_uz': 'Olcha pomidor',
                'name_ru': 'Помидоры черри',
              },
            },
          ),
        ),
        'a question on a line not waiting': orderWith(<String, Object?>{
          ...price,
          'status': 'pending',
        }),
        'a question left uncounted': <String, Object?>{
          ...orderWith(price),
          'pending_approval_count': 0,
        },
        'a question counted but not shown': <String, Object?>{
          ...orderWith(orderLineJson()),
          'pending_approval_count': 1,
        },
        'a price question without its price': orderWith(
          questionWith(price, <String, Object?>{
            'proposed_customer_unit_price_uzs': null,
          }),
        ),
        'a price question with a quantity': orderWith(
          questionWith(price, <String, Object?>{'proposed_quantity': '1.000'}),
        ),
        'a substitution without its replacement': orderWith(
          questionWith(substitution, <String, Object?>{'replacement': null}),
        ),
        'a substitution with a quantity': orderWith(
          questionWith(substitution, <String, Object?>{
            'proposed_quantity': '1.000',
          }),
        ),
        'a replacement at another price': orderWith(
          questionWith(substitution, <String, Object?>{
            'replacement': <String, Object?>{
              'name_uz': 'Olcha pomidor',
              'name_ru': 'Помидоры черри',
              'customer_unit_price_uzs': 21000,
            },
          }),
        ),
        'a quantity question without its quantity': orderWith(
          questionWith(quantity, <String, Object?>{'proposed_quantity': null}),
        ),
        'a quantity question with a price': orderWith(
          questionWith(quantity, <String, Object?>{
            'proposed_customer_unit_price_uzs': 18400,
          }),
        ),
        'a quantity question with a replacement': orderWith(
          questionWith(quantity, <String, Object?>{
            'replacement': <String, Object?>{
              'name_uz': 'Olcha pomidor',
              'name_ru': 'Помидоры черри',
              'customer_unit_price_uzs': 21850,
            },
          }),
        ),
        'a proposed quantity of nothing': orderWith(
          questionWith(quantity, <String, Object?>{
            'proposed_quantity': '0.000',
          }),
        ),
        'a proposed quantity out of its form': orderWith(
          questionWith(quantity, <String, Object?>{'proposed_quantity': '1.5'}),
        ),
        'a pending request resolved': <String, Object?>{
          ...customerOrderJson(cancellationRequest: 'pending'),
          'cancellation_request': <String, Object?>{
            ...request('pending'),
            'resolved_at': '2026-09-28T08:30:00Z',
          },
        },
        'a decided request not resolved': <String, Object?>{
          ...customerOrderJson(cancellationRequest: 'approved'),
          'cancellation_request': <String, Object?>{
            ...request('approved'),
            'resolved_at': null,
          },
        },
        'a request without its reason': <String, Object?>{
          ...customerOrderJson(cancellationRequest: 'pending'),
          'cancellation_request': <String, Object?>{...request('pending')}
            ..remove('reason'),
        },
        'a paid payment without its instant': customerOrderJson(
          payment: <String, Object?>{...cash, 'paid_at': null},
        ),
        'an unpaid payment with an instant': customerOrderJson(
          payment: <String, Object?>{
            ...cash,
            'method': 'online',
            'status': 'pending',
          },
        ),
        'cash not paid': customerOrderJson(
          payment: <String, Object?>{
            ...cash,
            'status': 'pending',
            'paid_at': null,
          },
        ),
      };
      broken.forEach((String what, Map<String, Object?> json) {
        expect(
          () => CustomerOrdersApi.parseOrder(json),
          throwsFormatException,
          reason: what,
        );
      });

      // Each is refused for its own fault: as the fixtures build them, the
      // same orders parse.
      for (final Map<String, Object?> line in <Map<String, Object?>>[
        price,
        substitution,
        quantity,
        bought,
      ]) {
        expect(CustomerOrdersApi.parseOrder(orderWith(line)), isNotNull);
      }
      for (final String status in <String>['pending', 'approved']) {
        expect(
          CustomerOrdersApi.parseOrder(
            customerOrderJson(cancellationRequest: status),
          ).cancellationRequest,
          isNotNull,
        );
      }
      expect(
        CustomerOrdersApi.parseOrder(customerOrderJson(payment: cash))
            .payment!
            .status,
        PaymentStatus.paid,
      );
      expect(
        CustomerOrdersApi.parseOrder(
          customerOrderJson(
            payment: <String, Object?>{
              ...cash,
              'method': 'online',
              'status': 'pending',
              'paid_at': null,
            },
          ),
        ).payment!.status,
        PaymentStatus.pending,
      );
      expect(
        () => CustomerOrdersApi.parseSummary(
          <String, Object?>{...orderSummaryJson()}
            ..remove('pending_approval_count'),
        ),
        throwsFormatException,
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
        <String, Object?>{
          ...customerOrderJson(cancellationRequest: 'pending'),
          'cancellation_request': <String, Object?>{'status': 'maybe'},
        },
        <String, Object?>{...customerOrderJson()}
          ..remove('cancellation_request'),
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

    test(
      'a cancel from shopping on answers the order carrying its request',
      () async {
        answer = customerOrderJson(
          status: 'shopping',
          changeable: false,
          cancellationRequest: 'pending',
        );
        final CustomerOrder asked = await repository.cancel(
          orderOne,
          'Kerak emas',
          'key',
        );
        expect(asked.status, OrderStatus.shopping);
        expect(
          asked.cancellationRequest!.status,
          CancellationRequestStatus.pending,
        );

        // A replay answers the order as it is now: its request may have
        // been decided since.
        answer = customerOrderJson(
          status: 'shopping',
          changeable: false,
          cancellationRequest: 'rejected',
        );
        final CustomerOrder replayed = await repository.cancel(
          orderOne,
          'Kerak emas',
          'key',
        );
        expect(
          replayed.cancellationRequest!.status,
          CancellationRequestStatus.rejected,
        );

        // Neither cancelled nor asked is not what a cancel answers.
        answer = customerOrderJson(status: 'shopping', changeable: false);
        await expectLater(
          repository.cancel(orderOne, 'Kerak emas', 'key'),
          throwsA(isA<MalformedResponseFailure>()),
        );
      },
    );

    test(
      'a decision: its path, body and key on the Customer session',
      () async {
        answer = approvalJson();
        final CustomerApproval approved = await repository.decide(
          orderOne,
          approvalOne,
          ApprovalDecision.approve,
          'key-1',
        );
        expect(approved.status, ApprovalStatus.approved);
        expect(approved.type, ApprovalType.priceOverTolerance);
        answer = approvalJson(status: 'rejected');
        await repository.decide(
          orderOne,
          approvalOne,
          ApprovalDecision.reject,
          'key-2',
        );

        expect(
          adapter.requests.map((RequestOptions o) => '${o.method} ${o.path}'),
          <String>[
            'POST /customer/approvals/$approvalOne/decision',
            'POST /customer/approvals/$approvalOne/decision',
          ],
        );
        expect(adapter.requests[0].data, <String, Object?>{
          'decision': 'approve',
        });
        expect(adapter.requests[0].headers['Idempotency-Key'], 'key-1');
        expect(adapter.requests[1].data, <String, Object?>{
          'decision': 'reject',
        });
        expect(adapter.requests[1].headers['Idempotency-Key'], 'key-2');
        for (final RequestOptions request in adapter.requests) {
          expect(
            RequestSlot.resolve(request, () => SessionSlot.staff),
            SessionSlot.customer,
          );
        }
      },
    );

    test('a decision answer that does not show the decision', () async {
      for (final Map<String, Object?> wrong in <Map<String, Object?>>[
        approvalJson(status: 'rejected'),
        approvalJson(status: 'pending'),
        approvalJson(status: 'expired'),
        approvalJson(id: '0192f0a0-0000-7000-8000-00000000c032'),
        approvalJson(orderId: '0192f0a0-0000-7000-8000-00000000c002'),
        <String, Object?>{...approvalJson(), 'type': 'cheaper'},
      ]) {
        answer = wrong;
        await expectLater(
          repository.decide(
            orderOne,
            approvalOne,
            ApprovalDecision.approve,
            'key',
          ),
          throwsA(isA<MalformedResponseFailure>()),
          reason: '$wrong',
        );
      }
      // Ids are compared as the server writes them.
      answer = approvalJson();
      expect(
        (await repository.decide(
          orderOne.toUpperCase(),
          approvalOne.toUpperCase(),
          ApprovalDecision.approve,
          'key',
        )).id,
        approvalOne,
      );
    });

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
