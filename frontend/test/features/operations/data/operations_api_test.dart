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
/// and 39.
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

      final ShopperChoice shopper = OperationsApi.parseShopper(shopperJson());
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
            .having((AssignmentDetails d) => d.isSelfOrder, 'self', isFalse),
      );
    });

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
      },
    );

    test('every request goes on the staff session', () async {
      await repository.orders(const BoardQuery());
      await repository.order(orderA);
      await repository.summary();
      await repository.attention();
      await repository.shoppers();

      expect(adapter.requests.map((RequestOptions o) => o.path), <String>[
        '/operations/orders',
        '/operations/orders/$orderA',
        '/operations/summary',
        '/operations/attention',
        '/operations/shoppers',
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

    test('a page parses', () async {
      final Paged<BoardRow> page = await repository.orders(const BoardQuery());
      expect(page.items.single.id, orderA);
    });
  });
}
