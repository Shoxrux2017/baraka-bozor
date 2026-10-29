import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/widgets/customer_tab_bar.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/address_map.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/catalog/presentation/home_screen.dart';
import 'package:baraka_bozor/features/favorites/domain/favorites.dart';
import 'package:baraka_bozor/features/favorites/presentation/favorites_screen.dart';
import 'package:baraka_bozor/features/orders/presentation/order_cards.dart';
import 'package:baraka_bozor/features/orders/presentation/orders_screens.dart';
import 'package:baraka_bozor/features/profile/domain/profile.dart';
import 'package:baraka_bozor/features/profile/presentation/edit_profile_screen.dart';
import 'package:baraka_bozor/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_address_map.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_cart_repository.dart';
import '../../../support/fake_catalog_repository.dart';
import '../../../support/fake_checkout_repository.dart';
import '../../../support/fake_customer_orders_repository.dart';
import '../../../support/fake_customer_repositories.dart';
import '../../../support/fake_favorites_repository.dart';
import '../../../support/in_memory_stores.dart';

/// The Customer's four tabs in one shell (`DL-118`), through the real router.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCatalogRepository catalog;
  late FakeFavoritesRepository favorites;
  late FakeCustomerOrdersRepository orders;
  late FakeProfileRepository profile;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  FavoriteProduct favorite(int i) => FavoriteProduct(
    product: catalogProduct(
      id: 'f-$i',
      nameUz: 'Mahsulot $i',
      nameRu: 'Товар $i',
      isFavorite: true,
    ),
    isAvailable: true,
  );

  setUp(() {
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    catalog = FakeCatalogRepository(
      products: <CatalogProduct>[catalogProduct()],
    )..featuredIds = <String>{'p-1'};
    favorites = FakeFavoritesRepository(
      favorites: <FavoriteProduct>[for (int i = 0; i < 30; i++) favorite(i)],
    );
    orders = FakeCustomerOrdersRepository();
    profile = FakeProfileRepository()
      ..current = const CustomerProfile(
        id: 'c',
        phone: '+998901234567',
        fullName: 'Dilnoza',
        supportPhone: '+998712000000',
      );
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = user(id: 'c');
  });

  Future<void> open(
    WidgetTester tester, {
    FakeCartRepository? cart,
    FakeAddressesRepository? addresses,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        catalog: catalog,
        cart: cart,
        addresses: addresses,
        favorites: favorites,
        orders: orders,
        profile: profile,
        overrides: [addressMapProvider.overrideWithValue(FakeAddressMap())],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tab(WidgetTester tester, String key) async {
    await tester.tap(byKey(key));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  GoRouter routerOf(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Scaffold).first));

  double gridPixels(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(
          of: byKey('favorites-grid'),
          matching: find.byType(Scrollable),
        ),
      )
      .position
      .pixels;

  testWidgets('a tab keeps its place: the same scroll and no new load', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tab(tester, 'open-favorites');
    await tester.drag(byKey('favorites-grid'), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(gridPixels(tester), 400);

    await tab(tester, 'open-home');
    await tab(tester, 'open-favorites');

    expect(gridPixels(tester), 400);
    expect(favorites.listLoads, 1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a switch is instant', (WidgetTester tester) async {
    await open(tester);

    await tester.tap(byKey('open-orders'));
    await tester.pump();

    expect(find.byType(OrdersScreen), findsOneWidget);
    expect(find.byType(CatalogHomeScreen), findsNothing);
  });

  testWidgets('a tab keeps its data after a heart elsewhere', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tab(tester, 'open-favorites');
    await tab(tester, 'open-home');
    await tester.tap(byKey('heart-p-1'));
    await tester.pumpAndSettle();

    await tester.tap(byKey('open-favorites'));
    await tester.pump();

    expect(find.byType(FavoritesScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(byKey('favorites-grid'), findsOneWidget);
  });

  testWidgets(
    'the system back on a tab goes home; on the home nothing is left to pop',
    (WidgetTester tester) async {
      await open(tester);
      await tab(tester, 'open-profile');
      expect(find.byType(ProfileScreen), findsOneWidget);

      await back(tester);

      expect(find.byType(CatalogHomeScreen), findsOneWidget);
      expect(find.byType(ProfileScreen), findsNothing);
      expect(routerOf(tester).canPop(), isFalse);
    },
  );

  testWidgets('a sheet open on a tab closes before the tab', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tab(tester, 'open-profile');
    await tester.tap(byKey('profile-language'));
    await tester.pumpAndSettle();
    expect(byKey('language-sheet'), findsOneWidget);

    await back(tester);

    expect(byKey('language-sheet'), findsNothing);
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets(
    'a screen opened from a tab covers the bar and back returns to the tab',
    (WidgetTester tester) async {
      await open(tester);
      await tab(tester, 'open-profile');

      await tester.tap(byKey('profile-edit'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(find.byType(CustomerTabBar), findsNothing);

      await back(tester);

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(CustomerTabBar), findsOneWidget);
    },
  );

  testWidgets(
    'back on a tab after a screen over it was closed still goes home',
    (WidgetTester tester) async {
      await open(tester);
      await tab(tester, 'open-profile');
      await tester.tap(byKey('profile-edit'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsOneWidget);

      // An inset that appears under the editor rebuilds the tab beneath it.
      tester.view.padding = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPadding);
      await tester.pump();

      await back(tester);
      expect(find.byType(ProfileScreen), findsOneWidget);

      await back(tester);
      expect(find.byType(CatalogHomeScreen), findsOneWidget);
    },
  );

  testWidgets('a tab reached by go, then back, goes home', (
    WidgetTester tester,
  ) async {
    await open(tester);
    routerOf(tester).go(AppPaths.customerOrders);
    await tester.pumpAndSettle();
    expect(find.byType(CatalogHomeScreen), findsNothing);

    await back(tester);

    expect(find.byType(CatalogHomeScreen), findsOneWidget);
  });

  testWidgets('a placed order is on the kept orders tab at once', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      cart: FakeCartRepository(
        cart: cartOf(<Map<String, Object?>>[cartLineJson()]),
      ),
      addresses: FakeAddressesRepository(rows: <Address>[address()]),
    );
    await tab(tester, 'open-orders');
    expect(find.byType(CurrentOrderCard), findsOneWidget);
    await tab(tester, 'open-home');

    // The server now holds one more order.
    orders.rows = <Map<String, Object?>>[
      ...orders.rows,
      customerOrderJson(id: placedOrderId),
    ];
    routerOf(tester).push('/customer/cart');
    await tester.pumpAndSettle();
    await tester.tap(byKey('go-to-checkout'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(byKey('checkout-confirm'));
    await tester.tap(byKey('checkout-confirm'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('checkout-to-home'));
    await tester.pumpAndSettle();

    await tab(tester, 'open-orders');

    expect(find.byType(CurrentOrderCard), findsNWidgets(2));
  });

  testWidgets('a push opens the orders tab with the order over it', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tab(tester, 'open-favorites');
    await tester.drag(byKey('favorites-grid'), const Offset(0, -400));
    await tester.pumpAndSettle();

    final GoRouter router = routerOf(tester);
    router.go(AppPaths.customerOrders);
    router.push<void>(AppPaths.customerOrder(orderOne));
    await tester.pumpAndSettle();
    expect(byKey('order'), findsOneWidget);

    await back(tester);
    expect(find.byType(OrdersScreen), findsOneWidget);
    expect(find.byType(CustomerTabBar), findsOneWidget);

    await tab(tester, 'open-favorites');
    expect(gridPixels(tester), 400);
  });

  testWidgets('a tap on the current tab scrolls its list to the top', (
    WidgetTester tester,
  ) async {
    orders.summaries = <Map<String, Object?>>[
      for (int i = 0; i < 12; i++)
        orderSummaryJson(
          id: '0192f0a0-0000-7000-8000-00000000d0${i.toString().padLeft(2, '0')}',
          number: 2000 + i,
          status: 'completed',
        ),
    ];
    double pixels(WidgetTester tester, String key) => tester
        .state<ScrollableState>(
          find
              .descendant(of: byKey(key), matching: find.byType(Scrollable))
              .first,
        )
        .position
        .pixels;
    await open(tester);
    tester.view.physicalSize = const Size(800, 600);
    await tester.pumpAndSettle();

    final List<(String, String, String)> cases = <(String, String, String)>[
      ('open-home', 'home-body', 'home'),
      ('open-favorites', 'favorites-grid', 'favorites'),
      ('open-orders', 'orders-list', 'orders'),
      ('open-profile', 'profile-list', 'profile'),
    ];
    for (final (String tabKey, String listKey, String name) in cases) {
      await tab(tester, tabKey);
      if (name == 'orders') {
        await tester.tap(byKey('orders-tab-past'));
        await tester.pumpAndSettle();
      }
      final double before = pixels(tester, listKey);
      await tester.drag(byKey(listKey), const Offset(0, -300));
      await tester.pumpAndSettle();
      final double scrolled = pixels(tester, listKey);
      expect(scrolled, greaterThan(before), reason: name);

      await tab(tester, tabKey);
      expect(pixels(tester, listKey), 0, reason: name);

      await tab(tester, tabKey);
      expect(pixels(tester, listKey), 0, reason: name);
    }
  });

  testWidgets('a hidden orders tab loads nothing', (WidgetTester tester) async {
    await open(tester);
    await tab(tester, 'open-orders');
    await tab(tester, 'open-home');
    int listLoads() =>
        orders.loads.where((String l) => l.startsWith('orders:')).length;
    final int before = listLoads();

    await tester.pump(const Duration(seconds: 31));
    expect(listLoads(), before);

    await tab(tester, 'open-orders');
    await tester.tap(find.byType(CurrentOrderCard).first);
    await tester.pumpAndSettle();
    expect(byKey('order'), findsOneWidget);
    final int underOrder = listLoads();

    await tester.pump(const Duration(seconds: 31));
    expect(listLoads(), underOrder);
  });

  testWidgets(
    'another Customer after a sign-out starts at the home with fresh tabs',
    (WidgetTester tester) async {
      await open(tester);
      await tab(tester, 'open-favorites');
      await tester.drag(byKey('favorites-grid'), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tab(tester, 'open-profile');
      await tester.tap(byKey('logout-button'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsNothing);

      auth.verifyResult = IssuedSession(
        token: 'c2',
        user: user(id: 'c2'),
      );
      await tester.enterText(byKey('phone-field'), '901234567');
      await tester.tap(byKey('continue-button'));
      await tester.pumpAndSettle();
      if (byKey('confirm-phone-send').evaluate().isNotEmpty) {
        await tester.tap(byKey('confirm-phone-send'));
        await tester.pumpAndSettle();
      }
      await tester.enterText(byKey('code-field'), '482913');
      await tester.tap(byKey('verify-button'));
      await tester.pumpAndSettle();

      expect(find.byType(CatalogHomeScreen), findsOneWidget);
      await tab(tester, 'open-favorites');
      expect(favorites.listLoads, 2);
      expect(gridPixels(tester), 0);
    },
  );
}
