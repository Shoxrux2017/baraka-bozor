import 'package:baraka_bozor/core/formatting/phone_format.dart';
import 'package:baraka_bozor/core/formatting/tashkent_time.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/kit/kit_note.dart';
import 'package:baraka_bozor/core/widgets/panel/panel_person.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/admin/application/admin_customers_controllers.dart';
import 'package:baraka_bozor/features/admin/domain/admin_customers.dart';
import 'package:baraka_bozor/features/admin/presentation/admin_paths.dart';
import 'package:baraka_bozor/features/admin/presentation/customers_screen.dart';
import 'package:baraka_bozor/features/admin/presentation/staff_widgets.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(CustomersScreen)));

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    // A field that still has the focus scrolls its window back to its caret,
    // so the button the test scrolls to would slide away again.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// The note of the given tone that holds [text].
  Finder note(KitTone tone, String text) => find.ancestor(
    of: find.text(text),
    matching: find.byWidgetPredicate(
      (Widget widget) => widget is KitNote && widget.tone == tone,
    ),
  );

  Future<void> openCustomers(
    WidgetTester tester, {
    Size size = const Size(1400, 2600),
    Locale device = const Locale('ru'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        surface: Surface.web,
        device: device,
        overrides: [adminCustomersApiProvider.overrideWithValue(api)],
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go(AdminPaths.customers);
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(byKey('customers-phone'), text);
    await tapAndSettle(tester, byKey('customers-find'));
  }

  testWidgets('the search takes nine digits or a whole pasted number', (
    WidgetTester tester,
  ) async {
    for (final String text in <String>[
      '901234567',
      '90 123 45 67',
      '+998 90 123 45 67',
      '+998901234567',
    ]) {
      expect(customerPhoneOf(text), '+998901234567', reason: text);
    }
    for (final String text in <String>['90123456', '+7 901 234 56 78', '']) {
      expect(customerPhoneOf(text), isNull, reason: text);
    }

    await openCustomers(tester);
    await search(tester, '90 123');

    expect(
      tester.widget<TextField>(byKey('customers-phone')).decoration!.errorText,
      l10n(tester).customersPhoneHint,
    );
    expect(find.text('+998 и 9 цифр'), findsOneWidget);
    expect(api.finds, isEmpty);

    await search(tester, '90 123 45 67');

    expect(api.finds, <String>[phone]);
    expect(
      tester.widget<TextField>(byKey('customers-phone')).decoration!.errorText,
      isNull,
    );
  });

  testWidgets('before a search the page says what to do', (
    WidgetTester tester,
  ) async {
    await openCustomers(tester);

    expect(find.text(l10n(tester).customersStartTitle), findsOneWidget);
    expect(find.text(l10n(tester).customersStartText), findsOneWidget);
    expect(find.text(l10n(tester).customersNone), findsNothing);
  });

  testWidgets('a phone with no account says so and what to check', (
    WidgetTester tester,
  ) async {
    await openCustomers(tester);

    await search(tester, '+998909999999');

    expect(find.text('Покупателей с этим номером нет'), findsOneWidget);
    expect(find.text(l10n(tester).customersNoneHint), findsOneWidget);
    expect(find.text(l10n(tester).customersStartTitle), findsNothing);
  });

  testWidgets('the accounts on a phone show as cards', (
    WidgetTester tester,
  ) async {
    final DateTime lastLogin = DateTime.utc(2026, 10, 20, 8, 30);
    api.byPhone[phone] = <AdminCustomer>[
      FakeAdminCustomersApi.customer(id: idA, lastLoginAt: lastLogin),
      FakeAdminCustomersApi.customer(
        id: idB,
        fullName: null,
        status: 'blocked',
      ),
    ];
    await openCustomers(tester);

    await search(tester, phone);

    expect(api.finds, <String>[phone]);
    final Finder cardA = byKey('customer-$idA');
    final Finder cardB = byKey('customer-$idB');
    Finder within(Finder card, Finder finder) =>
        find.descendant(of: card, matching: finder);

    final Text name = tester.widget<Text>(
      within(cardA, find.text('Aziza Karimova')),
    );
    expect(name.style?.fontSize, 20);
    expect(name.style?.fontWeight, FontWeight.w700);
    expect(within(cardA, find.byType(AccountStatusChip)), findsOneWidget);
    expect(within(cardA, find.text('Активен')), findsOneWidget);
    expect(within(cardA, find.text(formatPhone(phone))), findsOneWidget);
    expect(
      within(cardA, find.text(l10n(tester).customerOrdersLabel.toUpperCase())),
      findsOneWidget,
    );
    expect(within(cardA, find.text('3')), findsOneWidget);
    expect(
      within(cardA, find.text(l10n(tester).customerSince.toUpperCase())),
      findsOneWidget,
    );
    expect(
      within(cardA, find.text(TashkentTime.date(DateTime.utc(2026, 9, 1, 7)))),
      findsOneWidget,
    );
    expect(
      within(
        cardA,
        find.text(l10n(tester).customerLastLoginLabel.toUpperCase()),
      ),
      findsOneWidget,
    );
    expect(
      within(cardA, find.text(TashkentTime.format(lastLogin))),
      findsOneWidget,
    );

    expect(within(cardB, find.text('Без имени')), findsOneWidget);
    expect(within(cardB, find.text('Заблокирован')), findsOneWidget);
    expect(within(cardB, find.text('—')), findsOneWidget);
  });

  testWidgets('the erase button is disabled while an order is unfinished', (
    WidgetTester tester,
  ) async {
    await openCustomers(tester);
    await search(tester, phone);

    expect(enabled(tester, 'customer-erase-$idA'), isTrue);
    expect(enabled(tester, 'customer-erase-$idB'), isFalse);
    expect(
      note(KitTone.amber, l10n(tester).customerUnfinished('1042')),
      findsOneWidget,
    );
    expect(
      note(KitTone.amber, l10n(tester).customerUnfinishedExplained),
      findsOneWidget,
    );
  });

  testWidgets('a blocked account says its number stays blocked', (
    WidgetTester tester,
  ) async {
    const String text =
        'Аккаунт заблокирован: номер останется в чёрном списке, '
        'зарегистрироваться с ним снова будет нельзя.';
    api.byPhone[phone] = <AdminCustomer>[
      FakeAdminCustomersApi.customer(id: idA, status: 'blocked'),
    ];
    await openCustomers(tester);
    await search(tester, phone);

    expect(enabled(tester, 'customer-erase-$idA'), isTrue);
    expect(note(KitTone.amber, text), findsOneWidget);

    await tapAndSettle(tester, byKey('customer-erase-$idA'));

    expect(
      find.descendant(
        of: byKey('customer-erase-dialog'),
        matching: note(KitTone.amber, text),
      ),
      findsOneWidget,
    );
    expect(api.erased, isEmpty);

    await tapAndSettle(tester, byKey('customer-erase-confirm'));

    expect(api.erased, <String>[idA]);
    expect(byKey('customer-$idA'), findsNothing);
  });

  testWidgets('erasing asks, sends once, removes the card and confirms', (
    WidgetTester tester,
  ) async {
    await openCustomers(tester);
    await search(tester, phone);

    await tapAndSettle(tester, byKey('customer-erase-$idA'));

    final Finder dialog = byKey('customer-erase-dialog');
    expect(dialog, findsOneWidget);
    Finder inDialog(Finder finder) =>
        find.descendant(of: dialog, matching: finder);
    expect(inDialog(find.text('Удалить аккаунт покупателя?')), findsOneWidget);
    expect(inDialog(find.byType(PanelPersonLine)), findsOneWidget);
    expect(inDialog(find.text('Aziza Karimova')), findsOneWidget);
    expect(
      inDialog(find.text('${formatPhone(phone)} · Заказов: 3')),
      findsOneWidget,
    );
    expect(
      inDialog(
        find.text(
          'Сотрём имя, номер, адреса, избранное и корзину. '
          'История заказов останется без имени и телефона.',
        ),
      ),
      findsOneWidget,
    );
    expect(
      inDialog(find.text(l10n(tester).customerEraseFinal)),
      findsOneWidget,
    );
    expect(api.erased, isEmpty);

    await tapAndSettle(tester, byKey('customer-erase-confirm'));

    expect(api.erased, <String>[idA]);
    expect(byKey('customer-$idA'), findsNothing);
    expect(byKey('customer-$idB'), findsOneWidget);
    expect(find.text('Аккаунт удалён'), findsOneWidget);
  });

  testWidgets('the erase actions use the error colour', (
    WidgetTester tester,
  ) async {
    await openCustomers(tester);
    await search(tester, phone);

    final ButtonStyle? card = tester
        .widget<OutlinedButton>(byKey('customer-erase-$idA'))
        .style;
    expect(card?.foregroundColor?.resolve(<WidgetState>{}), KitColors.danger);
    expect(card?.side?.resolve(<WidgetState>{})?.color, KitColors.danger);
    expect(
      find.descendant(
        of: byKey('customer-erase-$idA'),
        matching: find.byIcon(Icons.person_remove_outlined),
      ),
      findsOneWidget,
    );

    await tapAndSettle(tester, byKey('customer-erase-$idA'));

    final ButtonStyle? confirm = tester
        .widget<FilledButton>(byKey('customer-erase-confirm'))
        .style;
    expect(
      confirm?.backgroundColor?.resolve(<WidgetState>{}),
      KitColors.danger,
    );
  });

  testWidgets('cancelling the question sends nothing', (
    WidgetTester tester,
  ) async {
    await openCustomers(tester);
    await search(tester, phone);

    await tapAndSettle(tester, byKey('customer-erase-$idA'));
    await tapAndSettle(tester, find.text('Отмена'));

    expect(byKey('customer-erase-dialog'), findsNothing);
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

    await tapAndSettle(tester, byKey('customer-erase-$idA'));
    await tapAndSettle(tester, byKey('customer-erase-confirm'));

    expect(find.text('Незавершённый заказ № 1050'), findsOneWidget);
    expect(byKey('customer-$idA'), findsOneWidget);
    expect(find.text('Аккаунт удалён'), findsNothing);
  });

  testWidgets('the help card stands beside from 1000 and under below', (
    WidgetTester tester,
  ) async {
    await openCustomers(tester, size: const Size(1048, 1000));

    final Rect search = tester.getRect(byKey('customers-search'));
    final Rect help = tester.getRect(byKey('customers-help'));
    expect(help.left, greaterThanOrEqualTo(search.right));
    expect(help.top, search.top);
    expect(help.width, 372);

    final AppLocalizations text = l10n(tester);
    expect(find.text(text.customersHelpTitle), findsOneWidget);
    expect(find.text(text.customersHelpStep1), findsOneWidget);
    expect(find.text(text.customersHelpStep2), findsOneWidget);
    expect(find.text(text.customersHelpStep3), findsOneWidget);
    expect(find.text(text.customersHelpPrivacy), findsOneWidget);

    await openCustomers(tester, size: const Size(1047, 1000));

    final Rect results = tester.getRect(byKey('customers-results'));
    final Rect under = tester.getRect(byKey('customers-help'));
    expect(under.top, greaterThanOrEqualTo(results.bottom));
    expect(under.left, tester.getRect(byKey('customers-search')).left);
  });

  testWidgets('the stacked help card stands 16 under the results', (
    WidgetTester tester,
  ) async {
    await openCustomers(tester, size: const Size(1047, 1000));

    final Rect results = tester.getRect(byKey('customers-results'));
    final Rect under = tester.getRect(byKey('customers-help'));
    expect(under.top - results.bottom, 16);
  });

  testWidgets('the search button is as high as its field and aligned', (
    WidgetTester tester,
  ) async {
    await openCustomers(tester);

    final Rect field = tester.getRect(byKey('customers-phone'));
    final Rect button = tester.getRect(byKey('customers-find'));
    expect(button.height, field.height);
    expect(button.top, field.top);
  });

  testWidgets('the search field types at 13 in ink', (
    WidgetTester tester,
  ) async {
    await openCustomers(tester);

    expect(
      tester.widget<TextField>(byKey('customers-phone')).style,
      const TextStyle(fontSize: 13, color: KitColors.ink),
    );
  });

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    for (final Size size in const <Size>[Size(1440, 900), Size(820, 1180)]) {
      testWidgets('the customers page holds at the extremes '
          '(${device.languageCode} ${size.width.toInt()})', (
        WidgetTester tester,
      ) async {
        api.byPhone[phone] = <AdminCustomer>[
          FakeAdminCustomersApi.customer(
            id: idA,
            fullName: 'Dilnoza ' * 20,
            status: 'blocked',
          ),
          FakeAdminCustomersApi.customer(
            id: idB,
            unfinishedOrder: (id: orderId, number: 1042),
          ),
        ];
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await openCustomers(tester, size: size, device: device);
        expect(tester.takeException(), isNull);
        await search(tester, phone);

        expect(byKey('customer-$idA'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(byKey('customer-erase-$idB'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tapAndSettle(tester, byKey('customer-erase-$idA'));
        expect(byKey('customer-erase-dialog'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tapAndSettle(tester, byKey('customer-erase-confirm'));
        expect(api.erased, <String>[idA]);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
