import 'package:flutter/material.dart';

import '../../theme/kit_colors.dart';
import 'kit_buttons.dart';

/// An empty list: a green circle with an icon, a title, a short text and an
/// optional filled button, which may carry an icon before its label. The
/// [quiet] face is grey, for a failure (`DL-137`). It scrolls when the text is
/// tall.
class KitEmptyState extends StatelessWidget {
  const KitEmptyState({
    required this.icon,
    required this.title,
    required this.text,
    this.actionLabel,
    this.onAction,
    this.actionKey,
    this.actionIcon,
    this.quiet = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;
  final IconData? actionIcon;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: quiet ? KitColors.chip : KitColors.primaryWash,
            ),
            child: Icon(
              icon,
              size: 44,
              color: quiet ? KitColors.muted : KitColors.primaryDark,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: KitColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: KitColors.muted,
            ),
          ),
          if (actionLabel != null) ...<Widget>[
            const SizedBox(height: 24),
            FilledButton(
              key: actionKey,
              style: kitFilled(height: 50),
              onPressed: onAction,
              child: actionIcon == null
                  ? Text(actionLabel!)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(actionIcon, size: 22),
                        const SizedBox(width: 10),
                        Flexible(child: Text(actionLabel!)),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!constraints.hasBoundedHeight) {
          return content;
        }

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}
