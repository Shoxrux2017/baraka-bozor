import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/widgets/active_mode_bar.dart';
import 'package:baraka_bozor/features/addresses/application/delivery_address.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:baraka_bozor/features/addresses/presentation/addresses_screens.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/map_picker.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/catalog/presentation/catalog_screens.dart';
import 'package:baraka_bozor/features/catalog/presentation/customer_home_header.dart';
import 'package:baraka_bozor/features/catalog/presentation/customer_home_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_cart_repository.dart';
import '../../support/fake_catalog_repository.dart';
import '../../support/fake_customer_repositories.dart';
import '../../support/in_memory_stores.dart';

/// A map that shows where the pin starts, as the address screens' tests do.
Widget _fakeMap({
  required GeoPoint initial,
  required bool enabled,
  required ValueChanged<GeoPoint> onMoved,
}) => Text('${initial.latitude},${initial.longitude}');

/// The Customer home's floating bar (design 4a), through the real router.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCatalogRepository catalog;
  late FakeAddressesRepository addresses;
  late InMemoryPreferenceStore preferences;

  const int sections = 12;
  const String lastCategoryId = 'c-$sections';

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  setUp(() {
    addresses = FakeAddressesRepository();
    preferences = InMemoryPreferenceStore();
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    catalog = FakeCatalogRepository(
      categories: <CatalogCategory>[
        for (int i = 1; i <= sections; i++)
          catalogCategory(
            id: 'c-$i',
            nameUz: 'Bo\'lim $i',
            nameRu: 'Раздел $i',
          ),
      ],
      products: <CatalogProduct>[catalogProduct()],
    );
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = user(id: 'c');
  });

  Future<void> open(
    WidgetTester tester, {
    Locale device = const Locale('uz'),
    FakeCartRepository? cart,
  }) async {
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        device: device,
        catalog: catalog,
        addresses: addresses,
        preferences: preferences,
        cart: cart,
        overrides: [mapPickerProvider.overrideWithValue(_fakeMap)],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the floating bar opens the orders and the profile over the home',
    (WidgetTester tester) async {
      await open(tester);
      expect(
        find.descendant(
          of: find.byType(CustomerHomeNav),
          matching: byKey('open-orders'),
        ),
        findsOneWidget,
      );
      await tester.tap(byKey('open-orders'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerHomeNav), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(byKey('open-profile'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerHomeNav), findsNothing);
    },
  );

  testWidgets('the header shows the search, the cart and the newest address', (
    WidgetTester tester,
  ) async {
    await open(tester);
    final Finder header = find.byType(CustomerHomeHeader);
    expect(
      find.descendant(of: header, matching: byKey('catalog-search')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: header, matching: byKey('open-cart')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: header, matching: find.text('Amir Temur, 12')),
      findsOneWidget,
    );
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets(
    'the address line changes the delivery address, and it is remembered',
    (WidgetTester tester) async {
      addresses.rows = <Address>[
        address(id: 'a-1'),
        address(id: 'a-2', label: 'Ish', street: 'Bobur', house: '7'),
      ];
      await open(tester);
      await tester.tap(byKey('delivery-address'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('delivery-address-a-2'));
      await tester.pumpAndSettle();
      expect(find.text('Bobur, 7'), findsOneWidget);
      expect(
        preferences.values[DeliveryAddressChoice.preferenceKey('c')],
        'a-2',
      );

      await tester.pumpWidget(const SizedBox()); // a later launch, same device
      await open(tester);
      expect(find.text('Bobur, 7'), findsOneWidget);
    },
  );

  testWidgets('with no address the line adds one', (WidgetTester tester) async {
    addresses.rows = <Address>[];
    await open(tester);
    await tester.tap(find.text(l10n(tester).deliveryAddressAdd));
    await tester.pumpAndSettle();
    expect(find.byType(AddressFormScreen), findsOneWidget);
  });

  testWidgets('the sheet adds an address too', (WidgetTester tester) async {
    await open(tester);
    await tester.tap(byKey('delivery-address'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('delivery-address-new'));
    await tester.pumpAndSettle();
    expect(find.byType(AddressFormScreen), findsOneWidget);
  });

  testWidgets('a list that failed to load offers a retry that reloads it', (
    WidgetTester tester,
  ) async {
    addresses.loadFailure = const UnexpectedFailure();
    await open(tester);
    expect(find.text(l10n(tester).deliveryAddressRetry), findsOneWidget);
    expect(find.text('Amir Temur, 12'), findsNothing);
    await tester.tap(byKey('delivery-address'));
    await tester.pumpAndSettle();
    expect(find.text('Amir Temur, 12'), findsOneWidget);
  });

  testWidgets(
    'the cart button on the header counts the cart lines and opens the cart',
    (WidgetTester tester) async {
      final FakeCartRepository cart = FakeCartRepository(
        cart: cartOf(<Map<String, Object?>>[
          cartLineJson(),
          cartLineJson(
            id: breadLine,
            productId: breadProduct,
            unit: 'piece',
            quantity: '2',
          ),
        ]),
      );
      await open(tester, cart: cart);
      expect(
        find.descendant(of: byKey('open-cart'), matching: byKey('cart-count')),
        findsOneWidget,
      );
      expect(find.text('2'), findsOneWidget);
      await tester.tap(byKey('open-cart'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerHomeHeader), findsNothing);
    },
  );

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    for (final bool twoSessions in const <bool>[false, true]) {
      testWidgets(
        'large text on a small phone: the header and the bar fit and the last '
        'section is reachable (${device.languageCode}, '
        '${twoSessions ? 'two sessions' : 'one session'})',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          WidgetController.hitTestWarningShouldBeFatal = true;
          addTearDown(
            () => WidgetController.hitTestWarningShouldBeFatal = false,
          );
          if (twoSessions) {
            tokens.tokens[SessionSlot.staff] = 's';
            auth.identities[SessionSlot.staff] = user(
              id: 's',
              role: UserRole.courier,
            );
            await open(tester, device: device);
            await tester.tap(byKey('staff-menu'));
            await tester.pumpAndSettle();
            await tester.tap(byKey('switch-to-customer-button'));
            await tester.pumpAndSettle();
          } else {
            await open(tester, device: device);
          }
          expect(tester.takeException(), isNull);
          expect(find.text('Amir Temur, 12'), findsOneWidget);
          if (twoSessions) {
            expect(
              find.descendant(
                of: find.byType(ActiveModeBar),
                matching: byKey('switch-to-staff-button'),
              ),
              findsOneWidget,
            );
          }

          await tester.enterText(byKey('catalog-search'), 'pom');
          await tester.pump(CatalogHomeScreen.searchPause);
          await tester.pumpAndSettle();
          expect(
            find.text(device.languageCode == 'uz' ? 'Pomidor' : 'Помидор'),
            findsOneWidget,
          );
          await tester.tap(byKey('catalog-search-clear'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final Finder last = byKey('category-$lastCategoryId');
          await tester.dragUntilVisible(
            last,
            byKey('category-list'),
            const Offset(0, -100),
          );
          await tester.drag(byKey('category-list'), const Offset(0, -2000));
          await tester.pumpAndSettle();
          await tester.tap(last);
          await tester.pumpAndSettle();
          expect(find.byType(CustomerHomeNav), findsNothing);
        },
      );
    }
  }
}
