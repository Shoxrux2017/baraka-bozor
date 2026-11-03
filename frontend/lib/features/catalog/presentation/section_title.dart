import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';

/// A section's title with "Все" at its right, as the home and the search
/// screen show them. With [count] "Все" reads «Все 24 ›»: the total, and a
/// chevron after it (`DL-128`).
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    required this.title,
    required this.seeAllKey,
    required this.onSeeAll,
    this.seeAllLabel,
    this.count,
    this.titleKey,
    this.holding,
    super.key,
  });

  final String title;
  final String seeAllKey;

  /// `null` leaves "Все" out.
  final VoidCallback? onSeeAll;

  /// What "Все" opens, for a screen reader; the title is a heading
  /// (`DL-125`).
  final String? seeAllLabel;

  /// The total "Все" names; without it "Все" stands alone.
  final int? count;

  /// Marks the title's text, so a flight can measure where it stands.
  final GlobalKey? titleKey;

  /// While true the title is drawn at opacity 0: a copy of it is flying.
  final ValueListenable<bool>? holding;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ValueListenable<bool>? holding = this.holding;
    final Widget text = Semantics(
      header: true,
      child: Text(
        this.title,
        key: titleKey,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: KitColors.ink,
        ),
      ),
    );
    final Widget title = holding == null
        ? text
        : ValueListenableBuilder<bool>(
            valueListenable: holding,
            builder: (BuildContext context, bool held, Widget? child) =>
                Opacity(opacity: held ? 0 : 1, child: child),
            child: text,
          );
    final int? count = this.count;
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
              padding: count == null
                  ? null
                  : const EdgeInsetsDirectional.only(start: 12, end: 8),
            ),
            onPressed: onSeeAll,
            child: Semantics(
              label: seeAllLabel,
              excludeSemantics: seeAllLabel != null,
              child: count == null
                  ? Text(l10n.homeSeeAll)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(l10n.homeSeeAllCount(count)),
                        const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
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
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: title,
                  ),
                ),
                ?seeAll,
              ],
            ),
    );
  }
}
