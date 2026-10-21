import 'package:flutter/material.dart';

import '../../theme/kit_colors.dart';

/// The colour family of a [KitNote] or a [KitTag].
enum KitTone { green, amber, red, grey }

({Color wash, Color strong, Color text}) _tone(KitTone tone) {
  return switch (tone) {
    KitTone.green => (
      wash: KitColors.primaryWash,
      strong: KitColors.primaryDark,
      text: KitColors.primaryDark,
    ),
    KitTone.amber => (
      wash: KitColors.warningWash,
      strong: KitColors.warning,
      text: KitColors.warningDark,
    ),
    KitTone.red => (
      wash: KitColors.dangerWash,
      strong: KitColors.danger,
      text: KitColors.danger,
    ),
    KitTone.grey => (
      wash: KitColors.field,
      strong: KitColors.muted,
      text: KitColors.muted,
    ),
  };
}

/// A notice in a tinted box: an icon and a short text.
class KitNote extends StatelessWidget {
  const KitNote({
    required this.icon,
    required this.text,
    this.tone = KitTone.green,
    super.key,
  });

  final IconData icon;
  final Widget text;
  final KitTone tone;

  @override
  Widget build(BuildContext context) {
    final ({Color wash, Color strong, Color text}) colors = _tone(tone);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.wash,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 20, color: colors.strong),
            const SizedBox(width: 10),
            Expanded(
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontSize: 12, color: KitColors.ink),
                child: text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small chip: a [text] with an optional [icon], in a tone's wash.
class KitTag extends StatelessWidget {
  const KitTag({
    required this.text,
    this.icon,
    this.tone = KitTone.grey,
    super.key,
  });

  final String text;
  final IconData? icon;
  final KitTone tone;

  @override
  Widget build(BuildContext context) {
    final ({Color wash, Color strong, Color text}) colors = _tone(tone);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.wash,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 14, color: colors.text),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
