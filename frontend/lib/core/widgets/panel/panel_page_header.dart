import 'package:flutter/material.dart';

import '../../theme/kit_colors.dart';

/// The head of a panel page: its [title], a muted [subtitle] line under it,
/// and a [trailing] widget (a button) at the end, centred vertically.
class PanelPageHeader extends StatelessWidget {
  const PanelPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final String? subtitle = this.subtitle;
    final Widget? trailing = this.trailing;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: KitColors.ink,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: KitColors.muted),
                ),
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[const SizedBox(width: 12), trailing],
      ],
    );
  }
}
