import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/orders/application/customer_orders_controllers.dart';
import 'package:baraka_bozor/features/orders/application/order_draft.dart';
import 'package:baraka_bozor/features/orders/domain/customer_orders.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_catalog_repository.dart';
import '../../../support/fake_customer_orders_repository.dart';

// The wish the order holds: no change when the editor sends it back.
const String _wish = 'Kechqurun';

final CatalogProduct _carrot = catalogProduct(
  id: 'p-carrot',
  nameUz: 'Sabzi',
  nameRu: 'Морковь',
);

CatalogProduct _milk() =>
    catalogProduct(id: productMilk, unitCode: UnitCode.piece);

ProviderContainer _container(FakeCustomerOrdersRepository orders) =>
    ProviderContainer(
      overrides: [
        customerAccountProvider.overrideWith((Ref ref) => 'customer-a'),
        customerOrdersRepositoryProvider.overrideWithValue(orders),
      ],
    );

/// A container whose order [orderOne] has loaded, with the draft kept alive.
Future<ProviderContainer> _open(FakeCustomerOrdersRepository orders) async {
  final ProviderContainer container = _container(orders);
  container.listen(customerOrderProvider(orderOne), (_, _) {});
  await container.read(customerOrderProvider(orderOne).future);
  container.listen(orderDraftProvider(orderOne), (_, _) {});
  return container;
}

OrderDraftController _controller(ProviderContainer container) =>
    container.read(orderDraftProvider(orderOne).notifier);

OrderDraft _draft(ProviderContainer container) =>
    container.read(orderDraftProvider(orderOne));

CustomerOrder _order(ProviderContainer container) =>
    container.read(customerOrderProvider(orderOne)).requireValue;

void main() {
  test('a draft built before the order has loaded says so', () {
    final ProviderContainer container = _container(
      FakeCustomerOrdersRepository(),
    );
    addTearDown(container.dispose);

    expect(
      () => container.read(orderDraftProvider(orderOne)),
      throwsA(predicate((Object e) => e.toString().contains('has not loaded'))),
    );
  });

  test('a step, a removal and a restore change the lines and bump the '
      'version', () async {
    final ProviderContainer container = await _open(
      FakeCustomerOrdersRepository(),
    );
    addTearDown(container.dispose);

    expect(_draft(container).version, 0);
    expect(_draft(container).lines.map((DraftLine line) => line.key), <String>[
      lineTomato,
      lineBread,
    ]);

    _controller(container).step(lineTomato, up: true);
    expect(_draft(container).lines.first.quantity, '2');
    expect(_draft(container).version, 1);

    _controller(container).remove(lineBread);
    expect(_draft(container).kept.map((DraftLine line) => line.key), <String>[
      lineTomato,
    ]);
    expect(_draft(container).lines.last.removed, isTrue);
    expect(_draft(container).version, 2);

    _controller(container).restore(lineBread);
    expect(_draft(container).kept, hasLength(2));
    expect(_draft(container).version, 3);

    _controller(container).setQuantity(lineTomato, '2.250');
    _controller(container).setOptions(lineTomato, (
      quantity: '2.250',
      note: 'Ripe',
      policy: SubstitutionPolicy.contactBefore,
    ));
    final DraftLine tomato = _draft(container).lines.first;
    expect(tomato.quantity, '2.250');
    expect(tomato.note, 'Ripe');
    expect(tomato.policy, SubstitutionPolicy.contactBefore);
    expect(tomato.toEdit().customerNote, 'Ripe');
    expect(tomato.previewUzs, isNotNull);
    expect(_draft(container).version, 5);
  });

  test('the minus at the minimum removes an ordered line and drops an added '
      'one', () async {
    final ProviderContainer container = await _open(
      FakeCustomerOrdersRepository(),
    );
    addTearDown(container.dispose);

    _controller(container).step(lineBread, up: false);
    expect(_draft(container).lines.last.quantity, '1');
    _controller(container).step(lineBread, up: false);
    expect(_draft(container).lines.last.removed, isTrue);
    expect(_draft(container).lines, hasLength(2));

    final DraftLine added = _controller(container).add(_milk());
    expect(added.added, isTrue);
    expect(added.quantity, '1');
    _controller(container).step(added.key, up: false);
    expect(_draft(container).lines, hasLength(2));
    expect(
      _draft(container).lines.any((DraftLine line) => line.key == added.key),
      isFalse,
    );
  });

  test('adding a product already in the order keeps its line', () async {
    final ProviderContainer container = await _open(
      FakeCustomerOrdersRepository(),
    );
    addTearDown(container.dispose);

    _controller(container).remove(lineTomato);
    final int before = _draft(container).version;
    final DraftLine again = _controller(container)
        .add(catalogProduct(id: productTomato.toUpperCase()));

    expect(again.key, lineTomato);
    expect(again.added, isFalse);
    expect(_draft(container).lines, hasLength(2));
    expect(_draft(container).lines.first.removed, isFalse);
    expect(_draft(container).version, greaterThan(before));

    final int settled = _draft(container).version;
    _controller(container).add(catalogProduct(id: productTomato));
    expect(_draft(container).version, settled, reason: 'nothing changed');
  });

  test('lines added while arriving are held until settled', () async {
    final ProviderContainer container = await _open(
      FakeCustomerOrdersRepository(),
    );
    addTearDown(container.dispose);

    final DraftLine carrot = _controller(container)
        .add(_carrot, arriving: true);
    final DraftLine milk = _controller(container).add(_milk(), arriving: true);
    _controller(container)
        .add(catalogProduct(id: 'p-salt', unitCode: UnitCode.piece));
    expect(_draft(container).arriving, <String>{carrot.key, milk.key});

    _controller(container).remove(milk.key);
    expect(_draft(container).arriving, <String>{carrot.key});

    final int version = _draft(container).version;
    expect(_controller(container).settleArrivals(), <String>[carrot.key]);
    expect(_draft(container).arriving, isEmpty);
    expect(_draft(container).version, version);
    expect(_controller(container).settleArrivals(), isEmpty);
  });

  test('marks follow the latest answer and do not bump the version', () async {
    final ProviderContainer container = await _open(
      FakeCustomerOrdersRepository(),
    );
    addTearDown(container.dispose);

    _controller(container).step(lineTomato, up: true);
    final int version = _draft(container).version;

    _controller(container).setUnavailable(<String>{productTomato});
    expect(_draft(container).marked.map((DraftLine line) => line.key), <String>[
      lineTomato,
    ]);
    expect(_draft(container).version, version);

    _controller(container).setUnavailable(<String>{productBread});
    expect(_draft(container).marked.map((DraftLine line) => line.key), <String>[
      lineBread,
    ]);

    _controller(container).removeMarked();
    expect(_draft(container).marked, isEmpty);
    expect(_draft(container).kept.map((DraftLine line) => line.key), <String>[
      lineTomato,
    ]);
    expect(_draft(container).version, version + 1);

    _controller(container).setUnavailable(<String>{});
    expect(_draft(container).version, version + 1);
  });

  test(
    'changes list added, removed, quantity, note, rule and wish in order',
    () async {
      final ProviderContainer container = await _open(
        FakeCustomerOrdersRepository(),
      );
      addTearDown(container.dispose);

      expect(
        draftChanges(_draft(container), _order(container), _wish),
        isEmpty,
      );
      expect(linesChange(_draft(container), _order(container)), isFalse);

      // The page's three: the tomatoes 1,5 -> 3, the bread out, a carrot in.
      _controller(container).setQuantity(lineTomato, '3');
      _controller(container).remove(lineBread);
      _controller(container).add(_carrot);

      final List<DraftChange> changes = draftChanges(
        _draft(container),
        _order(container),
        _wish,
      );
      expect(
        changes.map((DraftChange change) => change.kind),
        <DraftChangeKind>[
          DraftChangeKind.quantity,
          DraftChangeKind.removed,
          DraftChangeKind.added,
        ],
      );
      expect(changes[0].nameRu, 'Помидоры');
      expect(changes[0].unit, UnitCode.kg);
      expect(changes[0].from, '1.500');
      expect(changes[0].to, '3');
      expect(changes[1].nameRu, 'Хлеб');
      expect(changes[1].nameUz, 'Non');
      expect(changes[2].nameRu, 'Морковь');
      expect(changes[2].to, '1');
      expect(linesChange(_draft(container), _order(container)), isTrue);

      _controller(container).restore(lineBread);
      _controller(container).setOptions(lineBread, (
        quantity: '2',
        note: '  Fresh  ',
        policy: SubstitutionPolicy.removeIfUnavailable,
      ));
      final List<DraftChange> more = draftChanges(
        _draft(container),
        _order(container),
        'Soon',
      );
      expect(more.map((DraftChange change) => change.kind), <DraftChangeKind>[
        DraftChangeKind.quantity,
        DraftChangeKind.note,
        DraftChangeKind.rule,
        DraftChangeKind.added,
        DraftChangeKind.wish,
      ]);
      expect(more[1].to, 'Fresh');
      expect(more[2].rule, SubstitutionPolicy.removeIfUnavailable);
      expect(more.last.to, 'Soon');

      _controller(container).setOptions(lineBread, (
        quantity: '2',
        note: null,
        policy: SubstitutionPolicy.allowSimilar,
      ));
      // The order's wish is "Kechqurun": cleared reads as a removal.
      final List<DraftChange> cleared = draftChanges(
        _draft(container),
        _order(container),
        '  ',
      );
      expect(cleared.last.kind, DraftChangeKind.wish);
      expect(cleared.last.to, isNull);
      expect(
        draftChanges(
          _draft(container),
          _order(container),
          'Kechqurun',
        ).where((DraftChange change) => change.kind == DraftChangeKind.wish),
        isEmpty,
      );
    },
  );

  test('changes compare with the order as last loaded', () async {
    final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository();
    final ProviderContainer container = await _open(orders);
    addTearDown(container.dispose);

    _controller(container).add(_milk());
    expect(
      draftChanges(_draft(container), _order(container), _wish).single.kind,
      DraftChangeKind.added,
    );

    // The save's answer was lost: the order now holds the milk too.
    orders.rows = <Map<String, Object?>>[
      customerOrderJson(
        lines: <Object?>[
          orderLineJson(),
          orderLineJson(
            id: lineBread,
            productId: productBread,
            unit: 'piece',
            quantity: '2',
          ),
          orderLineJson(
            id: lineMilk,
            productId: productMilk,
            unit: 'piece',
            quantity: '1',
          ),
        ],
      ),
    ];
    await container.refresh(customerOrderProvider(orderOne).future);

    expect(draftChanges(_draft(container), _order(container), _wish), isEmpty);
    expect(linesChange(_draft(container), _order(container)), isFalse);

    _controller(container).remove(_draft(container).lines.last.key);
    final List<DraftChange> dropped = draftChanges(
      _draft(container),
      _order(container),
      _wish,
    );
    expect(dropped.single.kind, DraftChangeKind.removed);
    expect(
      _draft(container).lines,
      hasLength(2),
      reason: 'a reload never reseeds the draft',
    );
  });
}
