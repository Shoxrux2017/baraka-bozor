import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/widgets/active_mode_bar.dart';

/// What follows a completed shopping (`docs/04` section 12, W3-16): the
/// order is the Shopper's no more, so the screen stands on its own, and
/// tells them to write the order number on the package and take it to the
/// handoff point.
class ShopperDoneScreen extends StatelessWidget {
  const ShopperDoneScreen({required this.orderNumber, super.key});

  final int orderNumber;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.shellShopper),
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
                        const Icon(Icons.check_circle_outline, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          l10n.doneTitle('$orderNumber'),
                          key: const ValueKey<String>('shopper-done-title'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.doneLabel('$orderNumber'),
                          key: const ValueKey<String>('shopper-done-label'),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          key: const ValueKey<String>('shopper-done-back'),
                          onPressed: () => context.go(AppPaths.shopper),
                          child: Text(l10n.doneBack),
                        ),
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
}
