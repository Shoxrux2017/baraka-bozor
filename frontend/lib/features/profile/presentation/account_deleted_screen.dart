import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';

/// Screen 36в: the account is deleted. An open page, so it stays on screen
/// once the session is gone; "Готово" and system back lead to the phone
/// screen. It fades in (`fadingPage`), its title is announced, and the grey
/// check comes in once (`DL-140`).
class AccountDeletedScreen extends StatefulWidget {
  const AccountDeletedScreen({super.key});

  @override
  State<AccountDeletedScreen> createState() => _AccountDeletedScreenState();
}

class _AccountDeletedScreenState extends State<AccountDeletedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  CurvedAnimation? _curve;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        announce(context, AppLocalizations.of(context).deletedTitle);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    // Decided once, when the page first builds: the circle comes in a single
    // time.
    _started = true;
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    _entrance.duration = Duration(milliseconds: reduced ? 200 : 450);
    _curve = CurvedAnimation(
      parent: _entrance,
      curve: reduced ? Curves.linear : const Cubic(0.2, 0.8, 0.2, 1),
    );
    _entrance.forward();
  }

  @override
  void dispose() {
    _curve?.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    final Animation<double> curve = _curve!;

    Widget check = Container(
      key: const ValueKey<String>('account-deleted-check'),
      width: 84,
      height: 84,
      decoration: const BoxDecoration(
        color: KitColors.chip,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.check, size: 40, color: KitColors.ink2),
    );
    if (!reduced) {
      check = ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1).animate(curve),
        child: check,
      );
    }
    check = FadeTransition(opacity: curve, child: check);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          context.go(AppPaths.auth);
        }
      },
      child: Scaffold(
        key: const ValueKey<String>('account-deleted'),
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        check,
                        const SizedBox(height: 24),
                        Semantics(
                          header: true,
                          child: Text(
                            l10n.deletedTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: KitColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.deletedBody,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: KitColors.ink2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.deletedThanks,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: KitColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: FilledButton(
                  key: const ValueKey<String>('account-deleted-done'),
                  style: FilledButton.styleFrom(
                    backgroundColor: KitColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => context.go(AppPaths.auth),
                  child: Text(
                    l10n.doneButton,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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
