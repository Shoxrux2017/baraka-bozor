import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/quantity_rules.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/features/orders/application/customer_orders_controllers.dart';
import 'package:baraka_bozor/features/orders/application/order_draft.dart';
import 'package:baraka_bozor/features/orders/application/order_edit_summary.dart';
import 'package:baraka_bozor/features/orders/domain/customer_orders.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_catalog_repository.dart';
import '../../../support/fake_customer_orders_repository.dart';

const Duration _quiet = Duration(milliseconds: 400);

/// The sums of an edit whose goods are the first line's quantity in
/// thousandths, so a test reads which draft an answer belongs to.
Map<String, Object?> _byFirstQuantity(String id, List<OrderEditLine> lines) =>
    editPreviewJson(
      merchandise: QuantityRules.thousandths(lines.first.quantity),
    );

Future<ProviderContainer> _open(
  WidgetTester tester,
  FakeCustomerOrdersRepository orders,
) async {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      customerAccountProvider.overrideWith((Ref ref) => 'customer-a'),
      customerOrdersRepositoryProvider.overrideWithValue(orders),
    ],
  );
  addTearDown(container.dispose);
  container.listen(customerOrderProvider(orderOne), (_, _) {});
  await container.read(customerOrderProvider(orderOne).future);
  container.listen(orderDraftProvider(orderOne), (_, _) {});
  container.listen(orderEditSummaryProvider(orderOne), (_, _) {});
  await tester.pump();
  return container;
}

OrderDraftController _draft(ProviderContainer container) =>
    container.read(orderDraftProvider(orderOne).notifier);

EditSummary _summary(ProviderContainer container) =>
    container.read(orderEditSummaryProvider(orderOne));

void main() {
  testWidgets('nothing changed sends nothing and shows the order\'s sums', (
    WidgetTester tester,
  ) async {
    final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository();
    final ProviderContainer container = await _open(tester, orders);

    expect(_summary(container).waiting, isFalse);
    expect(_summary(container).shown.totalUzs, 55600);

    // Up and down again: the lines are the order's once more.
    _draft(container).step(lineTomato, up: true);
    expect(_summary(container).waiting, isTrue);
    _draft(container).step(lineTomato, up: false);
    await tester.pump(_quiet);

    expect(orders.previewCalls, isEmpty);
    expect(_summary(container).waiting, isFalse);
    expect(_summary(container).failed, isFalse);
    expect(_summary(container).shown.totalUzs, 55600);
    expect(_summary(container).shown.totalChangeUzs, 0);
  });

  testWidgets('a change waits 400 ms, then one preview', (
    WidgetTester tester,
  ) async {
    final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository()
      ..previews = _byFirstQuantity;
    final ProviderContainer container = await _open(tester, orders);

    _draft(container).step(lineTomato, up: true);
    await tester.pump(const Duration(milliseconds: 399));
    expect(orders.previewCalls, isEmpty);
    expect(_summary(container).waiting, isTrue);

    await tester.pump(const Duration(milliseconds: 1));
    expect(orders.previewCalls, hasLength(1));
    expect(orders.previewCalls.single.$1, orderOne);
    expect(orders.previewCalls.single.$2.first.quantity, '2');
    expect(_summary(container).waiting, isFalse);
    expect(_summary(container).shown.merchandiseSubtotalUzs, 2000);
  });

  testWidgets('one preview at a time, the latest draft wins', (
    WidgetTester tester,
  ) async {
    final Completer<void> hold = Completer<void>();
    final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository()
      ..previews = _byFirstQuantity
      ..holdPreview = hold;
    final ProviderContainer container = await _open(tester, orders);

    _draft(container).step(lineTomato, up: true);
    await tester.pump(_quiet);
    expect(orders.previewCalls, hasLength(1));

    for (int step = 0; step < 4; step++) {
      _draft(container).step(lineTomato, up: true);
      await tester.pump(_quiet);
    }
    expect(orders.previewCalls, hasLength(1), reason: 'one at a time');

    hold.complete();
    await tester.pump();
    await tester.pump();

    expect(orders.previewCalls, hasLength(2));
    expect(orders.previewCalls.last.$2.first.quantity, '4');
    expect(_summary(container).waiting, isFalse);
    expect(_summary(container).shown.merchandiseSubtotalUzs, 4000);
  });

  testWidgets('an older answer landing late is dropped', (
    WidgetTester tester,
  ) async {
    final Completer<void> hold = Completer<void>();
    final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository()
      ..previews = _byFirstQuantity
      ..holdPreview = hold;
    final ProviderContainer container = await _open(tester, orders);

    _draft(container).step(lineTomato, up: true);
    await tester.pump(_quiet);
    _draft(container).step(lineTomato, up: true);

    hold.complete();
    await tester.pump();

    expect(
      _summary(container).shown.merchandiseSubtotalUzs,
      35600,
      reason: 'the answer to the first draft is not shown',
    );
    expect(_summary(container).waiting, isTrue);

    await tester.pump(_quiet);
    expect(orders.previewCalls, hasLength(2));
    expect(_summary(container).shown.merchandiseSubtotalUzs, 2500);
    expect(_summary(container).waiting, isFalse);
  });

  testWidgets('a failed preview clears the shortfall block', (
    WidgetTester tester,
  ) async {
    final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository()
      ..previews = (String id, List<OrderEditLine> lines) =>
          editPreviewJson(shortfall: 4000);
    final ProviderContainer container = await _open(tester, orders);

    _draft(container).step(lineTomato, up: true);
    await tester.pump(_quiet);
    expect(_summary(container).shortfallUzs, 4000);

    orders.previewFailure = const NetworkFailure();
    _draft(container).step(lineTomato, up: true);
    await tester.pump(_quiet);

    expect(_summary(container).failed, isTrue);
    expect(_summary(container).waiting, isFalse);
    expect(_summary(container).shortfallUzs, 0);
    expect(_summary(container).shown.minimumShortfallUzs, 4000);

    _draft(container).step(lineTomato, up: true);
    await tester.pump(_quiet);
    expect(_summary(container).failed, isFalse);
    expect(_summary(container).shortfallUzs, 4000);
  });

  testWidgets('product_unavailable marks the products and an accepted answer '
      'clears them', (WidgetTester tester) async {
    final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository()
      ..previewFailure = ApiRefusal(
        ApiError(
          status: 422,
          code: 'product_unavailable',
          details: <String, Object?>{
            'product_ids': <Object?>[productTomato.toUpperCase()],
          },
        ),
      );
    final ProviderContainer container = await _open(tester, orders);

    _draft(container).step(lineBread, up: true);
    await tester.pump(_quiet);

    final OrderDraft marked = container.read(orderDraftProvider(orderOne));
    expect(marked.marked.map((DraftLine line) => line.key), <String>[
      lineTomato,
    ]);
    expect(_summary(container).failed, isTrue);
    expect(_summary(container).locked, isFalse);
    final int version = marked.version;

    _draft(container).remove(lineTomato);
    await tester.pump(_quiet);

    final OrderDraft after = container.read(orderDraftProvider(orderOne));
    expect(after.marked, isEmpty);
    expect(after.version, version + 1, reason: 'marks never bump it');
    expect(_summary(container).failed, isFalse);
  });

  testWidgets('order_editing_locked locks and reloads the order', (
    WidgetTester tester,
  ) async {
    final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository()
      ..previewFailure = const ApiRefusal(
        ApiError(status: 409, code: 'order_editing_locked'),
      );
    final ProviderContainer container = await _open(tester, orders);
    container.listen(customerOrdersProvider(OrdersTab.current), (_, _) {});
    await tester.pump();
    final int orderLoads = orders.loads
        .where((String load) => load.startsWith('order:'))
        .length;
    final int listLoads = orders.loads
        .where((String load) => load.startsWith('orders:'))
        .length;

    int? loadsWhenLocked;
    bool? lockedSeen;
    container.listen(orderEditSummaryProvider(orderOne), (_, EditSummary next) {
      if (next.locked && lockedSeen == null) {
        lockedSeen = true;
        loadsWhenLocked = orders.loads
            .where((String load) => load.startsWith('order:'))
            .length;
      }
    });

    _draft(container).step(lineTomato, up: true);
    await tester.pump(_quiet);
    await tester.pump();

    expect(lockedSeen, isTrue);
    expect(
      loadsWhenLocked,
      orderLoads,
      reason: 'the lock is seen before the order reloads',
    );
    expect(_summary(container).locked, isTrue);
    expect(
      orders.loads.where((String load) => load.startsWith('order:')).length,
      orderLoads + 1,
    );
    expect(
      orders.loads.where((String load) => load.startsWith('orders:')).length,
      greaterThan(listLoads),
    );
  });

  testWidgets('a draft with a quantity to set anew is not priced', (
    WidgetTester tester,
  ) async {
    final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository(
      orders: <Map<String, Object?>>[
        customerOrderJson(
          lines: <Object?>[
            orderLineJson(),
            orderLineJson(
              id: lineBread,
              productId: productBread,
              unit: 'piece',
              quantity: '1.500',
            ),
          ],
        ),
      ],
    );
    final ProviderContainer container = await _open(tester, orders);
    expect(
      container.read(orderDraftProvider(orderOne)).lines.last.quantityValid,
      isFalse,
    );

    _draft(container).step(lineTomato, up: true);
    await tester.pump(_quiet);

    expect(orders.previewCalls, isEmpty);
    expect(_summary(container).failed, isTrue);
    expect(_summary(container).waiting, isFalse);
    expect(_summary(container).shortfallUzs, 0);
  });

  testWidgets('a save\'s minimum refusal shows its shortfall until the next '
      'answer', (WidgetTester tester) async {
    final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository();
    final ProviderContainer container = await _open(tester, orders);

    container
        .read(orderEditSummaryProvider(orderOne).notifier)
        .refusedMinimum(minimumUzs: 50000, shortfallUzs: 4400);

    expect(_summary(container).shortfallUzs, 4400);
    expect(_summary(container).shown.minimumOrderUzs, 50000);

    _draft(container).step(lineTomato, up: true);
    await tester.pump(_quiet);

    expect(orders.previewCalls, hasLength(1));
    expect(_summary(container).shortfallUzs, 0);
  });

  testWidgets('a refused minimum stays shown while the preview has failed', (
    WidgetTester tester,
  ) async {
    final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository()
      ..previewFailure = const NetworkFailure();
    final ProviderContainer container = await _open(tester, orders);

    _draft(container).step(lineTomato, up: true);
    await tester.pump(_quiet);
    expect(_summary(container).failed, isTrue);
    expect(_summary(container).shortfallUzs, 0);

    container
        .read(orderEditSummaryProvider(orderOne).notifier)
        .refusedMinimum(minimumUzs: 50000, shortfallUzs: 15000);

    expect(_summary(container).failed, isTrue);
    expect(_summary(container).shortfallUzs, 15000);

    // The next failure clears it.
    orders.previewFailure = const NetworkFailure();
    _draft(container).step(lineTomato, up: true);
    await tester.pump(_quiet);
    expect(_summary(container).failed, isTrue);
    expect(_summary(container).shortfallUzs, 0);
  });

  testWidgets("the order reloading as the draft brings the order's sums back", (
    WidgetTester tester,
  ) async {
    final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository()
      ..previews = (String id, List<OrderEditLine> lines) =>
          editPreviewJson(merchandise: 42600, total: 62600, change: 7000);
    final ProviderContainer container = await _open(tester, orders);

    _draft(container).step(lineTomato, up: true);
    await tester.pump(_quiet);
    expect(_summary(container).shown.totalChangeUzs, 7000);

    // The save went through and its answer was lost: the order reloads
    // holding what the draft holds.
    orders.rows = <Map<String, Object?>>[
      customerOrderJson(
        lines: <Object?>[
          orderLineJson(quantity: '2.000'),
          orderLineJson(
            id: lineBread,
            productId: productBread,
            unit: 'piece',
            quantity: '2',
          ),
        ],
      ),
    ];
    container.invalidate(customerOrderProvider(orderOne));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));

    expect(_summary(container).shown.totalChangeUzs, 0);
    expect(_summary(container).shown.totalUzs, 55600);
    expect(_summary(container).waiting, isFalse);
    expect(_summary(container).failed, isFalse);
  });

  testWidgets(
    'a draft of more than 100 lines is not priced and sends nothing',
    (WidgetTester tester) async {
      String id(int group, int i) =>
          '0192f0a0-0000-7000-800$group-${i.toString().padLeft(12, '0')}';
      final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository(
        orders: <Map<String, Object?>>[
          customerOrderJson(
            lines: <Object?>[
              for (int i = 0; i < orderMaxLines; i++)
                orderLineJson(
                  id: id(1, i),
                  productId: id(2, i),
                  unit: 'piece',
                  quantity: '1',
                ),
            ],
          ),
        ],
      );
      final ProviderContainer container = await _open(tester, orders);

      _draft(container).add(catalogProduct(id: productMilk));
      await tester.pump(_quiet);

      expect(orders.previewCalls, isEmpty);
      expect(_summary(container).failed, isTrue);
      expect(_summary(container).waiting, isFalse);
    },
  );
}
