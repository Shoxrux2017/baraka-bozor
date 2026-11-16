import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/addresses/application/delivery_address.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:baraka_bozor/features/addresses/presentation/addresses_screens.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/address_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_address_map.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_catalog_repository.dart';
import '../../support/fake_customer_repositories.dart';
import '../../support/in_memory_stores.dart';

/// The delivery-address sheet in the kit look (drawings 21, 21a), opened
/// from the home header through the real router.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeAddressesRepository addresses;
  late InMemoryPreferenceStore preferences;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  String? chosenInSheet(WidgetTester tester) => tester
      .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
      .groupValue;

  setUp(() {
    preferences = InMemoryPreferenceStore();
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = user(id: 'c');
    addresses = FakeAddressesRepository(
      rows: <Address>[
        address(
          id: 'a-home',
          label: 'Дом',
          street: 'ул. Навои',
          house: '30',
          apartment: '12',
          landmark: 'у аптеки',
        ),
        address(
          id: 'a-work',
          label: 'Работа',
          street: 'Амир Темур',
          house: '5',
          apartment: 'Офис 3',
        ),
        address(id: 'a-bare', label: null, street: 'Чиланзар', house: '14'),
      ],
    );
    preferences.values[DeliveryAddressChoice.preferenceKey('c')] = 'a-home';
  });

  Future<void> openSheet(
    WidgetTester tester, {
    Locale device = const Locale('ru'),
  }) async {
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        device: device,
        catalog: FakeCatalogRepository(),
        addresses: addresses,
        preferences: preferences,
        overrides: [addressMapProvider.overrideWithValue(FakeAddressMap())],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(byKey('delivery-address'));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester, String id) async {
    await tester.tap(byKey('delivery-address-menu-$id'));
    await tester.pumpAndSettle();
  }

  testWidgets('the cards show the label, the line and the landmark', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);

    Finder inCard(String id, String text) => find.descendant(
      of: byKey('delivery-address-$id'),
      matching: find.text(text),
    );
    expect(
      find.descendant(
        of: byKey('delivery-address-sheet'),
        matching: find.text('Адрес доставки'),
      ),
      findsOneWidget,
    );
    expect(inCard('a-home', 'Дом'), findsOneWidget);
    expect(inCard('a-home', 'ул. Навои, 30, кв. 12'), findsOneWidget);
    expect(inCard('a-home', 'Ориентир: у аптеки'), findsOneWidget);
    expect(inCard('a-work', 'Работа'), findsOneWidget);
    expect(inCard('a-work', 'Амир Темур, 5, Офис 3'), findsOneWidget);
    // Without a label the street is the title, and nothing repeats it.
    expect(inCard('a-bare', 'Чиланзар, 14'), findsOneWidget);
    expect(find.text('Добавить новый адрес'), findsOneWidget);
    expect(chosenInSheet(tester), 'a-home');
  });

  testWidgets('a card without a label shows only the apartment under it', (
    WidgetTester tester,
  ) async {
    addresses.rows = <Address>[
      address(
        id: 'a-bare',
        label: null,
        street: 'Чиланзар',
        house: '14',
        apartment: '7',
      ),
    ];
    preferences.values[DeliveryAddressChoice.preferenceKey('c')] = 'a-bare';
    await openSheet(tester);

    expect(
      find.descendant(
        of: byKey('delivery-address-a-bare'),
        matching: find.text('кв. 7'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the sheet is white with a rounded top and a title line', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);

    final BottomSheet sheet = tester.widget<BottomSheet>(
      find.byType(BottomSheet),
    );
    expect(sheet.backgroundColor, Colors.white);
    expect(
      sheet.shape,
      const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    );
    expect(
      find.descendant(
        of: byKey('delivery-address-sheet'),
        matching: find.byType(Divider),
      ),
      findsOneWidget,
    );
  });

  testWidgets('choosing a card closes the sheet', (WidgetTester tester) async {
    await openSheet(tester);
    await tester.tap(byKey('delivery-address-a-work'));
    await tester.pumpAndSettle();

    expect(byKey('delivery-address-sheet'), findsNothing);
    expect(
      preferences.values[DeliveryAddressChoice.preferenceKey('c')],
      'a-work',
    );
  });

  testWidgets('edit opens the address', (WidgetTester tester) async {
    await openSheet(tester);
    await openMenu(tester, 'a-work');
    await tester.tap(byKey('delivery-address-edit-a-work'));
    await tester.pumpAndSettle();

    expect(byKey('delivery-address-sheet'), findsNothing);
    final AddressFormScreen form = tester.widget<AddressFormScreen>(
      find.byType(AddressFormScreen),
    );
    expect(form.addressId, 'a-work');
  });

  Future<void> deleteCard(WidgetTester tester, String id) async {
    await openMenu(tester, id);
    await tester.tap(byKey('delivery-address-delete-$id'));
    await tester.pump();
    // The menu closes first, then the card folds and the bar comes in.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Past the bar's end: 5 s from when it has come in, plus its exit.
  Future<void> pastBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  }

  Finder undoButton(WidgetTester tester) => find.descendant(
    of: byKey('delivery-address-sheet'),
    matching: find.text(l10n(tester).undoAction),
  );

  testWidgets('delete folds the card at once and offers Вернуть in the sheet', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);
    await deleteCard(tester, 'a-work');

    // No question; the card is gone and the bar stands inside the sheet.
    expect(find.text('Удалить этот адрес?'), findsNothing);
    expect(byKey('delivery-address-a-work'), findsNothing);
    expect(find.text('Удалили «Работа».'), findsOneWidget);
    expect(undoButton(tester), findsOneWidget);
    expect(addresses.removed, isEmpty);

    await tester.pump(const Duration(seconds: 4));
    expect(addresses.removed, isEmpty);
    await pastBar(tester);

    expect(addresses.removed, <String>['a-work']);
    expect(byKey('delivery-address-sheet'), findsOneWidget);
    expect(undoButton(tester), findsNothing);
  });

  testWidgets('Вернуть in the sheet brings the card back and sends nothing', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);
    await deleteCard(tester, 'a-work');
    await tester.tap(undoButton(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await pastBar(tester);

    expect(addresses.removed, isEmpty);
    expect(byKey('delivery-address-a-work'), findsOneWidget);
    expect(undoButton(tester), findsNothing);
  });

  testWidgets('closing the sheet ends the bar and sends the removal', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);
    await deleteCard(tester, 'a-work');
    expect(addresses.removed, isEmpty);

    await tester.tap(byKey('delivery-address-close'));
    await tester.pumpAndSettle();

    expect(byKey('delivery-address-sheet'), findsNothing);
    expect(addresses.removed, <String>['a-work']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline the card returns in the sheet with why', (
    WidgetTester tester,
  ) async {
    addresses.removeFailure = const NetworkFailure();
    await openSheet(tester);
    await deleteCard(tester, 'a-work');
    await pastBar(tester);

    expect(
      find.descendant(
        of: byKey('delivery-address-a-work'),
        matching: find.text('Нет связи — адрес не удалён'),
      ),
      findsOneWidget,
    );
    expect(byKey('delivery-address-sheet'), findsOneWidget);
  });

  testWidgets('deleting the chosen address moves the radio to the newest', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);
    await deleteCard(tester, 'a-home');

    // The newest takes its place (DL-75), and the bar says so.
    expect(chosenInSheet(tester), 'a-work');
    expect(find.textContaining('Доставка теперь'), findsOneWidget);

    await tester.tap(undoButton(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(chosenInSheet(tester), 'a-home');
    await pastBar(tester);
    expect(addresses.removed, isEmpty);
  });

  testWidgets("the sheet's menu has icons and no Доставлять сюда", (
    WidgetTester tester,
  ) async {
    await openSheet(tester);
    await openMenu(tester, 'a-work');

    expect(byKey('delivery-address-edit-a-work'), findsOneWidget);
    expect(byKey('delivery-address-choose-a-work'), findsNothing);
    expect(find.text('Доставлять сюда'), findsNothing);
    expect(
      find.descendant(
        of: byKey('delivery-address-edit-a-work'),
        matching: find.byIcon(Icons.edit_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: byKey('delivery-address-delete-a-work'),
        matching: find.byIcon(Icons.delete_outline),
      ),
      findsOneWidget,
    );
  });

  testWidgets('close closes', (WidgetTester tester) async {
    await openSheet(tester);
    await tester.tap(byKey('delivery-address-close'));
    await tester.pumpAndSettle();
    expect(byKey('delivery-address-sheet'), findsNothing);
  });

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'the sheet holds at 320x640 with text x2 (${device.languageCode})',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addresses.rows = <Address>[
          address(
            id: 'a-long',
            label: List<String>.filled(60, 'x').join(),
            street: List<String>.filled(160, 'y').join(),
            apartment: '12',
            landmark: List<String>.filled(80, 'z').join(),
          ),
          address(id: 'a-2'),
          address(id: 'a-3', label: null),
        ];
        preferences.values[DeliveryAddressChoice.preferenceKey('c')] = 'a-long';
        await openSheet(tester, device: device);

        expect(byKey('delivery-address-sheet'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await openMenu(tester, 'a-long');
        expect(byKey('delivery-address-edit-a-long'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
