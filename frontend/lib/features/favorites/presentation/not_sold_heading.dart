import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/layout/text_width.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';

/// The heading over the favourites that stopped being sold: «Нет в продаже»,
/// how many there are, and «Убрать все» at the end when [onRemoveAll] is given
/// (`DL-129`). It stands 10 px under the row above it.
class NotSoldHeading extends StatelessWidget {
  const NotSoldHeading({required this.count, this.onRemoveAll, super.key});

  static const TextStyle _titleStyle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: KitColors.ink,
  );
  static const TextStyle _countStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: KitColors.muted,
  );
  static const TextStyle _buttonStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  final int count;

  /// Takes every not-sold favourite off; without it no button is drawn.
  final VoidCallback? onRemoveAll;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String spokenCount = l10n.catalogProductCount(count);
    final VoidCallback? removeAll = onRemoveAll;
    final Widget title = Semantics(
      header: true,
      label: l10n.favoritesNotSoldSpoken(spokenCount),
      excludeSemantics: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: <Widget>[
          Text(l10n.catalogUnavailable, style: _titleStyle),
          Text('$count', style: _countStyle),
        ],
      ),
    );
    final Widget? button = removeAll == null
        ? null
        : TextButton(
            key: const ValueKey<String>('not-sold-remove-all'),
            onPressed: removeAll,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              foregroundColor: KitColors.primaryDark,
              textStyle: _buttonStyle,
            ),
            child: Semantics(
              label: l10n.favoritesRemoveAllSpoken(spokenCount),
              excludeSemantics: true,
              child: Text(l10n.favoritesRemoveAll),
            ),
          );
    return Padding(
      key: const ValueKey<String>('not-sold-heading'),
      padding: const EdgeInsets.only(top: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            if (button == null) {
              return Align(
                alignment: AlignmentDirectional.centerStart,
                child: title,
              );
            }
            // The title with its count and the button on one row when they
            // fit as they are drawn; otherwise the button under the title at
            // the end, so large text never squeezes the title (`DL-129`).
            final double needed =
                textWidth(context, l10n.catalogUnavailable, _titleStyle) +
                6 +
                textWidth(context, '$count', _countStyle) +
                // The button's own padding is 12 on each side.
                math.max(
                  44,
                  textWidth(context, l10n.favoritesRemoveAll, _buttonStyle) +
                      24,
                );
            if (needed <= constraints.maxWidth) {
              return Row(
                children: <Widget>[
                  Expanded(child: title),
                  button,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: title,
                ),
                Align(alignment: AlignmentDirectional.centerEnd, child: button),
              ],
            );
          },
        ),
      ),
    );
  }
}
