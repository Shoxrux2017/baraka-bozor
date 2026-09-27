import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/session/staff_account.dart';
import 'package:baraka_bozor/features/operations/application/board_controllers.dart';
import 'package:baraka_bozor/features/operations/domain/board.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The signed-in staff account, switchable by the test.
class _Account extends Notifier<String?> {
  @override
  String? build() => 'staff-a';

  void signIn(String? id) => state = id;
}

final NotifierProvider<_Account, String?> _account =
    NotifierProvider<_Account, String?>(_Account.new);

void main() {
  test('the board\'s filters start over for another account', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        staffAccountProvider.overrideWith((Ref ref) => ref.watch(_account)),
      ],
    );
    addTearDown(container.dispose);
    final BoardQueryController queries = container.read(
      boardQueryProvider.notifier,
    );

    queries
      ..filterByStatus(OrderStatus.newOrder)
      ..selfOrdersOnly(true)
      ..search('  Aziza ');
    expect(
      container.read(boardQueryProvider),
      const BoardQuery(
        status: OrderStatus.newOrder,
        selfOrdersOnly: true,
        search: 'Aziza',
      ),
    );
    queries.goToPage(3);
    expect(container.read(boardQueryProvider).page, 3);
    queries.filterByPaymentMethod(PaymentMethod.cash);
    expect(
      container.read(boardQueryProvider).page,
      1,
      reason: 'a new filter starts from the first page',
    );

    container.read(_account.notifier).signIn('staff-b');

    expect(container.read(boardQueryProvider), const BoardQuery());
  });
}
