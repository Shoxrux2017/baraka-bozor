import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/session/session_state.dart';

enum _StaffAction { customerMode, logout }

/// A staff area's own actions in one menu of the app bar: the way into
/// Customer mode for a Shopper or a Courier, and the way out. One button
/// keeps the app bar from crowding a phone's width (`DL-69` (5)).
class StaffAreaMenu extends ConsumerWidget {
  const StaffAreaMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SessionState? state = ref.watch(sessionControllerProvider).value;
    if (state is! SignedIn) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<_StaffAction>(
      key: const ValueKey<String>('staff-menu'),
      tooltip: l10n.staffMenu,
      onSelected: (_StaffAction action) {
        switch (action) {
          case _StaffAction.customerMode:
            // The Customer session opened with the code that signed in, so
            // the switch asks for nothing (`docs/02-user-roles.md`
            // section 10).
            ref
                .read(sessionControllerProvider.notifier)
                .switchMode(SessionMode.customer);
          case _StaffAction.logout:
            ref
                .read(sessionControllerProvider.notifier)
                .logout(state.activeMode);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<_StaffAction>>[
        if (state.canOfferCustomerMode)
          PopupMenuItem<_StaffAction>(
            key: const ValueKey<String>('switch-to-customer-button'),
            value: _StaffAction.customerMode,
            child: Text(l10n.switchToCustomer),
          ),
        PopupMenuItem<_StaffAction>(
          key: const ValueKey<String>('logout-button'),
          value: _StaffAction.logout,
          child: Text(l10n.logoutButton),
        ),
      ],
    );
  }
}
