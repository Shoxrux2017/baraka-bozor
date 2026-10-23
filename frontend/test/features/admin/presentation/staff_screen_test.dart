import 'dart:async';

import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/core/formatting/phone_format.dart';
import 'package:baraka_bozor/core/formatting/tashkent_time.dart';
import 'package:baraka_bozor/core/state/mutation_state.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/kit/kit_card.dart';
import 'package:baraka_bozor/core/widgets/panel/panel_card.dart';
import 'package:baraka_bozor/core/widgets/panel/panel_page_header.dart';
import 'package:baraka_bozor/core/widgets/panel/panel_person.dart';
import 'package:baraka_bozor/core/widgets/panel/panel_pills.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/admin/application/admin_staff_controllers.dart';
import 'package:baraka_bozor/features/admin/domain/admin_staff.dart';
import 'package:baraka_bozor/features/admin/presentation/admin_paths.dart';
import 'package:baraka_bozor/features/admin/presentation/staff_widgets.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/operations/domain/board.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_admin_staff_repository.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_operations_repository.dart';
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
    FakeOperationsRepository? operations,
    Locale device = const Locale('uz'),
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
        device: device,
        operations: operations,
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

  testWidgets(
    'blocking a Shopper or a Courier says how many orders are in their hands',
    (WidgetTester tester) async {
      staff.members = <StaffMember>[
        staffMember(),
        staffMember(
          id: 's-2',
          role: UserRole.courier,
          phone: '+998905554433',
          fullName: 'Kamol Karimov',
        ),
        staffMember(
          id: 's-3',
          role: UserRole.operator,
          phone: '+998907776655',
          fullName: 'Olim Operator',
        ),
        staffMember(
          id: 's-4',
          role: UserRole.courier,
          phone: '+998903332211',
          fullName: 'Botir Aliyev',
        ),
      ];
      await open(
        tester,
        operations: FakeOperationsRepository(
          // Each list holds only its own role, so a count read from the
          // other role's list would be missing.
          shopperList: const <StaffChoice>[
            StaffChoice(
              id: 's-1',
              fullName: 'Dilnoza Karimova',
              phone: '+998901112233',
              currentAssignmentCount: 3,
            ),
          ],
          courierList: const <StaffChoice>[
            StaffChoice(
              id: 's-2',
              fullName: 'Kamol Karimov',
              phone: '+998905554433',
              currentAssignmentCount: 2,
            ),
            StaffChoice(
              id: 's-4',
              fullName: 'Botir Aliyev',
              phone: '+998903332211',
              currentAssignmentCount: 0,
            ),
          ],
        ),
      );

      for (final (String id, int count) in <(String, int)>[
        ('s-1', 3),
        ('s-2', 2),
      ]) {
        await tapAndSettle(tester, byKey('block-$id'));
        expect(
          tester.widget<Text>(byKey('block-current-orders')).data,
          l10n(tester).staffBlockCurrentOrders(count),
        );
        await tapAndSettle(tester, find.text(l10n(tester).cancelButton));
      }

      // Nothing in hand, or a role that holds no orders: nothing to say.
      for (final String id in <String>['s-4', 's-3']) {
        await tapAndSettle(tester, byKey('block-$id'));
        expect(byKey('block-current-orders'), findsNothing);
        await tapAndSettle(tester, find.text(l10n(tester).cancelButton));
      }
      expect(staff.actions, isEmpty);
    },
  );

  testWidgets(
    'the block confirmation says when the count is loading or unknown, never nothing',
    (WidgetTester tester) async {
      final FakeOperationsRepository operations = FakeOperationsRepository(
        shopperList: const <StaffChoice>[],
      );
      await open(tester, operations: operations);
      String said() => tester.widget<Text>(byKey('block-current-orders')).data!;

      // A Shopper the list does not hold.
      await tapAndSettle(tester, byKey('block-s-1'));
      expect(said(), l10n(tester).staffBlockOrdersUnknown);
      await tapAndSettle(tester, find.text(l10n(tester).cancelButton));

      // The list failed.
      operations.shoppersFailure = const NetworkFailure();
      await tapAndSettle(tester, byKey('block-s-1'));
      expect(said(), l10n(tester).staffBlockOrdersUnknown);
      await tapAndSettle(tester, find.text(l10n(tester).cancelButton));

      // The list is on its way, then holds the Shopper.
      operations
        ..shoppersFailure = null
        ..shopperList = const <StaffChoice>[
          StaffChoice(
            id: 's-1',
            fullName: 'Dilnoza Karimova',
            phone: '+998901112233',
            currentAssignmentCount: 1,
          ),
        ];
      final Completer<void> hold = Completer<void>();
      operations.hold = hold;
      await tapAndSettle(tester, byKey('block-s-1'));
      expect(said(), l10n(tester).staffBlockOrdersLoading);
      operations.hold = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(said(), l10n(tester).staffBlockCurrentOrders(1));
      await tapAndSettle(tester, find.text(l10n(tester).cancelButton));
      expect(staff.actions, isEmpty);
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

  bool pillSelected(WidgetTester tester, String key) =>
      tester.widget<PanelPill>(byKey(key)).selected;

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
    expect(pillSelected(tester, 'staff-role-all'), isTrue);

    await tapAndSettle(tester, byKey('staff-role-courier'));
    expect(staff.queries.last.role, UserRole.courier);
    expect(pillSelected(tester, 'staff-role-courier'), isTrue);
    expect(pillSelected(tester, 'staff-role-all'), isFalse);
    expect(find.textContaining('Dilnoza'), findsNothing);
    expect(find.textContaining('Aziz Rahimov'), findsOneWidget);

    await tapAndSettle(tester, byKey('staff-role-all'));
    expect(staff.queries.last.role, isNull);
    expect(pillSelected(tester, 'staff-role-all'), isTrue);
    expect(find.textContaining('Dilnoza'), findsOneWidget);

    final String blocked = l10n(tester).statusBlocked;
    OutlinedButton statusButton() =>
        tester.widget<OutlinedButton>(byKey('staff-status-filter'));
    expect(
      statusButton().style!.backgroundColor!.resolve(<WidgetState>{}),
      Colors.white,
    );
    await tapAndSettle(tester, byKey('staff-status-filter'));
    await tapAndSettle(tester, byKey('staff-status-filter-2'));
    expect(staff.queries.last.status, AccountStatus.blocked);
    expect(
      find.descendant(
        of: byKey('staff-status-filter'),
        matching: find.text(blocked),
      ),
      findsOneWidget,
    );
    expect(
      statusButton().style!.backgroundColor!.resolve(<WidgetState>{}),
      KitColors.primaryWash,
    );
    expect(find.textContaining('Dilnoza'), findsNothing);
    expect(find.textContaining('Aziz Rahimov'), findsOneWidget);
  });

  testWidgets('the filters are kept while the Admin is elsewhere', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tapAndSettle(tester, byKey('staff-role-courier'));
    await tapAndSettle(tester, byKey('staff-status-filter'));
    await tapAndSettle(tester, byKey('staff-status-filter-2'));

    final GoRouter router = GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    );
    router.go(AdminPaths.settings);
    await tester.pumpAndSettle();
    router.go(AdminPaths.staff);
    await tester.pumpAndSettle();

    expect(staff.queries.last.role, UserRole.courier);
    expect(staff.queries.last.status, AccountStatus.blocked);
    expect(pillSelected(tester, 'staff-role-courier'), isTrue);
  });

  testWidgets('the header counts the staff', (WidgetTester tester) async {
    staff.members = <StaffMember>[
      staffMember(),
      staffMember(id: 's-2', fullName: 'Aziz Rahimov'),
      staffMember(id: 's-3', fullName: 'Kamol Karimov'),
    ];
    await open(tester);

    final Finder header = find.byType(PanelPageHeader);
    final Finder title = find.descendant(
      of: header,
      matching: find.text(l10n(tester).adminSectionStaff),
    );
    final Finder count = find.descendant(
      of: header,
      matching: find.text(l10n(tester).staffCount(3)),
    );
    expect(title, findsOneWidget);
    expect(count, findsOneWidget);
    expect(
      tester.getTopLeft(count).dy,
      greaterThan(tester.getTopLeft(title).dy),
    );

    final Rect button = tester.getRect(byKey('new-staff'));
    expect(button.height, 40);
    expect(button.center.dx, greaterThan(tester.getCenter(title).dx));
    expect(tester.getRect(header).right - button.right, lessThan(1));
    expect(
      find.descendant(
        of: byKey('new-staff'),
        matching: find.text(l10n(tester).staffNew),
      ),
      findsOneWidget,
    );
  });

  group('a wide card is a table and a narrow one cards', () {
    // The card is the window less the page padding (24 either side) below
    // the icon rail, so 848 makes it 800 and 847 makes it 799.
    for (final (double width, bool table) in <(double, bool)>[
      (848, true),
      (1440, true),
      (847, false),
      (820, false),
    ]) {
      testWidgets('at ${width.toInt()}', (WidgetTester tester) async {
        staff.members = <StaffMember>[
          staffMember(),
          staffMember(id: 's-2', fullName: 'Aziz Rahimov'),
        ];
        await open(tester, size: Size(width, width == 1440 ? 900 : 1000));
        final AppLocalizations text = l10n(tester);
        final Finder inCard = find.descendant(
          of: find.byType(PanelCard),
          matching: find.byType(Table),
        );

        if (table) {
          expect(inCard, findsWidgets);
          for (final String header in <String>[
            text.staffColumnMember,
            text.staffRole,
            text.staffColumnStatus,
            text.staffColumnLastLogin,
          ]) {
            expect(find.text(header.toUpperCase()), findsOneWidget);
          }
          expect(tester.widget(byKey('staff-s-1')), isNot(isA<KitCard>()));
        } else {
          expect(find.byType(Table), findsNothing);
          expect(tester.widget(byKey('staff-s-1')), isA<KitCard>());
          expect(tester.widget(byKey('staff-s-2')), isA<KitCard>());
          expect(find.text(text.staffColumnMember.toUpperCase()), findsNothing);
        }

        final Finder wrapped = find.ancestor(
          of: byKey('staff-role-all'),
          matching: find.byType(Wrap),
        );
        final Finder scrolling = find.ancestor(
          of: byKey('staff-role-all'),
          matching: find.byWidgetPredicate(
            (Widget w) =>
                w is SingleChildScrollView &&
                w.scrollDirection == Axis.horizontal,
          ),
        );
        expect(wrapped, table ? findsOneWidget : findsNothing);
        expect(scrolling, table ? findsNothing : findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('a row says who, what, where and when', (
    WidgetTester tester,
  ) async {
    final DateTime seen = DateTime.utc(2026, 10, 1, 7, 30);
    staff.members = <StaffMember>[
      staffMember(
        id: 's-1',
        role: UserRole.courier,
        fullName: 'Kamol Karimov',
        phone: '+998905554433',
        mustChangePassword: true,
      ),
      staffMember(id: 's-2', fullName: 'Aziz Rahimov', lastLoginAt: seen),
      staffMember(
        id: 's-3',
        role: UserRole.operator,
        fullName: 'Olim Operator',
        status: AccountStatus.blocked,
      ),
      staffMember(id: 'u-1', role: UserRole.admin, fullName: 'Admin'),
    ];
    await open(tester);
    final AppLocalizations text = l10n(tester);
    Finder inRow(String id, Finder finder) =>
        find.descendant(of: byKey('staff-$id'), matching: finder);

    expect(inRow('s-1', find.text('Kamol Karimov')), findsOneWidget);
    expect(
      inRow('s-1', find.text(formatPhone('+998905554433'))),
      findsOneWidget,
    );
    expect(
      inRow(
        's-1',
        find.byWidgetPredicate(
          (Widget w) => w is StaffRoleChip && w.role == UserRole.courier,
        ),
      ),
      findsOneWidget,
    );
    expect(inRow('s-1', find.text(text.roleCourier)), findsOneWidget);
    expect(
      inRow(
        's-1',
        find.byWidgetPredicate(
          (Widget w) => w is AccountStatusChip && !w.blocked,
        ),
      ),
      findsOneWidget,
    );
    expect(inRow('s-1', find.byType(MustChangePasswordTag)), findsOneWidget);
    expect(inRow('s-1', find.text(text.staffNeverLoggedIn)), findsOneWidget);
    expect(inRow('s-2', find.byType(MustChangePasswordTag)), findsNothing);
    expect(inRow('s-2', find.text(TashkentTime.format(seen))), findsOneWidget);
    expect(inRow('s-2', find.text(text.staffNeverLoggedIn)), findsNothing);

    // A blocked row is faded, with a grey avatar and the way back.
    DecoratedBox box(String id) =>
        tester.widget<DecoratedBox>(byKey('staff-$id'));
    expect((box('s-3').decoration as BoxDecoration).color, KitColors.card);
    expect((box('s-2').decoration as BoxDecoration).color, isNull);
    expect(
      tester
          .widget<PersonAvatar>(inRow('s-3', find.byType(PersonAvatar)))
          .muted,
      isTrue,
    );
    expect(
      tester
          .widget<PersonAvatar>(inRow('s-2', find.byType(PersonAvatar)))
          .muted,
      isFalse,
    );
    expect(
      inRow(
        's-3',
        find.byWidgetPredicate(
          (Widget w) => w is AccountStatusChip && w.blocked,
        ),
      ),
      findsOneWidget,
    );
    expect(byKey('activate-s-3'), findsOneWidget);
    expect(byKey('block-s-3'), findsNothing);

    // The own row keeps the rename alone.
    expect(inRow('u-1', byKey('own-u-1')), findsOneWidget);
    expect(inRow('u-1', find.text(text.staffYou)), findsOneWidget);
    expect(byKey('rename-u-1'), findsOneWidget);
    expect(byKey('reset-u-1'), findsNothing);
    expect(byKey('block-u-1'), findsNothing);
    expect(byKey('activate-u-1'), findsNothing);
  });

  testWidgets('a card says the same as a row', (WidgetTester tester) async {
    final DateTime seen = DateTime.utc(2026, 10, 1, 7, 30);
    staff.members = <StaffMember>[
      staffMember(
        id: 's-1',
        role: UserRole.courier,
        fullName: 'Kamol Karimov',
        mustChangePassword: true,
      ),
      staffMember(id: 's-2', fullName: 'Aziz Rahimov', lastLoginAt: seen),
    ];
    await open(tester, size: const Size(820, 1180));
    final AppLocalizations text = l10n(tester);
    Finder inCard(String id, Finder finder) =>
        find.descendant(of: byKey('staff-$id'), matching: finder);

    expect(inCard('s-1', find.byType(StaffRoleChip)), findsOneWidget);
    expect(inCard('s-1', find.byType(AccountStatusChip)), findsOneWidget);
    expect(inCard('s-1', find.byType(MustChangePasswordTag)), findsOneWidget);
    expect(inCard('s-1', find.text(text.staffNeverLoggedIn)), findsOneWidget);
    expect(
      inCard('s-2', find.text(text.staffLastLogin(TashkentTime.format(seen)))),
      findsOneWidget,
    );
    expect(inCard('s-1', byKey('block-s-1')), findsOneWidget);
    expect(inCard('s-1', byKey('reset-s-1')), findsOneWidget);
    expect(inCard('s-1', byKey('rename-s-1')), findsOneWidget);
  });

  testWidgets('the actions name themselves', (WidgetTester tester) async {
    staff.members = <StaffMember>[
      staffMember(),
      staffMember(
        id: 's-2',
        fullName: 'Aziz Rahimov',
        status: AccountStatus.blocked,
      ),
    ];
    await open(tester);
    final AppLocalizations text = l10n(tester);

    String tooltip(String key) => tester
        .widget<Tooltip>(
          find.ancestor(of: byKey(key), matching: find.byType(Tooltip)),
        )
        .message!;
    expect(tooltip('rename-s-1'), text.staffEditName);
    expect(tooltip('reset-s-1'), text.staffResetPassword);
    expect(tooltip('block-s-1'), text.staffBlock);
    expect(tooltip('activate-s-2'), text.staffActivate);

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(byKey('block-s-1')));
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.descendant(
        of: find.byType(Overlay),
        matching: find.text(text.staffBlock),
      ),
      findsWidgets,
    );
  });

  testWidgets('nothing found says how to widen it', (
    WidgetTester tester,
  ) async {
    await open(tester);
    expect(find.text(l10n(tester).staffEmptyHint), findsNothing);

    await tapAndSettle(tester, byKey('staff-role-courier'));

    expect(find.text(l10n(tester).catalogEmpty), findsOneWidget);
    expect(find.text(l10n(tester).staffEmptyHint), findsOneWidget);
  });

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    for (final Size size in const <Size>[Size(1440, 900), Size(820, 1180)]) {
      testWidgets('the staff list holds at the extremes '
          '(${device.languageCode} ${size.width.toInt()})', (
        WidgetTester tester,
      ) async {
        staff.members = <StaffMember>[
          staffMember(fullName: 'Dilnoza ' * 15),
          staffMember(
            id: 's-2',
            role: UserRole.courier,
            fullName: 'Aziz Rahimov',
            mustChangePassword: true,
            status: AccountStatus.blocked,
          ),
          staffMember(id: 'u-1', role: UserRole.admin, fullName: 'Admin'),
        ];
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await open(tester, size: size, device: device);

        expect(byKey('staff-s-1'), findsOneWidget);
        expect(byKey('new-staff'), findsOneWidget);
        expect(byKey('staff-role-manager'), findsOneWidget);
        expect(byKey('staff-status-filter'), findsOneWidget);
        expect(tester.takeException(), isNull);

        for (final String key in <String>[
          'block-s-1',
          'reset-s-1',
          'rename-s-1',
          'activate-s-2',
        ]) {
          await tester.ensureVisible(byKey(key));
          await tester.pumpAndSettle();
          expect(byKey(key), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

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
