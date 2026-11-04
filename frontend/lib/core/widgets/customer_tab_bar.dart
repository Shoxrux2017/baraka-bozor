import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/favorites/application/favorites_controllers.dart';
import '../../features/orders/application/customer_orders_controllers.dart';
import '../localization/generated/app_localizations.dart';
import '../routing/app_paths.dart';
import '../theme/kit_colors.dart';

/// The four places the Customer's bottom bar leads to. Tab `i` is branch `i`
/// of the tabs' shell (`DL-118`).
enum CustomerTab { home, favorites, orders, profile }

/// Wraps a tab screen other than the home: a system back that reaches it goes
/// to the home instead of closing the app. A tab is always the first page of
/// its branch; sheets and screens over it are popped first (`DL-118` (3)).
class CustomerTabScope extends StatelessWidget {
  const CustomerTabScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          context.go(AppPaths.customer);
        }
      },
      child: child,
    );
  }
}

/// The Customer's bottom bar (`DL-80` item 6, `DL-118`): home, favourites,
/// orders and profile. The four tabs are branches of one shell, so another
/// tab is switched to and keeps its place; the current tab is left to its
/// own handling. The system back from a tab other than the home goes home.
class CustomerTabBar extends ConsumerWidget {
  const CustomerTabBar({required this.current, super.key});

  final CustomerTab current;

  /// The bar without the system inset, and with the room the drawing leaves
  /// under it.
  static const double _content = 65;
  static const double _height = 99;

  void _open(BuildContext context, CustomerTab tab) {
    if (tab == current) {
      _toTop(context);
      return;
    }
    final StatefulNavigationShellState? shell = StatefulNavigationShell.maybeOf(
      context,
    );
    if (shell != null) {
      shell.goBranch(tab.index);
      return;
    }
    // A screen shown alone, with no shell above it.
    context.go(switch (tab) {
      CustomerTab.home => AppPaths.customer,
      CustomerTab.favorites => AppPaths.customerFavorites,
      CustomerTab.orders => AppPaths.customerOrders,
      CustomerTab.profile => AppPaths.customerProfile,
    });
  }

  /// A tap on the current tab: its main list, which takes the route's primary
  /// scroll controller, goes back to the top (`DL-118`). At the top nothing
  /// moves.
  void _toTop(BuildContext context) {
    final ScrollController? controller = PrimaryScrollController.maybeOf(
      context,
    );
    if (controller == null || !controller.hasClients) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.jumpTo(0);
    } else {
      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int waiting = ref.watch(openQuestionsProvider).length;
    final double inset = MediaQuery.paddingOf(context).bottom;
    final double height = math.max(_height, _content + inset);

    Widget tab(
      CustomerTab tab,
      String key,
      IconData filled,
      IconData outlined,
      String label, {
      int badge = 0,
      bool bumps = false,
    }) => Expanded(
      child: _TabButton(
        key: ValueKey<String>(key),
        icon: tab == current ? filled : outlined,
        label: label,
        selected: tab == current,
        badge: badge,
        bumps: bumps,
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
                    bumps: true,
                  ),
                  tab(
                    CustomerTab.orders,
                    'open-orders',
                    Icons.receipt_long,
                    Icons.receipt_long_outlined,
                    l10n.homeNavOrders,
                    badge: waiting,
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
    this.badge = 0,
    this.bumps = false,
    super.key,
  });

  /// Whether the icon bumps when a heart is set (`DL-129`).
  final bool bumps;

  /// How many questions wait on the tab; none draws nothing (`DL-125`).
  final int badge;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  Widget _icon() {
    final Icon glyph = Icon(
      icon,
      size: 26,
      color: selected ? KitColors.primary : KitColors.muted,
    );
    return bumps ? _BumpingIcon(child: glyph) : glyph;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: badge > 0
          ? AppLocalizations.of(context).homeNavOrdersWaiting(badge)
          : label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
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
            if (badge > 0)
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Transform.translate(
                    offset: const Offset(6, 0),
                    child: FractionalTranslation(
                      translation: const Offset(0.5, 0),
                      child: _Badge(count: badge),
                    ),
                  ),
                ),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _icon(),
                    const SizedBox(height: 2),
                    MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 15 / 11,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.2,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? KitColors.primaryDark
                                : KitColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The favourites icon, which bumps for 340 ms on each new heart set: up 3
/// and scaled to 1.24 at 40 %, and back, on the kit curve (`DL-129`). With
/// reduced motion it stays still.
class _BumpingIcon extends ConsumerStatefulWidget {
  const _BumpingIcon({required this.child});

  final Widget child;

  @override
  ConsumerState<_BumpingIcon> createState() => _BumpingIconState();
}

class _BumpingIconState extends ConsumerState<_BumpingIcon>
    with SingleTickerProviderStateMixin {
  static const Cubic _curve = Cubic(0.2, 0.8, 0.2, 1);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );

  /// 0 → 1 → 0 across the bump, 40 % up and 60 % back.
  late final Animation<double> _lift = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0, end: 1).chain(CurveTween(curve: _curve)),
        weight: 40,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1, end: 0).chain(CurveTween(curve: _curve)),
        weight: 60,
      ),
    ],
  ).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(favoriteAddedProvider, (int? before, int now) {
      if (now > (before ?? 0) && !MediaQuery.disableAnimationsOf(context)) {
        _controller.forward(from: 0);
      }
    });
    return AnimatedBuilder(
      animation: _lift,
      child: widget.child,
      builder: (BuildContext context, Widget? child) => Transform(
        key: const ValueKey<String>('favorites-bump'),
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..translateByDouble(0, -3 * _lift.value, 0, 1)
          ..scaleByDouble(1 + 0.24 * _lift.value, 1 + 0.24 * _lift.value, 1, 1),
        child: child,
      ),
    );
  }
}

/// The count of waiting questions: a red pill with a white ring.
class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('orders-badge'),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: KitColors.danger,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
