import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';

/// The heading over the favourites that stopped being sold: «Нет в продаже»,
/// how many there are, and «Убрать все» at the end when [onRemoveAll] is given
/// (`DL-129`). It stands 10 px under the row above it.
class NotSoldHeading extends StatelessWidget {
  const NotSoldHeading({required this.count, this.onRemoveAll, super.key});

  final int count;

  /// Takes every not-sold favourite off; without it no button is drawn.
  final VoidCallback? onRemoveAll;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String spokenCount = l10n.catalogProductCount(count);
    final VoidCallback? removeAll = onRemoveAll;
    return Padding(
      key: const ValueKey<String>('not-sold-heading'),
      padding: const EdgeInsets.only(top: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                header: true,
                label: l10n.favoritesNotSoldSpoken(spokenCount),
                excludeSemantics: true,
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: <Widget>[
                    Text(
                      l10n.catalogUnavailable,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: KitColors.ink,
                      ),
                    ),
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: KitColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (removeAll != null)
              TextButton(
                key: const ValueKey<String>('not-sold-remove-all'),
                onPressed: removeAll,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: KitColors.primaryDark,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Semantics(
                  label: l10n.favoritesRemoveAllSpoken(spokenCount),
                  excludeSemantics: true,
                  child: Text(l10n.favoritesRemoveAll),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
