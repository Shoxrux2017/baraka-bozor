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
    super.key,
  });

  final String title;
  final String seeAllKey;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: KitColors.ink,
              ),
            ),
          ),
          TextButton(
            key: ValueKey<String>(seeAllKey),
            style: TextButton.styleFrom(
              foregroundColor: KitColors.primaryDark,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: onSeeAll,
            child: Text(AppLocalizations.of(context).homeSeeAll),
          ),
        ],
      ),
    );
  }
}
