import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../localization/generated/app_localizations.dart';
import '../session/session_state.dart';
import '../theme/kit_colors.dart';

/// Which session acts, across the top of every Customer and staff area
/// screen while two sessions exist: the active mode is always visible
/// (`docs/02-user-roles.md` section 10). A full-width bar rather than a chip
/// among the app bar's actions, which it would crowd off a phone's screen. In
/// the kit's look (`DL-80`): a soft green strip with rounded corners, 16 from
/// the sides.
class ActiveModeBar extends ConsumerWidget {
  const ActiveModeBar({this.action, super.key});

  /// Shown at the bar's end, and only while the bar shows: the Customer's
  /// home puts the way back to the staff area here (`DL-75`).
  final Widget? action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionState? state = ref.watch(sessionControllerProvider).value;
    if (state is! SignedIn ||
        state.staffUser == null ||
        state.customerUser == null) {
      return const SizedBox.shrink();
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool customer = state.activeMode == SessionMode.customer;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: KitColors.primaryWash,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          // The action shares the line while it fits; otherwise it takes its
          // own line at the end, so a large text never squeezes both.
          child: OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            overflowAlignment: OverflowBarAlignment.end,
            spacing: 8,
            overflowSpacing: 0,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    customer
                        ? Icons.shopping_basket_outlined
                        : Icons.badge_outlined,
                    size: 18,
                    color: KitColors.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      customer ? l10n.customerModeLabel : l10n.staffModeLabel,
                      key: const ValueKey<String>('active-mode'),
                      style: const TextStyle(
                        color: KitColors.ink2,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (action != null)
                TextButtonTheme(
                  data: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: KitColors.primaryDark,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  child: action!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [child] under the [ActiveModeBar], filling the rest of the screen.
class UnderActiveMode extends StatelessWidget {
  const UnderActiveMode({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const ActiveModeBar(),
        Expanded(child: child),
      ],
    );
  }
}
