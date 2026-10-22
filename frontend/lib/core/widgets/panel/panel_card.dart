import 'package:flutter/material.dart';

import '../../theme/kit_colors.dart';
import '../kit/kit_card.dart';
import '../kit/kit_note.dart';

/// A card of the panel: a [KitCard] with the panel's padding, a header row
/// when it has a [title], a [count] or a [trailing] widget, and then its
/// [children]. A [tone] of amber washes it and outlines it in amber; red
/// outlines it in red. A [flush] card keeps the header's 20 px side padding
/// only, so a table below it runs edge to edge.
class PanelCard extends StatelessWidget {
  const PanelCard({
    required this.children,
    this.title,
    this.count,
    this.trailing,
    this.tone,
    this.flush = false,
    super.key,
  });

  final String? title;
  final String? count;
  final Widget? trailing;
  final List<Widget> children;
  final KitTone? tone;
  final bool flush;

  @override
  Widget build(BuildContext context) {
    final bool header = title != null || count != null || trailing != null;

    return KitCard(
      padding: flush
          ? const EdgeInsets.only(top: 18)
          : const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      color: tone == KitTone.amber ? KitColors.warningWash : Colors.white,
      outline: switch (tone) {
        KitTone.amber => KitColors.warning,
        KitTone.red => KitColors.danger,
        _ => null,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (header)
            Padding(
              padding: flush
                  ? const EdgeInsets.symmetric(horizontal: 20)
                  : EdgeInsets.zero,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Flexible(
                    child: Row(
                      children: <Widget>[
                        if (title != null)
                          Flexible(
                            child: Text(
                              title!,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: KitColors.ink,
                              ),
                            ),
                          ),
                        if (count != null) ...<Widget>[
                          const SizedBox(width: 8),
                          Text(
                            count!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: KitColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...<Widget>[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}
