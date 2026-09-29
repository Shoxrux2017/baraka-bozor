import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/session/session_controller.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/shells/presentation/staff_area_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_repository.dart';

/// A session controller whose state the test sets.
class _Session extends SessionController {
  _Session(this._initial);

  final SessionState _initial;

  @override
  Future<SessionState> build() async => _initial;
}

/// The staff area's menu offers Customer mode only to those
/// `docs/02-user-roles.md` section 10 lets in, and always the way out.
void main() {
  Future<void> openMenu(WidgetTester tester, AppUser staff) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(
            () => _Session(
              SignedIn(
                activeMode: SessionMode.staff,
                staffUser: staff,
                customerUser: null,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('uz'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: AppBar(actions: const <Widget>[StaffAreaMenu()]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('staff-menu')));
    await tester.pumpAndSettle();
  }

  final Finder customerMode = find.byKey(
    const ValueKey<String>('switch-to-customer-button'),
  );
  final Finder logout = find.byKey(const ValueKey<String>('logout-button'));

  testWidgets('a Courier is offered Customer mode and the way out', (
    WidgetTester tester,
  ) async {
    await openMenu(tester, user(role: UserRole.courier));

    expect(customerMode, findsOneWidget);
    expect(logout, findsOneWidget);
  });

  testWidgets('an Operator, or a Shopper before the password change, is not', (
    WidgetTester tester,
  ) async {
    for (final AppUser staff in <AppUser>[
      user(role: UserRole.operator),
      user(role: UserRole.shopper, mustChangePassword: true),
    ]) {
      await openMenu(tester, staff);

      expect(customerMode, findsNothing, reason: '${staff.role}');
      expect(logout, findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
