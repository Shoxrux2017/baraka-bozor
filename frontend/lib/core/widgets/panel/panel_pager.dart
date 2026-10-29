import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../localization/generated/app_localizations.dart';
import '../../network/paged.dart';
import '../../theme/kit_colors.dart';
import 'panel_hit_box.dart';

/// The panel's pager: the range shown on the left, and on the right the
/// previous and next buttons around up to five numbered pages near the
/// current one. Nothing when the list is one page. A page button is drawn 32
/// square and taps from 44 square (DL-117).
class PanelPager extends StatelessWidget {
  const PanelPager({required this.page, required this.onPage, super.key});

  final Paged<Object?> page;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    if (page.lastPage <= 1) {
      return const SizedBox.shrink();
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int from = (page.page - 1) * page.perPage + 1;
    final int to = math.min(page.page * page.perPage, page.total);
    final int first = math.max(1, math.min(page.page - 2, page.lastPage - 4));
    final int last = math.min(page.lastPage, first + 4);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: <Widget>[
          Text(
            l10n.boardPageRange(from, to, page.total),
            style: const TextStyle(fontSize: 12, color: KitColors.muted),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                key: const ValueKey<String>('previous-page'),
                tooltip: MaterialLocalizations.of(context).previousPageTooltip,
                icon: const Icon(Icons.chevron_left),
                onPressed: page.hasPrevious
                    ? () => onPage(page.page - 1)
                    : null,
              ),
              for (int number = first; number <= last; number++)
                _PageButton(
                  number: number,
                  current: number == page.page,
                  onTap: () => onPage(number),
                ),
              IconButton(
                key: const ValueKey<String>('next-page'),
                tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                icon: const Icon(Icons.chevron_right),
                onPressed: page.hasNext ? () => onPage(page.page + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.number,
    required this.current,
    required this.onTap,
  });

  final int number;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(8);

    return Semantics(
      button: true,
      selected: current,
      excludeSemantics: true,
      label: '$number',
      onTap: current ? null : onTap,
      child: PanelHitBox(
        onTap: current ? null : onTap,
        child: Material(
          key: ValueKey<String>('page-$number'),
          color: current ? KitColors.primary : Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: current ? null : onTap,
            child: SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: current ? Colors.white : KitColors.ink2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
