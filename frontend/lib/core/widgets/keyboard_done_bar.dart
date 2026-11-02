import 'package:flutter/material.dart';

import '../localization/generated/app_localizations.dart';
import '../theme/kit_colors.dart';

/// The bar that sits on the keyboard with «Готово» at its end, as the system
/// keyboards of iOS have it (`DL-122`). It is 44 high, in the system greys.
class KeyboardDoneBar extends StatelessWidget {
  const KeyboardDoneBar({required this.onDone, super.key});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Container(
      height: 44,
      alignment: AlignmentDirectional.centerEnd,
      color: const Color(0xFFF4F5F6),
      // Drawn over the bar, so the button keeps its full 44.
      foregroundDecoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFC9CCD1))),
      ),
      child: TextButton(
        key: const ValueKey<String>('keyboard-done'),
        onPressed: onDone,
        style: TextButton.styleFrom(
          foregroundColor: KitColors.primaryDark,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: Text(l10n.keyboardDone),
      ),
    );
  }
}
