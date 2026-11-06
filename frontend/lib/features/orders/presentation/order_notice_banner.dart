import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/timed_banner.dart';

/// The dark box the order page's strips share (`DL-133`, `DL-134`): an icon,
/// a title over a hint, on the kit's shadow. It announces nothing and does not
/// move: the strip that holds it does both.
class DarkNoticeBanner extends StatelessWidget {
  const DarkNoticeBanner({
    required this.icon,
    required this.title,
    required this.hint,
    required this.boxKey,
    super.key,
  });

  final IconData icon;
  final String title;
  final String hint;

  /// The key of the box itself, which tests and the page find it by.
  final Key boxKey;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: boxKey,
      decoration: BoxDecoration(
        color: KitColors.ink2,
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
            Icon(icon, size: 24, color: Colors.white),
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
                      hint,
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
    );
  }
}

/// The strip the order page shows when the rating screen found the order
/// already rated (`DL-134`): the stars the server holds, and that they cannot
/// be changed. It rises from the bottom as a [TimedBanner] does and announces
/// nothing: the page does.
class RatedAlreadyBanner extends StatelessWidget {
  const RatedAlreadyBanner({required this.stars, super.key});

  /// The stored rating's stars.
  final int stars;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return TimedBanner(
      fromBelow: true,
      child: DarkNoticeBanner(
        boxKey: const ValueKey<String>('rated-already-banner'),
        icon: Icons.info,
        title: l10n.ratedAlreadyTitle(stars),
        hint: l10n.ratedAlreadyHint,
      ),
    );
  }
}
