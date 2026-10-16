import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/widgets/customer_tab_bar.dart';
import 'package:baraka_bozor/features/addresses/application/delivery_address.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:baraka_bozor/features/addresses/presentation/addresses_screens.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/map_picker.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/catalog/presentation/all_categories_screen.dart';
import 'package:baraka_bozor/features/catalog/presentation/all_products_screen.dart';
import 'package:baraka_bozor/features/catalog/presentation/home_screen.dart';
import 'package:baraka_bozor/features/catalog/presentation/kit_product_card.dart';
import 'package:baraka_bozor/features/catalog/presentation/recommended_screen.dart';
import 'package:baraka_bozor/features/catalog/presentation/search_screen.dart';
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

/// The Customer's home in the kit look (`DL-80`), through the real router.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCatalogRepository catalog;
  late FakeAddressesRepository addresses;
  late InMemoryPreferenceStore preferences;

  const int sections = 10;

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
      products: <CatalogProduct>[
        catalogProduct(),
        catalogProduct(
          id: 'p-2',
          nameUz: 'Olma',
          nameRu: 'Яблоко',
          customerUnitPriceUzs: 3500,
        ),
        catalogProduct(
          id: 'p-3',
          nameUz: 'Banan',
          nameRu: 'Банан',
          customerUnitPriceUzs: 9000,
        ),
      ],
    )..featuredIds = <String>{'p-1', 'p-2'};
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

  double top(WidgetTester tester, Finder finder) =>
      tester.getTopLeft(finder).dy;

  testWidgets('the tab bar opens the orders and the profile over the home', (
    WidgetTester tester,
  ) async {
    await open(tester);
    expect(
      find.descendant(
        of: find.byType(CustomerTabBar),
        matching: byKey('open-orders'),
      ),
      findsOneWidget,
    );
    await tester.tap(byKey('open-orders'));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogHomeScreen), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogHomeScreen), findsOneWidget);
    await tester.tap(byKey('open-profile'));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogHomeScreen), findsNothing);
  });

  testWidgets('the system back from a tab returns to the home', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.tap(byKey('open-orders'));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogHomeScreen), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CatalogHomeScreen), findsOneWidget);

    await tester.tap(byKey('open-favorites'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('open-profile'));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogHomeScreen), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CatalogHomeScreen), findsOneWidget);
  });

  testWidgets('each card of the recommended row is keyed by its product', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.drag(byKey('home-body'), const Offset(0, -2000));
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<KitProductCard>(
            find.descendant(
              of: byKey('recommended-row'),
              matching: find.byType(KitProductCard),
            ),
          )
          .map((KitProductCard c) => c.key),
      <Key>[const ValueKey<String>('p-1'), const ValueKey<String>('p-2')],
    );
  });

  testWidgets(
    'the sections come in order: address and cart, search, categories, '
    'recommended',
    (WidgetTester tester) async {
      await open(tester);
      final AppLocalizations words = l10n(tester);

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(CustomerTabBar), findsOneWidget);
      expect(find.text('Amir Temur, 12'), findsOneWidget);
      expect(
        tester.getCenter(byKey('open-cart')).dx,
        greaterThan(tester.getCenter(byKey('delivery-address')).dx),
        reason: 'the cart at the right of the address',
      );
      expect(
        top(tester, byKey('delivery-address')),
        lessThan(top(tester, byKey('catalog-search'))),
      );
      expect(
        tester.getCenter(byKey('open-sort')).dx,
        greaterThan(tester.getCenter(byKey('catalog-search')).dx),
      );
      expect(tester.getSize(byKey('open-sort')), const Size(50, 50));
      expect(
        top(tester, byKey('catalog-search')),
        lessThan(top(tester, find.text(words.homeCategories))),
      );
      expect(
        top(tester, find.text(words.homeCategories)),
        lessThan(top(tester, find.text(words.recommendedTitle))),
      );
      expect(byKey('open-categories'), findsOneWidget);
      expect(byKey('open-recommended'), findsOneWidget);
      expect(byKey('recommended-row'), findsOneWidget);
      expect(find.text('Pomidor'), findsOneWidget);
      expect(find.text('Olma'), findsOneWidget);
      expect(find.text('Banan'), findsNothing, reason: 'not recommended');
    },
  );

  testWidgets('eight of ten categories show, four to a row; "all" opens them '
      'all', (WidgetTester tester) async {
    await open(tester);
    for (int i = 1; i <= 8; i++) {
      expect(byKey('category-c-$i'), findsOneWidget, reason: 'c-$i');
    }
    expect(byKey('category-c-9'), findsNothing);
    expect(byKey('category-c-10'), findsNothing);
    expect(
      top(tester, byKey('category-c-4')),
      top(tester, byKey('category-c-1')),
    );
    expect(
      top(tester, byKey('category-c-5')),
      greaterThan(top(tester, byKey('category-c-1'))),
    );

    await tester.tap(byKey('open-categories'));
    await tester.pumpAndSettle();
    expect(find.byType(AllCategoriesScreen), findsOneWidget);
    expect(byKey('category-c-9'), findsOneWidget);
    expect(byKey('category-c-10'), findsOneWidget);
  });

  testWidgets('a category tile opens the category', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.tap(byKey('category-c-2'));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogHomeScreen), findsNothing);
    expect(catalog.requests.last, '|c-2|1');
  });

  testWidgets('"all" of the recommended opens the recommended products', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.ensureVisible(byKey('open-recommended'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('open-recommended'));
    await tester.pumpAndSettle();
    expect(find.byType(RecommendedScreen), findsOneWidget);
  });

  testWidgets('no recommended section while nothing is recommended', (
    WidgetTester tester,
  ) async {
    catalog.featuredIds = <String>{};
    await open(tester);
    expect(find.text(l10n(tester).recommendedTitle), findsNothing);
    expect(byKey('open-recommended'), findsNothing);
    expect(byKey('category-c-1'), findsOneWidget);
  });

  testWidgets('no recommended section when its request fails', (
    WidgetTester tester,
  ) async {
    catalog.nextFailure = const NetworkFailure();
    await open(tester);
    expect(find.text(l10n(tester).recommendedTitle), findsNothing);
    expect(byKey('category-c-1'), findsOneWidget);
  });

  testWidgets('the filter button asks the sort and opens every product in it', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.tap(byKey('open-sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n(tester).sortPriceAsc));
    await tester.pumpAndSettle();
    expect(find.byType(AllProductsScreen), findsOneWidget);

    // Row-major order of the grid: Olma 3 500, Banan 9 000, Pomidor 18 400.
    final List<String> names = <String>['Olma', 'Banan', 'Pomidor'];
    double place(String name) {
      final Offset at = tester.getTopLeft(find.text(name));
      return at.dy * 1000 + at.dx;
    }

    final List<double> places = names.map(place).toList();
    expect(places, orderedEquals(<double>[...places]..sort()));
  });

  testWidgets('the search field opens the search; no results show under it', (
    WidgetTester tester,
  ) async {
    await open(tester);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(byKey('catalog-search'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    await tester.tap(byKey('search-back'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsNothing);
    expect(byKey('category-c-1'), findsOneWidget);
  });

  testWidgets('dismissing the sort sheet opens nothing', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.tap(byKey('open-sort'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(AllProductsScreen), findsNothing);
    expect(find.byType(CatalogHomeScreen), findsOneWidget);
  });

  testWidgets(
    'the address line shows the label with the street under it, or the '
    'street alone',
    (WidgetTester tester) async {
      addresses.rows = <Address>[
        address(id: 'a-1', label: 'Ish', street: 'Bobur', house: '7'),
      ];
      await open(tester);
      expect(tester.widget<Text>(byKey('delivery-address-value')).data, 'Ish');
      expect(find.text('Bobur, 7'), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
    },
  );

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

  testWidgets('with no address the line asks for one and the tap adds it', (
    WidgetTester tester,
  ) async {
    addresses.rows = <Address>[];
    await open(tester);
    expect(find.text(l10n(tester).deliveryAddressAdd), findsOneWidget);
    expect(find.text(l10n(tester).deliveryAddressEmptyHint), findsOneWidget);
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

  Future<void> saveNewAddress(WidgetTester tester) async {
    await tester.enterText(byKey('field-street'), 'Dacha');
    await tester.enterText(byKey('field-house'), '9');
    await tester.ensureVisible(byKey('address-save'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('address-save'));
    await tester.pumpAndSettle();
  }

  testWidgets('an address added from the sheet becomes the delivery address', (
    WidgetTester tester,
  ) async {
    addresses.rows = <Address>[
      address(id: 'a-1'),
      address(id: 'a-2', label: 'Ish', street: 'Bobur', house: '7'),
    ];
    preferences.values[DeliveryAddressChoice.preferenceKey('c')] = 'a-2';
    await open(tester);
    expect(find.text('Bobur, 7'), findsOneWidget);

    await tester.tap(byKey('delivery-address'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('delivery-address-new'));
    await tester.pumpAndSettle();
    await saveNewAddress(tester);

    expect(byKey('delivery-address'), findsOneWidget, reason: 'back home');
    expect(
      tester.widget<Text>(byKey('delivery-address-value')).data,
      'Dacha, 9',
    );
    expect(
      preferences.values[DeliveryAddressChoice.preferenceKey('c')],
      'a-new-1',
    );
  });

  testWidgets('the first address added from the header becomes the choice', (
    WidgetTester tester,
  ) async {
    addresses.rows = <Address>[];
    await open(tester);
    await tester.tap(find.text(l10n(tester).deliveryAddressAdd));
    await tester.pumpAndSettle();
    await saveNewAddress(tester);

    expect(
      tester.widget<Text>(byKey('delivery-address-value')).data,
      'Dacha, 9',
    );
    expect(
      preferences.values[DeliveryAddressChoice.preferenceKey('c')],
      'a-new-1',
    );
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

  group('centred messages stop above the tab bar', () {
    Future<void> smallPhone(WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }

    void expectClearOfBar(WidgetTester tester, Finder finder) {
      final Rect bar = tester.getRect(find.byType(CustomerTabBar));
      expect(
        tester.getRect(finder).overlaps(bar),
        isFalse,
        reason: 'under the bar',
      );
    }

    testWidgets('sections that failed to load keep their retry above the bar', (
      WidgetTester tester,
    ) async {
      await smallPhone(tester);
      catalog.categoriesFailure = const NetworkFailure();
      await open(tester);

      expect(byKey('retry-load'), findsOneWidget);
      expectClearOfBar(tester, byKey('retry-load'));
    });
  });

  testWidgets('the cart button counts the cart lines and opens the cart', (
    WidgetTester tester,
  ) async {
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
    expect(
      tester.widget<Text>(byKey('cart-count')).data,
      '2',
      reason: 'lines, not the quantity',
    );
    await tester.tap(byKey('open-cart'));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogHomeScreen), findsNothing);
  });

  testWidgets('an empty cart shows no count', (WidgetTester tester) async {
    await open(tester);
    expect(byKey('cart-count'), findsNothing);
  });

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'large text on a small phone: the address sheet and the add and '
      'retry states raise no exception (${device.languageCode})',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        addresses.rows = <Address>[
          address(id: 'a-1'),
          address(
            id: 'a-2',
            label: 'Ota-onamning uyi, Chilonzor tumani',
            street: 'Bunyodkor shoh yo\'li',
          ),
        ];
        await open(tester, device: device);
        await tester.tap(byKey('delivery-address'));
        await tester.pumpAndSettle();
        expect(byKey('delivery-address-sheet'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(byKey('delivery-address-a-1'));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox());
        addresses.rows = <Address>[];
        await open(tester, device: device);
        expect(find.text(l10n(tester).deliveryAddressAdd), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
        addresses.loadFailure = const UnexpectedFailure();
        await open(tester, device: device);
        expect(find.text(l10n(tester).deliveryAddressRetry), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'with the keyboard open at large text and two sessions the header '
      'scrolls inside what is left and nothing overflows '
      '(${device.languageCode})',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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

        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final double above = 640 - 300;
        final Rect header = tester.getRect(byKey('home-header'));
        expect(
          header.height,
          lessThanOrEqualTo(above * CatalogHomeScreen.headerShare + 0.5),
          reason: 'the cap is a share of what the keyboard leaves',
        );
        expect(header.bottom, lessThanOrEqualTo(above));
        await tester.ensureVisible(byKey('catalog-search'));
        await tester.pumpAndSettle();
        final Rect field = tester.getRect(byKey('catalog-search'));
        expect(field.bottom, lessThanOrEqualTo(header.bottom));
        expect(field.top, greaterThanOrEqualTo(header.top));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    for (final bool twoSessions in const <bool>[false, true]) {
      testWidgets(
        'large text on a small phone: the header fits, the mode bar is whole '
        'with its action reachable, and the last section is reachable '
        '(${device.languageCode}, '
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

          // The controls lie in what the header shows, not below its scroll.
          final Rect visible = tester.getRect(byKey('home-header'));
          final List<String> keys = <String>[
            'catalog-search',
            'open-sort',
            'open-cart',
            'delivery-address',
            if (twoSessions) ...<String>[
              'active-mode',
              'switch-to-staff-button',
            ],
          ];
          for (final String key in keys) {
            final Rect rect = tester.getRect(byKey(key));
            expect(rect.top, greaterThanOrEqualTo(visible.top), reason: key);
            expect(rect.bottom, lessThanOrEqualTo(visible.bottom), reason: key);
            expect(rect.left, greaterThanOrEqualTo(0), reason: key);
            expect(rect.right, lessThanOrEqualTo(320), reason: key);
          }
          if (twoSessions) {
            // The part-1 residual: the label is whole, not cut or clipped.
            final String label = l10n(tester).customerModeLabel;
            final Text text = tester.widget<Text>(byKey('active-mode'));
            expect(text.data, label);
            expect(text.overflow, isNull);
            expect(text.maxLines, isNull);
            expect(
              tester.getSize(byKey('active-mode')).height,
              lessThan(tester.getSize(byKey('active-mode')).width),
            );
            await tester.tap(byKey('switch-to-staff-button'));
            await tester.pumpAndSettle();
            expect(find.byType(CatalogHomeScreen), findsNothing);
            expect(tester.takeException(), isNull);
            return;
          }

          await tester.drag(byKey('home-body'), const Offset(0, -2000));
          await tester.pumpAndSettle();
          expect(byKey('recommended-row'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(byKey('category-c-1'));
          await tester.pumpAndSettle();
          await tester.tap(byKey('category-c-1'));
          await tester.pumpAndSettle();
          expect(find.byType(CatalogHomeScreen), findsNothing);
        },
      );
    }
  }
}
