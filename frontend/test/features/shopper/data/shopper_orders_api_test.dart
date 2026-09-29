import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/auth_interceptor.dart';
import 'package:baraka_bozor/core/network/paged.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/shopper/data/shopper_orders_api.dart';
import 'package:baraka_bozor/features/shopper/domain/shopper_orders.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';
import '../../../support/fake_shopper_orders_repository.dart';
import '../../../support/operations_json.dart' show pageJson;

/// The Shopper's data source against `docs/09-api-contracts.md` sections 28
/// and 29.
void main() {
  Map<String, Object?> without(Map<String, Object?> json, String key) =>
      Map<String, Object?>.of(json)..remove(key);

  group('parsing', () {
    test('a row, as the list shows it', () {
      final ShopperOrderRow row = ShopperOrdersApi.parseRow(
        shopperRowJson(open: 1, accepted: true),
      );
      expect(row.orderNumber, 1001);
      expect(row.status, OrderStatus.shoppingAssigned);
      expect(row.itemCount, 2);
      expect(row.openItemCount, 1);
      expect(row.deliveryTimeNote, 'Kechqurun');
      expect(row.assignment.acceptedAt, DateTime.utc(2026, 9, 27, 7, 6));
      expect(row.assignment.startedAt, isNull);
    });

    test('an order with each kind of line', () {
      final ShopperOrder order = ShopperOrdersApi.parseOrder(
        shopperOrderJson(
          status: 'shopping',
          items: <Object?>[
            shopperLineJson(
              status: 'awaiting_customer',
              patch: <String, Object?>{
                'approved_quantity_cap': '1.500',
                'replacement': <String, Object?>{
                  'product_id': shopperProductCherry,
                  'name_uz': 'Olcha pomidor',
                  'name_ru': 'Помидоры черри',
                  'market_price_uzs': 15500,
                  'substitution_resolution': 'automatic',
                  'bound': <String, Object?>{
                    'customer_unit_price_uzs': 21160,
                    'market_price_uzs': 18400,
                  },
                },
                'pending_approval': <String, Object?>{
                  'id': shopperQuestion,
                  'type': 'price_over_tolerance',
                  'expires_at': '2026-09-27T08:00:00Z',
                },
              },
            ),
            shopperLineJson(bread: true, status: 'purchased'),
          ],
        ),
      );

      expect(order.customerPhone, '+998901112233');
      expect(order.canAccept, isFalse);
      expect(order.canStart, isFalse);
      expect(order.assignment?.startedAt, DateTime.utc(2026, 9, 27, 7, 7));
      final ShopperLine tomato = order.items.first;
      expect(tomato.unit, UnitCode.kg);
      expect(tomato.approvedQuantityCap, '1.500');
      expect(tomato.bound?.marketPriceUzs, 18400);
      expect(tomato.replacement?.marketPriceUzs, 15500);
      expect(tomato.replacement?.resolution, SubstitutionResolution.automatic);
      expect(tomato.openQuestion?.type, ApprovalType.priceOverTolerance);
      final ShopperLine bread = order.items.last;
      expect(bread.bound, isNull);
      expect(bread.purchase?.billableUnitPriceUzs, 4000);
      expect(bread.purchase?.actualMarketPriceUzs, isNull);
    });

    test('a row off the contract is refused', () {
      for (final Map<String, Object?> broken in <Map<String, Object?>>[
        shopperRowJson(status: 'new'),
        shopperRowJson(status: 'ready_for_delivery'),
        shopperRowJson(open: 3),
        <String, Object?>{...shopperRowJson(), 'item_count': -1},
        <String, Object?>{
          ...shopperRowJson(),
          'assignment': <String, Object?>{
            ...shopperAssignmentJson(),
            'started_at': '2026-09-27T07:07:00Z',
          },
        },
        <String, Object?>{...shopperRowJson(), 'assignment': null},
        without(shopperRowJson(), 'open_item_count'),
      ]) {
        expect(
          () => ShopperOrdersApi.parseRow(broken),
          throwsFormatException,
          reason: '$broken',
        );
      }
    });

    test('an order or a line off the contract is refused', () {
      Map<String, Object?> withLine(Map<String, Object?> line) =>
          shopperOrderJson(status: 'shopping', items: <Object?>[line]);
      for (final Map<String, Object?> broken in <Map<String, Object?>>[
        // The Customer's phone is there exactly while shopping.
        <String, Object?>{
          ...shopperOrderJson(),
          'customer_phone': '+998901112233',
        },
        <String, Object?>{
          ...shopperOrderJson(status: 'shopping'),
          'customer_phone': null,
        },
        <String, Object?>{
          ...shopperOrderJson(status: 'shopping'),
          'customer_phone': '901112233',
        },
        // What is offered follows from the assignment.
        <String, Object?>{...shopperOrderJson(), 'can_accept': false},
        <String, Object?>{
          ...shopperOrderJson(accepted: true),
          'can_start': false,
        },
        <String, Object?>{...shopperOrderJson(), 'can_start': true},
        <String, Object?>{
          ...shopperOrderJson(status: 'shopping'),
          'can_start': true,
        },
        without(shopperOrderJson(), 'items'),
        // Lines.
        withLine(
          shopperLineJson(
            status: 'purchased',
            patch: <String, Object?>{'purchase': null},
          ),
        ),
        withLine(
          shopperLineJson(
            patch: <String, Object?>{
              'purchase': shopperLineJson(status: 'purchased')['purchase'],
            },
          ),
        ),
        withLine(
          shopperLineJson(
            patch: <String, Object?>{'removed_reason_code': 'unavailable'},
          ),
        ),
        withLine(
          shopperLineJson(
            status: 'removed',
            patch: <String, Object?>{'removed_reason_code': null},
          ),
        ),
        withLine(
          shopperLineJson(
            status: 'removed',
            patch: <String, Object?>{
              'replacement': <String, Object?>{
                'product_id': shopperProductCherry,
                'name_uz': 'Olcha pomidor',
                'name_ru': 'Помидоры черри',
                'market_price_uzs': 15500,
                'substitution_resolution': 'automatic',
                'bound': shopperLineJson()['bound'],
              },
            },
          ),
        ),
        withLine(
          shopperLineJson(
            patch: <String, Object?>{
              'pending_approval': <String, Object?>{
                'id': shopperQuestion,
                'type': 'price_over_tolerance',
                'expires_at': '2026-09-27T08:00:00Z',
              },
            },
          ),
        ),
        withLine(
          shopperLineJson(
            patch: <String, Object?>{
              'replacement': <String, Object?>{
                'product_id': shopperProductCherry,
                'name_uz': 'Olcha pomidor',
                'name_ru': 'Помидоры черри',
                'market_price_uzs': 15500,
                'substitution_resolution': null,
                'bound': shopperLineJson()['bound'],
              },
            },
          ),
        ),
        withLine(
          shopperLineJson(patch: <String, Object?>{'quantity': '0.000'}),
        ),
        withLine(shopperLineJson(patch: <String, Object?>{'quantity': '2.5'})),
        withLine(
          shopperLineJson(patch: <String, Object?>{'unit_code': 'tonne'}),
        ),
        withLine(without(shopperLineJson(), 'bound')),
        // A fixed line has no bound, and an estimate has one.
        withLine(
          shopperLineJson(
            bread: true,
            patch: <String, Object?>{'bound': shopperLineJson()['bound']},
          ),
        ),
        withLine(shopperLineJson(patch: <String, Object?>{'bound': null})),
        // Quantities follow their unit.
        withLine(
          shopperLineJson(
            bread: true,
            patch: <String, Object?>{'quantity': '2.000'},
          ),
        ),
        withLine(shopperLineJson(patch: <String, Object?>{'quantity': '2'})),
        withLine(
          shopperLineJson(
            patch: <String, Object?>{'approved_quantity_cap': '1'},
          ),
        ),
        // Prices are above zero, and a replacement has its own.
        withLine(
          shopperLineJson(patch: <String, Object?>{'market_price_uzs': 0}),
        ),
        withLine(
          shopperLineJson(
            patch: <String, Object?>{
              'bound': <String, Object?>{
                'customer_unit_price_uzs': 21160,
                'market_price_uzs': 0,
              },
            },
          ),
        ),
        withLine(
          shopperLineJson(
            patch: <String, Object?>{
              'replacement': <String, Object?>{
                'product_id': shopperProductCherry,
                'name_uz': 'Olcha pomidor',
                'name_ru': 'Помидоры черри',
                'market_price_uzs': null,
                'substitution_resolution': 'automatic',
                'bound': shopperLineJson()['bound'],
              },
            },
          ),
        ),
        // The purchase names the product bought.
        withLine(
          shopperLineJson(
            status: 'purchased',
            patch: <String, Object?>{
              'purchase': <String, Object?>{
                ...(shopperLineJson(status: 'purchased')['purchase']!
                    as Map<String, Object?>),
                'product_id': shopperProductCherry,
              },
            },
          ),
        ),
        withLine(
          shopperLineJson(
            status: 'purchased',
            patch: <String, Object?>{
              'purchase': <String, Object?>{
                ...(shopperLineJson(status: 'purchased')['purchase']!
                    as Map<String, Object?>),
                'billable_unit_price_uzs': 0,
              },
            },
          ),
        ),
        withLine(
          shopperLineJson(
            status: 'purchased',
            patch: <String, Object?>{
              'purchase': <String, Object?>{
                ...(shopperLineJson(status: 'purchased')['purchase']!
                    as Map<String, Object?>),
                'purchased_quantity': '2',
              },
            },
          ),
        ),
        withLine(
          shopperLineJson(
            status: 'purchased',
            patch: <String, Object?>{
              'purchase': <String, Object?>{
                ...(shopperLineJson(status: 'purchased')['purchase']!
                    as Map<String, Object?>),
                'billable_quantity': '2',
              },
            },
          ),
        ),
        withLine(
          shopperLineJson(
            status: 'purchased',
            patch: <String, Object?>{
              'purchase': <String, Object?>{
                ...(shopperLineJson(status: 'purchased')['purchase']!
                    as Map<String, Object?>),
                'line_total_uzs': -1,
              },
            },
          ),
        ),
      ]) {
        expect(
          () => ShopperOrdersApi.parseOrder(broken),
          throwsFormatException,
          reason: '$broken',
        );
      }
    });
  });

  group('requests', () {
    late FakeHttpClientAdapter adapter;
    late ShopperOrdersRepositoryImpl repository;
    Object? pageAnswer;
    Object? orderAnswer;

    setUp(() {
      pageAnswer = null;
      orderAnswer = null;
      adapter = FakeHttpClientAdapter((RequestOptions options) {
        return switch (options.path) {
          '/shopper/orders' => jsonReply(
            200,
            pageAnswer ??
                pageJson(<Object?>[
                  shopperRowJson(),
                ], page: options.queryParameters['page']! as int),
          ),
          _ => jsonReply(200, <String, Object?>{
            'data': orderAnswer ?? shopperOrderJson(),
          }),
        };
      });
      repository = ShopperOrdersRepositoryImpl(
        ShopperOrdersApi(dioWith(adapter)),
      );
    });

    test(
      'every request goes on the staff session, with its verb and path',
      () async {
        await repository.orders(2);
        await repository.order(shopperOrderA.toUpperCase());
        orderAnswer = shopperOrderJson(accepted: true);
        await repository.accept(shopperOrderA);
        orderAnswer = shopperOrderJson(status: 'shopping');
        await repository.start(shopperOrderA);

        expect(
          adapter.requests.map((RequestOptions o) => '${o.method} ${o.path}'),
          <String>[
            'GET /shopper/orders',
            'GET /shopper/orders/${shopperOrderA.toUpperCase()}',
            'POST /shopper/orders/$shopperOrderA/accept',
            'POST /shopper/orders/$shopperOrderA/start',
          ],
        );
        expect(adapter.requests.first.queryParameters, <String, Object>{
          'page': 2,
        });
        for (final RequestOptions request in adapter.requests) {
          expect(
            RequestSlot.resolve(request, () => SessionSlot.customer),
            SessionSlot.staff,
            reason: request.path,
          );
        }
        expect(
          adapter.requests.skip(2).map((RequestOptions o) => o.data),
          <Object?>[null, null],
        );
      },
    );

    test('an answer to another question, or without the action, is '
        'malformed', () async {
      pageAnswer = pageJson(<Object?>[shopperRowJson()], page: 3);
      await expectLater(
        repository.orders(1),
        throwsA(isA<MalformedResponseFailure>()),
      );

      orderAnswer = shopperOrderJson(id: shopperOrderB);
      await expectLater(
        repository.order(shopperOrderA),
        throwsA(isA<MalformedResponseFailure>()),
      );

      orderAnswer = shopperOrderJson();
      await expectLater(
        repository.accept(shopperOrderA),
        throwsA(isA<MalformedResponseFailure>()),
      );

      // A start answered by an order not shopping, or not started.
      for (final Map<String, Object?> answer in <Map<String, Object?>>[
        shopperOrderJson(accepted: true),
        <String, Object?>{
          ...shopperOrderJson(accepted: true),
          'assignment': shopperAssignmentJson(started: true),
          'can_start': false,
        },
        <String, Object?>{
          ...shopperOrderJson(status: 'shopping'),
          'assignment': shopperAssignmentJson(accepted: true),
        },
      ]) {
        orderAnswer = answer;
        await expectLater(
          repository.start(shopperOrderA),
          throwsA(isA<MalformedResponseFailure>()),
          reason: '$answer',
        );
      }
    });

    test('each action at the market sends its body, the purchase and the '
        'completion their key', () async {
      orderAnswer = shopperOrderJson(
        status: 'shopping',
        items: <Object?>[
          shopperLineJson(status: 'purchased'),
          shopperLineJson(bread: true),
        ],
      );
      await repository.purchase(
        shopperOrderA,
        shopperLineTomato,
        const PurchaseEntry(
          quantity: '2',
          actualMarketPriceUzs: 16500,
          productId: null,
        ),
        'key-1',
      );
      await repository.purchase(
        shopperOrderA,
        shopperLineTomato,
        const PurchaseEntry(
          quantity: '2.000',
          actualMarketPriceUzs: null,
          productId: shopperProductTomato,
        ),
        'key-2',
      );
      orderAnswer = shopperOrderJson(
        status: 'shopping',
        items: <Object?>[
          shopperLineJson(status: 'removed'),
          shopperLineJson(bread: true),
        ],
      );
      await repository.markUnavailable(shopperOrderA, shopperLineTomato, null);
      await repository.markUnavailable(
        shopperOrderA,
        shopperLineTomato,
        'Qolmagan',
      );
      orderAnswer = shopperOrderJson(
        status: 'shopping',
        items: <Object?>[shopperAskedLineJson('price_over_tolerance')],
      );
      await repository.askAboutPrice(
        shopperOrderA,
        shopperLineTomato,
        22000,
        shopperProductCherry,
        'Narx oshgan',
      );
      orderAnswer = shopperOrderJson(
        status: 'shopping',
        items: <Object?>[
          shopperLineJson(
            patch: <String, Object?>{'replacement': shopperReplacementJson()},
          ),
        ],
      );
      await repository.substitute(
        shopperOrderA,
        shopperLineTomato,
        shopperProductCherry,
        15500,
        null,
      );
      orderAnswer = shopperOrderJson(
        status: 'shopping',
        items: <Object?>[shopperAskedLineJson('reduced_quantity')],
      );
      await repository.askAboutQuantity(
        shopperOrderA,
        shopperLineTomato,
        '1.5',
        null,
      );
      orderAnswer = <String, Object?>{
        ...shopperOrderJson(status: 'ready_for_delivery'),
        'assignment': shopperAssignmentJson(accepted: true, started: true),
        'can_accept': false,
        'can_start': false,
      };
      await repository.complete(shopperOrderA, 'key-3');

      const String line =
          '/shopper/orders/$shopperOrderA/items/$shopperLineTomato';
      expect(
        adapter.requests.map(
          (RequestOptions o) => '${o.method} ${o.path} ${o.data}',
        ),
        <String>[
          'POST $line/purchase {purchased_quantity: 2, actual_market_price_uzs: 16500}',
          'POST $line/purchase '
              '{purchased_quantity: 2.000, fulfilled_product_id: $shopperProductTomato}',
          'POST $line/unavailable {}',
          'POST $line/unavailable {note: Qolmagan}',
          'POST $line/price-approval {actual_market_price_uzs: 22000, '
              'fulfilled_product_id: $shopperProductCherry, note: Narx oshgan}',
          'POST $line/substitution {replacement_product_id: $shopperProductCherry, '
              'actual_market_price_uzs: 15500}',
          'POST $line/reduced-quantity-approval {proposed_quantity: 1.5}',
          'POST /shopper/orders/$shopperOrderA/complete null',
        ],
      );
      final List<Object?> keys = <Object?>[
        for (final RequestOptions o in adapter.requests)
          o.headers['Idempotency-Key'],
      ];
      expect(keys, <Object?>[
        'key-1',
        'key-2',
        null,
        null,
        null,
        null,
        null,
        'key-3',
      ]);
    });

    test(
      'an action\'s answer that does not show it done is malformed',
      () async {
        // The order as it was: the tomatoes still to buy, nothing asked.
        orderAnswer = shopperOrderJson(status: 'shopping');
        for (final Future<ShopperOrder> Function() action
            in <Future<ShopperOrder> Function()>[
              () => repository.purchase(
                shopperOrderA,
                shopperLineTomato,
                const PurchaseEntry(
                  quantity: '2',
                  actualMarketPriceUzs: 16500,
                  productId: null,
                ),
                'key',
              ),
              () => repository.markUnavailable(
                shopperOrderA,
                shopperLineTomato,
                null,
              ),
              () => repository.askAboutPrice(
                shopperOrderA,
                shopperLineTomato,
                22000,
                null,
                null,
              ),
              () => repository.substitute(
                shopperOrderA,
                shopperLineTomato,
                shopperProductCherry,
                15500,
                null,
              ),
              () => repository.askAboutQuantity(
                shopperOrderA,
                shopperLineTomato,
                '1.5',
                null,
              ),
              () => repository.complete(shopperOrderA, 'key'),
            ]) {
          await expectLater(action(), throwsA(isA<MalformedResponseFailure>()));
        }

        // A question of another kind than the one asked.
        orderAnswer = shopperOrderJson(
          status: 'shopping',
          items: <Object?>[shopperAskedLineJson('reduced_quantity')],
        );
        await expectLater(
          repository.askAboutPrice(
            shopperOrderA,
            shopperLineTomato,
            22000,
            null,
            null,
          ),
          throwsA(isA<MalformedResponseFailure>()),
        );
        // Another line done than the one acted on.
        orderAnswer = shopperOrderJson(
          status: 'shopping',
          items: <Object?>[
            shopperLineJson(),
            shopperLineJson(bread: true, status: 'purchased'),
          ],
        );
        await expectLater(
          repository.purchase(
            shopperOrderA,
            shopperLineTomato,
            const PurchaseEntry(
              quantity: '2',
              actualMarketPriceUzs: 1,
              productId: null,
            ),
            'key',
          ),
          throwsA(isA<MalformedResponseFailure>()),
        );
      },
    );

    test('a substitution asked of the Customer, and a completion replayed '
        'after a Courier was assigned, are answers of their own', () async {
      orderAnswer = shopperOrderJson(
        status: 'shopping',
        items: <Object?>[shopperAskedLineJson('substitution')],
      );
      final ShopperOrder asked = await repository.substitute(
        shopperOrderA,
        shopperLineTomato,
        shopperProductCherry,
        15500,
        null,
      );
      expect(asked.items.single.openQuestion?.type, ApprovalType.substitution);

      orderAnswer = <String, Object?>{
        ...shopperOrderJson(status: 'delivery_assigned'),
        'assignment': shopperAssignmentJson(accepted: true, started: true),
        'can_accept': false,
        'can_start': false,
      };
      final ShopperOrder replayed = await repository.complete(
        shopperOrderA,
        'key',
      );
      expect(replayed.status, OrderStatus.deliveryAssigned);

      // An order still being shopped, or one without the assignment that
      // shopped it, is no completion.
      for (final Map<String, Object?> answer in <Map<String, Object?>>[
        shopperOrderJson(status: 'shopping'),
        <String, Object?>{
          ...shopperOrderJson(status: 'ready_for_delivery'),
          'assignment': null,
          'can_accept': false,
          'can_start': false,
        },
        <String, Object?>{
          ...shopperOrderJson(status: 'ready_for_delivery', accepted: true),
          'can_start': false,
        },
      ]) {
        orderAnswer = answer;
        await expectLater(
          repository.complete(shopperOrderA, 'key'),
          throwsA(isA<MalformedResponseFailure>()),
          reason: '$answer',
        );
      }
    });

    test('the replacement search asks for its page, and its term only when '
        'there is one', () async {
      pageAnswer = null;
      final FakeHttpClientAdapter search = FakeHttpClientAdapter(
        (RequestOptions options) => jsonReply(
          200,
          pageJson(<Object?>[
            shopperChoiceJson(),
          ], page: options.queryParameters['page']! as int),
        ),
      );
      final ShopperOrdersRepositoryImpl choices = ShopperOrdersRepositoryImpl(
        ShopperOrdersApi(dioWith(search)),
      );

      final Paged<ReplacementChoice> first = await choices.replacements(
        shopperOrderA,
        shopperLineTomato,
        '',
        1,
      );
      await choices.replacements(shopperOrderA, shopperLineTomato, 'olcha', 2);

      expect(first.items.single.marketPriceUzs, 15500);
      expect(
        search.requests.map((RequestOptions o) => o.queryParameters),
        <Map<String, Object?>>[
          <String, Object?>{'page': 1},
          <String, Object?>{'page': 2, 'search': 'olcha'},
        ],
      );
      expect(
        search.requests.first.path,
        '/shopper/orders/$shopperOrderA/items/$shopperLineTomato/replacements',
      );
      for (final Map<String, Object?> broken in <Map<String, Object?>>[
        shopperChoiceJson(price: 0),
        <String, Object?>{...shopperChoiceJson(), 'unit_code': 'tonne'},
        without(shopperChoiceJson(), 'market_price_uzs'),
      ]) {
        expect(
          () => ShopperOrdersApi.parseChoice(broken),
          throwsFormatException,
          reason: '$broken',
        );
      }
    });

    test('a page parses', () async {
      final Paged<ShopperOrderRow> page = await repository.orders(1);
      expect(page.items.single.id, shopperOrderA);
    });
  });
}
