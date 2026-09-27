import 'dart:async';

import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/admin/application/admin_staff_controllers.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_admin_staff_repository.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/in_memory_stores.dart';

/// The web panel's shell for the Admin and the Operator (`docs/02` section
/// 7, `DL-37` (17), `DL-46`): each role's navigation, and a reload of a deep
/// page, through the real router and session controller.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeAdminStaffRepository staff;

  const List<String> adminSections = <String>[
    AppPaths.adminCategories,
    AppPaths.adminProducts,
    AppPaths.adminStaff,
    AppPaths.adminSettings,
  ];

  Finder section(String path) =>
      find.byKey(ValueKey<String>('panel-section-$path'));
  final Finder board = find.byKey(const ValueKey<String>('operations-board'));
  final Finder rail = find.byKey(const ValueKey<String>('panel-rail'));

  BuildContext anywhere(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).first);

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(anywhere(tester));

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
    Size size = const Size(1400, 1000),
    String? reload,
    Completer<void>? hold,
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
      expect(find.text(l10n(tester).shellAdmin), findsOneWidget);
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

  testWidgets('an Operator sees the board alone and no Admin section opens', (
    WidgetTester tester,
  ) async {
    await open(tester, UserRole.operator);

    expect(location(tester), AppPaths.operations);
    expect(board, findsOneWidget);
    expect(find.text(l10n(tester).shellOperations), findsOneWidget);
    // One section needs no navigation.
    expect(rail, findsNothing);
    expect(tester.widget<Scaffold>(find.byType(Scaffold).first).drawer, isNull);
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

  testWidgets('a narrow window puts the Admin\'s sections in a drawer', (
    WidgetTester tester,
  ) async {
    await open(tester, UserRole.admin, size: const Size(400, 800));

    expect(rail, findsNothing);
    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(section(AppPaths.adminStaff));
    await tester.pumpAndSettle();

    expect(location(tester), AppPaths.adminStaff);
    expect(section(AppPaths.adminStaff), findsNothing, reason: 'closed');
    expect(tester.takeException(), isNull);
  });

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

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(location(tester), '${AppPaths.bootstrap}?next=%2Fadmin%2Fstaff');

      hold.complete();
      await tester.pumpAndSettle();

      expect(location(tester), AppPaths.adminStaff);
      expect(staff.queries, isNotEmpty);
    },
  );

  testWidgets(
    'an Operator\'s reload keeps the board, and a page it may not see goes to the board',
    (WidgetTester tester) async {
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
    },
  );

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
}
