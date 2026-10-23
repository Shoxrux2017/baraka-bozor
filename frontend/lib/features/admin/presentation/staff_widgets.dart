import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/role_labels.dart';
import '../../../core/theme/kit_colors.dart';
import '../../auth/domain/app_user.dart';

/// A staff member's role: its icon and name in a `field` pill with a `line`
/// outline.
class StaffRoleChip extends StatelessWidget {
  const StaffRoleChip(this.role, {super.key});

  final UserRole role;

  static IconData iconOf(UserRole role) => switch (role) {
    UserRole.shopper => Icons.shopping_basket_outlined,
    UserRole.courier => Icons.two_wheeler,
    UserRole.operator => Icons.support_agent,
    UserRole.admin => Icons.admin_panel_settings_outlined,
    UserRole.manager => Icons.insights_outlined,
    UserRole.customer => Icons.person_outline,
  };

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KitColors.field,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: KitColors.line),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(iconOf(role), size: 17, color: KitColors.muted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  roleLabel(AppLocalizations.of(context), role),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: KitColors.ink2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An account's state: active in green, blocked in red.
class AccountStatusChip extends StatelessWidget {
  const AccountStatusChip({required this.blocked, super.key});

  final bool blocked;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: blocked ? KitColors.dangerWash : KitColors.primaryWash,
        borderRadius: BorderRadius.circular(6),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            blocked ? l10n.statusBlocked : l10n.statusActive,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: blocked ? KitColors.dangerDark : KitColors.primaryDark,
            ),
          ),
        ),
      ),
    );
  }
}

/// The amber tag of an account whose password is still the temporary one.
class MustChangePasswordTag extends StatelessWidget {
  const MustChangePasswordTag({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KitColors.warningWash,
        borderRadius: BorderRadius.circular(6),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.key_outlined,
                size: 14,
                color: KitColors.warningDark,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  AppLocalizations.of(context).staffMustChangePassword,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: KitColors.warningDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small "you" tag after the Admin's own name.
class OwnTag extends StatelessWidget {
  const OwnTag({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KitColors.primaryWash,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: KitColors.primarySoft),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          child: Text(
            AppLocalizations.of(context).staffYou,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: KitColors.primaryDark,
            ),
          ),
        ),
      ),
    );
  }
}
