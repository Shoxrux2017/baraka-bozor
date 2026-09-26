import 'dart:async';

import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/core/state/mutation_state.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/admin/application/admin_staff_controllers.dart';
import 'package:baraka_bozor/features/admin/domain/admin_staff.dart';
import 'package:baraka_bozor/features/admin/presentation/admin_paths.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_admin_staff_repository.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/in_memory_stores.dart';

/// The panel's staff screen (W1-11) through the real router, session and
/// screens, against staff accounts in memory.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeAdminStaffRepository staff;
  late List<String> clipboard;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  Finder inDialog(Finder finder) =>
      find.descendant(of: find.byType(AlertDialog), matching: finder);

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  setUp(() {
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    staff = FakeAdminStaffRepository();
    clipboard = <String>[];
    tokens.tokens[SessionSlot.staff] = 's';
    auth.identities[SessionSlot.staff] = user(role: UserRole.admin);
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(1400, 1600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add(
            (call.arguments as Map<Object?, Object?>)['text']! as String,
          );
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        surface: Surface.web,
        overrides: [adminStaffRepositoryProvider.overrideWithValue(staff)],
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go(AdminPaths.staff);
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

  Future<void> fillNewStaff(WidgetTester tester) async {
    await tapAndSettle(tester, byKey('new-staff'));
    await tester.enterText(byKey('field-full_name'), 'Aziz Rahimov');
    await tester.enterText(byKey('field-phone'), '90 765 43 21');
  }

  /// Escape and a tap beside the dialog: neither may close it.
  Future<void> tryToDismiss(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
  }

  testWidgets(
    'a new staff member is created and the password is shown once, then forgotten',
    (WidgetTester tester) async {
      await open(tester);

      await tapAndSettle(tester, byKey('new-staff'));
      await tester.enterText(byKey('field-full_name'), '  Aziz Rahimov ');
      await tester.enterText(byKey('field-phone'), '90 765 43 21');
      await tapAndSettle(tester, byKey('field-role'));
      await tapAndSettle(tester, find.text(l10n(tester).roleCourier).last);
      await tapAndSettle(tester, byKey('staff-save'));

      final NewStaffMember sent = staff.created.single;
      expect(sent.fullName, 'Aziz Rahimov');
      expect(sent.phone, '+998907654321');
      expect(sent.role, UserRole.courier);

      final String password = staff.issued.single;
      expect(find.text(password), findsOneWidget);
      expect(
        find.text(l10n(tester).staffTemporaryPasswordWarning),
        findsOneWidget,
      );
      // While the password shows, the controller that answered it holds
      // nothing but its state.
      expect(
        container(tester).read(newStaffControllerProvider),
        isA<MutationIdle>(),
      );
      await tapAndSettle(tester, byKey('copy-password'));
      expect(clipboard, <String>[password]);
      expect(find.text(l10n(tester).staffCopied), findsOneWidget);

      await tapAndSettle(tester, byKey('password-done'));

      expect(find.text(password), findsNothing);
      expect(find.textContaining('Aziz Rahimov'), findsOneWidget);
      expect(find.text(l10n(tester).staffMustChangePassword), findsOneWidget);
    },
  );

  testWidgets(
    'neither the create nor its password can be dismissed by accident',
    (WidgetTester tester) async {
      await open(tester);
      await fillNewStaff(tester);
      staff.hold = Completer<void>();

      await tester.tap(byKey('staff-save'));
      await tester.pump();
      await tryToDismiss(tester);
      expect(byKey('staff-save'), findsOneWidget);

      staff.hold!.complete();
      await tester.pumpAndSettle();
      final String password = staff.issued.single;
      await tryToDismiss(tester);
      await tester.pumpAndSettle();
      expect(find.text(password), findsOneWidget);

      await tapAndSettle(tester, byKey('password-done'));
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('signing out while a create runs shows no password', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await fillNewStaff(tester);
    staff.hold = Completer<void>();
    await tester.tap(byKey('staff-save'));
    await tester.pump();

    await container(tester)
        .read(sessionControllerProvider.notifier)
        .logout(SessionMode.staff);
    await tester.pumpAndSettle();
    staff.hold!.complete();
    await tester.pumpAndSettle();

    expect(staff.issued, hasLength(1));
    expect(find.text(staff.issued.single), findsNothing);
    expect(byKey('temporary-password'), findsNothing);
  });

  testWidgets('a failure shows where it happened and nowhere else', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await fillNewStaff(tester);
    staff.changeFailure = const NetworkFailure();
    await tapAndSettle(tester, byKey('staff-save'));
    expect(inDialog(find.text(l10n(tester).errorNetwork)), findsOneWidget);

    await tapAndSettle(tester, find.text(l10n(tester).cancelButton));
    expect(find.text(l10n(tester).errorNetwork), findsNothing);

    staff.changeFailure = const ApiRefusal(
      ApiError(status: 409, code: 'last_active_admin_required'),
    );
    await tapAndSettle(tester, byKey('block-s-1'));
    await tapAndSettle(tester, byKey('confirm-action'));
    expect(
      find.text(l10n(tester).errorLastActiveAdminRequired),
      findsOneWidget,
    );

    await tapAndSettle(tester, byKey('rename-s-1'));
    expect(
      inDialog(find.text(l10n(tester).errorLastActiveAdminRequired)),
      findsNothing,
    );
  });

  testWidgets('the form refuses a bad name or phone and sends nothing', (
    WidgetTester tester,
  ) async {
    await open(tester);

    await tapAndSettle(tester, byKey('new-staff'));
    await tester.enterText(byKey('field-phone'), '90 765');
    await tapAndSettle(tester, byKey('staff-save'));

    expect(find.text(l10n(tester).fieldRequired), findsOneWidget);
    expect(find.text(l10n(tester).phoneInvalid), findsOneWidget);
    expect(staff.created, isEmpty);
  });

  testWidgets(
    'a phone another active staff account holds is explained, and the form stays',
    (WidgetTester tester) async {
      staff.changeFailure = const ApiRefusal(
        ApiError(status: 409, code: 'phone_already_active'),
      );
      await open(tester);

      await tapAndSettle(tester, byKey('new-staff'));
      await tester.enterText(byKey('field-full_name'), 'Aziz Rahimov');
      await tester.enterText(byKey('field-phone'), '901112233');
      await tapAndSettle(tester, byKey('staff-save'));

      expect(find.text(l10n(tester).errorPhoneAlreadyActive), findsWidgets);
      expect(byKey('staff-save'), findsOneWidget);
      expect(staff.issued, isEmpty);
    },
  );

  testWidgets('block asks first; a blocked account is activated again', (
    WidgetTester tester,
  ) async {
    await open(tester);

    await tapAndSettle(tester, byKey('block-s-1'));
    expect(
      find.text(l10n(tester).staffBlockConfirm('Dilnoza Karimova')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: byKey('confirm-action'),
        matching: find.text(l10n(tester).staffBlock),
      ),
      findsOneWidget,
    );
    await tapAndSettle(tester, find.text(l10n(tester).cancelButton));
    expect(staff.actions, isEmpty);

    await tapAndSettle(tester, byKey('block-s-1'));
    await tapAndSettle(tester, byKey('confirm-action'));
    expect(staff.actions, <String>['block s-1']);
    expect(find.text(l10n(tester).statusBlocked), findsWidgets);

    await tapAndSettle(tester, byKey('activate-s-1'));
    expect(staff.actions, <String>['block s-1', 'activate s-1']);
    expect(byKey('block-s-1'), findsOneWidget);
  });

  testWidgets('a reset asks first, then shows the new password once', (
    WidgetTester tester,
  ) async {
    await open(tester);

    await tapAndSettle(tester, byKey('reset-s-1'));
    expect(
      find.text(l10n(tester).staffResetConfirm('Dilnoza Karimova')),
      findsOneWidget,
    );
    await tapAndSettle(tester, find.text(l10n(tester).cancelButton));
    expect(staff.actions, isEmpty);

    await tapAndSettle(tester, byKey('reset-s-1'));
    staff.hold = Completer<void>();
    await tester.tap(byKey('confirm-action'));
    await tester.pump();
    await tryToDismiss(tester);
    expect(byKey('confirm-action'), findsOneWidget);

    staff.hold!.complete();
    await tester.pumpAndSettle();
    final String password = staff.issued.single;
    expect(staff.actions, <String>['reset s-1']);
    expect(find.text(password), findsOneWidget);
    await tapAndSettle(tester, byKey('password-done'));
    expect(find.text(password), findsNothing);
  });

  testWidgets('a refused reset explains itself in its dialog', (
    WidgetTester tester,
  ) async {
    staff.changeFailure = const ApiRefusal(
      ApiError(status: 409, code: 'self_reset_not_allowed'),
    );
    await open(tester);

    await tapAndSettle(tester, byKey('reset-s-1'));
    await tapAndSettle(tester, byKey('confirm-action'));

    expect(
      inDialog(find.text(l10n(tester).errorSelfResetNotAllowed)),
      findsOneWidget,
    );
    expect(staff.issued, isEmpty);
  });

  testWidgets('a refused block explains why', (WidgetTester tester) async {
    staff.changeFailure = const ApiRefusal(
      ApiError(status: 409, code: 'last_active_admin_required'),
    );
    await open(tester);

    await tapAndSettle(tester, byKey('block-s-1'));
    await tapAndSettle(tester, byKey('confirm-action'));

    expect(
      find.text(l10n(tester).errorLastActiveAdminRequired),
      findsOneWidget,
    );
  });

  testWidgets('a name is changed', (WidgetTester tester) async {
    await open(tester);

    await tapAndSettle(tester, byKey('rename-s-1'));
    await tester.enterText(
      byKey('field-full_name'),
      'Dilnoza Karimova-Aliyeva',
    );
    await tapAndSettle(tester, byKey('rename-save'));

    expect(staff.actions, <String>['rename s-1 Dilnoza Karimova-Aliyeva']);
    expect(find.textContaining('Dilnoza Karimova-Aliyeva'), findsOneWidget);
    expect(find.text(l10n(tester).staffSaved), findsOneWidget);
  });

  testWidgets('the role and status filters narrow the list', (
    WidgetTester tester,
  ) async {
    staff.members = <StaffMember>[
      staffMember(),
      staffMember(
        id: 's-2',
        role: UserRole.courier,
        fullName: 'Aziz Rahimov',
        status: AccountStatus.blocked,
      ),
    ];
    await open(tester);
    expect(find.textContaining('Aziz Rahimov'), findsOneWidget);

    await tapAndSettle(tester, byKey('staff-role-filter'));
    await tapAndSettle(tester, find.text(l10n(tester).roleShopper).last);
    expect(staff.queries.last.role, UserRole.shopper);
    expect(find.textContaining('Aziz Rahimov'), findsNothing);

    await tapAndSettle(tester, byKey('staff-role-filter'));
    await tapAndSettle(tester, find.text(l10n(tester).staffAllRoles).last);
    await tapAndSettle(tester, byKey('staff-status-filter'));
    await tapAndSettle(tester, find.text(l10n(tester).statusBlocked).last);
    expect(staff.queries.last.status, AccountStatus.blocked);
    expect(find.textContaining('Dilnoza'), findsNothing);
    expect(find.textContaining('Aziz Rahimov'), findsOneWidget);
  });

  testWidgets('the filters are kept while the Admin is elsewhere', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tapAndSettle(tester, byKey('staff-role-filter'));
    await tapAndSettle(tester, find.text(l10n(tester).roleShopper).last);

    final GoRouter router = GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    );
    router.go(AdminPaths.settings);
    await tester.pumpAndSettle();
    router.go(AdminPaths.staff);
    await tester.pumpAndSettle();

    expect(staff.queries.last.role, UserRole.shopper);
  });

  testWidgets('after signing out the list asks for nothing more', (
    WidgetTester tester,
  ) async {
    await open(tester);
    final int asked = staff.queries.length;

    await container(tester)
        .read(sessionControllerProvider.notifier)
        .logout(SessionMode.staff);
    await tester.pumpAndSettle();

    expect(staff.queries, hasLength(asked));
  });

  testWidgets('a phone-size window with large text fits every dialog', (
    WidgetTester tester,
  ) async {
    staff.members = <StaffMember>[
      staffMember(fullName: 'Dilnoza Karimova-Aliyeva Rustamovna'),
    ];
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, size: const Size(360, 640));
    expect(byKey('staff-s-1'), findsOneWidget);

    await fillNewStaff(tester);
    await tapAndSettle(tester, byKey('staff-save'));
    expect(byKey('temporary-password'), findsOneWidget);
    await tapAndSettle(tester, byKey('password-done'));

    // The new account heads the list now.
    await tapAndSettle(tester, byKey('reset-s-new-0'));
    await tapAndSettle(tester, byKey('confirm-action'));
    expect(byKey('temporary-password'), findsOneWidget);
    await tapAndSettle(tester, byKey('password-done'));

    await tapAndSettle(tester, byKey('block-s-new-0'));
    await tapAndSettle(tester, find.text(l10n(tester).cancelButton));
    await tapAndSettle(tester, byKey('rename-s-new-0'));
    await tapAndSettle(tester, byKey('rename-save'));
  });

  testWidgets("the Admin's own account can be renamed only", (
    WidgetTester tester,
  ) async {
    staff.members = <StaffMember>[
      staffMember(),
      staffMember(id: 'u-1', role: UserRole.admin, fullName: 'Admin'),
    ];
    await open(tester);

    expect(byKey('own-u-1'), findsOneWidget);
    expect(byKey('rename-u-1'), findsOneWidget);
    expect(byKey('block-u-1'), findsNothing);
    expect(byKey('reset-u-1'), findsNothing);
    expect(byKey('own-s-1'), findsNothing);
    expect(byKey('block-s-1'), findsOneWidget);
  });

  testWidgets('a block confirmed after the Admin left blocks nothing', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tapAndSettle(tester, byKey('block-s-1'));

    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go(AdminPaths.settings);
    await tester.pumpAndSettle();
    await tapAndSettle(tester, byKey('confirm-action'));

    expect(staff.actions, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the list pages', (WidgetTester tester) async {
    staff.members = <StaffMember>[
      for (int i = 1; i <= 25; i++)
        staffMember(id: 's-$i', fullName: 'Xodim $i'),
    ];
    await open(tester);
    expect(find.textContaining('Xodim 25'), findsNothing);
    await tapAndSettle(tester, byKey('next-page'));

    expect(staff.queries.last.page, 2);
    expect(find.textContaining('Xodim 25'), findsOneWidget);
    expect(find.textContaining('Xodim 1 '), findsNothing);
  });

  testWidgets('a name the server refused is marked in the rename dialog', (
    WidgetTester tester,
  ) async {
    staff.changeFailure = const ApiRefusal(
      ApiError(
        status: 422,
        code: 'validation_failed',
        errors: <String, List<String>>{
          'full_name': <String>['The full name field is invalid.'],
        },
      ),
    );
    await open(tester);

    await tapAndSettle(tester, byKey('rename-s-1'));
    await tester.enterText(byKey('field-full_name'), 'Dilnoza K.');
    await tapAndSettle(tester, byKey('rename-save'));

    expect(find.text(l10n(tester).fieldRejected), findsOneWidget);
    expect(byKey('rename-save'), findsOneWidget);
  });

  testWidgets('signing out while a reset runs shows no password', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tapAndSettle(tester, byKey('reset-s-1'));
    staff.hold = Completer<void>();
    await tester.tap(byKey('confirm-action'));
    await tester.pump();

    await container(tester)
        .read(sessionControllerProvider.notifier)
        .logout(SessionMode.staff);
    await tester.pumpAndSettle();
    staff.hold!.complete();
    await tester.pumpAndSettle();

    expect(staff.issued, hasLength(1));
    expect(find.text(staff.issued.single), findsNothing);
    expect(byKey('temporary-password'), findsNothing);
  });
}
