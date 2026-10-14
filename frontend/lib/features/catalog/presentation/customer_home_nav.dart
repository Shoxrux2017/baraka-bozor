import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/brand_colors.dart';

/// The home's floating bar (design 4a): the home itself, the Customer's
/// orders and their profile. Orders and the profile open over the home, so
/// the system back returns to it.
class CustomerHomeNav extends StatelessWidget {
  const CustomerHomeNav({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Material(
        color: Colors.white,
        elevation: 8,
        shadowColor: const Color(0x29111827),
        shape: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: _CurrentTab(
                    icon: Icons.home_rounded,
                    label: l10n.homeNavHome,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _Tab(
                    key: const ValueKey<String>('open-orders'),
                    icon: Icons.receipt_long_outlined,
                    label: l10n.homeNavOrders,
                    onTap: () => context.push(AppPaths.customerOrders),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _Tab(
                    key: const ValueKey<String>('open-profile'),
                    icon: Icons.person_outline_rounded,
                    label: l10n.profileTitle,
                    onTap: () => context.push(AppPaths.customerProfile),
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

/// The screen the Customer is on: an orange pill.
class _CurrentTab extends StatelessWidget {
  const _CurrentTab({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: const ShapeDecoration(
          color: BrandColors.orange,
          shape: StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Another screen: an icon over its name.
class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: BrandColors.muted),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BrandColors.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
