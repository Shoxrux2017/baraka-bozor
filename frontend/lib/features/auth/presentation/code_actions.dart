import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import 'rise_in.dart';
import 'telegram_mark.dart';

/// «Вставить код»: a green-washed chip that reads the clipboard when tapped.
/// The sign-in and the account deletion code pages share it (`DL-140`).
class CodePasteChip extends StatelessWidget {
  const CodePasteChip({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return RiseIn(
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Center(
          child: TextButton.icon(
            key: const ValueKey<String>('code-paste'),
            onPressed: onTap,
            icon: const Icon(Icons.content_paste, size: 20),
            label: Text(l10n.codePaste),
            style: TextButton.styleFrom(
              foregroundColor: KitColors.primaryDark,
              backgroundColor: KitColors.primaryWash,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «Открыть Telegram»: white, a hairline edge and the Telegram mark.
class OpenTelegramButton extends StatelessWidget {
  const OpenTelegramButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return OutlinedButton(
      key: const ValueKey<String>('code-open-telegram'),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: KitColors.ink,
        backgroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: KitColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const TelegramMark(size: 24),
          const SizedBox(width: 10),
          Flexible(child: Text(l10n.codeOpenTelegram)),
        ],
      ),
    );
  }
}
