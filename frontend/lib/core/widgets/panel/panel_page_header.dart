import 'package:flutter/material.dart';

import '../../theme/kit_colors.dart';
import '../kit/kit_buttons.dart';

/// The head of a panel page: its [title], a muted [subtitle] line under it,
/// and a [trailing] widget (a button) at the end, centred vertically. A page
/// that needs to find its subtitle gives it a [subtitleKey].
class PanelPageHeader extends StatelessWidget {
  const PanelPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleKey,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Key? subtitleKey;
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
                  key: subtitleKey,
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

/// The filled 40-high button at the end of a panel page's head. [labelled] it
/// shows its [label] beside the [icon]; otherwise only the icon, with the label
/// as its tooltip.
class PanelHeaderButton extends StatelessWidget {
  const PanelHeaderButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.labelled,
    super.key,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool labelled;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = kitFilled(height: 40)
        .copyWith(tapTargetSize: MaterialTapTargetSize.shrinkWrap);

    if (labelled) {
      return FilledButton.icon(
        key: buttonKey,
        style: style,
        icon: Icon(icon, size: 20),
        label: Text(label),
        onPressed: onPressed,
      );
    }
    return Tooltip(
      message: label,
      child: FilledButton(
        key: buttonKey,
        style: style.copyWith(
          minimumSize: const WidgetStatePropertyAll<Size>(Size(40, 40)),
          padding: const WidgetStatePropertyAll<EdgeInsets>(
            EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
        onPressed: onPressed,
        child: Icon(icon, size: 20),
      ),
    );
  }
}
