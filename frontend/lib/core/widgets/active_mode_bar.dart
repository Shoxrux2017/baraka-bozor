import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../localization/generated/app_localizations.dart';
import '../session/session_state.dart';

/// Which session acts, across the top of every Customer and staff area
/// screen while two sessions exist: the active mode is always visible
/// (`docs/02-user-roles.md` section 10). A full-width bar rather than a chip
/// among the app bar's actions, which it would crowd off a phone's screen.
class ActiveModeBar extends ConsumerWidget {
  const ActiveModeBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionState? state = ref.watch(sessionControllerProvider).value;
    if (state is! SignedIn ||
        state.staffUser == null ||
        state.customerUser == null) {
      return const SizedBox.shrink();
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool customer = state.activeMode == SessionMode.customer;

    return Material(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: <Widget>[
            Icon(
              customer ? Icons.shopping_basket_outlined : Icons.badge_outlined,
              size: 18,
              color: colors.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                customer ? l10n.customerModeLabel : l10n.staffModeLabel,
                key: const ValueKey<String>('active-mode'),
                style: TextStyle(color: colors.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
