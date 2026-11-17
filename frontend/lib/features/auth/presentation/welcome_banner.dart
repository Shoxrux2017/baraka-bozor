import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/timed_banner.dart';

/// The strip the home shows once a new Customer has given a name: the welcome
/// that was a dialog before (`DL-139`). It looks and moves like the order's
/// edited strip and is one stop for a screen reader. It does not announce:
/// the home does when it takes the notice.
class WelcomeBanner extends StatelessWidget {
  const WelcomeBanner({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String title = l10n.welcomeTitle(name);

    final Widget card = Semantics(
      container: true,
      label: '$title ${l10n.welcomeBody}',
      excludeSemantics: true,
      child: DecoratedBox(
        key: const ValueKey<String>('welcome-banner'),
        decoration: BoxDecoration(
          color: KitColors.primaryDark,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: KitColors.shadow,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.check_circle, size: 24, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        l10n.welcomeBody,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return TimedBanner(fromBelow: false, child: card);
  }
}
