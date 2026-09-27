import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/auth_interceptor.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/cart/data/cart_api.dart';
import 'package:baraka_bozor/features/cart/domain/cart.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_cart_repository.dart';
import '../../../support/fake_http_client_adapter.dart';

/// The cart's data source against `docs/09-api-contracts.md` section 17.
void main() {
  group('parsing', () {
    test('lines in both units, available or not', () {
      final Cart cart = CartApi.parseCart(
        cartJson(<Map<String, Object?>>[
          cartLineJson(note: 'Qizilini oling'),
          cartLineJson(
            id: breadLine,
            productId: breadProduct,
            unit: 'piece',
            quantity: '2',
            priceMode: 'fixed',
            available: false,
          ),
        ], subtotal: 27600),
      );

      expect(cart.itemCount, 2);
      expect(cart.estimatedSubtotalUzs, 27600);
      final CartLine tomato = cart.lines.first;
      expect(tomato.unit, UnitCode.kg);
      expect(tomato.quantity, '1.500');
      expect(tomato.customerNote, 'Qizilini oling');
      expect(tomato.substitutionPolicy, SubstitutionPolicy.allowSimilar);
      final CartLine bread = cart.lines.last;
      expect(bread.isAvailable, isFalse);
      expect(bread.customerUnitPriceUzs, isNull);
      expect(bread.quantity, '2');
    });

    test('a line whose product became a whole unit keeps its decimals', () {
      final CartLine line = CartApi.parseLine(
        cartLineJson(unit: 'piece', quantity: '1.500'),
      );
      expect(line.quantity, '1.500');
    });

    test('a cart off the contract is refused', () {
      final Map<String, Object?> priced = cartLineJson();
      for (final Map<String, Object?> broken in <Map<String, Object?>>[
        <String, Object?>{
          ...cartJson(<Map<String, Object?>>[priced]),
          'item_count': 2,
        },
        cartJson(<Map<String, Object?>>[
          <String, Object?>{...priced, 'customer_unit_price_uzs': null},
        ]),
        cartJson(<Map<String, Object?>>[
          <String, Object?>{
            ...cartLineJson(available: false),
            'estimated_line_total_uzs': 100,
          },
        ]),
        cartJson(<Map<String, Object?>>[
          <String, Object?>{...priced, 'quantity': '1.5'},
        ]),
        cartJson(<Map<String, Object?>>[
          <String, Object?>{...priced, 'quantity': '0.000'},
        ]),
        cartJson(<Map<String, Object?>>[
          <String, Object?>{...priced, 'substitution_policy': 'whatever'},
        ]),
        cartJson(<Map<String, Object?>>[], subtotal: -1),
      ]) {
        expect(
          () => CartApi.parseCart(broken),
          throwsFormatException,
          reason: '$broken',
        );
      }
    });
  });

  group('requests', () {
    late FakeHttpClientAdapter adapter;
    late CartRepositoryImpl repository;
    Map<String, Object?>? answer;

    setUp(() {
      answer = null;
      adapter = FakeHttpClientAdapter(
        (RequestOptions options) =>
            jsonReply(options.method == 'POST' ? 201 : 200, <String, Object?>{
              'data':
                  answer ??
                  cartJson(<Map<String, Object?>>[
                    cartLineJson(quantity: '2.000', note: 'Pishganini'),
                  ]),
            }),
      );
      repository = CartRepositoryImpl(CartApi(dioWith(adapter)));
    });

    CartLine line() => CartApi.parseLine(cartLineJson());

    test(
      'each call on the Customer session, with its verb, path and body',
      () async {
        await repository.cart();
        await repository.add(
          const NewCartLine(
            productId: tomatoProduct,
            quantity: '2',
            customerNote: null,
            substitutionPolicy: SubstitutionPolicy.contactBefore,
          ),
        );
        await repository.change(
          tomatoLine,
          CartLinePatch.between(
            line(),
            quantity: '2',
            customerNote: 'Pishganini',
            substitutionPolicy: SubstitutionPolicy.allowSimilar,
          ),
        );
        answer = cartJson(<Map<String, Object?>>[]);
        await repository.remove(tomatoLine);

        expect(
          adapter.requests.map((RequestOptions o) => '${o.method} ${o.path}'),
          <String>[
            'GET /customer/cart',
            'POST /customer/cart/items',
            'PATCH /customer/cart/items/$tomatoLine',
            'DELETE /customer/cart/items/$tomatoLine',
          ],
        );
        expect(adapter.requests[1].data, <String, Object?>{
          'product_id': tomatoProduct,
          'quantity': '2',
          'customer_note': null,
          'substitution_policy': 'contact_before_substitution',
        });
        expect(adapter.requests[2].data, <String, Object?>{
          'quantity': '2',
          'customer_note': 'Pishganini',
        }, reason: 'only what changed; the rule did not');
        for (final RequestOptions request in adapter.requests) {
          expect(
            RequestSlot.resolve(request, () => SessionSlot.staff),
            SessionSlot.customer,
          );
        }
      },
    );

    test('a change that clears the note sends it as null', () async {
      answer = cartJson(<Map<String, Object?>>[cartLineJson()]);
      await repository.change(
        tomatoLine,
        CartLinePatch.between(
          CartApi.parseLine(cartLineJson(note: 'Eski')),
          quantity: '1.5',
          customerNote: null,
          substitutionPolicy: SubstitutionPolicy.allowSimilar,
        ),
      );

      expect(adapter.requests.single.data, <String, Object?>{
        'customer_note': null,
      });
    });

    test('an answer that does not show the change is malformed', () async {
      answer = cartJson(<Map<String, Object?>>[]);
      await expectLater(
        repository.add(
          const NewCartLine(
            productId: tomatoProduct,
            quantity: '1',
            customerNote: null,
            substitutionPolicy: SubstitutionPolicy.allowSimilar,
          ),
        ),
        throwsA(isA<MalformedResponseFailure>()),
      );

      answer = cartJson(<Map<String, Object?>>[cartLineJson()]);
      await expectLater(
        repository.change(
          tomatoLine,
          CartLinePatch.between(
            line(),
            quantity: '3',
            customerNote: null,
            substitutionPolicy: SubstitutionPolicy.allowSimilar,
          ),
        ),
        throwsA(isA<MalformedResponseFailure>()),
      );

      answer = cartJson(<Map<String, Object?>>[cartLineJson()]);
      await expectLater(
        repository.remove(tomatoLine),
        throwsA(isA<MalformedResponseFailure>()),
      );
    });
  });

  test('a patch holds only what differs, and amounts compare as amounts', () {
    final CartLine line = CartApi.parseLine(cartLineJson(note: 'Eski'));

    expect(
      CartLinePatch.between(
        line,
        quantity: '1.5',
        customerNote: 'Eski',
        substitutionPolicy: SubstitutionPolicy.allowSimilar,
      ).isEmpty,
      isTrue,
    );
    final CartLinePatch patch = CartLinePatch.between(
      line,
      quantity: '1.5',
      customerNote: 'Eski',
      substitutionPolicy: SubstitutionPolicy.removeIfUnavailable,
    );
    expect(patch.quantity, isNull);
    expect(patch.noteChanged, isFalse);
    expect(patch.substitutionPolicy, SubstitutionPolicy.removeIfUnavailable);
  });
}
