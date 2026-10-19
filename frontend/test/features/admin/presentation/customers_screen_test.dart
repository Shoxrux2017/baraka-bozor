import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/admin/application/admin_customers_controllers.dart';
import 'package:baraka_bozor/features/admin/domain/admin_customers.dart';
import 'package:baraka_bozor/features/admin/presentation/admin_paths.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_admin_customers_api.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/in_memory_stores.dart';

/// The Admin's customers page through the real router, session and screens,
/// against the accounts in memory. The device speaks Russian.
void main() {
  const String phone = '+998901234567';
  const String idA = '0198a000-0000-7000-8000-0000000000a1';
  const String idB = '0198a000-0000-7000-8000-0000000000a2';
  const String orderId = '0198a000-0000-7000-8000-0000000000b1';

  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeAdminCustomersApi api;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  bool enabled(WidgetTester tester, String key) =>
      tester.widget<OutlinedButton>(byKey(key)).onPressed != null;

  setUp(() {
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    api = FakeAdminCustomersApi();
    tokens.tokens[SessionSlot.staff] = 's';
    auth.identities[SessionSlot.staff] = user(role: UserRole.admin);
    api.byPhone[phone] = <AdminCustomer>[
      FakeAdminCustomersApi.customer(id: idA),
      FakeAdminCustomersApi.customer(
        id: idB,
        fullName: null,
        unfinishedOrder: (id: orderId, number: 1042),
      ),
    ];
  });

  Future<void> openCustomers(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        surface: Surface.web,
        device: const Locale('ru'),
        overrides: [adminCustomersApiProvider.overrideWithValue(api)],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(byKey('panel-section-${AdminPaths.customers}'));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(byKey('customers-phone'), text);
    await tester.tap(byKey('customers-find'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a malformed phone shows the hint as an error and sends nothing',
    (WidgetTester tester) async {
      await openCustomers(tester);

      await search(tester, '90 123');

      expect(
        tester
            .widget<TextField>(byKey('customers-phone'))
            .decoration!
            .errorText,
        '+998 и 9 цифр',
      );
      expect(api.finds, isEmpty);
    },
  );

  testWidgets('the accounts on a phone show as cards', (
    WidgetTester tester,
  ) async {
    await openCustomers(tester);

    await search(tester, phone);

    expect(api.finds, <String>[phone]);
    expect(find.text('Aziza Karimova'), findsOneWidget);
    expect(find.text('Без имени'), findsOneWidget);
    expect(find.text('+998 90 123 45 67'), findsNWidgets(2));
    expect(find.text('Заказов: 3'), findsNWidgets(2));
    expect(find.text('Активен'), findsNWidgets(2));
    expect(find.text('Незавершённый заказ № 1042'), findsOneWidget);
  });

  testWidgets('a phone with no account says so', (WidgetTester tester) async {
    await openCustomers(tester);

    await search(tester, '+998909999999');

    expect(find.text('Покупателей с этим номером нет'), findsOneWidget);
  });

  testWidgets('the erase button is disabled while an order is unfinished', (
    WidgetTester tester,
  ) async {
    await openCustomers(tester);
    await search(tester, phone);

    expect(enabled(tester, 'customer-erase-$idA'), isTrue);
    expect(enabled(tester, 'customer-erase-$idB'), isFalse);
  });

  testWidgets('erasing asks, sends once, removes the card and confirms', (
    WidgetTester tester,
  ) async {
    await openCustomers(tester);
    await search(tester, phone);

    await tester.tap(byKey('customer-erase-$idA'));
    await tester.pumpAndSettle();

    expect(find.text('Удалить аккаунт покупателя?'), findsOneWidget);
    expect(
      find.text(
        'Сотрём имя, номер, адреса, избранное и корзину. '
        'История заказов останется без имени и телефона.',
      ),
      findsOneWidget,
    );
    expect(api.erased, isEmpty);

    await tester.tap(byKey('customer-erase-confirm'));
    await tester.pumpAndSettle();

    expect(api.erased, <String>[idA]);
    expect(byKey('customer-$idA'), findsNothing);
    expect(byKey('customer-$idB'), findsOneWidget);
    expect(find.text('Аккаунт удалён'), findsOneWidget);
  });

  testWidgets('cancelling the question sends nothing', (
    WidgetTester tester,
  ) async {
    await openCustomers(tester);
    await search(tester, phone);

    await tester.tap(byKey('customer-erase-$idA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(api.erased, isEmpty);
    expect(byKey('customer-$idA'), findsOneWidget);
    expect(find.text('Аккаунт удалён'), findsNothing);
  });

  testWidgets('a refusal for an unfinished order names the order', (
    WidgetTester tester,
  ) async {
    await openCustomers(tester);
    await search(tester, phone);
    api.eraseFailure = ApiRefusal(
      const ApiError(
        status: 409,
        code: 'account_has_unfinished_orders',
        details: <String, Object?>{'order_id': orderId, 'order_number': 1050},
      ),
    );

    await tester.tap(byKey('customer-erase-$idA'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('customer-erase-confirm'));
    await tester.pumpAndSettle();

    expect(find.text('Незавершённый заказ № 1050'), findsOneWidget);
    expect(byKey('customer-$idA'), findsOneWidget);
    expect(find.text('Аккаунт удалён'), findsNothing);
  });
}
