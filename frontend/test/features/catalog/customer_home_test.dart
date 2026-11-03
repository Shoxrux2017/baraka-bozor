import 'dart:async';

import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/customer_tab_bar.dart';
import 'package:baraka_bozor/core/widgets/fold.dart';
import 'package:baraka_bozor/core/widgets/skeleton_bar.dart';
import 'package:baraka_bozor/features/cart/application/cart_controllers.dart';
import 'package:baraka_bozor/features/addresses/application/delivery_address.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:baraka_bozor/features/addresses/presentation/addresses_screens.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/address_map.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/catalog/presentation/all_categories_screen.dart';
import 'package:baraka_bozor/features/catalog/presentation/catalog_paths.dart';
import 'package:baraka_bozor/features/catalog/presentation/home_screen.dart';
import 'package:baraka_bozor/features/catalog/presentation/kit_product_card.dart';
import 'package:baraka_bozor/features/catalog/presentation/recommended_screen.dart';
import 'package:baraka_bozor/features/catalog/presentation/search_screen.dart';
import 'package:baraka_bozor/features/catalog/presentation/section_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/app_harness.dart';
import '../../support/fake_address_map.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_cart_repository.dart';
import '../../support/fake_catalog_repository.dart';
import '../../support/fake_customer_orders_repository.dart';
import '../../support/fake_customer_repositories.dart';
import '../../support/in_memory_stores.dart';
import '../../support/nonlinear_text_scaler.dart';
import '../../support/paragraphs.dart';

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
    FakeCustomerOrdersRepository? orders,
    DateTime Function()? clock,
    bool settle = true,
    TextScaler? textScaler,
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
        orders: orders,
        clock: clock,
        textScaler: textScaler,
        overrides: [addressMapProvider.overrideWithValue(FakeAddressMap())],
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  double top(WidgetTester tester, Finder finder) =>
      tester.getTopLeft(finder).dy;

  Future<void> smallPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> asTwoSessionCustomer(
    WidgetTester tester,
    Locale device, {
    FakeCustomerOrdersRepository? orders,
    DateTime Function()? clock,
    FakeCartRepository? cart,
  }) async {
    tokens.tokens[SessionSlot.staff] = 's';
    auth.identities[SessionSlot.staff] = user(id: 's', role: UserRole.courier);
    await open(
      tester,
      device: device,
      orders: orders,
      clock: clock,
      cart: cart,
    );
    await tester.tap(byKey('staff-menu'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('switch-to-customer-button'));
    await tester.pumpAndSettle();
  }

  final Finder verticalScrollables = find.byWidgetPredicate(
    (Widget w) => w is Scrollable && w.axis == Axis.vertical,
  );

  testWidgets('the tab bar switches to the orders and the profile tabs', (
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
    // The orders tab has no back arrow of its own: the system back goes home.
    expect(find.byType(BackButton), findsNothing);
    await tester.binding.handlePopRoute();
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
    await tester.drag(byKey('home-scroll'), const Offset(0, -2000));
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

  /// Makes [count] products recommended; the row shows ten of them.
  void featureMany(int count) {
    catalog.productRows = <CatalogProduct>[
      for (int i = 1; i <= count; i++)
        catalogProduct(
          id: 'p-$i',
          nameUz: 'Tovar $i',
          nameRu: 'Товар $i',
          customerUnitPriceUzs: 1000 * i,
        ),
    ];
    catalog.featuredIds = <String>{for (int i = 1; i <= count; i++) 'p-$i'};
  }

  Future<void> scrollToRow(WidgetTester tester) async {
    await tester.drag(byKey('home-scroll'), const Offset(0, -2000));
    await tester.pumpAndSettle();
  }

  Finder gridCard(String id) => find.descendant(
    of: find.byType(RecommendedScreen),
    matching: find.byKey(ValueKey<String>(id)),
    skipOffstage: false,
  );

  Finder homeCard(String id) => find.descendant(
    of: byKey('recommended-row'),
    matching: find.byKey(ValueKey<String>(id)),
  );

  /// The opacity the home's «Рекомендуем» title is drawn with.
  double homeTitleOpacity(WidgetTester tester) {
    final Finder title = find.byWidgetPredicate(
      (Widget w) => w is SectionTitle && w.title == 'Рекомендуем',
      skipOffstage: false,
    );
    return tester
        .widget<Opacity>(
          find
              .descendant(
                of: title,
                matching: find.byType(Opacity, skipOffstage: false),
                skipOffstage: false,
              )
              .first,
        )
        .opacity;
  }

  double gridCardOpacity(WidgetTester tester, String id) => tester
      .widget<Opacity>(
        find.ancestor(of: gridCard(id), matching: find.byType(Opacity)).first,
      )
      .opacity;

  testWidgets('the home\'s recommended row keeps its title and "all"', (
    WidgetTester tester,
  ) async {
    featureMany(24);
    await open(tester);
    await scrollToRow(tester);

    expect(find.text(l10n(tester).recommendedTitle), findsOneWidget);
    expect(byKey('recommended-row'), findsOneWidget);
    expect(byKey('open-recommended'), findsOneWidget);
    expect(find.text(l10n(tester).homeSeeAll), findsWidgets);
  });

  testWidgets('Все shows the total and only when the row cannot hold all', (
    WidgetTester tester,
  ) async {
    featureMany(24);
    final SemanticsHandle handle = tester.ensureSemantics();
    await open(tester, device: const Locale('ru'));
    await scrollToRow(tester);

    expect(
      find.descendant(
        of: byKey('open-recommended'),
        matching: find.text('Все 24'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: byKey('open-recommended'),
        matching: find.byIcon(Icons.chevron_right),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(byKey('open-recommended')).label,
      'Все 24 рекомендуемых товара',
    );
    handle.dispose();

    featureMany(10);
    await tester.pumpWidget(const SizedBox());
    await open(tester, device: const Locale('ru'));
    await scrollToRow(tester);
    expect(byKey('recommended-row'), findsOneWidget);
    expect(byKey('open-recommended'), findsNothing);
  });

  testWidgets('Все 24 meets the tap target guideline', (
    WidgetTester tester,
  ) async {
    featureMany(24);
    final SemanticsHandle handle = tester.ensureSemantics();
    await open(tester, device: const Locale('ru'));
    await scrollToRow(tester);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('the visible row cards fly to their grid places and the title '
      'into the header', (WidgetTester tester) async {
    featureMany(24);
    await open(tester, device: const Locale('ru'));
    await scrollToRow(tester);
    final Rect rowCard = tester.getRect(homeCard('p-2'));
    expect(homeTitleOpacity(tester), 1);

    await tester.tap(byKey('open-recommended'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final Rect place = tester.getRect(gridCard('p-2'));
    final Offset copy = tester.getTopLeft(
      find.byKey(const ValueKey<String>('flight-card-p-2')),
    );
    expect(copy.dx, inExclusiveRange(rowCard.left, place.left));
    expect(copy.dy, inExclusiveRange(place.top, rowCard.top));
    expect(
      find.byKey(const ValueKey<String>('flight-card-p-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('flight-card-p-20')),
      findsNothing,
      reason: 'only the row\'s cards fly',
    );
    expect(find.byKey(const ValueKey<String>('flight-title')), findsOneWidget);
    expect(gridCardOpacity(tester, 'p-2'), 0);
    expect(homeTitleOpacity(tester), 0);

    await tester.pump(const Duration(milliseconds: 221));
    expect(gridCardOpacity(tester, 'p-2'), 1);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('flight-card-p-2')), findsNothing);
    expect(homeTitleOpacity(tester), 1);
  });

  testWidgets('back flies them home', (WidgetTester tester) async {
    featureMany(24);
    await open(tester, device: const Locale('ru'));
    await scrollToRow(tester);
    await tester.tap(byKey('open-recommended'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('flight-card-p-2')), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(
      find.byKey(const ValueKey<String>('flight-card-p-2')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('flight-title')), findsOneWidget);
    expect(homeTitleOpacity(tester), 0);

    await tester.pumpAndSettle();
    expect(find.byType(RecommendedScreen), findsNothing);
    expect(homeTitleOpacity(tester), 1);
  });

  testWidgets('with reduced motion Рекомендуем fades in', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    featureMany(24);
    await open(tester, device: const Locale('ru'));
    await scrollToRow(tester);
    await tester.tap(byKey('open-recommended'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(RecommendedScreen), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('flight-card-p-1')), findsNothing);
    expect(find.byKey(const ValueKey<String>('flight-title')), findsNothing);
    final double opacity = tester
        .widget<FadeTransition>(byKey('flight-page-fade'))
        .opacity
        .value;
    expect(opacity, inExclusiveRange(0, 1));
    expect(homeTitleOpacity(tester), 1);
    await tester.pumpAndSettle();
  });

  testWidgets('opened from the search icon it slides in as before', (
    WidgetTester tester,
  ) async {
    featureMany(24);
    await open(tester, device: const Locale('ru'));
    await tester.tap(byKey('catalog-search'));
    await tester.pumpAndSettle();
    // The search screen has no flight to Рекомендуем without the row's tap:
    // a plain push of the route carries no opening.
    final BuildContext context = tester.element(find.byType(Scaffold).last);
    unawaited(GoRouter.of(context).push<void>(CatalogPaths.recommended));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey<String>('flight-page-fade')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey<String>('flight-card-p-1')), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(RecommendedScreen), findsOneWidget);
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
      expect(byKey('open-sort'), findsNothing);
      expect(
        top(tester, byKey('catalog-search')),
        lessThan(top(tester, find.text(words.homeCategories))),
      );
      expect(
        top(tester, find.text(words.homeCategories)),
        lessThan(top(tester, find.text(words.recommendedTitle))),
      );
      expect(byKey('open-categories'), findsOneWidget);
      expect(
        byKey('open-recommended'),
        findsNothing,
        reason: 'two products: the row holds them all',
      );
      expect(byKey('recommended-row'), findsOneWidget);
      expect(find.text('Pomidor'), findsOneWidget);
      expect(find.text('Olma'), findsOneWidget);
      expect(find.text('Banan'), findsNothing, reason: 'not recommended');
    },
  );

  testWidgets('eight of ten categories show; "all" opens them all', (
    WidgetTester tester,
  ) async {
    await open(tester);
    for (int i = 1; i <= 8; i++) {
      expect(byKey('category-c-$i'), findsOneWidget, reason: 'c-$i');
    }
    expect(byKey('category-c-9'), findsNothing);
    expect(byKey('category-c-10'), findsNothing);

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
    featureMany(24);
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

  testWidgets('a failed recommended request keeps still skeletons under the '
      'line', (WidgetTester tester) async {
    catalog.nextFailure = const NetworkFailure();
    await open(tester, device: const Locale('ru'));
    // The row keeps still skeletons under the line; the categories stay.
    expect(byKey('recommended-skeletons'), findsOneWidget);
    expect(byKey('recommended-row'), findsNothing);
    expect(
      tester
          .widgetList<SkeletonBar>(
            find.descendant(
              of: byKey('recommended-skeletons'),
              matching: find.byType(SkeletonBar),
            ),
          )
          .any((SkeletonBar b) => b.pulsing),
      isFalse,
    );
    expect(find.textContaining('Нет связи'), findsOneWidget);
    expect(byKey('category-c-1'), findsOneWidget);
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
    await tester.tap(byKey('address-point-confirm'));
    await tester.pumpAndSettle();
    await tester.enterText(byKey('field-street'), 'Dacha');
    await tester.enterText(byKey('field-house'), '9');
    await tester.scrollUntilVisible(
      byKey('address-save'),
      200,
      scrollable: find
          .descendant(
            of: byKey('address-form'),
            matching: find.byType(Scrollable),
          )
          .first,
    );
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

      expect(byKey('stale-retry'), findsOneWidget);
      expectClearOfBar(tester, byKey('stale-retry'));
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

  testWidgets('the home keeps the ink bag and its badge bumps when the cart '
      'grows', (WidgetTester tester) async {
    final FakeCartRepository cart = FakeCartRepository(
      cart: cartOf(<Map<String, Object?>>[cartLineJson()]),
    );
    await open(tester, cart: cart);

    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: byKey('open-cart'),
              matching: find.byIcon(Icons.shopping_bag_outlined),
            ),
          )
          .color,
      KitColors.ink,
    );
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(byKey('open-cart')),
    );
    container
        .read(cartProvider(container.read(customerAccountProvider)!).notifier)
        .show(
          cartOf(<Map<String, Object?>>[
            cartLineJson(),
            cartLineJson(id: breadLine, productId: breadProduct, unit: 'piece'),
          ]),
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      tester.widget<ScaleTransition>(byKey('cart-badge-bump')).scale.value,
      closeTo(1.3, 0.01),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('every target meets iOSTapTargetGuideline', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await open(tester);

    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
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
      'scrolls with the page and nothing overflows (${device.languageCode})',
      (WidgetTester tester) async {
        await smallPhone(tester);
        await asTwoSessionCustomer(tester, device);

        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(verticalScrollables, findsOneWidget);
        final double above = 640 - 300;
        final Rect scroll = tester.getRect(byKey('home-scroll'));
        expect(scroll.bottom, lessThanOrEqualTo(above));
        await tester.drag(byKey('home-scroll'), const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(byKey('catalog-search')).dy,
          tester.getTopLeft(byKey('home-scroll')).dy + 8,
          reason: 'the search sticks inside what the keyboard leaves',
        );
        expect(byKey('catalog-search').hitTestable(), findsOneWidget);
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
          final Rect visible = tester.getRect(byKey('home-scroll'));
          final List<String> keys = <String>[
            'catalog-search',
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

          await tester.drag(byKey('home-scroll'), const Offset(0, -2000));
          await tester.pumpAndSettle();
          expect(byKey('recommended-row'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.drag(byKey('home-scroll'), const Offset(0, 2000));
          await tester.pumpAndSettle();
          await tester.tap(byKey('category-c-1'));
          await tester.pumpAndSettle();
          expect(find.byType(CatalogHomeScreen), findsNothing);
        },
      );
    }
  }

  testWidgets('the search entry exposes a tap action', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await open(tester);

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );
    for (final (String, String) entry in <(String, String)>[
      ('catalog-search', l10n.catalogSearchSpoken),
    ]) {
      final String key = entry.$1;
      final String label = entry.$2;
      expect(
        tester.getSemantics(byKey(key)),
        matchesSemantics(isButton: true, hasTapAction: true, label: label),
        reason: key,
      );
    }
    handle.dispose();
  });

  Map<String, Object?> pendingRow() => <String, Object?>{
    'id': approvalOne,
    'order_id': orderOne,
    'order_number': 1001,
    'expires_at': '2026-11-02T09:00:00Z',
  };

  Future<void> pull(WidgetTester tester) async {
    await tester.drag(byKey('home-scroll'), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  Iterable<String> announced(WidgetTester tester) => tester
      .takeAnnouncements()
      .map((CapturedAccessibilityAnnouncement a) => a.message);

  for (final Locale device in const <Locale>[Locale('ru'), Locale('uz')]) {
    testWidgets(
      'one scroll: at text x2 with two sessions and a question the address '
      'scrolls away and the search sticks (${device.languageCode})',
      (WidgetTester tester) async {
        await smallPhone(tester);
        WidgetController.hitTestWarningShouldBeFatal = true;
        addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
        final FakeCustomerOrdersRepository orders =
            FakeCustomerOrdersRepository()
              ..pendingRows = <Map<String, Object?>>[pendingRow()];
        await asTwoSessionCustomer(
          tester,
          device,
          orders: orders,
          clock: () => DateTime.utc(2026, 11, 2, 8),
        );

        expect(verticalScrollables, findsOneWidget);
        expect(byKey('question-banner'), findsOneWidget);
        expect(byKey('delivery-address').hitTestable(), findsOneWidget);

        await tester.drag(byKey('home-scroll'), const Offset(0, -400));
        await tester.pumpAndSettle();

        expect(top(tester, byKey('catalog-search')), 8);
        expect(byKey('catalog-search').hitTestable(), findsOneWidget);
        expect(byKey('delivery-address').hitTestable(), findsNothing);
        final Rect title = tester.getRect(
          find.text(l10n(tester).homeCategories),
        );
        expect(title.top, greaterThanOrEqualTo(0));
        expect(title.bottom, lessThanOrEqualTo(640));
        expect(tester.takeException(), isNull);

        await tester.drag(byKey('home-scroll'), const Offset(0, 400));
        await tester.pumpAndSettle();
        expect(byKey('switch-to-staff-button').hitTestable(), findsOneWidget);
      },
    );
  }

  BoxDecoration searchDecoration(WidgetTester tester) =>
      tester
              .widget<AnimatedContainer>(
                find.descendant(
                  of: byKey('home-search-bar'),
                  matching: find.byType(AnimatedContainer),
                ),
              )
              .decoration!
          as BoxDecoration;

  testWidgets('the search sticks with a shadow only once scrolled', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open(tester);

    expect(searchDecoration(tester).boxShadow ?? const <BoxShadow>[], isEmpty);
    await tester.drag(byKey('home-scroll'), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(top(tester, byKey('catalog-search')), lessThan(20));
    expect(searchDecoration(tester).boxShadow, const <BoxShadow>[
      BoxShadow(
        color: Color(0x59151D16),
        offset: Offset(0, 8),
        blurRadius: 12,
        spreadRadius: -10,
      ),
    ]);
    await tester.drag(byKey('home-scroll'), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(searchDecoration(tester).boxShadow ?? const <BoxShadow>[], isEmpty);
  });

  testWidgets('no filter button; the search takes the full width', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open(tester);

    expect(byKey('open-sort'), findsNothing);
    expect(find.byIcon(Icons.tune), findsNothing);
    final Rect field = tester.getRect(byKey('catalog-search'));
    expect(field.left, 16);
    expect(field.right, 320 - 16);
  });

  testWidgets(
    'loading shows bars for the address, eight tiles and three cards, then '
    'the data fades in',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(520, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addresses.loadHold = Completer<void>();
      catalog.categoriesGate = Completer<void>();
      catalog.gates[''] = Completer<void>();
      await open(tester, settle: false);
      await tester.pump(const Duration(milliseconds: 50));

      final Finder address = find.descendant(
        of: byKey('delivery-address'),
        matching: find.byType(SkeletonBar),
      );
      expect(
        tester
            .widgetList<SkeletonBar>(address)
            .map((SkeletonBar b) => (b.width, b.height, b.pulsing)),
        <(double, double, bool)>[(90, 14, true), (170, 10, true)],
      );
      expect(find.text('…'), findsNothing);
      expect(
        find.descendant(
          of: byKey('category-skeletons'),
          matching: find.byType(SkeletonBar),
        ),
        findsNWidgets(16),
        reason: 'eight tiles, a picture and a name each',
      );
      expect(
        find.descendant(
          of: byKey('recommended-skeletons'),
          matching: find.byType(SkeletonBar),
        ),
        findsNWidgets(12),
        reason: 'three cards of four bars',
      );
      expect(find.text(l10n(tester).recommendedTitle), findsOneWidget);
      expect(byKey('category-c-1'), findsNothing);

      addresses.loadHold!.complete();
      catalog.categoriesGate!.complete();
      catalog.gates['']!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester
            .widget<SliverFadeTransition>(find.byType(SliverFadeTransition))
            .opacity
            .value,
        inExclusiveRange(0, 1),
      );
      expect(
        tester.widget<Opacity>(byKey('recommended-fade')).opacity,
        inExclusiveRange(0, 1),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonBar), findsNothing);
      expect(byKey('category-c-1'), findsOneWidget);
      expect(byKey('recommended-row'), findsOneWidget);
      expect(find.text('Amir Temur, 12'), findsOneWidget);
    },
  );

  testWidgets('pull to refresh reloads the categories and the recommended', (
    WidgetTester tester,
  ) async {
    final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository();
    final FakeCartRepository cart = FakeCartRepository();
    await open(tester, orders: orders, cart: cart);
    final int categories = catalog.categoryLoads;
    final int products = catalog.requests.length;
    int count(List<String> log, String entry) =>
        log.where((String l) => l == entry).length;
    final int questions = count(orders.loads, 'pending');
    final int carts = count(cart.calls, 'cart');

    await pull(tester);

    expect(catalog.categoryLoads, categories + 1);
    expect(catalog.requests.length, products + 1);
    expect(count(orders.loads, 'pending'), questions + 1);
    expect(count(cart.calls, 'cart'), carts + 1);
    expect(announced(tester), contains('Yangilandi'));
  });

  testWidgets(
    'offline after a load keeps everything under Нет связи · данные на 12:46',
    (WidgetTester tester) async {
      DateTime at = DateTime.utc(2026, 11, 2, 7, 46);
      final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository()
        ..pendingRows = <Map<String, Object?>>[pendingRow()];
      await open(
        tester,
        device: const Locale('ru'),
        clock: () => at,
        orders: orders,
      );
      expect(byKey('stale-line'), findsNothing);

      // Half an hour on: the line still names the first load's time.
      at = at.add(const Duration(minutes: 30));
      catalog.categoriesFailure = const NetworkFailure();
      await pull(tester);

      expect(find.text('Нет связи · данные на 12:46'), findsOneWidget);
      expect(byKey('category-c-1'), findsOneWidget);
      expect(byKey('recommended-row'), findsOneWidget);
      expect(byKey('question-banner'), findsOneWidget);
      expect(
        announced(tester),
        contains('Нет связи. Показаны данные на 12:46'),
      );

      await pull(tester);
      expect(byKey('stale-line'), findsNothing);
      expect(announced(tester), contains('Обновлено'));
    },
  );

  testWidgets('the recommended failing alone shows the line over the data', (
    WidgetTester tester,
  ) async {
    await open(tester, device: const Locale('ru'));
    catalog.nextFailure = const UnexpectedFailure();
    await pull(tester);

    expect(byKey('stale-line'), findsOneWidget);
    expect(byKey('category-c-1'), findsOneWidget);
    expect(byKey('recommended-row'), findsOneWidget);
  });

  testWidgets('a first load that fails shows Нет связи · Повторить over still '
      'skeletons', (WidgetTester tester) async {
    catalog.categoriesFailure = const NetworkFailure();
    await open(tester, device: const Locale('ru'));

    expect(find.text('Нет связи'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    final Finder tiles = find.descendant(
      of: byKey('category-skeletons'),
      matching: find.byType(SkeletonBar),
    );
    expect(tiles, findsNWidgets(16));
    expect(
      tester.widgetList<SkeletonBar>(tiles).any((SkeletonBar b) => b.pulsing),
      isFalse,
    );
    expect(byKey('recommended-row'), findsOneWidget, reason: 'it came');

    await tester.tap(byKey('stale-retry'));
    await tester.pumpAndSettle();
    expect(byKey('stale-line'), findsNothing);
    expect(byKey('category-c-1'), findsOneWidget);
    expect(find.byType(SkeletonBar), findsNothing);
  });

  for (final Locale device in const <Locale>[Locale('ru'), Locale('uz')]) {
    testWidgets(
      'at text x2 the categories stand in two columns and the cards are 260 '
      'wide with the price whole (${device.languageCode})',
      (WidgetTester tester) async {
        await smallPhone(tester);
        await loadMontserrat();
        await open(tester, device: device);

        expect(
          top(tester, byKey('category-c-2')),
          top(tester, byKey('category-c-1')),
        );
        expect(
          top(
            tester,
            find.byKey(
              const ValueKey<String>('category-c-3'),
              skipOffstage: false,
            ),
          ),
          greaterThan(top(tester, byKey('category-c-1'))),
        );
        await tester.drag(byKey('home-scroll'), const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.getSize(byKey('p-1')).width, 260);

        final Finder price = find.descendant(
          of: byKey('p-1'),
          matching: find.byWidgetPredicate(
            (Widget w) => w is Text && (w.data ?? '').startsWith('≈'),
          ),
        );
        expect(
          tester.renderObject<RenderParagraph>(price).didExceedMaxLines,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('lying at 812 eight categories stand in one row', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(812, 375);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open(tester);

    final double first = top(tester, byKey('category-c-1'));
    for (int i = 2; i <= 8; i++) {
      expect(top(tester, byKey('category-c-$i')), first, reason: 'c-$i');
    }
    expect(tester.takeException(), isNull);
  });

  group('for a screen reader (DL-125)', () {
    testWidgets('the address says доставка', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await open(tester, device: const Locale('ru'));

      expect(
        tester.getSemantics(byKey('delivery-address')),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          label: 'Адрес доставки: Uy, Amir Temur, 12. Изменить',
        ),
      );
      handle.dispose();
    });

    testWidgets('the address with a label reads label, then street', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      addresses.rows = <Address>[
        address(id: 'a-1', label: 'Ish', street: 'Bobur', house: '7'),
      ];
      await open(tester, device: const Locale('ru'));

      expect(
        tester.getSemantics(byKey('delivery-address')).label,
        'Адрес доставки: Ish, Bobur, 7. Изменить',
      );
      handle.dispose();
    });

    testWidgets('«Все» says what it opens and the titles are headings', (
      WidgetTester tester,
    ) async {
      featureMany(24);
      final SemanticsHandle handle = tester.ensureSemantics();
      await open(tester, device: const Locale('ru'));

      expect(
        tester.getSemantics(byKey('open-categories')).label,
        'Все категории',
      );
      expect(
        tester.getSemantics(byKey('open-recommended')).label,
        'Все 24 рекомендуемых товара',
      );
      for (final String title in <String>['Категории', 'Рекомендуем']) {
        expect(
          tester
              .getSemantics(find.text(title))
              .getSemanticsData()
              .flagsCollection
              .isHeader,
          isTrue,
          reason: title,
        );
      }
      handle.dispose();
    });

    testWidgets('the search reads Поиск товаров', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await open(tester, device: const Locale('ru'));

      expect(
        tester.getSemantics(byKey('catalog-search')),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          label: 'Поиск товаров',
        ),
      );
      handle.dispose();
    });
  });

  group('the question banner', () {
    late DateTime now;
    late FakeCustomerOrdersRepository orders;
    late List<MethodCall> platformCalls;

    Map<String, Object?> row({
      String approval = approvalOne,
      int number = 1044,
      String expires = '2026-11-02T07:09:00Z',
    }) => <String, Object?>{
      'id': approval,
      'order_id': orderOne,
      'order_number': number,
      'expires_at': expires,
    };

    setUp(() {
      now = DateTime.utc(2026, 11, 2, 7);
      orders = FakeCustomerOrdersRepository();
      platformCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall call,
          ) async {
            platformCalls.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
    });

    Future<void> home(WidgetTester tester) => open(
      tester,
      device: const Locale('ru'),
      orders: orders,
      clock: () => now,
    );

    /// Moves the clock and the fake time together.
    Future<void> advance(WidgetTester tester, Duration by) async {
      now = now.add(by);
      await tester.pump(by);
    }

    int buzzes() => platformCalls
        .where(
          (MethodCall c) =>
              c.method == 'HapticFeedback.vibrate' &&
              c.arguments == 'HapticFeedbackType.lightImpact',
        )
        .length;

    Iterable<String> said(WidgetTester tester) => tester
        .takeAnnouncements()
        .map((CapturedAccessibilityAnnouncement a) => a.message);

    double unfolded(WidgetTester tester) => tester
        .widget<Align>(
          find
              .descendant(of: find.byType(Fold), matching: find.byType(Align))
              .first,
        )
        .heightFactor!;

    testWidgets('a question that arrives unfolds, buzzes and is announced', (
      WidgetTester tester,
    ) async {
      await home(tester);
      expect(byKey('question-banner'), findsNothing);
      tester.takeAnnouncements();

      orders.pendingRows = <Map<String, Object?>>[row()];
      await advance(tester, const Duration(seconds: 30));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(byKey('question-banner'), findsOneWidget);
      expect(unfolded(tester), inExclusiveRange(0, 1));
      expect(buzzes(), 1);
      expect(
        said(tester),
        contains('Сборщик спрашивает про заказ № 1044. осталось 9 минут'),
      );
      await tester.pumpAndSettle();
      expect(unfolded(tester), 1);
    });

    testWidgets('a question known at the first build stands still and silent', (
      WidgetTester tester,
    ) async {
      orders.pendingRows = <Map<String, Object?>>[row()];
      await home(tester);

      expect(byKey('question-banner'), findsOneWidget);
      expect(unfolded(tester), 1);
      expect(buzzes(), 0);
      expect(said(tester), isEmpty);
    });

    testWidgets(
      'Осталось 9 мин turns red at 3 and the banner folds at its expiry',
      (WidgetTester tester) async {
        orders.pendingRows = <Map<String, Object?>>[row()];
        await home(tester);
        Color chipColor(String text) =>
            tester.widget<Text>(find.text(text)).style!.color!;

        expect(find.text('Осталось 9 мин'), findsOneWidget);
        expect(chipColor('Осталось 9 мин'), KitColors.warningDark);
        expect(byKey('orders-badge'), findsOneWidget);

        await advance(tester, const Duration(minutes: 6, seconds: 30));
        expect(find.text('Осталось 3 мин'), findsOneWidget);
        expect(chipColor('Осталось 3 мин'), KitColors.danger);
        tester.takeAnnouncements();

        await advance(tester, const Duration(minutes: 2, seconds: 30));
        expect(byKey('orders-badge'), findsNothing, reason: 'the same pump');
        expect(said(tester), contains('Время на ответ вышло'));
        await tester.pumpAndSettle();
        expect(byKey('question-banner'), findsNothing);
      },
    );

    testWidgets('an answered question folds without a word', (
      WidgetTester tester,
    ) async {
      orders.pendingRows = <Map<String, Object?>>[row()];
      await home(tester);
      tester.takeAnnouncements();

      orders.pendingRows = <Map<String, Object?>>[];
      await advance(tester, const Duration(seconds: 30));
      await tester.pumpAndSettle();

      expect(byKey('question-banner'), findsNothing);
      expect(byKey('orders-badge'), findsNothing);
      expect(said(tester), isEmpty);
    });

    testWidgets('the banner is one stop that opens the order', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      orders.pendingRows = <Map<String, Object?>>[row()];
      await home(tester);

      expect(
        tester.getSemantics(byKey('question-banner')),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          label:
              'Сборщик ждёт вашего ответа. Заказ № 1044, осталось 9 минут. '
              'Ответить',
        ),
      );
      await tester.tap(byKey('question-banner'));
      await tester.pumpAndSettle();
      expect(find.byType(CatalogHomeScreen), findsNothing);
      handle.dispose();
    });

    testWidgets('with reduced motion it stands and goes at once', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await home(tester);

      orders.pendingRows = <Map<String, Object?>>[row()];
      await advance(tester, const Duration(seconds: 30));
      await tester.pump();
      expect(byKey('question-banner'), findsOneWidget);
      expect(unfolded(tester), 1);

      orders.pendingRows = <Map<String, Object?>>[];
      await advance(tester, const Duration(seconds: 30));
      await tester.pump();
      await tester.pump();
      expect(byKey('question-banner'), findsNothing);
    });
  });

  group('closed', () {
    late DateTime now;
    late FakeCartRepository cart;

    /// A Tashkent wall-clock time as an instant.
    DateTime tashkent(int hour, int minute) => DateTime.utc(
      2026,
      11,
      2,
      hour,
      minute,
    ).subtract(const Duration(hours: 5));

    const Map<String, Object?> daytime = <String, Object?>{
      'opens_at': '08:00',
      'closes_at': '22:00',
    };

    Future<void> home(
      WidgetTester tester, {
      Map<String, Object?>? hours = daytime,
      Locale device = const Locale('ru'),
    }) {
      cart = FakeCartRepository(
        cart: cartOf(<Map<String, Object?>>[], workingHours: hours),
      );
      return open(tester, device: device, cart: cart, clock: () => now);
    }

    Future<void> advance(WidgetTester tester, Duration by) async {
      now = now.add(by);
      await tester.pump(by);
    }

    testWidgets('at night the home says it is closed and when it opens', (
      WidgetTester tester,
    ) async {
      now = tashkent(23, 10);
      await home(tester);

      expect(byKey('store-closed'), findsOneWidget);
      expect(
        find.text(
          'Сейчас закрыто. Заказ примем сейчас, соберём и привезём с 8:00',
        ),
        findsOneWidget,
      );
      expect(
        top(tester, byKey('store-closed')),
        greaterThan(top(tester, byKey('catalog-search'))),
        reason: 'right under the search',
      );
    });

    testWidgets('the line folds away at opening while the home is shown', (
      WidgetTester tester,
    ) async {
      now = tashkent(7, 59);
      await home(tester);
      expect(byKey('store-closed'), findsOneWidget);

      await advance(tester, const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(byKey('store-closed'), findsNothing);
    });

    testWidgets('it comes at closing while the home is shown', (
      WidgetTester tester,
    ) async {
      now = tashkent(21, 59);
      await home(tester);
      expect(byKey('store-closed'), findsNothing);

      await advance(tester, const Duration(minutes: 1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(byKey('store-closed'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(byKey('store-closed'), findsOneWidget);
    });

    testWidgets('no line while open, always open or unset', (
      WidgetTester tester,
    ) async {
      now = tashkent(12, 0);
      await home(tester);
      expect(byKey('store-closed'), findsNothing);

      now = tashkent(23, 10);
      await tester.pumpWidget(const SizedBox());
      await home(tester, hours: null);
      expect(byKey('store-closed'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await home(
        tester,
        hours: <String, Object?>{'opens_at': '00:00', 'closes_at': '23:59'},
      );
      expect(byKey('store-closed'), findsNothing);
    });

    testWidgets('the line is one phrase', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      now = tashkent(23, 10);
      await home(tester);

      expect(
        tester.getSemantics(byKey('store-closed')).label,
        'Сейчас закрыто. Заказ примем сейчас, соберём и привезём с 8:00',
      );
      handle.dispose();
    });

    testWidgets('the line speaks Uzbek', (WidgetTester tester) async {
      now = tashkent(23, 10);
      await home(tester, device: const Locale('uz'));

      expect(
        find.text(
          "Hozir yopiq. Buyurtmani hozir qabul qilamiz, soat 8:00 dan yig'ib, "
          'yetkazib beramiz',
        ),
        findsOneWidget,
      );
    });
  });

  for (final Locale device in const <Locale>[Locale('ru'), Locale('uz')]) {
    for (final double scale in <double>[1, 2]) {
      testWidgets('every target of the home meets iOSTapTargetGuideline '
          '(text x$scale, ${device.languageCode})', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle semantics = tester.ensureSemantics();
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        // 23:10 in Tashkent: the store is closed; the question runs on.
        final DateTime night = DateTime.utc(2026, 11, 2, 18, 10);
        final FakeCustomerOrdersRepository orders =
            FakeCustomerOrdersRepository()
              ..pendingRows = <Map<String, Object?>>[
                <String, Object?>{
                  'id': approvalOne,
                  'order_id': orderOne,
                  'order_number': 1044,
                  'expires_at': '2026-11-02T19:00:00Z',
                },
              ];
        // The recommended products fail: the stale line shows over the data.
        catalog.nextFailure = const UnexpectedFailure();
        await asTwoSessionCustomer(
          tester,
          device,
          orders: orders,
          clock: () => night,
          cart: FakeCartRepository(
            cart: cartOf(
              <Map<String, Object?>>[],
              workingHours: <String, Object?>{
                'opens_at': '08:00',
                'closes_at': '22:00',
              },
            ),
          ),
        );
        // At the top of the page, then scrolled until the question has gone
        // under the search and the stale line shows whole: a target half
        // under the pinned search is clipped, which no screen can avoid.
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        final ScrollPosition position = tester
            .state<ScrollableState>(verticalScrollables)
            .position;
        final double searchBottom =
            tester.getRect(byKey('catalog-search')).bottom + 8;
        position.jumpTo(
          position.pixels +
              tester
                  .getRect(
                    find.byKey(
                      const ValueKey<String>('question-banner'),
                      skipOffstage: false,
                    ),
                  )
                  .bottom -
              searchBottom +
              1,
        );
        await tester.pumpAndSettle();
        expect(byKey('stale-line'), findsOneWidget);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        semantics.dispose();
      });
    }
  }

  group('the final review', () {
    testWidgets('the search hint is not clipped at text x2 (P2-1)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await loadMontserrat();
      await open(tester, device: const Locale('ru'));

      final RenderParagraph hint = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: byKey('catalog-search'),
          matching: find.text('Найти: огурцы, лепёшки…'),
        ),
      );
      final double field = tester.getSize(byKey('catalog-search')).height;
      expect(
        field,
        greaterThanOrEqualTo(hint.size.height + 28 - 0.01),
        reason: 'the field holds the hint with its 14 padding above and below',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a retry after a failure shows its progress (P2-2)', (
      WidgetTester tester,
    ) async {
      catalog.categoriesFailure = const NetworkFailure();
      await open(tester, device: const Locale('ru'));
      final int loads = catalog.categoryLoads;
      catalog.categoriesGate = Completer<void>();

      await tester.tap(byKey('stale-retry'));
      await tester.pump();

      expect(
        tester
            .widgetList<SkeletonBar>(
              find.descendant(
                of: byKey('category-skeletons'),
                matching: find.byType(SkeletonBar),
              ),
            )
            .every((SkeletonBar b) => b.pulsing),
        isTrue,
      );
      expect(
        find.descendant(
          of: byKey('stale-retry'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(tester.widget<TextButton>(byKey('stale-retry')).onPressed, isNull);
      expect(
        tester.getSize(byKey('stale-retry')).height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(byKey('stale-retry'), warnIfMissed: false);
      await tester.pump();
      expect(catalog.categoryLoads, loads + 1, reason: 'one request');

      catalog.categoriesGate!.complete();
      await tester.pumpAndSettle();
      expect(byKey('stale-line'), findsNothing);
      expect(byKey('category-c-1'), findsOneWidget);
    });

    testWidgets('a retry over kept data is busy and starts one request', (
      WidgetTester tester,
    ) async {
      await open(tester, device: const Locale('ru'));
      catalog.categoriesFailure = const NetworkFailure();
      await pull(tester);
      expect(byKey('stale-line'), findsOneWidget);
      final int loads = catalog.categoryLoads;
      catalog.categoriesGate = Completer<void>();

      await tester.tap(byKey('stale-retry'));
      await tester.pump();
      expect(
        find.descendant(
          of: byKey('stale-retry'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      await tester.tap(byKey('stale-retry'), warnIfMissed: false);
      await tester.pump();
      expect(catalog.categoryLoads, loads + 1);

      catalog.categoriesGate!.complete();
      await tester.pumpAndSettle();
      expect(byKey('stale-line'), findsNothing);
    });

    Future<void> backToTheApp(WidgetTester tester) async {
      for (final AppLifecycleState state in <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
    }

    testWidgets('the closed line re-reads the clock when the app resumes '
        '(P2-3)', (WidgetTester tester) async {
      DateTime now = DateTime.utc(2026, 11, 2, 2, 59); // 07:59 in Tashkent
      cartWithHours() => FakeCartRepository(
        cart: cartOf(
          <Map<String, Object?>>[],
          workingHours: <String, Object?>{
            'opens_at': '08:00',
            'closes_at': '22:00',
          },
        ),
      );
      await open(
        tester,
        device: const Locale('ru'),
        cart: cartWithHours(),
        clock: () => now,
      );
      expect(byKey('store-closed'), findsOneWidget);

      // The device slept past opening: no timer ran.
      now = DateTime.utc(2026, 11, 2, 3, 30);
      await backToTheApp(tester);
      await tester.pumpAndSettle();
      expect(byKey('store-closed'), findsNothing);
    });

    testWidgets('an expired question drops at once when the app resumes '
        '(P2-3)', (WidgetTester tester) async {
      DateTime now = DateTime.utc(2026, 11, 2, 7);
      final FakeCustomerOrdersRepository orders = FakeCustomerOrdersRepository()
        ..pendingRows = <Map<String, Object?>>[
          <String, Object?>{
            'id': approvalOne,
            'order_id': orderOne,
            'order_number': 1044,
            'expires_at': '2026-11-02T07:09:00Z',
          },
        ];
      await open(
        tester,
        device: const Locale('ru'),
        orders: orders,
        clock: () => now,
      );
      expect(byKey('orders-badge'), findsOneWidget);

      now = DateTime.utc(2026, 11, 2, 7, 30);
      await backToTheApp(tester);
      expect(byKey('orders-badge'), findsNothing);
      await tester.pumpAndSettle();
      expect(byKey('question-banner'), findsNothing);
    });
  });

  group("Android's nonlinear text at 200 %", () {
    Future<void> android(WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await loadMontserrat();
      await open(
        tester,
        device: const Locale('ru'),
        textScaler: const NonlinearTextScaler(2),
      );
    }

    testWidgets("with Android's nonlinear text at 200 % the home's categories "
        'stand in two columns', (WidgetTester tester) async {
      await android(tester);

      expect(
        top(tester, byKey('category-c-2')),
        top(tester, byKey('category-c-1')),
      );
      expect(
        top(
          tester,
          find.byKey(
            const ValueKey<String>('category-c-3'),
            skipOffstage: false,
          ),
        ),
        greaterThan(top(tester, byKey('category-c-1'))),
      );
    });

    testWidgets("with Android's nonlinear text at 200 % the recommended cards "
        'are 260 wide with the price whole', (WidgetTester tester) async {
      await android(tester);
      await tester.drag(byKey('home-scroll'), const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(tester.getSize(byKey('p-1')).width, 260);
      final Finder price = find.descendant(
        of: byKey('p-1'),
        matching: find.byWidgetPredicate(
          (Widget w) => w is Text && (w.data ?? '').startsWith('≈'),
        ),
      );
      expect(
        tester.renderObject<RenderParagraph>(price).didExceedMaxLines,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
