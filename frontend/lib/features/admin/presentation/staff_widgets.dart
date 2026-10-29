import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/role_labels.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../auth/domain/app_user.dart';

/// The staff roles an Admin creates and filters by, in the order the pills
/// and the form offer them.
const List<UserRole> staffRoles = <UserRole>[
  UserRole.shopper,
  UserRole.courier,
  UserRole.operator,
  UserRole.admin,
  UserRole.manager,
];

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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
              color: blocked ? KitColors.danger : KitColors.primaryDark,
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

/// The roles as tiles, two to a row from [twoColumnsWidth] wide at normal text
/// and one below that or at large text,
/// 10 apart: each says where the role works, and the chosen one is outlined in
/// `primary`. A null [onSelected] holds the choice.
class StaffRoleTiles extends StatelessWidget {
  const StaffRoleTiles({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  static const double twoColumnsWidth = 440;

  final UserRole selected;
  final ValueChanged<UserRole>? onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns =
            constraints.maxWidth >= twoColumnsWidth && !kitLargeText(context)
            ? 2
            : 1;
        Widget tile(int index) => _RoleTile(
          role: staffRoles[index],
          selected: staffRoles[index] == selected,
          onSelected: onSelected,
        );
        final List<Widget> rows = <Widget>[];

        for (int start = 0; start < staffRoles.length; start += columns) {
          rows.add(
            columns == 1
                ? tile(start)
                : IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(child: tile(start)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: start + 1 < staffRoles.length
                              ? tile(start + 1)
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < rows.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 10),
              rows[i],
            ],
          ],
        );
      },
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.role,
    required this.selected,
    required this.onSelected,
  });

  final UserRole role;
  final bool selected;
  final ValueChanged<UserRole>? onSelected;

  String _hint(AppLocalizations l10n) => switch (role) {
    UserRole.shopper => l10n.staffRoleShopperHint,
    UserRole.courier => l10n.staffRoleCourierHint,
    UserRole.operator => l10n.staffRoleOperatorHint,
    UserRole.admin => l10n.staffRoleAdminHint,
    UserRole.manager => l10n.staffRoleManagerHint,
    UserRole.customer => '',
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ValueChanged<UserRole>? onSelected = this.onSelected;

    return Semantics(
      button: true,
      selected: selected,
      enabled: onSelected != null,
      child: Material(
        key: ValueKey<String>('role-${role.name}'),
        color: selected ? KitColors.primaryWash : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? KitColors.primary : KitColors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onSelected == null ? null : () => onSelected(role),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected ? KitColors.primary : KitColors.field,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    StaffRoleChip.iconOf(role),
                    size: 20,
                    color: selected ? Colors.white : KitColors.muted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        roleLabel(l10n, role),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: KitColors.ink,
                        ),
                      ),
                      Text(
                        _hint(l10n),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: KitColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? KitColors.primary : KitColors.line,
                      width: selected ? 6 : 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
