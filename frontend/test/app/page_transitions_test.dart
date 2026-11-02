import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/address_map.dart';
import 'package:baraka_bozor/features/cart/presentation/cart_paths.dart';
import 'package:baraka_bozor/features/cart/presentation/cart_screen.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/catalog/presentation/home_screen.dart';
import 'package:baraka_bozor/features/catalog/presentation/product_screen.dart';
import 'package:baraka_bozor/features/favorites/domain/favorites.dart';
import 'package:baraka_bozor/features/favorites/presentation/favorites_screen.dart';
import 'package:baraka_bozor/features/orders/presentation/orders_screens.dart';
import 'package:baraka_bozor/features/profile/domain/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/app_harness.dart';
import '../support/fake_address_map.dart';
import '../support/fake_auth_repository.dart';
import '../support/fake_catalog_repository.dart';
import '../support/fake_customer_orders_repository.dart';
import '../support/fake_customer_repositories.dart';
import '../support/fake_favorites_repository.dart';
import '../support/in_memory_stores.dart';

/// Pages come in by the platform's transition, tabs stay instant (`DL-124`),
/// through the real router.
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

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        catalog: catalog,
        favorites: favorites,
        orders: orders,
        profile: profile,
        overrides: [addressMapProvider.overrideWithValue(FakeAddressMap())],
      ),
    );
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

  testWidgets('the cart slides in over the home', (WidgetTester tester) async {
    await open(tester);

    routerOf(tester).push(CartPaths.cart);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CatalogHomeScreen), findsOneWidget);
    expect(find.byType(CartScreen), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(CatalogHomeScreen), findsNothing);
  });

  testWidgets(
    'a swipe back from a page over the favourites tab returns to it, scroll kept',
    (WidgetTester tester) async {
      await open(tester);
      await tester.tap(byKey('open-favorites'));
      await tester.pumpAndSettle();
      await tester.drag(byKey('favorites-grid'), const Offset(0, -400));
      await tester.pumpAndSettle();
      final double before = gridPixels(tester);

      routerOf(tester).push(CartPaths.cart);
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(5, 300), const Offset(600, 0));
      await tester.pumpAndSettle();

      expect(find.byType(FavoritesScreen), findsOneWidget);
      expect(find.byType(CartScreen), findsNothing);
      expect(gridPixels(tester), before);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('a second tap while the product comes in opens one page', (
    WidgetTester tester,
  ) async {
    await open(tester);

    final Offset at = tester.getCenter(find.text('Pomidor').first);
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(at);
    await tester.pumpAndSettle();
    expect(find.byType(ProductScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(CatalogHomeScreen), findsOneWidget);
  });

  testWidgets('a tab switch is still instant', (WidgetTester tester) async {
    await open(tester);

    await tester.tap(byKey('open-orders'));
    await tester.pump();

    expect(find.byType(OrdersScreen), findsOneWidget);
    expect(find.byType(CatalogHomeScreen), findsNothing);
  });
}
