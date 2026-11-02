import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';

/// A section's title with "Все" at its right, as the home and the search
/// screen show them.
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    required this.title,
    required this.seeAllKey,
    required this.onSeeAll,
    this.seeAllLabel,
    super.key,
  });

  final String title;
  final String seeAllKey;

  /// `null` leaves "Все" out.
  final VoidCallback? onSeeAll;

  /// What "Все" opens, for a screen reader; the title is a heading
  /// (`DL-125`).
  final String? seeAllLabel;

  @override
  Widget build(BuildContext context) {
    final Widget title = Semantics(
      header: true,
      child: Text(
        this.title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: KitColors.ink,
        ),
      ),
    );
    final VoidCallback? onSeeAll = this.onSeeAll;
    final Widget? seeAll = onSeeAll == null
        ? null
        : TextButton(
            key: ValueKey<String>(seeAllKey),
            style: TextButton.styleFrom(
              foregroundColor: KitColors.primaryDark,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: onSeeAll,
            child: Semantics(
              label: seeAllLabel,
              excludeSemantics: seeAllLabel != null,
              child: Text(AppLocalizations.of(context).homeSeeAll),
            ),
          );
    // A large text leaves the title no room beside "Все": it goes under it
    // (`DL-125`).
    final bool stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: stacked && seeAll != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                title,
                Align(alignment: AlignmentDirectional.centerEnd, child: seeAll),
              ],
            )
          : Row(
              children: <Widget>[
                Expanded(child: title),
                ?seeAll,
              ],
            ),
    );
  }
}
