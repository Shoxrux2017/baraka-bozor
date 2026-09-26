import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/language_menu.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/session_state.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../auth/application/code_login_controller.dart';
import '../../auth/domain/app_user.dart';

/// The entry of one staff role's area: its name, the language switch, the
/// way out, and — for a Shopper or Courier — the way into Customer mode
/// (`docs/02-user-roles.md` section 10). The active mode is always visible
/// while two sessions exist. The area itself arrives with the feature that
/// owns it; until then the body says so.
class RoleShellScreen extends ConsumerWidget {
  const RoleShellScreen({required this.role, super.key});

  final UserRole role;

  static String labelOf(AppLocalizations l10n, UserRole role) => switch (role) {
    UserRole.customer => l10n.shellCustomer,
    UserRole.shopper => l10n.shellShopper,
    UserRole.courier => l10n.shellCourier,
    UserRole.operator => l10n.shellOperations,
    UserRole.admin => l10n.shellAdmin,
    UserRole.manager => l10n.shellManager,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SessionState? state = ref.watch(sessionControllerProvider).value;
    final SignedIn? session = state is SignedIn ? state : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(labelOf(l10n, role)),
        actions: <Widget>[
          const LanguageMenuButton(),
          if (session != null)
            IconButton(
              key: const ValueKey<String>('logout-button'),
              icon: const Icon(Icons.logout),
              tooltip: l10n.logoutButton,
              onPressed: () => ref
                  .read(sessionControllerProvider.notifier)
                  .logout(session.activeMode),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const ActiveModeBar(),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          l10n.shellPlaceholder,
                          textAlign: TextAlign.center,
                        ),
                        if (session != null)
                          ..._modeSwitch(context, ref, l10n, session),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _modeSwitch(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    SignedIn session,
  ) {
    if (role.isStaff && session.canOfferCustomerMode) {
      return <Widget>[
        const SizedBox(height: 24),
        OutlinedButton(
          key: const ValueKey<String>('switch-to-customer-button'),
          onPressed: () {
            if (session.customerUser != null) {
              ref
                  .read(sessionControllerProvider.notifier)
                  .switchMode(SessionMode.customer);
            } else {
              ref
                  .read(codeLoginControllerProvider.notifier)
                  .requestCodeForStaffAccount();
              context.go(AppPaths.customerMode);
            }
          },
          child: Text(l10n.switchToCustomer),
        ),
      ];
    }

    return const <Widget>[];
  }
}
