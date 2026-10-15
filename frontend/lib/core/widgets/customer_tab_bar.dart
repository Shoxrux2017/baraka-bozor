import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../localization/generated/app_localizations.dart';
import '../routing/app_paths.dart';
import '../theme/kit_colors.dart';

/// The four places the Customer's bottom bar leads to.
enum CustomerTab { home, favorites, orders, profile }

/// The Customer's bottom bar (`DL-80` item 6): home, favourites, orders and
/// profile. The home, the favourites, the orders and the profile stay
/// separate routes, so the bar only decides how one is reached: the current
/// tab does nothing; the home is gone back to; another tab is pushed over the
/// home, and replaces the tab it is opened from. The system back therefore
/// always returns to the home and never closes the app from a tab.
class CustomerTabBar extends StatelessWidget {
  const CustomerTabBar({required this.current, super.key});

  final CustomerTab current;

  /// The bar without the system inset, and with the room the drawing leaves
  /// under it.
  static const double _content = 65;
  static const double _height = 99;

  void _open(BuildContext context, CustomerTab tab) {
    if (tab == current) {
      return;
    }
    if (tab == CustomerTab.home) {
      context.go(AppPaths.customer);
      return;
    }
    final String path = switch (tab) {
      CustomerTab.favorites => AppPaths.customerFavorites,
      CustomerTab.orders => AppPaths.customerOrders,
      CustomerTab.profile => AppPaths.customerProfile,
      CustomerTab.home => AppPaths.customer,
    };
    if (current == CustomerTab.home) {
      context.push<void>(path);
    } else {
      context.pushReplacement(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final double inset = MediaQuery.paddingOf(context).bottom;
    final double height = math.max(_height, _content + inset);

    Widget tab(
      CustomerTab tab,
      String key,
      IconData filled,
      IconData outlined,
      String label,
    ) => Expanded(
      child: _TabButton(
        key: ValueKey<String>(key),
        icon: tab == current ? filled : outlined,
        label: label,
        selected: tab == current,
        onTap: () => _open(context, tab),
      ),
    );

    return Material(
      color: Colors.white,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x0D000000),
              offset: Offset(0, -6),
              blurRadius: 20,
            ),
          ],
        ),
        child: SizedBox(
          height: height,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: _content,
              child: Row(
                children: <Widget>[
                  tab(
                    CustomerTab.home,
                    'open-home',
                    Icons.home,
                    Icons.home_outlined,
                    l10n.homeNavHome,
                  ),
                  tab(
                    CustomerTab.favorites,
                    'open-favorites',
                    Icons.favorite,
                    Icons.favorite_border,
                    l10n.favoritesTitle,
                  ),
                  tab(
                    CustomerTab.orders,
                    'open-orders',
                    Icons.receipt_long,
                    Icons.receipt_long_outlined,
                    l10n.homeNavOrders,
                  ),
                  tab(
                    CustomerTab.profile,
                    'open-profile',
                    Icons.person,
                    Icons.person_outline,
                    l10n.profileTitle,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            if (selected)
              // The soft glow above the current icon.
              const Positioned(
                top: 0,
                child: SizedBox(
                  width: 36,
                  height: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: KitColors.primarySoft,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(4),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: KitColors.primarySoft,
                          blurRadius: 14,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Icon(
              icon,
              size: 28,
              color: selected ? KitColors.primary : KitColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}
