import 'dart:typed_data';

import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/admin/application/admin_catalog_controllers.dart';
import 'package:baraka_bozor/features/admin/application/product_image_picker.dart';
import 'package:baraka_bozor/features/admin/domain/admin_catalog.dart';
import 'package:baraka_bozor/features/admin/presentation/admin_paths.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_admin_catalog_repository.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/in_memory_stores.dart';

/// A picker that hands over whatever the test put in it.
class _FakePicker implements ProductImagePicker {
  PickedImage? next;

  @override
  Future<PickedImage?> pick() async => next;
}

PickedImage _png({int size = 64}) {
  final Uint8List bytes = Uint8List(size)
    ..setRange(0, 8, <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  return PickedImage(bytes: bytes, name: 'pomidor.png');
}

/// The panel's catalog screens (W1-10) through the real router, session and
/// screens, against a catalog in memory.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeAdminCatalogRepository catalog;
  late _FakePicker picker;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));
  Finder field(String apiKey) => byKey('field-$apiKey');

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  setUp(() {
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    catalog = FakeAdminCatalogRepository();
    picker = _FakePicker();
    tokens.tokens[SessionSlot.staff] = 's';
    auth.identities[SessionSlot.staff] = user(role: UserRole.admin);
  });

  Future<void> open(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        surface: Surface.web,
        overrides: [
          adminCatalogRepositoryProvider.overrideWithValue(catalog),
          productImagePickerProvider.overrideWithValue(picker),
        ],
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('categories', () {
    testWidgets('a new category is created with both names and shown', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.categories);
      expect(find.text('Sabzavotlar · Овощи'), findsOneWidget);

      await tapAndSettle(tester, byKey('new-category'));
      await tester.enterText(field('name_uz'), '  Mevalar ');
      await tester.enterText(field('name_ru'), 'Фрукты');
      await tester.enterText(field('sort_order'), '5');
      await tapAndSettle(tester, byKey('category-save'));

      final (String? id, CategoryDraft draft) = catalog.savedCategories.single;
      expect(id, isNull);
      expect(draft.nameUz, 'Mevalar');
      expect(draft.nameRu, 'Фрукты');
      expect(draft.sortOrder, 5);
      expect(draft.isActive, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(l10n(tester).categorySaved), findsOneWidget);
      expect(find.text('Mevalar · Фрукты'), findsOneWidget);
    });

    testWidgets('the form refuses empty names and sends nothing', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.categories);

      await tapAndSettle(tester, byKey('new-category'));
      await tapAndSettle(tester, byKey('category-save'));

      expect(find.text(l10n(tester).fieldRequired), findsNWidgets(2));
      expect(catalog.savedCategories, isEmpty);
    });

    testWidgets(
      'a field the server refused is marked in the dialog, which stays open',
      (WidgetTester tester) async {
        catalog.changeFailure = const ApiRefusal(
          ApiError(
            status: 422,
            code: 'validation_failed',
            errors: <String, List<String>>{
              'name_ru': <String>['The name ru field is required.'],
            },
          ),
        );
        await open(tester, AdminPaths.categories);

        await tapAndSettle(tester, byKey('edit-c-1'));
        await tapAndSettle(tester, byKey('category-save'));

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text(l10n(tester).fieldRejected), findsOneWidget);
        expect(catalog.savedCategories.single.$1, 'c-1');
      },
    );

    testWidgets(
      'archive hides a category until archived ones are shown, then it is restored',
      (WidgetTester tester) async {
        await open(tester, AdminPaths.categories);

        await tapAndSettle(tester, byKey('archive-c-1'));
        expect(catalog.actions, <String>['archive c-1']);
        expect(find.text('Sabzavotlar · Овощи'), findsNothing);

        await tapAndSettle(tester, byKey('include-archived'));
        expect(find.text('Sabzavotlar · Овощи'), findsOneWidget);
        expect(find.text(l10n(tester).catalogStateArchived), findsOneWidget);

        await tapAndSettle(tester, byKey('restore-c-1'));
        expect(catalog.actions, <String>['archive c-1', 'restore c-1']);
        expect(find.text(l10n(tester).catalogStateActive), findsOneWidget);
      },
    );

    testWidgets(
      'an archived category is edited without the visibility switch',
      (WidgetTester tester) async {
        catalog.categoryRows = <AdminCategory>[
          adminCategory(archivedAt: DateTime.utc(2026, 9, 26)),
        ];
        await open(tester, AdminPaths.categories);
        await tapAndSettle(tester, byKey('include-archived'));

        await tapAndSettle(tester, byKey('edit-c-1'));
        expect(field('is_active'), findsNothing);
        expect(find.text(l10n(tester).catalogArchivedNote), findsOneWidget);
        await tapAndSettle(tester, byKey('category-save'));

        expect(catalog.savedCategories.single.$2.isActive, isNull);
      },
    );
  });

  group('products', () {
    testWidgets(
      'the list shows prices, and search and the category filter narrow it',
      (WidgetTester tester) async {
        catalog.categoryRows = <AdminCategory>[
          adminCategory(),
          adminCategory(id: 'c-2', nameUz: 'Mevalar', nameRu: 'Фрукты'),
        ];
        catalog.productRows = <AdminProduct>[
          adminProduct(),
          adminProduct(
            id: 'p-2',
            categoryId: 'c-2',
            nameUz: 'Olma',
            nameRu: 'Яблоко',
          ),
        ];
        await open(tester, AdminPaths.products);

        expect(find.text('Pomidor · Помидор'), findsOneWidget);
        expect(find.text('Olma · Яблоко'), findsOneWidget);
        expect(
          find.text(
            l10n(tester)
                .productCustomerPrice(MoneyFormat.uzs(18400, AppLanguage.uz)),
          ),
          findsNWidgets(2),
        );

        await tester.enterText(byKey('product-search'), 'яблоко');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(catalog.productQueries.last.search, 'яблоко');
        expect(find.text('Pomidor · Помидор'), findsNothing);

        await tester.enterText(byKey('product-search'), '');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        await tapAndSettle(tester, byKey('product-category-filter'));
        await tapAndSettle(tester, find.text('Sabzavotlar').last);

        expect(catalog.productQueries.last.categoryId, 'c-1');
        expect(find.text('Olma · Яблоко'), findsNothing);
        expect(find.text('Pomidor · Помидор'), findsOneWidget);
      },
    );

    testWidgets('the list pages', (WidgetTester tester) async {
      catalog.productRows = <AdminProduct>[
        for (int i = 1; i <= 25; i++)
          adminProduct(id: 'p-$i', nameUz: 'Mahsulot $i', nameRu: 'Товар $i'),
      ];
      await open(tester, AdminPaths.products);
      expect(find.text(l10n(tester).catalogPage(1, 2)), findsOneWidget);

      await tapAndSettle(tester, byKey('next-page'));

      expect(catalog.productQueries.last.page, 2);
      expect(find.text('Mahsulot 25 · Товар 25'), findsOneWidget);
      expect(find.text('Mahsulot 1 · Товар 1'), findsNothing);
    });

    testWidgets(
      'a new product is created and its page opens, ready for an image',
      (WidgetTester tester) async {
        await open(tester, AdminPaths.products);

        await tapAndSettle(tester, byKey('new-product'));
        expect(find.text(l10n(tester).productImageAfterSave), findsOneWidget);
        await tapAndSettle(tester, field('category_id'));
        await tapAndSettle(tester, find.text('Sabzavotlar').last);
        await tester.enterText(field('name_uz'), 'Bodring');
        await tester.enterText(field('name_ru'), 'Огурец');
        await tester.enterText(field('market_price_uzs'), '12 000');
        await tapAndSettle(tester, find.text(l10n(tester).priceModeFixed));
        await tapAndSettle(tester, byKey('product-save'));

        final (String? id, ProductDraft draft) = catalog.savedProducts.single;
        expect(id, isNull);
        expect(draft.categoryId, 'c-1');
        expect(draft.marketPriceUzs, 12000);
        expect(draft.priceMode, PriceMode.fixed);
        expect(draft.unitCode, UnitCode.kg);
        expect(draft.isActive, isTrue);
        expect(byKey('choose-image'), findsOneWidget);
        expect(find.text(l10n(tester).productEditTitle), findsOneWidget);
      },
    );

    testWidgets('the form refuses a missing category and a bad price', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.newProduct);

      await tester.enterText(field('name_uz'), 'Bodring');
      await tester.enterText(field('name_ru'), 'Огурец');
      await tester.enterText(field('market_price_uzs'), '0');
      await tapAndSettle(tester, byKey('product-save'));

      expect(find.text(l10n(tester).fieldRequired), findsOneWidget);
      expect(find.text(l10n(tester).fieldMarketPrice), findsOneWidget);
      expect(catalog.savedProducts, isEmpty);
    });

    testWidgets(
      'an archived category is offered only to the product already in it',
      (WidgetTester tester) async {
        catalog.categoryRows = <AdminCategory>[
          adminCategory(archivedAt: DateTime.utc(2026, 9, 26)),
          adminCategory(id: 'c-2', nameUz: 'Mevalar', nameRu: 'Фрукты'),
        ];
        await open(tester, AdminPaths.newProduct);
        await tapAndSettle(tester, field('category_id'));
        expect(find.text('Sabzavotlar'), findsNothing);
        expect(find.text('Mevalar'), findsWidgets);
        await tester.tapAt(Offset.zero);
        await tester.pumpAndSettle();

        await open(tester, AdminPaths.product('p-1'));
        await tapAndSettle(tester, byKey('product-save'));
        expect(catalog.savedProducts.single.$2.categoryId, 'c-1');
      },
    );
  });

  group('product image', () {
    testWidgets('a picked image is previewed and uploaded as picked', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.product('p-1'));
      picker.next = _png();

      await tapAndSettle(tester, byKey('choose-image'));
      expect(byKey('picked-image'), findsOneWidget);
      await tapAndSettle(tester, byKey('upload-image'));

      final (String productId, PickedImage sent) = catalog.uploads.single;
      expect(productId, 'p-1');
      expect(sent.name, 'pomidor.png');
      expect(sent.bytes.length, 64);
      expect(byKey('picked-image'), findsNothing);
      expect(byKey('remove-image'), findsOneWidget);
    });

    testWidgets('a file over 5 MB or not an image is refused before sending', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.product('p-1'));

      picker.next = _png(size: PickedImage.maxBytes + 1);
      await tapAndSettle(tester, byKey('choose-image'));
      expect(find.text(l10n(tester).productImageTooLarge), findsOneWidget);
      expect(byKey('upload-image'), findsNothing);

      picker.next = PickedImage(
        bytes: Uint8List.fromList(<int>[0x47, 0x49, 0x46, 0x38, 0x39, 0x61]),
        name: 'pomidor.png',
      );
      await tapAndSettle(tester, byKey('choose-image'));
      expect(find.text(l10n(tester).productImageWrongType), findsOneWidget);
      expect(byKey('upload-image'), findsNothing);

      picker.next = null;
      await tapAndSettle(tester, byKey('choose-image'));
      expect(catalog.uploads, isEmpty);
    });

    testWidgets('removing the image asks first', (WidgetTester tester) async {
      catalog.productRows = <AdminProduct>[
        adminProduct(imageUrl: 'https://api.test/storage/products/a.webp'),
      ];
      await open(tester, AdminPaths.product('p-1'));

      await tapAndSettle(tester, byKey('remove-image'));
      await tapAndSettle(tester, find.text(l10n(tester).cancelButton));
      expect(catalog.removedImages, isEmpty);

      await tapAndSettle(tester, byKey('remove-image'));
      await tapAndSettle(tester, byKey('confirm-remove-image'));
      expect(catalog.removedImages, <String>['p-1']);
      expect(byKey('remove-image'), findsNothing);
    });

    testWidgets('a product that does not exist says so', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.product('p-404'));

      expect(find.text(l10n(tester).errorNotFound), findsOneWidget);
      expect(field('name_uz'), findsNothing);
    });
  });
}
