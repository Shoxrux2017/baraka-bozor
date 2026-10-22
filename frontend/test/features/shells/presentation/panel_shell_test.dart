import 'dart:async';

import 'package:baraka_bozor/core/widgets/brand_wordmark.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/localization/role_labels.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/admin/application/admin_staff_controllers.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/operations/data/operations_api.dart';
import 'package:baraka_bozor/features/shells/presentation/panel_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_admin_staff_repository.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_operations_repository.dart';
import '../../../support/in_memory_stores.dart';
import '../../../support/operations_json.dart';

/// The web panel's shell for the Admin and the Operator (`docs/02` section
/// 7, `DL-37` (17), `DL-46`, `DL-100`): each role's menu in three widths, and
/// a reload of a deep page, through the real router and session controller.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeAdminStaffRepository staff;

  const List<String> adminSections = <String>[
    AppPaths.adminCategories,
    AppPaths.adminProducts,
    AppPaths.adminStaff,
    AppPaths.adminCustomers,
    AppPaths.adminLegalDocuments,
    AppPaths.adminSettings,
  ];

  Finder section(String path) =>
      find.byKey(ValueKey<String>('panel-section-$path'));
  final Finder board = find.byKey(const ValueKey<String>('operations-board'));
  final Finder rail = find.byKey(const ValueKey<String>('panel-rail'));
  final Finder drawer = find.byKey(const ValueKey<String>('panel-drawer'));
  final Finder logout = find.byKey(const ValueKey<String>('logout-button'));
  final Finder badge = find.byKey(
    const ValueKey<String>('panel-attention-badge'),
  );
  final Finder sectionKeys = find.byWidgetPredicate(
    (Widget w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('panel-section-'),
  );

  BuildContext anywhere(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).first);

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(anywhere(tester));

  String menuTooltip(WidgetTester tester) =>
      MaterialLocalizations.of(anywhere(tester)).openAppDrawerTooltip;

  String location(WidgetTester tester) =>
      GoRouter.of(anywhere(tester)).routeInformationProvider.value.uri
          .toString();

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.staff] = 's';
    auth = FakeAuthRepository();
    staff = FakeAdminStaffRepository();
  });

  /// Opens the panel signed in as [role]. With [reload] the browser asks for
  /// that page first, as a reload does; with [hold] the session stays
  /// unknown until the test completes it.
  Future<void> open(
    WidgetTester tester,
    UserRole role, {
    Size size = const Size(1440, 1000),
    String? reload,
    Completer<void>? hold,
    FakeOperationsRepository? operations,
    Locale device = const Locale('uz'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (reload != null) {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = reload;
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
    }
    auth
      ..identities[SessionSlot.staff] = user(role: role)
      ..holdAnswers = hold;

    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        surface: Surface.web,
        operations: operations,
        device: device,
        overrides: [adminStaffRepositoryProvider.overrideWithValue(staff)],
      ),
    );
    // A held session keeps the bootstrap spinner turning, which never settles.
    if (hold == null) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets(
    'an Admin lands on the board and moves between it and its own sections',
    (WidgetTester tester) async {
      await open(tester, UserRole.admin);

      expect(location(tester), AppPaths.operations);
      expect(board, findsOneWidget);
      expect(
        find.text(roleLabel(l10n(tester), UserRole.admin)),
        findsOneWidget,
      );
      expect(rail, findsOneWidget);
      expect(section(AppPaths.operations), findsOneWidget);
      for (final String path in adminSections) {
        expect(section(path), findsOneWidget, reason: path);
      }

      await tester.tap(section(AppPaths.adminStaff));
      await tester.pumpAndSettle();
      expect(location(tester), AppPaths.adminStaff);
      expect(staff.queries, isNotEmpty);

      await tester.tap(section(AppPaths.operations));
      await tester.pumpAndSettle();
      expect(location(tester), AppPaths.operations);
      expect(board, findsOneWidget);

      // The Admin area's own root is the board.
      GoRouter.of(anywhere(tester)).go(AppPaths.admin);
      await tester.pumpAndSettle();
      expect(location(tester), AppPaths.operations);
    },
  );

  testWidgets('a wide window shows the Admin\'s whole menu', (
    WidgetTester tester,
  ) async {
    await open(tester, UserRole.admin, size: const Size(1440, 900));

    expect(rail, findsOneWidget);
    expect(tester.getSize(rail).width, 232);
    expect(section(AppPaths.operations), findsOneWidget);
    for (final String path in adminSections) {
      expect(section(path), findsOneWidget, reason: path);
    }
    expect(
      find.descendant(of: rail, matching: find.text('Aziza Karimova')),
      findsOneWidget,
    );
    expect(find.text(roleLabel(l10n(tester), UserRole.admin)), findsOneWidget);
    expect(logout, findsOneWidget);
    expect(find.byIcon(Icons.language), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('the whole menu stacks the language above the way out', (
    WidgetTester tester,
  ) async {
    await open(tester, UserRole.admin, size: const Size(1440, 900));

    final Finder language = find.byType(PanelLanguageButton);
    // The rail's 1 px right border and the 16 px gutters on both sides.
    final double footerWidth = tester.getSize(rail).width - 1 - 32;
    expect(tester.getSize(language).height, 38);
    expect(tester.getSize(logout).height, 38);
    expect(tester.getSize(language).width, footerWidth);
    expect(tester.getSize(logout).width, footerWidth);
    expect(
      tester.getTopLeft(logout).dy,
      greaterThan(tester.getBottomLeft(language).dy),
    );
    expect(tester.getTopLeft(logout).dy - tester.getBottomLeft(language).dy, 8);
    expect(tester.takeException(), isNull);
  });

  for (final (Locale locale, String name) in <(Locale, String)>[
    (const Locale('uz'), "O'zbekcha"),
    (const Locale('ru'), 'Русский'),
  ]) {
    testWidgets(
      'the whole menu shows the language name whole in ${locale.languageCode}',
      (WidgetTester tester) async {
        await open(
          tester,
          UserRole.admin,
          size: const Size(1440, 900),
          device: locale,
        );

        final Finder text = find.descendant(
          of: find.byType(PanelLanguageButton),
          matching: find.text(name),
        );
        expect(text, findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('the whole menu holds with text x2', (WidgetTester tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, UserRole.admin, size: const Size(1440, 900));

    expect(logout, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the drawer keeps them one above the other', (
    WidgetTester tester,
  ) async {
    await open(tester, UserRole.admin, size: const Size(820, 1180));
    await tester.tap(find.byTooltip(menuTooltip(tester)));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(logout).dy,
      greaterThan(tester.getBottomLeft(find.byType(PanelLanguageButton)).dy),
    );
  });

  testWidgets('the menu is whole at 1440 and folds at 1439', (
    WidgetTester tester,
  ) async {
    await open(tester, UserRole.admin, size: const Size(1440, 900));
    expect(tester.getSize(rail).width, 232);

    await open(tester, UserRole.admin, size: const Size(1439, 900));
    expect(tester.getSize(rail).width, 76);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the rail stands at exactly 1200 and the top bar at 1199', (
    WidgetTester tester,
  ) async {
    await open(tester, UserRole.admin, size: const Size(1200, 900));
    expect(tester.getSize(rail).width, 76);

    await open(tester, UserRole.admin, size: const Size(1199, 900));
    expect(rail, findsNothing);
    expect(find.byTooltip(menuTooltip(tester)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a laptop window folds the menu to icons that name themselves', (
    WidgetTester tester,
  ) async {
    await open(tester, UserRole.admin, size: const Size(1280, 800));

    final AppLocalizations text = l10n(tester);
    expect(rail, findsOneWidget);
    expect(tester.getSize(rail).width, 76);
    for (final String label in <String>[
      text.panelSectionBoard,
      text.adminSectionProducts,
    ]) {
      expect(
        find.descendant(of: rail, matching: find.text(label)),
        findsNothing,
      );
    }
    expect(find.byTooltip(text.adminSectionProducts), findsOneWidget);

    await tester.tap(find.byTooltip(text.adminSectionProducts));
    await tester.pumpAndSettle();
    expect(location(tester), AppPaths.adminProducts);
    expect(logout, findsOneWidget);
  });

  for (final Size size in const <Size>[Size(1199, 900), Size(820, 1180)]) {
    testWidgets('a window under 1200 puts the menu behind a button ($size)', (
      WidgetTester tester,
    ) async {
      await open(tester, UserRole.admin, size: size);

      expect(rail, findsNothing);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(BrandWordmark), findsOneWidget);
      await tester.tap(find.byTooltip(menuTooltip(tester)));
      await tester.pumpAndSettle();

      expect(drawer, findsOneWidget);
      expect(section(AppPaths.operations), findsOneWidget);
      for (final String path in adminSections) {
        expect(section(path), findsOneWidget, reason: path);
      }
      expect(
        find.descendant(of: drawer, matching: find.text('Aziza Karimova')),
        findsOneWidget,
      );
      expect(logout, findsOneWidget);

      await tester.tap(section(AppPaths.adminStaff));
      await tester.pumpAndSettle();

      expect(location(tester), AppPaths.adminStaff);
      expect(drawer, findsNothing, reason: 'closed');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the board\'s entry carries the attention count', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      UserRole.admin,
      operations: FakeOperationsRepository(
        summary: OperationsApi.parseSummary(summaryJson(attention: 6)),
      ),
    );
    expect(badge, findsOneWidget);
    expect(
      find.descendant(of: badge, matching: find.text('6')),
      findsOneWidget,
    );

    await open(
      tester,
      UserRole.admin,
      operations: FakeOperationsRepository(
        summary: OperationsApi.parseSummary(summaryJson(attention: 0)),
      ),
    );
    expect(badge, findsNothing);
  });

  testWidgets('an Operator sees the board alone and no Admin section opens', (
    WidgetTester tester,
  ) async {
    await open(tester, UserRole.operator);

    expect(location(tester), AppPaths.operations);
    expect(board, findsOneWidget);
    expect(
      find.text(roleLabel(l10n(tester), UserRole.operator)),
      findsOneWidget,
    );
    expect(rail, findsOneWidget);
    expect(section(AppPaths.operations), findsOneWidget);
    expect(sectionKeys, findsOneWidget);
    for (final String path in adminSections) {
      expect(section(path), findsNothing, reason: path);
    }

    for (final String path in <String>[AppPaths.admin, ...adminSections]) {
      GoRouter.of(anywhere(tester)).go(path);
      await tester.pumpAndSettle();
      expect(location(tester), AppPaths.operations, reason: path);
    }
    expect(staff.queries, isEmpty);
  });

  testWidgets('an Operator signs out from the panel', (
    WidgetTester tester,
  ) async {
    await open(tester, UserRole.operator);

    await tester.tap(logout);
    await tester.pumpAndSettle();

    expect(auth.calls, contains('logout:staff'));
    expect(location(tester), AppPaths.auth);
  });

  testWidgets(
    'a narrow window gives the Operator a menu with the board alone',
    (WidgetTester tester) async {
      await open(tester, UserRole.operator, size: const Size(400, 800));

      expect(board, findsOneWidget);
      await tester.tap(find.byTooltip(menuTooltip(tester)));
      await tester.pumpAndSettle();

      expect(drawer, findsOneWidget);
      expect(section(AppPaths.operations), findsOneWidget);
      expect(sectionKeys, findsOneWidget);
      expect(logout, findsOneWidget);
    },
  );

  testWidgets(
    'a reload that met an unreachable server returns to its page after a retry',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          AppPaths.adminStaff;
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      auth.identities[SessionSlot.staff] = const NetworkFailure();

      await tester.pumpWidget(
        appUnderTest(
          tokens: tokens,
          repository: auth,
          surface: Surface.web,
          overrides: [adminStaffRepositoryProvider.overrideWithValue(staff)],
        ),
      );
      await tester.pumpAndSettle();
      expect(location(tester), '${AppPaths.unreachable}?next=%2Fadmin%2Fstaff');

      auth.identities[SessionSlot.staff] = user(role: UserRole.admin);
      await tester.tap(find.byKey(const ValueKey<String>('retry-button')));
      await tester.pumpAndSettle();

      expect(location(tester), AppPaths.adminStaff);
      expect(staff.queries, isNotEmpty);
    },
  );

  testWidgets(
    'an Admin\'s reload of a deep page returns there once the session is known',
    (WidgetTester tester) async {
      final Completer<void> hold = Completer<void>();
      await open(
        tester,
        UserRole.admin,
        reload: AppPaths.adminStaff,
        hold: hold,
      );

      expect(find.byType(BrandWordmark), findsOneWidget);
      expect(location(tester), '${AppPaths.bootstrap}?next=%2Fadmin%2Fstaff');

      hold.complete();
      await tester.pumpAndSettle();

      expect(location(tester), AppPaths.adminStaff);
      expect(staff.queries, isNotEmpty);
    },
  );

  testWidgets('an Operator\'s reload keeps the board and its query', (
    WidgetTester tester,
  ) async {
    final Completer<void> hold = Completer<void>();
    await open(
      tester,
      UserRole.operator,
      reload: '${AppPaths.operations}?status=new',
      hold: hold,
    );
    hold.complete();
    await tester.pumpAndSettle();

    expect(location(tester), '${AppPaths.operations}?status=new');
    expect(board, findsOneWidget);
  });

  testWidgets('an Operator\'s reload of an Admin page lands on the board', (
    WidgetTester tester,
  ) async {
    final Completer<void> hold = Completer<void>();
    await open(
      tester,
      UserRole.operator,
      reload: AppPaths.adminStaff,
      hold: hold,
    );
    hold.complete();
    await tester.pumpAndSettle();

    expect(location(tester), AppPaths.operations);
    expect(staff.queries, isEmpty);
  });

  testWidgets('the top bar holds on a phone with text x2', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, UserRole.operator, size: const Size(360, 800));

    expect(find.byTooltip(menuTooltip(tester)), findsOneWidget);
    expect(find.byType(BrandWordmark), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
