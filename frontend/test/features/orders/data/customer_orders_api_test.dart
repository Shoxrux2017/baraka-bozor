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

    test('a question carries what each answer does to the bill', () {
      final CustomerQuestion price = CustomerOrdersApi.parseOrder(
        orderWith(questionLineJson('price_over_tolerance')),
      ).lines.single.question!;
      expect(price.estimateIfApprovedUzs, 25300);
      expect(price.changeIfApprovedUzs, 5300);
      expect(price.changeIfRejectedUzs, -20000);

      final CustomerQuestion substitution = CustomerOrdersApi.parseOrder(
        orderWith(questionLineJson('substitution')),
      ).lines.single.question!;
      expect(
        substitution.replacement!.imageUrl,
        'https://cdn.example/cherry.webp',
      );
      expect(substitution.replacement!.name(AppLanguage.ru), 'Помидоры черри');

      final Map<String, Object?> noPicture = questionWith(
        questionLineJson('substitution'),
        <String, Object?>{
          'replacement': <String, Object?>{
            'name_uz': 'Olcha pomidor',
            'name_ru': 'Помидоры черри',
            'customer_unit_price_uzs': 21850,
            'image_url': null,
          },
        },
      );
      expect(
        CustomerOrdersApi.parseOrder(orderWith(noPicture))
            .lines
            .single
            .question!
            .replacement!
            .imageUrl,
        isNull,
      );
    });

    test('a line says what the Customer agreed, or null', () {
      expect(
        CustomerOrdersApi.parseOrder(orderWith(orderLineJson()))
            .lines
            .single
            .agreed,
        isNull,
      );
      final AgreedTerms agreed = CustomerOrdersApi.parseOrder(
        orderWith(
          orderLineJson(
            patch: <String, Object?>{
              'agreed': <String, Object?>{
                'customer_unit_price_uzs': 21850,
                'quantity': '1.000',
              },
            },
          ),
        ),
      ).lines.single.agreed!;
      expect(agreed.customerUnitPriceUzs, 21850);
      expect(agreed.quantity, '1.000');
      final AgreedTerms priceOnly = CustomerOrdersApi.parseOrder(
        orderWith(
          orderLineJson(
            patch: <String, Object?>{
              'agreed': <String, Object?>{
                'customer_unit_price_uzs': 21850,
                'quantity': null,
              },
            },
          ),
        ),
      ).lines.single.agreed!;
      expect(priceOnly.quantity, isNull);
    });

    test('the keys the question and the line now carry are required', () {
      final Map<String, Object?> substitution = questionLineJson(
        'substitution',
      );
      Map<String, Object?> without(String key) {
        final Map<String, Object?> question = <String, Object?>{
          ...substitution['pending_approval']! as Map<String, Object?>,
        }..remove(key);
        return <String, Object?>{...substitution, 'pending_approval': question};
      }

      final Map<String, Map<String, Object?>> broken =
          <String, Map<String, Object?>>{
            for (final String key in <String>[
              'estimate_if_approved_uzs',
              'change_if_approved_uzs',
              'change_if_rejected_uzs',
            ])
              'a question without $key': without(key),
            'a replacement without image_url': questionWith(
              substitution,
              <String, Object?>{
                'replacement': <String, Object?>{
                  'name_uz': 'Olcha pomidor',
                  'name_ru': 'Помидоры черри',
                  'customer_unit_price_uzs': 21850,
                },
              },
            ),
            'a line without agreed': <String, Object?>{...orderLineJson()}
              ..remove('agreed'),
            'an agreement without its quantity': orderLineJson(
              patch: <String, Object?>{
                'agreed': <String, Object?>{'customer_unit_price_uzs': 1},
              },
            ),
            'an agreement of a text price': orderLineJson(
              patch: <String, Object?>{
                'agreed': <String, Object?>{
                  'customer_unit_price_uzs': '1',
                  'quantity': null,
                },
              },
            ),
          };
      broken.forEach((String what, Map<String, Object?> line) {
        expect(
          () => CustomerOrdersApi.parseOrder(orderWith(line)),
          throwsFormatException,
          reason: what,
        );
      });
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

    test('cancellation_note is read, null or words, and is required', () {
      expect(
        CustomerOrdersApi.parseOrder(customerOrderJson()).cancellationNote,
        isNull,
      );
      expect(
        CustomerOrdersApi.parseOrder(
          customerOrderJson(
            status: 'cancelled',
            changeable: false,
            cancellationNote: 'Передумал',
          ),
        ).cancellationNote,
        'Передумал',
      );
      expect(
        () => CustomerOrdersApi.parseOrder(
          <String, Object?>{...customerOrderJson()}
            ..remove('cancellation_note'),
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

    test('a summary reads its question deadlines and preview', () {
      final OrderSummary summary = CustomerOrdersApi.parseSummary(
        orderSummaryJson(
          waiting: 2,
          deadlines: <String>['2026-09-28T07:10:00Z', '2026-09-28T07:20:00Z'],
          itemCount: 10,
        ),
      );
      expect(summary.questionDeadlines, <DateTime>[
        DateTime.utc(2026, 9, 28, 7, 10),
        DateTime.utc(2026, 9, 28, 7, 20),
      ]);
      expect(summary.preview.lineCount, 10);
      expect(summary.preview.lines, hasLength(4));
      expect(summary.preview.lines.first.nameUz, 'Pomidor');
      expect(summary.preview.lines.first.nameRu, 'Помидоры');
      expect(summary.preview.lines.first.imageUrl, isNull);
      final OrderSummary pictured = CustomerOrdersApi.parseSummary(
        orderSummaryJson(
          previewCount: 1,
          previewLines: <Map<String, Object?>>[
            <String, Object?>{
              'name_uz': 'Sut',
              'name_ru': 'Молоко',
              'image_url': 'https://cdn.example/milk.webp',
            },
          ],
        ),
      );
      expect(pictured.preview.lines.single.imageUrl, contains('milk'));
    });

    test('a summary off the deadlines or preview contract is refused', () {
      Map<String, Object?> preview(int count, int shown) => <String, Object?>{
        'line_count': count,
        'lines': <Object?>[
          for (int i = 0; i < shown; i++)
            <String, Object?>{
              'name_uz': 'Non',
              'name_ru': 'Лепёшка',
              'image_url': null,
            },
        ],
      };
      final Map<String, Object?> noRussian = preview(1, 1);
      (((noRussian['lines']! as List<Object?>).single)! as Map<String, Object?>)
          .remove('name_ru');
      for (final Map<String, Object?> broken in <Map<String, Object?>>[
        <String, Object?>{
          ...orderSummaryJson(waiting: 2),
          'pending_approval_expires_at': <Object?>['2026-09-28T07:10:00Z'],
        },
        <String, Object?>{
          ...orderSummaryJson(waiting: 2),
          'pending_approval_expires_at': <Object?>[
            '2026-09-28T07:20:00Z',
            '2026-09-28T07:10:00Z',
          ],
        },
        <String, Object?>{
          ...orderSummaryJson(itemCount: 6),
          'preview': preview(6, 5),
        },
        <String, Object?>{
          ...orderSummaryJson(itemCount: 6),
          'preview': preview(6, 3),
        },
        <String, Object?>{...orderSummaryJson()}..remove('preview'),
        <String, Object?>{...orderSummaryJson()}
          ..remove('pending_approval_expires_at'),
        <String, Object?>{...orderSummaryJson(), 'preview': noRussian},
      ]) {
        expect(
          () => CustomerOrdersApi.parseSummary(broken),
          throwsFormatException,
          reason: '$broken',
        );
      }
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
        await repository.orders(OrdersTab.current, 2);
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
          'state': 'current',
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

    test('an edit preview sends the lines and reads its sums', () async {
      answer = editPreviewJson(
        merchandise: 40000,
        total: 60000,
        before: 55600,
        change: 4400,
        minimum: 50000,
      );
      final OrderEditPreview preview = await repository.previewEdit(
        orderOne,
        const <OrderEditLine>[
          OrderEditLine(
            productId: productTomato,
            quantity: '2',
            customerNote: null,
            substitutionPolicy: SubstitutionPolicy.contactBefore,
          ),
        ],
      );

      final RequestOptions request = adapter.requests.single;
      expect(
        '${request.method} ${request.path}',
        'POST /customer/orders/$orderOne/items/preview',
      );
      expect(request.data, <String, Object?>{
        'items': <Map<String, Object?>>[
          <String, Object?>{
            'product_id': productTomato,
            'quantity': '2',
            'customer_note': null,
            'substitution_policy': 'contact_before_substitution',
          },
        ],
      });
      expect(
        RequestSlot.resolve(request, () => SessionSlot.staff),
        SessionSlot.customer,
      );
      expect(preview.merchandiseSubtotalUzs, 40000);
      expect(preview.serviceFeeUzs, 5000);
      expect(preview.deliveryFeeUzs, 15000);
      expect(preview.totalUzs, 60000);
      expect(preview.totalKind, TotalKind.estimate);
      expect(preview.totalBeforeUzs, 55600);
      expect(preview.totalChangeUzs, 4400);
      expect(preview.minimumOrderUzs, 50000);
      expect(preview.minimumShortfallUzs, 0);
    });

    test('an edit preview off the contract is a format failure', () async {
      final Map<String, Map<String, Object?>> broken =
          <String, Map<String, Object?>>{
            'a missing key': editPreviewJson()..remove('delivery_fee_uzs'),
            'no total kind': editPreviewJson(kind: 'none'),
            'a negative shortfall': editPreviewJson(shortfall: -1),
            'a total off its parts': editPreviewJson(total: 55601),
            'a change off the totals': editPreviewJson(change: 5),
            'a shortfall without a minimum': editPreviewJson(
              shortfall: 100,
              minimum: null,
            ),
          };
      for (final MapEntry<String, Map<String, Object?>> entry
          in broken.entries) {
        answer = entry.value;
        await expectLater(
          repository.previewEdit(orderOne, const <OrderEditLine>[]),
          throwsA(isA<ApiFailure>()),
          reason: entry.key,
        );
        expect(
          () => CustomerOrdersApi.parsePreview(entry.value),
          throwsFormatException,
          reason: entry.key,
        );
      }
    });

    test('a preview of the order itself shows no change', () {
      final OrderEditPreview preview = OrderEditPreview.ofOrder(
        CustomerOrdersApi.parseOrder(customerOrderJson()),
      );

      expect(preview.merchandiseSubtotalUzs, 35600);
      expect(preview.serviceFeeUzs, 5000);
      expect(preview.deliveryFeeUzs, 15000);
      expect(preview.totalUzs, 55600);
      expect(preview.totalBeforeUzs, 55600);
      expect(preview.totalKind, TotalKind.estimate);
      expect(preview.totalChangeUzs, 0);
      expect(preview.minimumShortfallUzs, 0);
      expect(
        () => OrderEditPreview.ofOrder(
          CustomerOrdersApi.parseOrder(
            customerOrderJson(status: 'cancelled', changeable: false),
          ),
        ),
        throwsStateError,
      );
    });

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

  group('the 6a fields', () {
    late FakeHttpClientAdapter adapter;
    late CustomerOrdersRepositoryImpl repository;
    Map<String, Object?>? answer;

    setUp(() {
      answer = null;
      adapter = FakeHttpClientAdapter((RequestOptions options) {
        if (options.path == '/customer/orders' ||
            options.path == '/customer/approvals') {
          return jsonReply(200, <String, Object?>{
            'data': options.path == '/customer/orders'
                ? <Object?>[orderSummaryJson()]
                : <Object?>[
                    approvalJson(status: 'pending'),
                    approvalJson(
                      id: '0192f0a0-0000-7000-8000-00000000c032',
                      status: 'pending',
                    ),
                  ],
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

    test('a tab asks for its state', () async {
      await repository.orders(OrdersTab.past, 2);
      expect(adapter.requests.single.queryParameters, <String, Object>{
        'state': 'past',
        'page': 2,
      });
    });

    test('a summary carries the 6a fields', () {
      final OrderSummary summary = CustomerOrdersApi.parseSummary(
        <String, Object?>{
          ...orderSummaryJson(status: 'on_the_way'),
          'courier_phone': '+998901234567',
          'image_url': 'https://cdn.example/p.webp',
          'rating_stars': 4,
          'can_rate': true,
        },
      );
      expect(summary.street, 'Amir Temur');
      expect(summary.house, '12');
      expect(summary.courierPhone, '+998901234567');
      expect(summary.imageUrl, 'https://cdn.example/p.webp');
      expect(summary.ratingStars, 4);
      expect(summary.canRate, isTrue);

      final OrderSummary bare = CustomerOrdersApi.parseSummary(
        orderSummaryJson(),
      );
      expect(bare.courierPhone, isNull);
      expect(bare.imageUrl, isNull);
      expect(bare.ratingStars, isNull);
      expect(bare.canRate, isFalse);

      expect(
        () => CustomerOrdersApi.parseSummary(<String, Object?>{
          ...orderSummaryJson()..remove('address'),
        }),
        throwsFormatException,
      );
      for (final Map<String, Object?> bad in <Map<String, Object?>>[
        <String, Object?>{'courier_phone': '998901234567'},
        <String, Object?>{'rating_stars': 6},
        <String, Object?>{'rating_stars': 0},
      ]) {
        expect(
          () => CustomerOrdersApi.parseSummary(<String, Object?>{
            ...orderSummaryJson(),
            ...bad,
          }),
          throwsFormatException,
        );
      }
    });

    test('an order carries the courier, support, rating and instants', () {
      final Map<String, Object?> json = customerOrderJson(
        status: 'on_the_way',
        courier: <String, Object?>{
          'first_name': null,
          'phone': '+998901234567',
        },
        supportPhone: '+998712000000',
        rating: <String, Object?>{
          'stars': 2,
          'reasons': <Object?>['not_fresh', 'from_the_future'],
          'comment': 'мятые',
          'created_at': '2026-09-29T08:00:00Z',
        },
        lines: <Object?>[
          orderLineJson(patch: <String, Object?>{'image_url': 'https://i/1'}),
        ],
      );
      (json['timestamps']! as Map<String, Object?>)['on_the_way_at'] =
          '2026-09-28T09:00:00Z';
      final CustomerOrder order = CustomerOrdersApi.parseOrder(json);
      expect(order.courier!.firstName, isNull);
      expect(order.courier!.phone, '+998901234567');
      expect(order.supportPhone, '+998712000000');
      expect(order.rating!.stars, 2);
      expect(order.rating!.reasons, <RatingReason>[RatingReason.notFresh]);
      expect(order.rating!.comment, 'мятые');
      expect(order.onTheWayAt, DateTime.utc(2026, 9, 28, 9));
      expect(order.shoppingStartedAt, isNull);
      expect(order.lines.single.imageUrl, 'https://i/1');
      expect(order.canRate, isFalse);

      final CustomerOrder plain = CustomerOrdersApi.parseOrder(
        customerOrderJson(),
      );
      expect(plain.courier, isNull);
      expect(plain.rating, isNull);
      expect(plain.supportPhone, isNull);
      expect(plain.lines.first.imageUrl, isNull);

      expect(
        () => CustomerOrdersApi.parseOrder(
          customerOrderJson(supportPhone: '712000000'),
        ),
        throwsFormatException,
      );
      expect(
        () => CustomerOrdersApi.parseOrder(
          customerOrderJson(
            courier: <String, Object?>{'first_name': 'Ali', 'phone': '1'},
          ),
        ),
        throwsFormatException,
      );
    });

    test('reorder posts with its key and parses the four lists', () async {
      answer = <String, Object?>{
        'added_items': <Object?>[
          <String, Object?>{
            'product_id': productTomato,
            'name_uz': 'Pomidor',
            'name_ru': 'Помидоры',
            'quantity': '2.000',
          },
        ],
        'skipped_existing_items': <Object?>[
          <String, Object?>{
            'product_id': productBread,
            'name_uz': 'Non',
            'name_ru': 'Хлеб',
          },
        ],
        'unavailable_items': <Object?>[
          <String, Object?>{
            'product_id': productMilk,
            'name_uz': 'Sut',
            'name_ru': 'Молоко',
          },
        ],
        'cart_full_items': <Object?>[],
      };
      final ReorderResult result = await repository.reorder(orderOne, 'key-1');

      final RequestOptions request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/customer/orders/$orderOne/reorder');
      expect(request.headers['Idempotency-Key'], 'key-1');
      expect(request.data, isNull);
      expect(result.added.single.quantity, '2.000');
      expect(result.added.single.name(AppLanguage.ru), 'Помидоры');
      expect(result.skipped.single.quantity, isNull);
      expect(result.unavailable.single.quantity, isNull);
      expect(result.cartFull, isEmpty);
    });

    test('rate posts stars, reasons and a comment', () async {
      answer = customerOrderJson(
        status: 'completed',
        rating: <String, Object?>{
          'stars': 2,
          'reasons': <Object?>['not_fresh'],
          'comment': 'мятые',
          'created_at': '2026-09-29T08:00:00Z',
        },
      );
      final CustomerOrder order = await repository.rate(
        orderOne,
        2,
        const <RatingReason>[RatingReason.notFresh],
        'мятые',
      );
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, '/customer/orders/$orderOne/rating');
      expect(adapter.requests.single.data, <String, Object?>{
        'stars': 2,
        'reasons': <String>['not_fresh'],
        'comment': 'мятые',
      });
      expect(adapter.requests.single.headers['Idempotency-Key'], isNull);
      expect(order.rating!.stars, 2);

      answer = customerOrderJson(
        status: 'completed',
        rating: <String, Object?>{
          'stars': 5,
          'reasons': <Object?>[],
          'comment': null,
          'created_at': '2026-09-29T08:00:00Z',
        },
      );
      await repository.rate(orderOne, 5, const <RatingReason>[], null);
      expect(adapter.requests.last.data, <String, Object?>{'stars': 5});

      answer = customerOrderJson(status: 'completed');
      await expectLater(
        repository.rate(orderOne, 5, const <RatingReason>[], null),
        throwsA(isA<MalformedResponseFailure>()),
      );
    });

    test('pending questions read the approvals list', () async {
      final List<PendingQuestion> questions = await repository
          .pendingQuestions();
      final RequestOptions request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/customer/approvals');
      expect(request.queryParameters, <String, Object>{
        'status': 'pending',
        'page': 1,
      });
      expect(questions, hasLength(2));
      expect(questions.first.approvalId, approvalOne);
      expect(questions.first.orderId, orderOne);
      expect(questions.first.orderNumber, 1001);
      expect(questions.first.expiresAt, DateTime.utc(2026, 9, 28, 8));
    });
  });
}
