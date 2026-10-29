import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/features/cart/application/cart_controllers.dart';
import 'package:baraka_bozor/features/cart/application/cart_quantity_queue.dart';
import 'package:baraka_bozor/features/cart/domain/cart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_cart_repository.dart';

/// The signed-in Customer, switchable by the test.
class _Account extends Notifier<String?> {
  @override
  String? build() => 'customer-a';

  void signIn(String? id) => state = id;
}

final NotifierProvider<_Account, String?> _account =
    NotifierProvider<_Account, String?>(_Account.new);

const Duration _settle = CartQuantityQueue.settleDelay;

void main() {
  late FakeCartRepository carts;

  /// A container with the cart of `customer-a` listened, as a badge would.
  Future<ProviderContainer> open(WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        customerAccountProvider.overrideWith((Ref ref) => ref.watch(_account)),
        cartRepositoryProvider.overrideWithValue(carts),
      ],
    );
    addTearDown(container.dispose);
    container.listen(cartProvider('customer-a'), (_, _) {});
    await tester.pump();
    return container;
  }

  setUp(() {
    carts = FakeCartRepository(
      cart: cartOf(<Map<String, Object?>>[cartLineJson()]),
    );
  });

  testWidgets('three quick steps send one change with the result', (
    tester,
  ) async {
    final ProviderContainer container = await open(tester);
    final CartQuantityQueue queue = container.read(
      cartQuantityQueueProvider.notifier,
    );
    carts.calls.clear();

    unawaited(queue.want(tomatoProduct, '1.5'));
    await tester.pump(const Duration(milliseconds: 100));
    unawaited(queue.want(tomatoProduct, '2'));
    await tester.pump(const Duration(milliseconds: 100));
    unawaited(queue.want(tomatoProduct, '2.5'));
    await tester.pump(const Duration(milliseconds: 499));
    expect(carts.calls, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    expect(carts.calls, <String>['change:$tomatoLine']);
    expect(carts.patches.single.quantity, '2.5');
    expect(carts.patches.single.noteChanged, isFalse);
    expect(carts.patches.single.substitutionPolicy, isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a product not in the cart is added at once', (tester) async {
    final ProviderContainer container = await open(tester);
    carts.calls.clear();

    unawaited(
      container
          .read(cartQuantityQueueProvider.notifier)
          .want(breadProduct, '1'),
    );

    expect(carts.calls, <String>['add:$breadProduct']);
    expect(carts.added.single.quantity, '1');
    expect(carts.added.single.customerNote, isNull);
    expect(
      carts.added.single.substitutionPolicy,
      SubstitutionPolicy.allowSimilar,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'a step while a change is on its way waits, then sends the newest',
    (tester) async {
      final ProviderContainer container = await open(tester);
      final CartQuantityQueue queue = container.read(
        cartQuantityQueueProvider.notifier,
      );
      carts.calls.clear();
      final Completer<void> hold = Completer<void>();
      carts.hold = hold;

      unawaited(queue.want(tomatoProduct, '2'));
      await tester.pump(_settle);
      expect(carts.calls, <String>['change:$tomatoLine']);

      unawaited(queue.want(tomatoProduct, '2.5'));
      await tester.pump(const Duration(milliseconds: 100));
      unawaited(queue.want(tomatoProduct, '3'));
      await tester.pump(_settle);
      await tester.pump(_settle);
      expect(carts.calls, hasLength(1), reason: 'never two open at once');

      carts.hold = null;
      hold.complete();
      await tester.pump();
      await tester.pump();
      expect(carts.calls, <String>['change:$tomatoLine', 'change:$tomatoLine']);
      expect(carts.patches.last.quantity, '3');
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('the wish shows until the answer, then goes', (tester) async {
    final ProviderContainer container = await open(tester);
    final CartQuantityQueue queue = container.read(
      cartQuantityQueueProvider.notifier,
    );
    final Completer<void> hold = Completer<void>();
    carts.hold = hold;
    final CartLine line = container
        .read(cartProvider('customer-a'))
        .requireValue
        .lines
        .single;

    unawaited(queue.want(tomatoProduct, '2'));
    await tester.pump(_settle);

    final Map<String, String> wishes = container.read(
      cartQuantityQueueProvider,
    );
    expect(wishes, <String, String>{tomatoProduct: '2'});
    expect(shownCartQuantity(wishes, tomatoProduct, line), '2');

    carts.hold = null;
    carts.answer = cartOf(<Map<String, Object?>>[
      cartLineJson(quantity: '2.000'),
    ]);
    hold.complete();
    await tester.pump();
    await tester.pump();

    final Map<String, String> after = container.read(cartQuantityQueueProvider);
    expect(after, isEmpty);
    final CartLine answered = container
        .read(cartProvider('customer-a'))
        .requireValue
        .lines
        .single;
    expect(shownCartQuantity(after, tomatoProduct, answered), '2.000');
    expect(
      shownCartQuantity(
        <String, String>{tomatoProduct: '0'},
        tomatoProduct,
        line,
      ),
      isNull,
    );
    expect(shownCartQuantity(after, breadProduct, null), isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a failure drops the wish and only the newest caller hears it', (
    tester,
  ) async {
    final ProviderContainer container = await open(tester);
    final CartQuantityQueue queue = container.read(
      cartQuantityQueueProvider.notifier,
    );
    carts.failure = const NetworkFailure();

    final Future<ApiFailure?> first = queue.want(tomatoProduct, '2');
    final Future<ApiFailure?> second = queue.want(tomatoProduct, '2.5');
    await tester.pump(_settle);
    await tester.pump();

    expect(await first, isNull);
    expect(await second, isA<NetworkFailure>());
    expect(container.read(cartQuantityQueueProvider), isEmpty);

    await tester.pump();
    final int calls = carts.calls.length;
    await tester.pump(const Duration(seconds: 1));
    expect(carts.calls, hasLength(calls));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'remove and restore go at once; restore keeps quantity, note and rule',
    (tester) async {
      final ProviderContainer container = await open(tester);
      final CartQuantityQueue queue = container.read(
        cartQuantityQueueProvider.notifier,
      );
      carts.calls.clear();

      carts.answer = cartOf(<Map<String, Object?>>[]);
      unawaited(queue.remove(tomatoProduct));
      expect(carts.calls, <String>['remove:$tomatoLine']);
      await tester.pump();
      await tester.pump();

      unawaited(
        queue.restore(
          const NewCartLine(
            productId: tomatoProduct,
            quantity: '1.5',
            customerNote: 'Eski',
            substitutionPolicy: SubstitutionPolicy.contactBefore,
          ),
          account: 'customer-a',
        ),
      );
      expect(carts.calls.last, 'add:$tomatoProduct');
      final NewCartLine added = carts.added.single;
      expect(added.quantity, '1.5');
      expect(added.customerNote, 'Eski');
      expect(added.substitutionPolicy, SubstitutionPolicy.contactBefore);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('a restore for the account that left adds nothing, even when '
      'the queue was rebuilt for the new one', (tester) async {
    final ProviderContainer container = await open(tester);
    container.listen(cartQuantityQueueProvider, (_, _) {});
    final CartQuantityQueue queue = container.read(
      cartQuantityQueueProvider.notifier,
    );
    carts.answer = cartOf(<Map<String, Object?>>[]);
    unawaited(queue.remove(tomatoProduct));
    await tester.pump();
    await tester.pump();

    container.read(_account.notifier).signIn('customer-b');
    await tester.pump();
    carts.calls.clear();
    final Future<ApiFailure?> restored = queue.restore(
      const NewCartLine(
        productId: tomatoProduct,
        quantity: '1.5',
        customerNote: 'Eski',
        substitutionPolicy: SubstitutionPolicy.contactBefore,
      ),
      account: 'customer-a',
    );
    await tester.pump(const Duration(seconds: 1));

    expect(await restored, isNull);
    expect(carts.added, isEmpty);
    expect(carts.calls.where((String c) => c.startsWith('add')), isEmpty);
    expect(container.read(cartQuantityQueueProvider), isEmpty);
  });

  testWidgets('a restore while the removal is on its way adds after it', (
    tester,
  ) async {
    final ProviderContainer container = await open(tester);
    final CartQuantityQueue queue = container.read(
      cartQuantityQueueProvider.notifier,
    );
    carts.calls.clear();
    final Completer<void> hold = Completer<void>();
    carts.hold = hold;

    final Future<ApiFailure?> removal = queue.remove(tomatoProduct);
    final Future<ApiFailure?> restored = queue.restore(
      const NewCartLine(
        productId: tomatoProduct,
        quantity: '1.500',
        customerNote: null,
        substitutionPolicy: SubstitutionPolicy.allowSimilar,
      ),
      account: 'customer-a',
    );
    expect(carts.calls, <String>['remove:$tomatoLine']);

    carts.hold = null;
    carts.answer = cartOf(<Map<String, Object?>>[]);
    hold.complete();
    await tester.pump();
    await tester.pump();

    expect(carts.calls, <String>['remove:$tomatoLine', 'add:$tomatoProduct']);
    expect(await removal, isNull);
    expect(await restored, isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('settle sends what waits and answers true', (tester) async {
    final ProviderContainer container = await open(tester);
    final CartQuantityQueue queue = container.read(
      cartQuantityQueueProvider.notifier,
    );
    carts.calls.clear();

    unawaited(queue.want(tomatoProduct, '2'));
    expect(carts.calls, isEmpty);
    final Future<bool> settled = queue.settle();
    expect(carts.calls, <String>['change:$tomatoLine']);
    await tester.pump();
    await tester.pump();

    expect(await settled, isTrue);
    expect(container.read(cartQuantityQueueProvider), isEmpty);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('settle answers false when a send fails', (tester) async {
    final ProviderContainer container = await open(tester);
    final CartQuantityQueue queue = container.read(
      cartQuantityQueueProvider.notifier,
    );
    carts.failure = const NetworkFailure();

    unawaited(queue.want(tomatoProduct, '2'));
    final Future<bool> settled = queue.settle();
    await tester.pump();
    await tester.pump();

    expect(await settled, isFalse);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a step leaves with its screen and is still sent', (
    tester,
  ) async {
    final ProviderContainer container = await open(tester);
    carts.calls.clear();

    // Nothing listens to the queue: no screen is left to show it.
    unawaited(
      container
          .read(cartQuantityQueueProvider.notifier)
          .want(tomatoProduct, '2'),
    );
    await tester.pump(_settle);

    expect(carts.calls, <String>['change:$tomatoLine']);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  });

  for (final bool listened in <bool>[false, true]) {
    testWidgets('another account drops the wishes and sends nothing'
        '${listened ? ' (queue listened)' : ''}', (tester) async {
      final ProviderContainer container = await open(tester);
      if (listened) {
        container.listen(cartQuantityQueueProvider, (_, _) {});
      }
      final CartQuantityQueue queue = container.read(
        cartQuantityQueueProvider.notifier,
      );
      carts.calls.clear();

      final Future<ApiFailure?> caller = queue.want(tomatoProduct, '2');
      await tester.pump(const Duration(milliseconds: 200));
      container.read(_account.notifier).signIn('customer-b');
      await tester.pump(_settle);

      expect(carts.calls.where((String c) => c != 'cart'), isEmpty);
      expect(carts.added, isEmpty);
      expect(container.read(cartQuantityQueueProvider), isEmpty);
      expect(await caller, isNull);
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
