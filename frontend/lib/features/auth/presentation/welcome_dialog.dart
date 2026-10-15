import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/kit_colors.dart';
import 'auth_scaffold.dart';
import 'confirm_phone_dialog.dart';

/// Screen 06 of `kit/01-vhod`: the account is ready. [context] must belong
/// to a navigator that outlives the screen that asks, since the session
/// change that follows the name may already be taking that screen away.
Future<void> showWelcomeDialog(BuildContext context, {required String name}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: authDialogBarrier,
    builder: (BuildContext context) {
      final AppLocalizations l10n = AppLocalizations.of(context);
      return Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Center(child: StatusHalo(icon: Icons.check_circle)),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  l10n.welcomeTitle(name),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: appFontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    height: 1.4,
                    color: KitColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.welcomeBody,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: KitColors.ink,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                key: const ValueKey<String>('welcome-button'),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.welcomeButton),
              ),
            ],
          ),
        ),
      );
    },
  );
}
