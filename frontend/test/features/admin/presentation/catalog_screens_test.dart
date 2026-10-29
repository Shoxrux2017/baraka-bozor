import 'dart:async';

import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/catalog_labels.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/core/state/mutation_state.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/kit/kit_card.dart';
import 'package:baraka_bozor/core/widgets/panel/panel_card.dart';
import 'package:baraka_bozor/features/admin/application/admin_catalog_controllers.dart';
import 'package:baraka_bozor/features/admin/application/product_image_picker.dart';
import 'package:baraka_bozor/features/admin/domain/admin_catalog.dart';
import 'package:baraka_bozor/features/admin/presentation/admin_paths.dart';
import 'package:baraka_bozor/core/widgets/kit/kit_note.dart';
import 'package:baraka_bozor/features/admin/presentation/catalog_image_card.dart';
import 'package:baraka_bozor/features/admin/presentation/catalog_widgets.dart';
import 'package:baraka_bozor/features/admin/presentation/categories_screen.dart';
import 'package:baraka_bozor/features/admin/presentation/product_edit_screen.dart';
import 'package:baraka_bozor/features/admin/presentation/products_screen.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/drawn_size.dart';
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

  String location(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .routeInformationProvider
          .value
          .uri
          .path;

  String textOf(WidgetTester tester, String apiKey) =>
      tester.widget<TextFormField>(field(apiKey)).controller!.text;

  Finder inDialog(Finder finder) =>
      find.descendant(of: byKey('category-dialog'), matching: finder);

  setUp(() {
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    catalog = FakeAdminCatalogRepository();
    picker = _FakePicker();
    tokens.tokens[SessionSlot.staff] = 's';
    auth.identities[SessionSlot.staff] = user(role: UserRole.admin);
  });

  Future<void> open(
    WidgetTester tester,
    String location, {
    Size size = const Size(1400, 2600),
    Locale device = const Locale('uz'),
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
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(byKey('product-search'), text);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  Future<void> fillNewProduct(WidgetTester tester) async {
    await tapAndSettle(tester, field('category_id'));
    await tapAndSettle(tester, find.text('Sabzavotlar').last);
    await tester.enterText(field('name_uz'), 'Bodring');
    await tester.enterText(field('name_ru'), 'Огурец');
    await tester.enterText(field('market_price_uzs'), '12 000');
  }

  Future<void> signOut(WidgetTester tester) async {
    await ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
        .read(sessionControllerProvider.notifier)
        .logout(SessionMode.staff);
    await tester.pumpAndSettle();
  }

  group('categories', () {
    Finder inRow(String id, Finder finder) =>
        find.descendant(of: byKey('category-$id'), matching: finder);

    testWidgets('a new category is created with both names and shown', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.categories);
      expect(inRow('c-1', find.text('Sabzavotlar')), findsOneWidget);
      expect(inRow('c-1', find.text('Овощи')), findsOneWidget);

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
      expect(byKey('category-dialog'), findsNothing);
      expect(find.text(l10n(tester).categorySaved), findsOneWidget);
      expect(find.text('Mevalar'), findsOneWidget);
      expect(find.text('Фрукты'), findsOneWidget);
    });

    testWidgets('the dialog stays open while it saves, then closes itself', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.categories);
      await tapAndSettle(tester, byKey('edit-c-1'));
      await tester.enterText(field('name_uz'), 'Sabzavot');
      catalog.hold = Completer<void>();

      await tester.tap(byKey('category-save'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      await tester.tap(byKey('category-dialog-close'));
      await tester.pump();
      expect(byKey('category-dialog'), findsOneWidget);

      catalog.hold!.complete();
      await tester.pumpAndSettle();
      expect(byKey('category-dialog'), findsNothing);
      expect(find.text(l10n(tester).categorySaved), findsOneWidget);
      expect(inRow('c-1', find.text('Sabzavot')), findsOneWidget);
      expect(inRow('c-1', find.text('Овощи')), findsOneWidget);
    });

    testWidgets('a tap outside the dialog does not throw the form away', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.categories);
      await tapAndSettle(tester, byKey('new-category'));
      await tester.enterText(field('name_uz'), 'Mevalar');

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(byKey('category-dialog'), findsOneWidget);
      expect(textOf(tester, 'name_uz'), 'Mevalar');
    });

    testWidgets('a failure shows where it happened and nowhere else', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.categories);
      await tapAndSettle(tester, byKey('edit-c-1'));
      await tester.enterText(field('name_uz'), 'Sabzavot');
      catalog.changeFailure = const NetworkFailure();
      await tapAndSettle(tester, byKey('category-save'));
      expect(inDialog(find.text(l10n(tester).errorNetwork)), findsOneWidget);

      await tapAndSettle(tester, find.text(l10n(tester).cancelButton));
      expect(find.text(l10n(tester).errorNetwork), findsNothing);

      catalog.changeFailure = const ApiRefusal(
        ApiError(status: 409, code: 'business_conflict'),
      );
      await tapAndSettle(tester, byKey('archive-c-1'));
      await tapAndSettle(tester, byKey('archive-confirm'));
      expect(
        find.descendant(
          of: byKey('archive-dialog'),
          matching: find.text(l10n(tester).errorBusinessConflict),
        ),
        findsOneWidget,
      );

      await tapAndSettle(tester, byKey('action-cancel'));
      await tapAndSettle(tester, byKey('edit-c-1'));
      expect(
        inDialog(find.text(l10n(tester).errorBusinessConflict)),
        findsNothing,
      );
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

        expect(byKey('category-dialog'), findsOneWidget);
        expect(find.text(l10n(tester).fieldRejected), findsOneWidget);
        expect(catalog.savedCategories.single.$1, 'c-1');
      },
    );

    testWidgets(
      'archive hides a category until archived ones are shown, then it is restored',
      (WidgetTester tester) async {
        await open(tester, AdminPaths.categories);

        await tapAndSettle(tester, byKey('archive-c-1'));
        Finder inWindow(Finder finder) =>
            find.descendant(of: byKey('archive-dialog'), matching: finder);
        expect(
          inWindow(find.text(l10n(tester).categoryArchiveTitle)),
          findsOneWidget,
        );
        expect(
          inWindow(find.text(l10n(tester).categoryArchiveExplained)),
          findsOneWidget,
        );
        expect(inWindow(find.text('Sabzavotlar')), findsOneWidget);
        expect(inWindow(find.text('Овощи')), findsOneWidget);
        expect(catalog.actions, isEmpty);

        await tapAndSettle(tester, byKey('archive-confirm'));
        expect(catalog.actions, <String>['archive c-1']);
        expect(byKey('archive-dialog'), findsNothing);
        expect(byKey('category-c-1'), findsNothing);

        await tapAndSettle(tester, byKey('include-archived'));
        expect(byKey('category-c-1'), findsOneWidget);
        expect(find.text(l10n(tester).catalogStateArchived), findsOneWidget);

        await tapAndSettle(tester, byKey('restore-c-1'));
        expect(catalog.actions, <String>['archive c-1', 'restore c-1']);
        expect(byKey('archive-dialog'), findsNothing);
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

    testWidgets('a category row opens its window', (WidgetTester tester) async {
      await open(tester, AdminPaths.categories);

      await tapAndSettle(tester, byKey('category-c-1'));

      expect(byKey('category-dialog'), findsOneWidget);
      expect(
        inDialog(find.text(l10n(tester).categoryEditTitle)),
        findsOneWidget,
      );
      expect(
        inDialog(
          find.byWidgetPredicate(
            (Widget w) => w is Text && w.data == 'Sabzavotlar',
          ),
        ),
        findsOneWidget,
      );
      expect(textOf(tester, 'name_uz'), 'Sabzavotlar');
    });

    testWidgets('the header counts the categories', (
      WidgetTester tester,
    ) async {
      catalog.categoryRows = <AdminCategory>[
        adminCategory(),
        adminCategory(id: 'c-2', nameUz: 'Mevalar', nameRu: 'Фрукты'),
      ];
      await open(tester, AdminPaths.categories);

      final Finder title = find.text(l10n(tester).adminSectionCategories);
      final Finder count = find.text(l10n(tester).catalogCategoryCount(2));
      expect(count, findsOneWidget);
      expect(
        tester.getTopLeft(count).dy,
        greaterThan(tester.getTopLeft(title.last).dy),
      );
      // Drawn 40 high, tapped from 48 (DL-117).
      expect(tester.getSize(byKey('new-category')).height, 48);
      expect(drawnSize(tester, byKey('new-category')).height, 40);
      expect(
        tester.getTopRight(byKey('new-category')).dx,
        closeTo(tester.getTopRight(find.byType(PanelCard).first).dx, 0.5),
      );
    });

    Finder listTable() => find.descendant(
      of: find.byType(PanelCard),
      matching: find.byType(Table),
    );

    testWidgets('a wide card is a table and a narrow one cards', (
      WidgetTester tester,
    ) async {
      expect(CategoriesScreen.tableWidth, 560);
      await open(tester, AdminPaths.categories, size: const Size(608, 1000));

      expect(tester.getSize(find.byType(PanelCard).first).width, 560);
      expect(listTable(), findsWidgets);
      expect(tester.widget(byKey('category-c-1')), isNot(isA<KitCard>()));
      final AppLocalizations text = l10n(tester);
      Finder header(String label) => find.text(label.toUpperCase());
      expect(header(text.productCategory), findsOneWidget);
      expect(header(text.catalogSortOrder), findsOneWidget);
      expect(header(text.catalogColumnShown), findsOneWidget);
      expect(
        tester.getTopLeft(header(text.catalogSortOrder)).dx,
        greaterThan(tester.getTopLeft(header(text.productCategory)).dx),
      );
      expect(
        tester.getTopLeft(header(text.catalogColumnShown)).dx,
        greaterThan(tester.getTopLeft(header(text.catalogSortOrder)).dx),
      );
      expect(
        tester.getTopLeft(byKey('edit-c-1')).dx,
        greaterThan(tester.getTopLeft(header(text.catalogColumnShown)).dx),
      );
      expect(
        tester.getTopLeft(byKey('archive-c-1')).dx,
        greaterThan(tester.getTopLeft(byKey('edit-c-1')).dx),
      );

      await open(tester, AdminPaths.categories, size: const Size(607, 1000));

      expect(tester.getSize(find.byType(PanelCard).first).width, 559);
      expect(listTable(), findsNothing);
      expect(tester.widget(byKey('category-c-1')), isA<KitCard>());
      expect(byKey('edit-c-1'), findsOneWidget);
      expect(byKey('archive-c-1'), findsOneWidget);
      expect(inRow('c-1', find.text(text.catalogStateActive)), findsOneWidget);
      expect(
        inRow('c-1', find.text('${text.catalogSortOrder}: 0')),
        findsOneWidget,
      );
      await tapAndSettle(tester, byKey('category-c-1'));
      expect(byKey('category-dialog'), findsOneWidget);
    });

    testWidgets(
      'the window is 720 wide and keeps the two languages side by side',
      (WidgetTester tester) async {
        await open(tester, AdminPaths.categories, size: const Size(1440, 900));
        await tapAndSettle(tester, byKey('edit-c-1'));

        expect(tester.getSize(byKey('category-dialog')).width, 720);
        expect(
          tester.getTopLeft(field('name_uz')).dx,
          lessThan(tester.getTopLeft(field('name_ru')).dx),
        );
        expect(
          tester.getTopLeft(field('name_uz')).dy,
          tester.getTopLeft(field('name_ru')).dy,
        );
        expect(tester.getSize(byKey('category-save')).width, 160);
        expect(tester.getSize(byKey('category-save')).height, 48);
        expect(tester.getSize(byKey('category-cancel')).width, 160);
        expect(
          tester.getTopRight(byKey('category-save')).dx,
          closeTo(tester.getTopRight(byKey('category-dialog')).dx - 24, 0.5),
        );

        await open(tester, AdminPaths.categories, size: const Size(400, 900));
        await tapAndSettle(tester, byKey('edit-c-1'));

        expect(
          tester.getTopLeft(field('name_ru')).dy,
          greaterThan(tester.getTopLeft(field('name_uz')).dy),
        );
        expect(
          tester.getTopLeft(field('name_ru')).dx,
          tester.getTopLeft(field('name_uz')).dx,
        );
        expect(tester.getSize(byKey('category-save')).height, 48);
        expect(
          tester.getSize(byKey('category-save')).width,
          lessThan(tester.getSize(byKey('category-dialog')).width / 2),
        );
      },
    );

    testWidgets('the switch row explains what hiding a category does', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.categories);
      await tapAndSettle(tester, byKey('edit-c-1'));

      expect(
        inDialog(find.text(l10n(tester).categoryShownHint)),
        findsOneWidget,
      );
      expect(
        inDialog(find.text(l10n(tester).catalogShownToCustomers)),
        findsOneWidget,
      );
      expect(tester.widget<Switch>(field('is_active')).value, isTrue);

      await tapAndSettle(tester, field('is_active'));
      await tapAndSettle(tester, byKey('category-save'));
      expect(catalog.savedCategories.single.$2.isActive, isFalse);
    });

    testWidgets('a hidden category is shown as such in its row', (
      WidgetTester tester,
    ) async {
      catalog.categoryRows = <AdminCategory>[adminCategory(isActive: false)];
      await open(tester, AdminPaths.categories);

      expect(
        inRow('c-1', find.text(l10n(tester).catalogStateHidden)),
        findsOneWidget,
      );
    });

    for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
      for (final Size size in const <Size>[Size(1440, 900), Size(820, 1180)]) {
        testWidgets('the categories hold at the extremes '
            '(${device.languageCode} ${size.width.toInt()})', (
          WidgetTester tester,
        ) async {
          final String long = 'Sabzavot ' * 15;
          catalog.categoryRows = <AdminCategory>[
            adminCategory(nameUz: long.trim(), nameRu: long.trim()),
            adminCategory(id: 'c-2', nameUz: 'Mevalar', nameRu: 'Фрукты'),
          ];
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await open(tester, AdminPaths.categories, size: size, device: device);
          expect(byKey('category-c-1'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tapAndSettle(tester, byKey('category-c-1'));
          expect(byKey('category-dialog'), findsOneWidget);
          await tester.ensureVisible(byKey('category-save'));
          await tester.pumpAndSettle();
          expect(byKey('category-save'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
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

        Finder inRow(String id, Finder finder) =>
            find.descendant(of: byKey('product-$id'), matching: finder);
        final AppLocalizations text = l10n(tester);
        final String market = MoneyFormat.uzs(16000, AppLanguage.uz);
        final String customer = MoneyFormat.uzs(18400, AppLanguage.uz);
        final String perUnit = text.catalogPerUnit(
          CatalogLabels.unit(text, UnitCode.kg),
        );

        expect(inRow('p-1', find.text('Pomidor')), findsOneWidget);
        expect(inRow('p-1', find.text('Помидор')), findsOneWidget);
        expect(inRow('p-1', find.text(market)), findsOneWidget);
        expect(inRow('p-1', find.text(perUnit)), findsOneWidget);
        expect(inRow('p-1', find.text(customer)), findsOneWidget);
        expect(inRow('p-2', find.text('Olma')), findsOneWidget);
        expect(
          tester.getTopLeft(inRow('p-1', find.text(perUnit))).dy,
          greaterThan(tester.getTopLeft(inRow('p-1', find.text(market))).dy),
        );
        expect(
          tester.getTopRight(inRow('p-1', find.text(perUnit))).dx,
          tester.getTopRight(inRow('p-1', find.text(market))).dx,
        );
        expect(
          tester.getTopRight(inRow('p-1', find.text(customer))).dx,
          greaterThan(tester.getTopRight(inRow('p-1', find.text(market))).dx),
        );

        await tester.enterText(byKey('product-search'), 'яблоко');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(catalog.productQueries.last.search, 'яблоко');
        expect(byKey('product-p-1'), findsNothing);

        await tester.enterText(byKey('product-search'), '');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        await tapAndSettle(tester, byKey('product-category-filter'));
        await tapAndSettle(tester, find.text('Sabzavotlar').last);

        expect(catalog.productQueries.last.categoryId, 'c-1');
        expect(byKey('product-p-2'), findsNothing);
        expect(byKey('product-p-1'), findsOneWidget);
        final Finder button = byKey('product-category-filter');
        expect(
          find.descendant(of: button, matching: find.text('Sabzavotlar')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<OutlinedButton>(button)
              .style!
              .backgroundColor!
              .resolve(<WidgetState>{}),
          KitColors.primaryWash,
        );
      },
    );

    testWidgets('the list pages', (WidgetTester tester) async {
      catalog.productRows = <AdminProduct>[
        for (int i = 1; i <= 25; i++)
          adminProduct(id: 'p-$i', nameUz: 'Mahsulot $i', nameRu: 'Товар $i'),
      ];
      await open(tester, AdminPaths.products);
      expect(find.text(l10n(tester).boardPageRange(1, 20, 25)), findsOneWidget);

      await tapAndSettle(tester, byKey('next-page'));

      expect(catalog.productQueries.last.page, 2);
      expect(find.text('Mahsulot 25'), findsOneWidget);
      expect(find.text('Mahsulot 1'), findsNothing);
      expect(
        find.text(l10n(tester).boardPageRange(21, 25, 25)),
        findsOneWidget,
      );
    });

    testWidgets('the header counts what the list holds', (
      WidgetTester tester,
    ) async {
      catalog.productRows = <AdminProduct>[
        for (int i = 1; i <= 25; i++)
          adminProduct(id: 'p-$i', nameUz: 'Mahsulot $i', nameRu: 'Товар $i'),
      ];
      await open(tester, AdminPaths.products);

      final Finder title = find.text(l10n(tester).adminSectionProducts);
      final Finder count = find.text(l10n(tester).catalogProductCount(25));
      expect(title, findsWidgets);
      expect(count, findsOneWidget);
      expect(
        tester.getTopLeft(count).dy,
        greaterThan(tester.getTopLeft(title.last).dy),
      );
      // Drawn 40 high, tapped from 48 (DL-117).
      expect(tester.getSize(byKey('new-product')).height, 48);
      expect(drawnSize(tester, byKey('new-product')).height, 40);
      expect(
        tester.widget<FilledButton>(byKey('new-product')).onPressed,
        isNotNull,
      );
      expect(
        tester.getTopRight(byKey('new-product')).dx,
        closeTo(tester.getTopRight(find.byType(PanelCard).first).dx, 0.5),
      );
    });

    Finder listTable() => find.descendant(
      of: find.byType(PanelCard),
      matching: find.byType(Table),
    );

    for (final Size size in const <Size>[Size(848, 1000), Size(1440, 900)]) {
      testWidgets('a card from 800 wide is a table (${size.width.toInt()})', (
        WidgetTester tester,
      ) async {
        await open(tester, AdminPaths.products, size: size);

        expect(listTable(), findsWidgets);
        expect(
          tester.getSize(find.byType(PanelCard).first).width,
          greaterThanOrEqualTo(ProductsScreen.tableWidth),
        );
        expect(tester.widget(byKey('product-p-1')), isNot(isA<KitCard>()));
      });
    }

    testWidgets('at 848 the card is 800 and the search 320 wide', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.products, size: const Size(848, 1000));

      expect(tester.getSize(find.byType(PanelCard).first).width, 800);
      expect(tester.getSize(byKey('product-search')).width, 320);
    });

    for (final Size size in const <Size>[Size(847, 1000), Size(820, 1180)]) {
      testWidgets('a narrower card is cards (${size.width.toInt()})', (
        WidgetTester tester,
      ) async {
        await open(tester, AdminPaths.products, size: size);

        expect(listTable(), findsNothing);
        expect(tester.widget(byKey('product-p-1')), isA<KitCard>());
      });
    }

    testWidgets('under 640 the search takes the whole row', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.products, size: const Size(687, 1000));

      final double card = tester.getSize(find.byType(PanelCard).first).width;
      expect(card, 639);
      expect(tester.getSize(byKey('product-search')).width, card - 40);
    });

    testWidgets('the list says which products their category hides', (
      WidgetTester tester,
    ) async {
      catalog.categoryRows = <AdminCategory>[
        adminCategory(isActive: false),
        adminCategory(id: 'c-2', archivedAt: DateTime.utc(2026, 9, 26)),
        adminCategory(id: 'c-3'),
      ];
      catalog.productRows = <AdminProduct>[
        adminProduct(id: 'p-1'),
        adminProduct(id: 'p-2', categoryId: 'c-2'),
        adminProduct(id: 'p-3', categoryId: 'c-3'),
        adminProduct(id: 'p-4', isActive: false),
        adminProduct(id: 'p-5', categoryId: 'c-unknown'),
      ];
      await open(tester, AdminPaths.products);

      Finder line(String id, String text) =>
          find.descendant(of: byKey('product-$id'), matching: find.text(text));
      final AppLocalizations text = l10n(tester);

      expect(line('p-1', text.catalogCategoryHiddenLine), findsOneWidget);
      expect(line('p-2', text.catalogCategoryArchivedLine), findsOneWidget);
      for (final String id in <String>['p-3', 'p-4', 'p-5']) {
        expect(line(id, text.catalogCategoryHiddenLine), findsNothing);
        expect(line(id, text.catalogCategoryArchivedLine), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets("a product is archived only after the window's confirm", (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.products);

      await tapAndSettle(tester, byKey('archive-p-1'));
      Finder inWindow(Finder finder) =>
          find.descendant(of: byKey('archive-dialog'), matching: finder);
      expect(
        inWindow(find.text(l10n(tester).productArchiveTitle)),
        findsOneWidget,
      );
      expect(inWindow(find.text('Pomidor')), findsOneWidget);
      expect(inWindow(find.text('Помидор')), findsOneWidget);
      expect(
        inWindow(find.text(l10n(tester).productArchiveExplained)),
        findsOneWidget,
      );
      expect(catalog.actions, isEmpty);

      await tapAndSettle(tester, byKey('action-cancel'));
      expect(byKey('archive-dialog'), findsNothing);
      expect(catalog.actions, isEmpty);

      await tapAndSettle(tester, byKey('archive-p-1'));
      await tapAndSettle(tester, byKey('archive-confirm'));

      expect(catalog.actions, <String>['archive p-1']);
      expect(byKey('archive-dialog'), findsNothing);
      expect(byKey('product-p-1'), findsNothing);
    });

    testWidgets(
      'an archive in flight holds its window and a refusal shows in it',
      (WidgetTester tester) async {
        await open(tester, AdminPaths.products);
        catalog.hold = Completer<void>();

        await tapAndSettle(tester, byKey('archive-p-1'));
        await tester.tap(byKey('archive-confirm'));
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(byKey('archive-dialog'), findsOneWidget);
        await tester.tapAt(const Offset(5, 5));
        await tester.pump();
        expect(byKey('archive-dialog'), findsOneWidget);
        await tester.tap(byKey('archive-dialog-close'));
        await tester.pump();
        expect(byKey('archive-dialog'), findsOneWidget);

        catalog.changeFailure = const ApiRefusal(
          ApiError(status: 409, code: 'business_conflict'),
        );
        catalog.hold!.complete();
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: byKey('archive-dialog'),
            matching: find.text(l10n(tester).errorBusinessConflict),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('a restore takes one tap', (WidgetTester tester) async {
      catalog.productRows = <AdminProduct>[
        adminProduct(archivedAt: DateTime.utc(2026, 9, 26)),
      ];
      await open(tester, AdminPaths.products);
      await tapAndSettle(tester, byKey('include-archived'));

      await tapAndSettle(tester, byKey('restore-p-1'));

      expect(catalog.actions, <String>['restore p-1']);
      expect(byKey('archive-dialog'), findsNothing);
    });

    testWidgets('nothing found says how to widen the search', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.products);

      await search(tester, 'zzz');
      expect(find.text(l10n(tester).catalogEmpty), findsOneWidget);
      expect(find.text(l10n(tester).catalogEmptyHint), findsOneWidget);

      catalog.productRows = <AdminProduct>[];
      await search(tester, '');
      expect(find.text(l10n(tester).catalogEmpty), findsOneWidget);
      expect(find.text(l10n(tester).catalogEmptyHint), findsNothing);
    });

    for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
      for (final Size size in const <Size>[Size(1440, 900), Size(820, 1180)]) {
        testWidgets('the products list holds at the extremes '
            '(${device.languageCode} ${size.width.toInt()})', (
          WidgetTester tester,
        ) async {
          final String long = 'Pomidor ' * 20;
          catalog.productRows = <AdminProduct>[
            adminProduct(nameUz: long.trim(), nameRu: long.trim()),
            adminProduct(id: 'p-2', isFeatured: true),
            for (int i = 3; i <= 25; i++)
              adminProduct(id: 'p-$i', nameUz: 'Mahsulot $i'),
          ];
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await open(tester, AdminPaths.products, size: size, device: device);

          expect(byKey('product-p-1'), findsOneWidget);
          expect(byKey('new-product'), findsOneWidget);
          expect(byKey('product-search'), findsOneWidget);
          expect(byKey('product-category-filter'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tapAndSettle(tester, byKey('archive-p-1'));
          expect(byKey('archive-dialog'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tapAndSettle(tester, byKey('action-cancel'));
          expect(byKey('archive-dialog'), findsNothing);

          await tapAndSettle(tester, byKey('next-page'));
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('a featured product shows the badge in the list', (
      WidgetTester tester,
    ) async {
      catalog.productRows = <AdminProduct>[
        adminProduct(id: 'p-1', isFeatured: true),
        adminProduct(id: 'p-2'),
      ];
      await open(tester, AdminPaths.products);

      expect(byKey('featured-p-1'), findsOneWidget);
      expect(byKey('featured-p-2'), findsNothing);
    });

    for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
      testWidgets(
        'the product form fits 320 px at double text in ${device.languageCode}',
        (WidgetTester tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await open(
            tester,
            AdminPaths.product('p-1'),
            size: const Size(320, 640),
            device: device,
          );
          await tester.ensureVisible(field('is_featured'));
          await tester.pumpAndSettle();

          expect(field('is_featured'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('the page has two columns from 1000 and one below', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        AdminPaths.product('p-1'),
        size: const Size(1048, 1000),
      );
      expect(ProductEditScreen.twoColumnsWidth, 1000);
      expect(
        tester.getTopLeft(find.byType(CatalogImageCard)).dx,
        greaterThan(tester.getTopRight(byKey('product-save')).dx),
      );
      expect(
        tester.widget<CatalogImageCard>(find.byType(CatalogImageCard)).compact,
        isFalse,
      );
      expect(tester.getSize(find.byType(CatalogImageCard)).width, 360);

      await open(
        tester,
        AdminPaths.product('p-1'),
        size: const Size(1047, 1000),
      );
      expect(
        tester.getBottomLeft(find.byType(CatalogImageCard)).dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.text(l10n(tester).productSectionMain)).dy,
        ),
      );
      expect(
        tester.widget<CatalogImageCard>(find.byType(CatalogImageCard)).compact,
        isTrue,
      );
    });

    testWidgets('the fields stand in three cards', (WidgetTester tester) async {
      await open(tester, AdminPaths.product('p-1'));
      final AppLocalizations text = l10n(tester);

      Finder card(String title) => find
          .ancestor(of: find.text(title), matching: find.byType(PanelCard))
          .first;
      Finder within(String title, Finder finder) =>
          find.descendant(of: card(title), matching: finder);

      for (final String key in <String>[
        'category_id',
        'unit_code',
        'name_uz',
        'name_ru',
        'description_uz',
        'description_ru',
      ]) {
        expect(within(text.productSectionMain, field(key)), findsOneWidget);
      }
      expect(
        within(text.productSectionPrice, field('market_price_uzs')),
        findsOneWidget,
      );
      expect(
        within(text.productSectionPrice, byKey('customer-price')),
        findsOneWidget,
      );
      expect(
        within(text.productSectionShown, field('sort_order')),
        findsOneWidget,
      );
      expect(
        within(text.productSectionShown, field('is_active')),
        findsOneWidget,
      );
      expect(
        within(text.productSectionShown, field('is_featured')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(field('is_active')).dy,
        lessThan(tester.getTopLeft(field('is_featured')).dy),
      );
    });

    testWidgets('the customer price box names the saved price it comes from', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.product('p-1'));
      final AppLocalizations text = l10n(tester);
      final String market = MoneyFormat.uzs(16000, AppLanguage.uz);
      final String customer = MoneyFormat.uzs(18400, AppLanguage.uz);

      void expectBox() {
        for (final String line in <String>[
          text.productCustomerPriceTitle,
          customer,
          text.catalogPerUnit(CatalogLabels.unit(text, UnitCode.kg)),
          text.productCustomerPriceBasis(market),
        ]) {
          expect(
            find.descendant(
              of: byKey('customer-price'),
              matching: find.text(line),
            ),
            findsOneWidget,
            reason: line,
          );
        }
      }

      expectBox();
      await tester.enterText(field('market_price_uzs'), '20 000');
      await tester.pumpAndSettle();
      expectBox();

      await open(tester, AdminPaths.newProduct);
      expect(
        find.descendant(
          of: byKey('customer-price'),
          matching: find.text(l10n(tester).productCustomerPriceLater),
        ),
        findsOneWidget,
      );
    });

    for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
      testWidgets('the page says when the chosen category hides the product '
          '(${device.languageCode})', (WidgetTester tester) async {
        final bool ru = device.languageCode == 'ru';
        catalog.categoryRows = <AdminCategory>[
          adminCategory(),
          adminCategory(
            id: 'c-2',
            nameUz: 'Mevalar',
            nameRu: 'Фрукты',
            isActive: false,
          ),
          adminCategory(
            id: 'c-3',
            nameUz: 'Konserva',
            nameRu: 'Консервы',
            archivedAt: DateTime.utc(2026, 9, 26),
          ),
        ];
        catalog.productRows = <AdminProduct>[
          adminProduct(),
          adminProduct(id: 'p-3', categoryId: 'c-3'),
          adminProduct(
            id: 'p-4',
            categoryId: 'c-2',
            archivedAt: DateTime.utc(2026, 9, 26),
          ),
        ];
        await open(tester, AdminPaths.product('p-1'), device: device);
        final AppLocalizations text = l10n(tester);
        expect(byKey('product-category-note'), findsNothing);

        await tapAndSettle(tester, field('category_id'));
        await tapAndSettle(tester, find.text(ru ? 'Фрукты' : 'Mevalar').last);
        expect(
          find.descendant(
            of: byKey('product-category-note'),
            matching: find.text(
              text.productCategoryHiddenNote(ru ? 'Фрукты' : 'Mevalar'),
            ),
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<KitNote>(byKey('product-category-note')).tone,
          KitTone.amber,
        );

        await tapAndSettle(tester, field('is_active'));
        expect(byKey('product-category-note'), findsNothing);

        await open(tester, AdminPaths.product('p-3'), device: device);
        expect(
          find.text(
            text.productCategoryArchivedNote(ru ? 'Консервы' : 'Konserva'),
          ),
          findsOneWidget,
        );
        expect(byKey('product-category-note'), findsOneWidget);

        await open(tester, AdminPaths.product('p-4'), device: device);
        final Finder archived = find.ancestor(
          of: find.text(text.catalogArchivedNote),
          matching: find.byType(KitNote),
        );
        expect(archived, findsOneWidget);
        expect(tester.widget<KitNote>(archived).tone, KitTone.grey);
        expect(
          tester.widget<KitNote>(archived).icon,
          Icons.inventory_2_outlined,
        );
        expect(byKey('product-category-note'), findsNothing);
      });
    }

    testWidgets('a description counts its characters', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.product('p-1'));

      await tester.enterText(field('description_uz'), 'a' * 66);
      await tester.pumpAndSettle();

      final Finder counter = find.descendant(
        of: field('description_uz'),
        matching: find.text('66/2000'),
      );
      final Finder optional = find.descendant(
        of: field('description_uz'),
        matching: find.text(l10n(tester).catalogOptional),
      );
      expect(counter, findsOneWidget);
      expect(optional, findsOneWidget);
      expect(
        tester.getTopLeft(optional).dx,
        lessThan(tester.getTopLeft(counter).dx),
      );
    });

    for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
      for (final Size size in const <Size>[Size(1440, 900), Size(820, 1180)]) {
        testWidgets('the product page holds at the extremes '
            '(${device.languageCode} ${size.width.toInt()})', (
          WidgetTester tester,
        ) async {
          final String long = ('Pomidor ' * 20).trim();
          catalog.productRows = <AdminProduct>[
            adminProduct(nameUz: long, nameRu: long, isFeatured: true),
          ];
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await open(
            tester,
            AdminPaths.product('p-1'),
            size: size,
            device: device,
          );

          expect(tester.widget<Text>(byKey('product-title')).data, long);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets(
      'a new product is created and its page opens, ready for an image',
      (WidgetTester tester) async {
        await open(tester, AdminPaths.products);

        await tapAndSettle(tester, byKey('new-product'));
        expect(
          tester.widget<Text>(byKey('product-title')).data,
          l10n(tester).productNew,
        );
        expect(find.text(l10n(tester).productImageAfterSave), findsOneWidget);
        await tapAndSettle(tester, field('category_id'));
        await tapAndSettle(tester, find.text('Sabzavotlar').last);
        await tester.enterText(field('name_uz'), 'Bodring');
        await tester.enterText(field('name_ru'), 'Огурец');
        await tester.enterText(field('market_price_uzs'), '12 000');
        expect(field('price_mode'), findsNothing);
        await tapAndSettle(tester, field('is_featured'));
        await tapAndSettle(tester, byKey('product-save'));

        final (String? id, ProductDraft draft) = catalog.savedProducts.single;
        expect(id, isNull);
        expect(draft.categoryId, 'c-1');
        expect(draft.marketPriceUzs, 12000);
        expect(draft.isFeatured, isTrue);
        expect(draft.unitCode, UnitCode.kg);
        expect(draft.isActive, isTrue);
        expect(byKey('choose-image'), findsOneWidget);
        expect(tester.widget<Text>(byKey('product-title')).data, 'Bodring');
        expect(find.byType(CatalogStateChip), findsOneWidget);
        expect(find.text(l10n(tester).catalogStateActive), findsOneWidget);
        expect(find.byType(FeaturedTag), findsOneWidget);
        expect(find.text('Огурец · Sabzavotlar'), findsOneWidget);
      },
    );

    testWidgets(
      'a new product saved after the Admin left keeps them where they went',
      (WidgetTester tester) async {
        await open(tester, AdminPaths.newProduct);
        await fillNewProduct(tester);
        catalog.hold = Completer<void>();

        await tester.tap(byKey('product-save'));
        await tester.pump();
        await tapAndSettle(tester, byKey('back-to-products'));
        expect(location(tester), AdminPaths.products);

        catalog.hold!.complete();
        await tester.pumpAndSettle();
        expect(catalog.savedProducts, hasLength(1));
        expect(location(tester), AdminPaths.products);
        expect(find.text(l10n(tester).productSaved), findsNothing);
      },
    );

    testWidgets(
      'the list keeps its page, filter and search while a product is open',
      (WidgetTester tester) async {
        catalog.productRows = <AdminProduct>[
          for (int i = 1; i <= 25; i++)
            adminProduct(id: 'p-$i', nameUz: 'Mahsulot $i', nameRu: 'Товар $i'),
        ];
        await open(tester, AdminPaths.products);
        await search(tester, 'mahsulot');
        await tapAndSettle(tester, byKey('include-archived'));
        await tapAndSettle(tester, byKey('next-page'));

        await tapAndSettle(tester, find.text('Mahsulot 25'));
        expect(textOf(tester, 'name_uz'), 'Mahsulot 25');
        await tapAndSettle(tester, byKey('back-to-products'));

        expect(
          catalog.productQueries.last,
          isA<ProductQuery>()
              .having((ProductQuery q) => q.page, 'page', 2)
              .having((ProductQuery q) => q.search, 'search', 'mahsulot')
              .having(
                (ProductQuery q) => q.includeArchived,
                'archived',
                isTrue,
              ),
        );
        expect(
          find.text(l10n(tester).boardPageRange(21, 25, 25)),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(byKey('product-search')).controller!.text,
          'mahsulot',
        );
      },
    );

    testWidgets('the search takes no more than the server does', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.products);

      await search(tester, 'a' * 150);

      expect(
        tester.widget<TextField>(byKey('product-search')).controller!.text,
        'a' * ProductQuery.searchMaxLength,
      );
      expect(
        catalog.productQueries.last.search,
        'a' * ProductQuery.searchMaxLength,
      );
    });

    testWidgets(
      'a conflict reloads the product, and the Admin keeps their edits',
      (WidgetTester tester) async {
        await open(tester, AdminPaths.product('p-1'));
        await tester.enterText(field('name_uz'), 'Pomidorlar');
        // Archived meanwhile, in another tab.
        catalog.productRows = <AdminProduct>[
          adminProduct(archivedAt: DateTime.utc(2026, 9, 26, 6)),
        ];
        catalog.changeFailure = const ApiRefusal(
          ApiError(status: 409, code: 'business_conflict'),
        );

        await tapAndSettle(tester, byKey('product-save'));
        expect(find.text(l10n(tester).errorBusinessConflict), findsOneWidget);
        expect(find.text(l10n(tester).catalogArchivedNote), findsOneWidget);
        expect(field('is_active'), findsNothing);
        expect(textOf(tester, 'name_uz'), 'Pomidorlar');

        await tapAndSettle(tester, byKey('product-save'));
        final ProductDraft sent = catalog.savedProducts.last.$2;
        expect(sent.nameUz, 'Pomidorlar');
        expect(sent.isActive, isNull);
        expect(find.text(l10n(tester).productSaved), findsOneWidget);
      },
    );

    testWidgets(
      'a reload refreshes an untouched form and leaves unsaved edits alone',
      (WidgetTester tester) async {
        await open(tester, AdminPaths.product('p-1'));
        // Renamed by another Admin; the image change below reloads it.
        catalog.productRows = <AdminProduct>[
          adminProduct(nameUz: 'Pomidor pushti'),
        ];
        picker.next = _png();
        await tapAndSettle(tester, byKey('choose-image'));
        await tapAndSettle(tester, byKey('upload-image'));
        expect(textOf(tester, 'name_uz'), 'Pomidor pushti');

        await tester.enterText(field('name_ru'), 'Томат');
        picker.next = _png();
        await tapAndSettle(tester, byKey('choose-image'));
        await tapAndSettle(tester, byKey('upload-image'));
        expect(catalog.uploads, hasLength(2));
        expect(textOf(tester, 'name_ru'), 'Томат');

        await tapAndSettle(tester, byKey('product-save'));
        expect(catalog.savedProducts.single.$2.nameRu, 'Томат');
        expect(catalog.savedProducts.single.$2.nameUz, 'Pomidor pushti');
      },
    );

    testWidgets("the form's and the image's failures stay apart", (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.product('p-1'));
      await tester.enterText(field('name_uz'), 'Pomidorlar');
      catalog.changeFailure = const NetworkFailure();
      await tapAndSettle(tester, byKey('product-save'));

      picker.next = _png();
      await tapAndSettle(tester, byKey('choose-image'));
      catalog.changeFailure = const ApiRefusal(
        ApiError(status: 413, code: 'payload_too_large'),
      );
      await tapAndSettle(tester, byKey('upload-image'));

      expect(find.text(l10n(tester).errorNetwork), findsOneWidget);
      expect(find.text(l10n(tester).errorPayloadTooLarge), findsOneWidget);

      await tapAndSettle(tester, byKey('back-to-products'));
      expect(find.text(l10n(tester).errorNetwork), findsNothing);
      expect(find.text(l10n(tester).errorPayloadTooLarge), findsNothing);
    });

    testWidgets('signing out while a save runs leaves nothing behind', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.newProduct);
      await fillNewProduct(tester);
      catalog.hold = Completer<void>();
      await tester.tap(byKey('product-save'));
      await tester.pump();

      await signOut(tester);
      final String signedOut = location(tester);
      expect(signedOut, isNot(startsWith('/admin')));

      catalog.hold!.complete();
      await tester.pumpAndSettle();
      expect(location(tester), signedOut);
      expect(find.text(l10n(tester).productSaved), findsNothing);
    });

    testWidgets('after signing out the lists ask for nothing more', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.products);
      final int asked = catalog.productQueries.length;

      await signOut(tester);

      expect(catalog.productQueries, hasLength(asked));
    });

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

  group('narrow window', () {
    testWidgets('long names and large text fit a phone-wide window', (
      WidgetTester tester,
    ) async {
      final String longUz = 'Sabzavotlar, ko\'katlar va dukkaklilar ' * 3;
      final String longRu = 'Овощи, зелень и бобовые на каждый день ' * 3;
      catalog.categoryRows = <AdminCategory>[
        adminCategory(nameUz: longUz.trim(), nameRu: longRu.trim()),
      ];
      catalog.productRows = <AdminProduct>[
        for (int i = 1; i <= 25; i++)
          adminProduct(id: 'p-$i', nameUz: 'Mahsulot $i', nameRu: 'Товар $i'),
      ];
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await open(tester, AdminPaths.products, size: const Size(360, 2600));
      expect(byKey('product-category-filter'), findsOneWidget);
      expect(byKey('next-page'), findsOneWidget);

      await tapAndSettle(tester, find.text('Mahsulot 1'));
      expect(field('category_id'), findsOneWidget);
      await tester.ensureVisible(byKey('product-save'));
      await tester.ensureVisible(byKey('choose-image'));
      await tester.pumpAndSettle();

      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go(AdminPaths.categories);
      await tester.pumpAndSettle();
      await tapAndSettle(tester, byKey('edit-c-1'));
      await tester.ensureVisible(byKey('category-save'));
      await tester.pumpAndSettle();
      expect(byKey('category-dialog'), findsOneWidget);
    });
  });

  group('category picture', () {
    testWidgets('a new category offers the picture only after saving', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.categories);
      await tapAndSettle(tester, byKey('new-category'));

      expect(find.text(l10n(tester).categoryImageAfterSave), findsOneWidget);
      expect(byKey('category-choose-image'), findsNothing);
    });

    testWidgets('a picture is uploaded, shown and removed after asking', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.categories);
      await tapAndSettle(tester, byKey('edit-c-1'));
      expect(byKey('category-choose-image'), findsOneWidget);
      expect(byKey('category-remove-image'), findsNothing);
      picker.next = _png();

      await tapAndSettle(tester, byKey('category-choose-image'));
      expect(byKey('category-picked-image'), findsOneWidget);
      await tapAndSettle(tester, byKey('category-upload-image'));

      final (String id, PickedImage sent) = catalog.categoryUploads.single;
      expect(id, 'c-1');
      expect(sent.name, 'pomidor.png');
      expect(byKey('category-picked-image'), findsNothing);
      expect(byKey('category-remove-image'), findsOneWidget);
      expect(
        catalog.categoryRows.single.imageUrl,
        'https://api.test/storage/categories/1.png',
      );

      await tapAndSettle(tester, byKey('category-remove-image'));
      expect(byKey('category-remove-image-dialog'), findsOneWidget);
      expect(
        find.text(l10n(tester).categoryRemoveImageConfirm),
        findsOneWidget,
      );
      expect(
        find.text(l10n(tester).categoryRemoveImageExplained),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(byKey('category-confirm-remove-image'))
            .style
            ?.backgroundColor
            ?.resolve(<WidgetState>{}),
        KitColors.danger,
      );
      await tapAndSettle(tester, byKey('action-cancel'));
      expect(byKey('category-remove-image-dialog'), findsNothing);
      expect(catalog.removedCategoryImages, isEmpty);

      await tapAndSettle(tester, byKey('category-remove-image'));
      await tapAndSettle(tester, byKey('category-confirm-remove-image'));
      expect(catalog.removedCategoryImages, <String>['c-1']);
      expect(byKey('category-remove-image'), findsNothing);
      expect(catalog.categoryRows.single.imageUrl, isNull);
    });

    testWidgets('the row shows the picture, or the first letter', (
      WidgetTester tester,
    ) async {
      catalog.categoryRows = <AdminCategory>[
        adminCategory(imageUrl: 'https://api.test/storage/categories/a.webp'),
        adminCategory(id: 'c-2', nameUz: 'Mevalar', nameRu: 'Фрукты'),
      ];
      await open(tester, AdminPaths.categories);

      expect(
        find.descendant(
          of: byKey('category-thumb-c-1'),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: byKey('category-thumb-c-2'),
          matching: find.text('M'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: byKey('category-thumb-c-2'),
          matching: find.byType(Image),
        ),
        findsNothing,
      );
    });

    for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
      testWidgets(
        'the category dialog fits 320 px at double text in ${device.languageCode}',
        (WidgetTester tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await open(
            tester,
            AdminPaths.categories,
            size: const Size(320, 640),
            device: device,
          );
          await tapAndSettle(tester, byKey('edit-c-1'));
          await tester.ensureVisible(byKey('category-choose-image'));
          await tester.pumpAndSettle();

          expect(byKey('category-choose-image'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
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

    testWidgets('an image from another origin may fall back to the browser', (
      WidgetTester tester,
    ) async {
      catalog.productRows = <AdminProduct>[
        adminProduct(imageUrl: 'https://api.test/storage/products/a.webp'),
      ];
      await open(tester, AdminPaths.product('p-1'));

      final NetworkImage image =
          tester
                  .widget<Image>(
                    find.descendant(
                      of: find.byKey(const ValueKey<String>('current-image')),
                      matching: find.byType(Image),
                    ),
                  )
                  .image
              as NetworkImage;
      expect(image.url, 'https://api.test/storage/products/a.webp');
      expect(image.webHtmlElementStrategy, WebHtmlElementStrategy.fallback);
    });

    testWidgets('removing the image asks first', (WidgetTester tester) async {
      catalog.productRows = <AdminProduct>[
        adminProduct(imageUrl: 'https://api.test/storage/products/a.webp'),
      ];
      await open(tester, AdminPaths.product('p-1'));

      await tapAndSettle(tester, byKey('remove-image'));
      expect(byKey('remove-image-dialog'), findsOneWidget);
      expect(find.text(l10n(tester).productRemoveImageConfirm), findsOneWidget);
      expect(
        find.text(l10n(tester).productRemoveImageExplained),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(byKey('confirm-remove-image'))
            .style
            ?.backgroundColor
            ?.resolve(<WidgetState>{}),
        KitColors.danger,
      );
      await tapAndSettle(tester, byKey('action-cancel'));
      expect(byKey('remove-image-dialog'), findsNothing);
      expect(catalog.removedImages, isEmpty);

      await tapAndSettle(tester, byKey('remove-image'));
      await tapAndSettle(tester, byKey('confirm-remove-image'));
      expect(catalog.removedImages, <String>['p-1']);
      expect(byKey('remove-image'), findsNothing);
    });

    testWidgets('a picked image waits with its label until it is uploaded', (
      WidgetTester tester,
    ) async {
      catalog.productRows = <AdminProduct>[
        adminProduct(imageUrl: 'https://api.test/storage/products/a.webp'),
      ];
      await open(tester, AdminPaths.product('p-1'));
      picker.next = _png();

      await tapAndSettle(tester, byKey('choose-image'));

      expect(
        find.descendant(
          of: byKey('picked-image'),
          matching: find.text(l10n(tester).productImagePicked),
        ),
        findsOneWidget,
      );
      expect(byKey('remove-image'), findsNothing);
      expect(
        tester.getTopLeft(byKey('upload-image')).dy,
        lessThan(tester.getTopLeft(byKey('choose-image')).dy),
      );

      await tapAndSettle(tester, byKey('upload-image'));
      expect(find.text(l10n(tester).productImagePicked), findsNothing);
    });

    for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
      for (final bool compact in <bool>[false, true]) {
        for (final double width in <double>[360, 720]) {
          testWidgets(
            'the ${compact ? 'compact' : 'square'} card holds at x2 and $width '
            'px in ${device.languageCode}',
            (WidgetTester tester) async {
              tester.platformDispatcher.textScaleFactorTestValue = 2;
              addTearDown(
                tester.platformDispatcher.clearTextScaleFactorTestValue,
              );
              tester.view.physicalSize = Size(width, 1600);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.reset);
              picker.next = _png(size: PickedImage.maxBytes + 1);

              await tester.pumpWidget(
                ProviderScope(
                  overrides: [
                    productImagePickerProvider.overrideWithValue(picker),
                  ],
                  child: MaterialApp(
                    locale: device,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    home: Scaffold(
                      body: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: CatalogImageCard(
                          imageUrl: 'https://api.test/storage/products/a.webp',
                          onUpload: (PickedImage image) async {},
                          onRemove: () async {},
                          change: const MutationIdle(),
                          keyPrefix: '',
                          compact: compact,
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              await tester.tap(byKey('choose-image'));
              await tester.pumpAndSettle();

              expect(byKey('image-problem'), findsOneWidget);
              expect(byKey('current-image'), findsOneWidget);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }

    testWidgets('a product that does not exist says so', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.product('p-404'));

      expect(find.text(l10n(tester).errorNotFound), findsOneWidget);
      expect(field('name_uz'), findsNothing);
      expect(byKey('retry-load'), findsNothing);
      expect(byKey('back-to-products'), findsOneWidget);
    });

    testWidgets('a product that failed to load can be asked for again', (
      WidgetTester tester,
    ) async {
      catalog.loadFailure = const NetworkFailure();
      await open(tester, AdminPaths.product('p-1'));
      expect(find.text(l10n(tester).errorNetwork), findsOneWidget);

      await tapAndSettle(tester, byKey('retry-load'));

      expect(textOf(tester, 'name_uz'), 'Pomidor');
    });
  });

  group('fix wave', () {
    Future<void> resize(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
    }

    testWidgets('typing survives the 1000 boundary on a saved product', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        AdminPaths.product('p-1'),
        size: const Size(1048, 1000),
      );
      await tester.enterText(field('name_uz'), 'Qizil pomidor');
      await tester.pumpAndSettle();

      await resize(tester, const Size(1047, 1000));
      expect(
        tester.widget<CatalogImageCard>(find.byType(CatalogImageCard)).compact,
        isTrue,
      );
      expect(textOf(tester, 'name_uz'), 'Qizil pomidor');

      await resize(tester, const Size(1048, 1000));
      expect(textOf(tester, 'name_uz'), 'Qizil pomidor');
    });

    testWidgets('a picked image survives the 1000 boundary', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        AdminPaths.product('p-1'),
        size: const Size(1048, 1000),
      );
      picker.next = _png();
      await tapAndSettle(tester, byKey('choose-image'));
      expect(byKey('picked-image'), findsOneWidget);

      await resize(tester, const Size(1047, 1000));
      expect(byKey('picked-image'), findsOneWidget);

      await resize(tester, const Size(1048, 1000));
      expect(byKey('picked-image'), findsOneWidget);
    });

    testWidgets('typing survives the 1000 boundary on a new product', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.newProduct, size: const Size(1048, 1000));
      await tester.enterText(field('name_uz'), 'Bodring');
      await tester.pumpAndSettle();

      await resize(tester, const Size(1047, 1000));
      expect(textOf(tester, 'name_uz'), 'Bodring');

      await resize(tester, const Size(1048, 1000));
      expect(textOf(tester, 'name_uz'), 'Bodring');
    });

    testWidgets("an earlier action's failure is not shown in another window", (
      WidgetTester tester,
    ) async {
      catalog.productRows = <AdminProduct>[
        adminProduct(),
        adminProduct(id: 'p-2', nameUz: 'Olma', nameRu: 'Яблоко'),
      ];
      await open(tester, AdminPaths.products);
      final Finder failure = find.descendant(
        of: byKey('archive-dialog'),
        matching: find.text(l10n(tester).errorBusinessConflict),
      );
      const ApiRefusal conflict = ApiRefusal(
        ApiError(status: 409, code: 'business_conflict'),
      );

      catalog.changeFailure = conflict;
      await tapAndSettle(tester, byKey('archive-p-1'));
      await tapAndSettle(tester, byKey('archive-confirm'));
      expect(failure, findsOneWidget);
      await tapAndSettle(tester, byKey('action-cancel'));

      await tapAndSettle(tester, byKey('archive-p-2'));
      expect(byKey('archive-dialog'), findsOneWidget);
      expect(failure, findsNothing);

      catalog.changeFailure = conflict;
      await tapAndSettle(tester, byKey('archive-confirm'));
      expect(failure, findsOneWidget);
    });

    testWidgets('a product page that did not load has no "new product" title', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.product('p-404'));

      expect(find.text(l10n(tester).productNew), findsNothing);
      expect(byKey('product-title'), findsNothing);
      expect(byKey('back-to-products'), findsOneWidget);
    });

    testWidgets('the square picture is clipped at radius 16, not 87', (
      WidgetTester tester,
    ) async {
      catalog.productRows = <AdminProduct>[
        adminProduct(imageUrl: 'https://api.test/storage/products/a.webp'),
      ];
      await open(
        tester,
        AdminPaths.product('p-1'),
        size: const Size(1400, 1000),
      );

      final ClipRRect clip = tester.widget<ClipRRect>(
        find.descendant(
          of: byKey('current-image'),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, BorderRadius.circular(16));
    });

    testWidgets(
      'a category without a picture shows the letter it is named by',
      (WidgetTester tester) async {
        await open(tester, AdminPaths.categories, device: const Locale('ru'));

        expect(
          find.descendant(
            of: byKey('category-thumb-c-1'),
            matching: find.text('О'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('a switch row is one labelled control the whole row toggles', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await open(tester, AdminPaths.product('p-1'));

      expect(
        tester.getSemantics(field('is_active')).label,
        contains(l10n(tester).catalogShownToCustomers),
      );

      final Finder title = find.text(l10n(tester).catalogShownToCustomers);
      await tester.ensureVisible(title);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(field('is_active')).value, isTrue);
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(field('is_active')).value, isFalse);
      semantics.dispose();
    });

    testWidgets('the saved prices show before the refetch lands', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.product('p-1'));
      final AppLocalizations text = l10n(tester);
      catalog.loadHold = Completer<void>();

      await tester.enterText(field('market_price_uzs'), '20 000');
      await tapAndSettle(tester, byKey('product-save'));

      expect(
        find.descendant(
          of: byKey('customer-price'),
          matching: find.text(
            text.productCustomerPriceBasis(
              MoneyFormat.uzs(20000, AppLanguage.uz),
            ),
          ),
        ),
        findsOneWidget,
      );
      catalog.loadHold!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('the search hint is not covered by the Enter key', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.products);

      final Finder hint = find.text(l10n(tester).productSearch);
      final Finder enter = byKey('search-enter-hint');
      expect(hint, findsOneWidget);
      // 60 in the font of the app; the test font is wider.
      expect(tester.getSize(enter).width, lessThan(80));
      expect(tester.getRect(hint).overlaps(tester.getRect(enter)), isFalse);
    });

    testWidgets('the category filter hugs its label instead of a fixed 240', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        AdminPaths.products,
        size: const Size(820, 1180),
        device: const Locale('ru'),
      );

      expect(
        tester.getSize(byKey('product-category-filter')).width,
        lessThan(240),
      );
    });

    testWidgets('the category field is white like the unit field', (
      WidgetTester tester,
    ) async {
      await open(tester, AdminPaths.product('p-1'));

      InputDecoration decoration(String apiKey) => tester
          .widget<InputDecorator>(
            find.descendant(
              of: field(apiKey),
              matching: find.byType(InputDecorator),
            ),
          )
          .decoration;
      expect(decoration('category_id').fillColor, Colors.white);
      expect(
        decoration('category_id').fillColor,
        decoration('unit_code').fillColor,
      );
      expect(decoration('category_id').filled, isTrue);
    });

    testWidgets('the picture buttons are 12 px compact and 13 px square', (
      WidgetTester tester,
    ) async {
      catalog.productRows = <AdminProduct>[
        adminProduct(imageUrl: 'https://api.test/storage/products/a.webp'),
      ];
      double sizeOf(String key) => tester
          .widget<DefaultTextStyle>(
            find
                .descendant(
                  of: byKey(key),
                  matching: find.byType(DefaultTextStyle),
                )
                .last,
          )
          .style
          .fontSize!;

      await open(
        tester,
        AdminPaths.product('p-1'),
        size: const Size(1400, 1000),
      );
      expect(sizeOf('choose-image'), 13);
      expect(sizeOf('remove-image'), 13);

      await open(
        tester,
        AdminPaths.product('p-1'),
        size: const Size(800, 1400),
      );
      expect(sizeOf('choose-image'), 12);
      expect(sizeOf('remove-image'), 12);
    });

    testWidgets('a card reaches the card edge with its prices and button', (
      WidgetTester tester,
    ) async {
      catalog.productRows = <AdminProduct>[
        adminProduct(customerUnitPriceUzs: 100),
      ];
      await open(tester, AdminPaths.products, size: const Size(847, 1180));

      final AppLocalizations text = l10n(tester);
      final Finder caption = find.text(
        '${text.catalogPerUnit(CatalogLabels.unit(text, UnitCode.kg))}'
        ' · '
        '${text.catalogForCustomer(MoneyFormat.uzs(100, AppLanguage.uz))}',
      );
      final double card = tester.getTopRight(byKey('product-p-1')).dx;
      // The 36 button stands in a 44 tap box: 4 more to the card edge (DL-117).
      expect(card - tester.getTopRight(byKey('archive-p-1')).dx, lessThan(24));
      // The prices take the width they need and the names the rest: the
      // caption stands on one line instead of wrapping at half the free space.
      expect(tester.getSize(caption).height, lessThan(20));
    });

    testWidgets('the compact picture of the product page is on a white card', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        AdminPaths.product('p-1'),
        size: const Size(800, 1400),
      );

      expect(
        find.ancestor(
          of: byKey('choose-image'),
          matching: find.byType(KitCard),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(CatalogImageCard),
          matching: find.text(l10n(tester).productImage),
        ),
        findsOneWidget,
      );
    });

    for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
      for (final Size size in const <Size>[Size(1440, 900), Size(820, 1180)]) {
        testWidgets('the archive window and the remove-image window hold at '
            'the extremes (${device.languageCode} ${size.width.toInt()})', (
          WidgetTester tester,
        ) async {
          final String name = ('Pomidor ' * 20).substring(0, 160);
          catalog.productRows = <AdminProduct>[
            adminProduct(
              nameUz: name,
              nameRu: name,
              imageUrl: 'https://api.test/storage/products/a.webp',
            ),
          ];
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await open(tester, AdminPaths.products, size: size, device: device);
          await tapAndSettle(tester, byKey('archive-p-1'));
          expect(byKey('archive-dialog'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tapAndSettle(tester, byKey('action-cancel'));

          GoRouter.of(tester.element(find.byType(Scaffold).first))
              .go(AdminPaths.product('p-1'));
          await tester.pumpAndSettle();
          await tapAndSettle(tester, byKey('remove-image'));
          expect(byKey('remove-image-dialog'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  testWidgets('the products list: every target meets iOSTapTargetGuideline', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await open(tester, AdminPaths.products);

    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });
}
