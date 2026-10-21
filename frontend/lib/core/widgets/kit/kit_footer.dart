import 'package:flutter/material.dart';

import '../../theme/kit_colors.dart';
import 'kit_buttons.dart';

/// The step a staff order offers, pinned under its list: white, with a
/// shadow cast upward, its [children] stretched in a column.
class KitFooter extends StatelessWidget {
  const KitFooter({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// The footer's main button: [label] with an [icon], a spinner in place of
/// the icon while [busy], and held while busy.
class KitFooterButton extends StatelessWidget {
  const KitFooterButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.busy,
    required this.onPressed,
    super.key,
  });

  final String buttonKey;
  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: ValueKey<String>(buttonKey),
      style: kitFilled(),
      icon: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: KitColors.muted,
              ),
            )
          : Icon(icon),
      label: Text(label),
      onPressed: busy ? null : onPressed,
    );
  }
}
