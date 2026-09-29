import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/auth_interceptor.dart';
import 'package:baraka_bozor/core/network/paged.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/operations/data/operations_api.dart';
import 'package:baraka_bozor/features/operations/data/operations_repository_impl.dart';
import 'package:baraka_bozor/features/operations/domain/board.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';
import '../../../support/operations_json.dart';

/// The board's data source against `docs/09-api-contracts.md` sections 38
/// to 41 and 45.
void main() {
  Map<String, Object?> without(Map<String, Object?> json, String key) =>
      Map<String, Object?>.of(json)..remove(key);

  group('parsing', () {
    test('a row, with and without a Shopper', () {
      final BoardRow row = OperationsApi.parseRow(rowJson(selfOrder: true));
      expect(row.orderNumber, 1001);
      expect(row.status, OrderStatus.shoppingAssigned);
      expect(row.paymentMethod, PaymentMethod.cash);
      expect(row.totalUzs, 75200);
      expect(row.totalKind, TotalKind.estimate);
      expect(row.shopper?.id, shopperId);
      expect(row.isSelfOrder, isTrue);
      expect(row.createdAt, DateTime.utc(2026, 9, 27, 7));

      final BoardRow none = OperationsApi.parseRow(
        rowJson(
          status: 'cancelled',
          totalUzs: null,
          totalKind: 'none',
          shopper: null,
        ),
      );
      expect(none.totalUzs, isNull);
      expect(none.shopper, isNull);

      // A self-order Shopper whose shopping was cancelled still marks the
      // order the row no longer names them on (DL-54 (14), DL-62 (5)).
      final BoardRow marked = OperationsApi.parseRow(
        rowJson(
          status: 'cancelled',
          totalUzs: null,
          totalKind: 'none',
          shopper: null,
          selfOrder: true,
        ),
      );
      expect(marked.isSelfOrder, isTrue);
      expect(marked.shopper, isNull);
    });

    test('a row off the contract is refused', () {
      for (final Map<String, Object?> broken in <Map<String, Object?>>[
        rowJson(totalUzs: null),
        rowJson(totalKind: 'none'),
        rowJson(status: 'approval_required'),
        rowJson(paymentMethod: 'card'),
        <String, Object?>{...rowJson(), 'id': 'o-1'},
        <String, Object?>{...rowJson(), 'order_number': 0},
        <String, Object?>{
          ...rowJson(),
          'created_at': '2026-09-27T12:00:00+05:00',
        },
        <String, Object?>{
          ...rowJson(),
          'customer': <String, Object?>{'full_name': 'A', 'phone': '901112233'},
        },
        without(rowJson(), 'is_self_order'),
      ]) {
        expect(
          () => OperationsApi.parseRow(broken),
          throwsFormatException,
          reason: '$broken',
        );
      }
    });

    test('the summary names every open status and nothing else', () {
      final BoardSummary summary = OperationsApi.parseSummary(summaryJson());
      expect(summary.day, '2026-09-27');
      expect(summary.openByStatus.keys, OrderStatus.open);
      expect(summary.openByStatus[OrderStatus.newOrder], 2);
      expect(summary.salesTodayUzs, 480000);

      final Map<String, Object?> extra = summaryJson();
      extra['open_by_status'] = <String, int>{
        ...(summaryJson()['open_by_status']! as Map<String, int>),
        'completed': 4,
      };
      final Map<String, Object?> missing = summaryJson();
      missing['open_by_status'] = Map<String, int>.of(
        summaryJson()['open_by_status']! as Map<String, int>,
      )..remove('on_the_way');
      for (final Map<String, Object?> broken in <Map<String, Object?>>[
        extra,
        missing,
        <String, Object?>{...summaryJson(), 'day': '27.09.2026'},
        <String, Object?>{...summaryJson(), 'sales_today_uzs': -1},
      ]) {
        expect(
          () => OperationsApi.parseSummary(broken),
          throwsFormatException,
          reason: '$broken',
        );
      }
    });

    test('an attention item and a Shopper of the picker', () {
      final AttentionItem item = OperationsApi.parseAttention(attentionJson());
      expect(item.type, AttentionType.selfOrder);
      expect(item.orderId, orderA);
      expect(item.shopper?.fullName, 'Sardor Yusupov');
      expect(item.courier, isNull);

      // Every type of docs/09 section 38 is read, and one this client does
      // not know yet is shown in general words, not refused (DL-54 (21)).
      for (final AttentionType type in AttentionType.values) {
        if (type == AttentionType.other) {
          continue;
        }
        expect(
          OperationsApi.parseAttention(<String, Object?>{
            ...attentionJson(),
            'type': type.code,
          }).type,
          type,
        );
      }
      final AttentionItem later = OperationsApi.parseAttention(
        <String, Object?>{
          ...attentionJson(),
          'type': 'something_new',
          'shopper': null,
          'courier': <String, Object?>{'id': shopperId, 'full_name': 'Kamol'},
        },
      );
      expect(later.type, AttentionType.other);
      expect(later.shopper, isNull);
      expect(later.courier?.fullName, 'Kamol');
      expect(
        () => OperationsApi.parseAttention(
          <String, Object?>{...attentionJson()}..remove('courier'),
        ),
        throwsFormatException,
      );

      final StaffChoice shopper = OperationsApi.parseStaff(shopperJson());
      expect(shopper.currentAssignmentCount, 1);
    });

    test(
      'a whole-number quantity and a markup of nothing are in the contract',
      () {
        final BoardOrder order = OperationsApi.parseOrder(
          orderJson(
            items: <Object?>[
              <String, Object?>{
                ...itemJson(),
                'unit_code': 'piece',
                'price_mode': 'fixed',
                'quantity': '2',
                'markup_percent': '0.00',
              },
            ],
          ),
        );

        expect(order.items.single.quantity, '2');
        expect(order.items.single.markupPercent, '0.00');
      },
    );

    test('an order with its lines, totals, assignments and history', () {
      final BoardOrder order = OperationsApi.parseOrder(orderJson());

      expect(order.orderNumber, 1001);
      expect(order.customer.phone, '+998901112233');
      expect(order.address.apartment, '34');
      expect(order.address.landmark, isNull);
      expect(order.items.single.marketPriceUzs, 16000);
      expect(order.items.single.markupPercent, '15.00');
      expect(order.items.single.quantity, '3.000');
      expect(order.totals.totalUzs, 75200);
      expect(order.currentAssignment?.id, assignmentId);
      final HistoryEntry entry = order.history.single;
      expect(entry.event, OrderHistoryEvent.shopperAssigned);
      expect(entry.actor?.role, UserRole.operator);
      expect(
        entry.details,
        isA<AssignmentDetails>()
            .having(
              (AssignmentDetails d) => d.assignmentId,
              'assignment',
              assignmentId,
            )
            .having((AssignmentDetails d) => d.isSelfOrder, 'self', isFalse)
            .having((AssignmentDetails d) => d.role, 'role', UserRole.shopper)
            .having((AssignmentDetails d) => d.staffId, 'staff', shopperId),
      );
    });

    test(
      'a Courier\'s assignment details are read with the Courier\'s ids',
      () {
        const String second = '0192f0a0-0000-7000-8000-0000000000a8';
        final BoardOrder order = OperationsApi.parseOrder(
          orderJson(
            history: <Object?>[
              historyJson(
                event: 'courier_reassigned',
                details: <String, Object?>{
                  'assignment_id': second,
                  'courier_id': otherCourierId,
                  'is_self_order': true,
                  'previous_assignment_id': courierAssignmentId,
                  'previous_courier_id': courierId,
                },
              ),
            ],
          ),
        );

        expect(
          order.history.single.details,
          isA<AssignmentDetails>()
              .having((AssignmentDetails d) => d.role, 'role', UserRole.courier)
              .having((AssignmentDetails d) => d.assignmentId, 'id', second)
              .having(
                (AssignmentDetails d) => d.staffId,
                'staff',
                otherCourierId,
              )
              .having((AssignmentDetails d) => d.isSelfOrder, 'self', isTrue)
              .having(
                (AssignmentDetails d) => d.previousAssignmentId,
                'previous',
                courierAssignmentId,
              )
              .having(
                (AssignmentDetails d) => d.previousStaffId,
                'previous staff',
                courierId,
              ),
        );

        // A Courier's entry names a Courier, and a reassignment the one before.
        for (final Map<String, Object?> details in <Map<String, Object?>>[
          <String, Object?>{
            'assignment_id': courierAssignmentId,
            'shopper_id': courierId,
            'is_self_order': false,
          },
          <String, Object?>{
            'assignment_id': second,
            'courier_id': otherCourierId,
            'is_self_order': false,
            'previous_assignment_id': courierAssignmentId,
          },
        ]) {
          final String event = details.containsKey('previous_assignment_id')
              ? 'courier_reassigned'
              : 'courier_assigned';
          expect(
            () => OperationsApi.parseOrder(
              orderJson(
                history: <Object?>[historyJson(event: event, details: details)],
              ),
            ),
            throwsFormatException,
            reason: '$details',
          );
        }
      },
    );

    test('every event of Wave 3\'s actions is read (DL-54 (2))', () {
      for (final String code in <String>[
        'shopper_accepted',
        'courier_accepted',
        'item_purchased',
        'item_unavailable',
        'item_substituted',
        'cancellation_requested',
        'cancellation_request_decided',
        'payment_recorded',
      ]) {
        final BoardOrder order = OperationsApi.parseOrder(
          orderJson(
            history: <Object?>[historyJson(event: code, details: null)],
          ),
        );

        expect(order.history.single.event.code, code);
      }
    });

    test('an edit\'s details are counted and other events\' are not read', () {
      final BoardOrder order = OperationsApi.parseOrder(
        orderJson(
          history: <Object?>[
            historyJson(
              event: 'edited',
              details: <String, Object?>{
                'added': <Object?>[<String, Object?>{}],
                'removed': <Object?>[],
                'changed': <Object?>[<String, Object?>{}, <String, Object?>{}],
                'delivery_time_note': <String, Object?>{
                  'before': null,
                  'after': 'Kechqurun',
                },
              },
            ),
            historyJson(event: 'status_changed', details: null),
          ],
        ),
      );

      expect(
        order.history.first.details,
        isA<EditDetails>()
            .having((EditDetails d) => d.added, 'added', 1)
            .having((EditDetails d) => d.removed, 'removed', 0)
            .having((EditDetails d) => d.changed, 'changed', 2)
            .having(
              (EditDetails d) => d.deliveryTimeNoteChanged,
              'note',
              isTrue,
            ),
      );
      expect(order.history.last.details, isNull);
    });

    test('a line\'s purchase, the questions, the requests and the payment', () {
      final BoardOrder order = OperationsApi.parseOrder(
        orderJson(
          status: 'shopping',
          items: <Object?>[
            itemJson(
              status: 'purchased',
              replaced: true,
              purchase: <String, Object?>{
                'purchased_quantity': '3.200',
                'actual_market_price_uzs': 17000,
                'billable_unit_price_uzs': 19550,
              },
            ),
          ],
          approvals: <Object?>[
            approvalJson(
              status: 'approved',
              resolution: 'approved',
              resolved: true,
            ),
            approvalJson(
              id: '0192f0a0-0000-7000-8000-0000000000b4',
              type: 'reduced_quantity',
              status: 'expired',
            ),
            approvalJson(
              id: '0192f0a0-0000-7000-8000-0000000000b5',
              type: 'substitution',
              status: 'expired',
              resolution: 'remove_item',
              resolved: true,
            ),
            approvalJson(
              id: '0192f0a0-0000-7000-8000-0000000000b6',
              status: 'cancelled',
            ),
          ],
          cancellationRequests: <Object?>[
            cancellationRequestJson(
              id: '0192f0a0-0000-7000-8000-0000000000b7',
              status: 'rejected',
              note: 'Buyurtma yig\'ilmoqda',
            ),
            cancellationRequestJson(),
          ],
          payment: paymentJson(),
          history: <Object?>[
            historyJson(
              event: 'price_corrected',
              details: <String, Object?>{
                'item_id': itemId,
                'correction_id': '0192f0a0-0000-7000-8000-0000000000b8',
                'old_actual_market_price_uzs': 16000,
                'new_actual_market_price_uzs': 17000,
                'old_billable_unit_price_uzs': 18400,
                'new_billable_unit_price_uzs': 19550,
                'line_total_uzs': 62560,
              },
            ),
          ],
        ),
      );

      final BoardItem line = order.items.single;
      expect(line.purchasedQuantity, '3.200');
      expect(line.billableQuantity, '3.000');
      expect(line.actualMarketPriceUzs, 17000);
      expect(line.billableUnitPriceUzs, 19550);
      expect(line.replacement?.id, replacementId);
      expect(line.replacementResolution, SubstitutionResolution.automatic);
      expect(line.billedFromPricePaid, isTrue);

      expect(order.approvals.map((BoardApproval a) => a.status), <Object>[
        ApprovalStatus.approved,
        ApprovalStatus.expired,
        ApprovalStatus.expired,
        ApprovalStatus.cancelled,
      ]);
      final BoardApproval price = order.approvals.first;
      expect(price.proposedCustomerUnitPriceUzs, 25300);
      expect(price.proposedActualMarketPriceUzs, 22000);
      expect(price.requestedBy.id, shopperId);
      expect(price.expiresAt, DateTime.utc(2026, 9, 27, 8));
      expect(order.approvals[1].proposedQuantity, '2.000');
      expect(order.approvals.map((BoardApproval a) => a.awaitsRemoval), <bool>[
        false,
        true,
        false,
        false,
      ]);
      expect(order.approvals[2].replacement?.nameRu, 'Помидоры черри');

      expect(order.cancellationRequests.first.resolvedBy?.id, operatorId);
      expect(order.cancellationRequests.first.resolutionNote, isNotNull);
      expect(order.pendingCancellationRequest?.id, requestId);
      expect(order.pendingCancellationRequest?.reason, isNotEmpty);

      expect(order.payment?.status, PaymentStatus.paid);
      expect(order.payment?.amountUzs, 75200);
      expect(order.payment?.recordedBy?.id, courierId);

      expect(
        order.history.single.details,
        isA<PriceCorrectionDetails>()
            .having((PriceCorrectionDetails d) => d.itemId, 'item', itemId)
            .having(
              (PriceCorrectionDetails d) => d.newActualMarketPriceUzs,
              'new',
              17000,
            )
            .having(
              (PriceCorrectionDetails d) => d.oldBillableUnitPriceUzs,
              'old billed',
              18400,
            ),
      );
    });

    test('a purchase, a question, a request or a payment off the contract '
        'is refused', () {
      Map<String, Object?> withApproval(Map<String, Object?> patch) =>
          orderJson(
            status: 'shopping',
            approvals: <Object?>[
              <String, Object?>{...approvalJson(), ...patch},
            ],
          );
      for (final Map<String, Object?> broken in <Map<String, Object?>>[
        // Lines.
        orderJson(
          items: <Object?>[
            itemJson(purchase: <String, Object?>{'billable_quantity': '1.000'}),
          ],
        ),
        orderJson(
          items: <Object?>[
            itemJson(
              purchase: <String, Object?>{'billable_unit_price_uzs': 18400},
            ),
          ],
        ),
        orderJson(
          items: <Object?>[
            itemJson(
              status: 'purchased',
              purchase: <String, Object?>{'purchased_quantity': null},
            ),
          ],
        ),
        orderJson(
          items: <Object?>[
            itemJson(
              status: 'purchased',
              purchase: <String, Object?>{'billable_unit_price_uzs': null},
            ),
          ],
        ),
        orderJson(
          items: <Object?>[
            itemJson(
              status: 'removed',
              removedReason: 'unavailable',
              replaced: true,
            ),
          ],
        ),
        orderJson(
          items: <Object?>[
            itemJson(
              replaced: true,
              purchase: <String, Object?>{
                'replacement': <String, Object?>{
                  'product_id': replacementId,
                  'name_uz': 'Olcha pomidor',
                  'name_ru': 'Помидоры черри',
                  'substitution_resolution': 'guessed',
                },
              },
            ),
          ],
        ),
        orderJson(
          items: <Object?>[
            itemJson(
              replaced: true,
              purchase: <String, Object?>{
                'replacement': <String, Object?>{
                  'product_id': replacementId,
                  'name_uz': 'Olcha pomidor',
                  'name_ru': 'Помидоры черри',
                  'substitution_resolution': null,
                },
              },
            ),
          ],
        ),
        orderJson(items: <Object?>[without(itemJson(), 'purchased_quantity')]),
        // Questions.
        withApproval(<String, Object?>{'item_id': productId}),
        withApproval(<String, Object?>{
          'proposed_actual_market_price_uzs': null,
        }),
        withApproval(<String, Object?>{'proposed_quantity': '1.000'}),
        <String, Object?>{
          ...orderJson(
            approvals: <Object?>[
              <String, Object?>{
                ...approvalJson(type: 'substitution'),
                'replacement': null,
              },
            ],
          ),
        },
        <String, Object?>{
          ...orderJson(
            approvals: <Object?>[
              <String, Object?>{
                ...approvalJson(type: 'reduced_quantity'),
                'proposed_customer_unit_price_uzs': 100,
              },
            ],
          ),
        },
        withApproval(<String, Object?>{'resolution': 'approved'}),
        withApproval(<String, Object?>{
          'status': 'approved',
          'resolution': 'approved',
        }),
        withApproval(<String, Object?>{
          'status': 'rejected',
          'resolution': 'approved',
          'resolved_at': '2026-09-27T08:05:00Z',
        }),
        withApproval(<String, Object?>{
          'status': 'expired',
          'resolution': 'approved',
          'resolved_at': '2026-09-27T08:05:00Z',
        }),
        withApproval(<String, Object?>{
          'status': 'expired',
          'resolved_at': '2026-09-27T08:05:00Z',
        }),
        withApproval(<String, Object?>{'status': 'cancelled'}),
        withApproval(<String, Object?>{
          'resolved_by': <String, Object?>{'id': operatorId, 'full_name': 'O'},
        }),
        withApproval(<String, Object?>{
          'status': 'approved',
          'resolution': 'approved',
          'resolved_at': '2026-09-27T08:05:00Z',
        }),
        withApproval(<String, Object?>{
          'status': 'expired',
          'resolution': 'remove_item',
          'resolved_at': '2026-09-27T08:05:00Z',
        }),
        withApproval(<String, Object?>{
          'status': 'rejected',
          'resolution': 'rejected',
          'resolved_at': '2026-09-27T08:05:00Z',
        }),
        withApproval(<String, Object?>{
          'status': 'expired',
          'resolved_by': <String, Object?>{'id': operatorId, 'full_name': 'O'},
        }),
        withApproval(<String, Object?>{'type': 'ask_again'}),
        withApproval(<String, Object?>{'attention_at': '2026-09-27T08:00:00Z'}),
        without(orderJson(), 'approvals'),
        // Requests.
        orderJson(
          cancellationRequests: <Object?>[
            <String, Object?>{
              ...cancellationRequestJson(),
              'resolved_at': '2026-09-27T07:50:00Z',
            },
          ],
        ),
        orderJson(
          cancellationRequests: <Object?>[
            <String, Object?>{
              ...cancellationRequestJson(status: 'approved'),
              'resolved_by': null,
            },
          ],
        ),
        orderJson(
          cancellationRequests: <Object?>[
            <String, Object?>{
              ...cancellationRequestJson(status: 'closed'),
              'resolved_by': <String, Object?>{
                'id': operatorId,
                'full_name': 'Olim',
              },
            },
          ],
        ),
        orderJson(
          cancellationRequests: <Object?>[
            cancellationRequestJson(),
            cancellationRequestJson(id: '0192f0a0-0000-7000-8000-0000000000b7'),
          ],
        ),
        without(orderJson(), 'cancellation_requests'),
        // The payment and a correction's details.
        orderJson(
          payment: <String, Object?>{...paymentJson(), 'paid_at': null},
        ),
        orderJson(
          payment: <String, Object?>{...paymentJson(), 'status': 'refunded'},
        ),
        orderJson(
          payment: <String, Object?>{...paymentJson(), 'recorded_by': null},
        ),
        orderJson(
          payment: <String, Object?>{
            ...paymentJson(),
            'status': 'pending',
            'paid_at': null,
          },
        ),
        orderJson(
          paymentMethod: 'online',
          payment: <String, Object?>{...paymentJson(), 'method': 'online'},
        ),
        orderJson(
          paymentMethod: 'online',
          payment: <String, Object?>{
            ...paymentJson(),
            'method': 'online',
            'status': 'pending',
            'recorded_by': null,
          },
        ),
        without(orderJson(), 'payment'),
        orderJson(
          history: <Object?>[
            historyJson(
              event: 'price_corrected',
              details: <String, Object?>{'item_id': itemId},
            ),
          ],
        ),
      ]) {
        expect(
          () => OperationsApi.parseOrder(broken),
          throwsFormatException,
          reason: '$broken',
        );
      }
    });

    test('an order off the contract is refused', () {
      for (final Map<String, Object?> broken in <Map<String, Object?>>[
        orderJson(items: <Object?>[itemJson(status: 'removed')]),
        orderJson(items: <Object?>[itemJson(removedReason: 'unavailable')]),
        orderJson(
          totals: <String, Object?>{
            'merchandise_subtotal_uzs': null,
            'service_fee_uzs': 5000,
            'delivery_fee_uzs': 15000,
            'total_uzs': 75200,
            'total_kind': 'estimate',
          },
        ),
        orderJson(
          totals: <String, Object?>{
            'merchandise_subtotal_uzs': 1,
            'service_fee_uzs': 1,
            'delivery_fee_uzs': 1,
            'total_uzs': 3,
            'total_kind': 'none',
          },
        ),
        // Only a delivery fails; a Shopper's assignment never ends so.
        orderJson(
          assignments: <Object?>[
            assignmentJson(
              endedAt: '2026-09-27T08:00:00Z',
              endedReason: 'delivery_failed',
            ),
          ],
        ),
        orderJson(
          assignments: <Object?>[
            assignmentJson(endedAt: '2026-09-27T08:00:00Z'),
          ],
        ),
        orderJson(
          assignments: <Object?>[
            assignmentJson(),
            assignmentJson(id: '0192f0a0-0000-7000-8000-0000000000a2'),
          ],
        ),
        orderJson(history: <Object?>[historyJson(withActor: false)]),
        orderJson(history: <Object?>[historyJson(actorType: 'system')]),
        orderJson(
          history: <Object?>[
            historyJson(
              event: 'shopper_reassigned',
              details: <String, Object?>{
                'assignment_id': assignmentId,
                'shopper_id': shopperId,
                'is_self_order': false,
              },
            ),
          ],
        ),
        orderJson(
          history: <Object?>[historyJson(event: 'edited', details: null)],
        ),
        <String, Object?>{
          ...orderJson(),
          'address': <String, Object?>{
            ...(orderJson()['address']! as Map<String, Object?>),
            'latitude': '41.3',
          },
        },
      ]) {
        expect(
          () => OperationsApi.parseOrder(broken),
          throwsFormatException,
          reason: '$broken',
        );
      }
    });
  });

  group('requests', () {
    late FakeHttpClientAdapter adapter;
    late OperationsRepositoryImpl repository;
    Object? pageAnswer;
    Object? orderAnswer;

    setUp(() {
      pageAnswer = null;
      orderAnswer = null;
      adapter = FakeHttpClientAdapter((RequestOptions options) {
        return switch (options.path) {
          '/operations/orders' => jsonReply(
            200,
            pageAnswer ??
                pageJson(<Object?>[
                  rowJson(),
                ], page: options.queryParameters['page']! as int),
          ),
          '/operations/summary' => jsonReply(200, <String, Object?>{
            'data': summaryJson(),
          }),
          '/operations/attention' => jsonReply(
            200,
            pageJson(<Object?>[attentionJson()]),
          ),
          '/operations/shoppers' => jsonReply(
            200,
            pageJson(<Object?>[shopperJson()]),
          ),
          '/operations/couriers' => jsonReply(
            200,
            pageJson(<Object?>[courierChoiceJson()]),
          ),
          _ => jsonReply(200, <String, Object?>{
            'data': orderAnswer ?? orderJson(),
          }),
        };
      });
      repository = OperationsRepositoryImpl(OperationsApi(dioWith(adapter)));
    });

    test(
      'the board sends its page and only the filters that are set',
      () async {
        await repository.orders(const BoardQuery());
        await repository.orders(
          BoardQuery(
            page: 2,
            status: OrderStatus.shoppingAssigned,
            shopperId: shopperId,
            paymentMethod: PaymentMethod.cash,
            from: DateTime(2026, 9, 1),
            to: DateTime(2026, 9, 27),
            search: '  1001 ',
          ),
        );
        pageAnswer = pageJson(<Object?>[rowJson(selfOrder: true)]);
        await repository.orders(
          const BoardQuery(selfOrdersOnly: true, search: '   '),
        );
        pageAnswer = pageJson(<Object?>[
          rowJson(courier: courierId, pendingApprovals: 1),
        ]);
        await repository.orders(
          const BoardQuery(courierId: courierId, awaitingCustomerOnly: true),
        );

        expect(adapter.requests[0].path, '/operations/orders');
        expect(adapter.requests[0].queryParameters, <String, Object>{
          'page': 1,
        });
        expect(adapter.requests[1].queryParameters, <String, Object>{
          'page': 2,
          'status': 'shopping_assigned',
          'shopper_id': shopperId,
          'payment_method': 'cash',
          'from': '2026-09-01',
          'to': '2026-09-27',
          'search': '1001',
        });
        expect(adapter.requests[2].queryParameters, <String, Object>{
          'page': 1,
          'attention': 'self_order',
        });
        expect(adapter.requests[3].queryParameters, <String, Object>{
          'page': 1,
          'courier_id': courierId,
          'awaiting_customer': 'true',
        });
      },
    );

    test('every request goes on the staff session', () async {
      await repository.orders(const BoardQuery());
      await repository.order(orderA);
      await repository.summary();
      await repository.attention();
      await repository.shoppers();
      await repository.couriers();

      expect(adapter.requests.map((RequestOptions o) => o.path), <String>[
        '/operations/orders',
        '/operations/orders/$orderA',
        '/operations/summary',
        '/operations/attention',
        '/operations/shoppers',
        '/operations/couriers',
      ]);
      expect(adapter.requests.last.queryParameters, <String, Object>{
        'per_page': 100,
      });
      for (final RequestOptions request in adapter.requests) {
        expect(
          RequestSlot.resolve(request, () => SessionSlot.customer),
          SessionSlot.staff,
          reason: request.path,
        );
      }
    });

    test('an answer to another question is malformed', () async {
      pageAnswer = pageJson(<Object?>[rowJson()], page: 3);
      await expectLater(
        repository.orders(const BoardQuery()),
        throwsA(isA<MalformedResponseFailure>()),
      );

      pageAnswer = pageJson(<Object?>[rowJson(status: 'new')]);
      await expectLater(
        repository.orders(
          const BoardQuery(status: OrderStatus.shoppingAssigned),
        ),
        throwsA(isA<MalformedResponseFailure>()),
      );

      pageAnswer = pageJson(<Object?>[rowJson(paymentMethod: 'online')]);
      await expectLater(
        repository.orders(const BoardQuery(paymentMethod: PaymentMethod.cash)),
        throwsA(isA<MalformedResponseFailure>()),
      );

      orderAnswer = orderJson(id: orderB);
      await expectLater(
        repository.order(orderA),
        throwsA(isA<MalformedResponseFailure>()),
      );
    });

    test(
      'a row whose Shopper changed after its page was read is kept',
      () async {
        // The page is filtered in one statement and its rows' Shoppers read in
        // another, so a reassignment in between is no malformed answer.
        pageAnswer = pageJson(<Object?>[rowJson(shopper: otherShopperId)]);
        expect(
          (await repository.orders(const BoardQuery(shopperId: shopperId)))
              .items
              .single
              .shopper
              ?.id,
          otherShopperId,
        );

        pageAnswer = pageJson(<Object?>[rowJson()]);
        expect(
          (await repository.orders(const BoardQuery(selfOrdersOnly: true)))
              .items,
          hasLength(1),
        );
      },
    );

    test('an id in capitals asks for the same order', () async {
      final BoardOrder order = await repository.order(orderA.toUpperCase());

      expect(order.id, orderA);
      expect(
        adapter.requests.single.path,
        '/operations/orders/${orderA.toUpperCase()}',
      );
    });

    test('an assignment is a POST and a reassignment a PUT naming what it replaces', () async {
      const String second = '0192f0a0-0000-7000-8000-0000000000a2';
      await repository.assignShopper(orderA, shopperId);
      orderAnswer = orderJson(
        assignments: <Object?>[
          assignmentJson(
            endedAt: '2026-09-27T07:10:00Z',
            endedReason: 'reassigned',
          ),
          assignmentJson(id: second, shopper: otherShopperId),
        ],
      );
      await repository.reassignShopper(orderA, otherShopperId, assignmentId);

      final RequestOptions assign = adapter.requests[0];
      final RequestOptions reassign = adapter.requests[1];
      expect(assign.method, 'POST');
      expect(assign.path, '/operations/orders/$orderA/shopper-assignment');
      expect(assign.data, <String, String>{'shopper_id': shopperId});
      expect(reassign.method, 'PUT');
      expect(reassign.path, '/operations/orders/$orderA/shopper-assignment');
      expect(reassign.data, <String, String>{
        'shopper_id': otherShopperId,
        'replaces_assignment_id': assignmentId,
      });
      for (final RequestOptions request in adapter.requests) {
        expect(
          RequestSlot.resolve(request, () => SessionSlot.customer),
          SessionSlot.staff,
        );
      }
    });

    test(
      'an answer that does not show the assignment asked for is malformed',
      () async {
        // The answer's current Shopper is another one.
        await expectLater(
          repository.assignShopper(orderA, otherShopperId),
          throwsA(isA<MalformedResponseFailure>()),
        );

        orderAnswer = orderJson(id: orderB);
        await expectLater(
          repository.assignShopper(orderA, shopperId),
          throwsA(isA<MalformedResponseFailure>()),
        );

        orderAnswer = orderJson(assignments: <Object?>[]);
        await expectLater(
          repository.reassignShopper(orderA, shopperId, assignmentId),
          throwsA(isA<MalformedResponseFailure>()),
        );
      },
    );

    test('a Courier assignment is a POST and a reassignment a PUT naming what it replaces', () async {
      const String second = '0192f0a0-0000-7000-8000-0000000000a8';
      orderAnswer = orderJson(
        status: 'delivery_assigned',
        courierAssignments: <Object?>[courierAssignmentJson()],
      );
      await repository.assignCourier(orderA, courierId);
      orderAnswer = orderJson(
        status: 'delivery_assigned',
        courierAssignments: <Object?>[
          courierAssignmentJson(
            endedAt: '2026-09-27T09:20:00Z',
            endedReason: 'reassigned',
          ),
          courierAssignmentJson(id: second, courier: otherCourierId),
        ],
      );
      await repository.reassignCourier(
        orderA,
        otherCourierId,
        courierAssignmentId,
      );

      final RequestOptions assign = adapter.requests[0];
      final RequestOptions reassign = adapter.requests[1];
      expect(assign.method, 'POST');
      expect(assign.path, '/operations/orders/$orderA/courier-assignment');
      expect(assign.data, <String, String>{'courier_id': courierId});
      expect(reassign.method, 'PUT');
      expect(reassign.data, <String, String>{
        'courier_id': otherCourierId,
        'replaces_assignment_id': courierAssignmentId,
      });

      // An answer whose current Courier is another one is malformed.
      await expectLater(
        repository.assignCourier(orderA, courierId),
        throwsA(isA<MalformedResponseFailure>()),
      );
    });

    test('a Courier assignment and a row\'s Courier are read strictly', () {
      final BoardOrder order = OperationsApi.parseOrder(
        orderJson(
          status: 'ready_for_delivery',
          courierAssignments: <Object?>[
            courierAssignmentJson(
              acceptedAt: '2026-09-27T09:05:00Z',
              startedAt: '2026-09-27T09:30:00Z',
              endedAt: '2026-09-27T10:00:00Z',
              endedReason: 'delivery_failed',
              failedReason: 'no_answer',
            ),
          ],
        ),
      );
      final CourierAssignment failed = order.courierAssignments.single;
      expect(failed.endedReason, AssignmentEndReason.deliveryFailed);
      expect(failed.failedReason, DeliveryFailureReason.noAnswer);
      expect(order.currentCourierAssignment, isNull);

      final BoardRow row = OperationsApi.parseRow(
        rowJson(courier: courierId, pendingApprovals: 2),
      );
      expect(row.courier?.id, courierId);
      expect(row.pendingApprovalCount, 2);

      for (final Map<String, Object?> broken in <Map<String, Object?>>[
        orderJson(
          courierAssignments: <Object?>[
            courierAssignmentJson(
              endedAt: '2026-09-27T10:00:00Z',
              endedReason: 'delivery_failed',
            ),
          ],
        ),
        orderJson(
          courierAssignments: <Object?>[
            courierAssignmentJson(failedReason: 'no_answer'),
          ],
        ),
        orderJson(
          courierAssignments: <Object?>[
            courierAssignmentJson(),
            courierAssignmentJson(
              id: '0192f0a0-0000-7000-8000-0000000000a8',
              courier: otherCourierId,
            ),
          ],
        ),
        <String, Object?>{...orderJson()}..remove('courier_assignments'),
      ]) {
        expect(
          () => OperationsApi.parseOrder(broken),
          throwsFormatException,
          reason: '$broken',
        );
      }
      for (final Map<String, Object?> broken in <Map<String, Object?>>[
        <String, Object?>{...rowJson()}..remove('courier'),
        <String, Object?>{...rowJson()}..remove('pending_approval_count'),
        <String, Object?>{...rowJson(), 'pending_approval_count': -1},
      ]) {
        expect(() => OperationsApi.parseRow(broken), throwsFormatException);
      }
    });

    test(
      'each action on an order sends its body and is held to its effect',
      () async {
        orderAnswer = orderJson(
          status: 'cancelled',
          approvals: <Object?>[
            approvalJson(
              status: 'expired',
              resolution: 'remove_item',
              resolved: true,
            ),
          ],
          cancellationRequests: <Object?>[
            cancellationRequestJson(status: 'approved'),
          ],
        );
        await repository.resolveExpiredApproval(orderA, approvalId, null);
        await repository.resolveExpiredApproval(
          orderA,
          approvalId,
          'Javob yo\'q',
        );
        await repository.decideCancellationRequest(
          orderA,
          requestId,
          CancellationDecision.approve,
          'Mijoz qo\'ng\'iroq qildi',
        );
        await repository.cancelAfterFailedDelivery(orderA, null);
        orderAnswer = orderJson(
          status: 'delivery_assigned',
          items: <Object?>[
            itemJson(
              status: 'purchased',
              purchase: <String, Object?>{'actual_market_price_uzs': 15000},
            ),
          ],
        );
        await repository.correctPrice(orderA, itemId, 15000, 'Chek bo\'yicha');

        expect(
          adapter.requests.map(
            (RequestOptions o) => '${o.method} ${o.path} ${o.data}',
          ),
          <String>[
            'POST /operations/approvals/$approvalId/resolve-expired '
                '{resolution: remove_item}',
            'POST /operations/approvals/$approvalId/resolve-expired '
                '{resolution: remove_item, note: Javob yo\'q}',
            'POST /operations/cancellation-requests/$requestId/decision '
                '{decision: approve, note: Mijoz qo\'ng\'iroq qildi}',
            'POST /operations/orders/$orderA/cancel '
                '{reason_code: delivery_failed}',
            'POST /admin/orders/$orderA/items/$itemId/price-correction '
                '{actual_market_price_uzs: 15000, reason: Chek bo\'yicha}',
          ],
        );

        // An answer that does not show what was asked for is malformed.
        orderAnswer = orderJson(
          status: 'shopping',
          approvals: <Object?>[approvalJson(status: 'expired')],
          cancellationRequests: <Object?>[cancellationRequestJson()],
        );
        for (final Future<BoardOrder> Function() action
            in <Future<BoardOrder> Function()>[
              () => repository.resolveExpiredApproval(orderA, approvalId, null),
              () => repository.decideCancellationRequest(
                orderA,
                requestId,
                CancellationDecision.reject,
                null,
              ),
              () => repository.cancelAfterFailedDelivery(orderA, null),
              () => repository.correctPrice(orderA, itemId, 15000, 'Chek'),
            ]) {
          await expectLater(action(), throwsA(isA<MalformedResponseFailure>()));
        }

        // So is one about another order, whatever it shows.
        orderAnswer = orderJson(
          status: 'shopping',
          approvals: <Object?>[
            approvalJson(
              status: 'expired',
              resolution: 'remove_item',
              resolved: true,
            ),
          ],
        );
        await expectLater(
          repository.resolveExpiredApproval(orderB, approvalId, null),
          throwsA(isA<MalformedResponseFailure>()),
        );
      },
    );

    test('a page parses', () async {
      final Paged<BoardRow> page = await repository.orders(const BoardQuery());
      expect(page.items.single.id, orderA);
    });
  });
}
