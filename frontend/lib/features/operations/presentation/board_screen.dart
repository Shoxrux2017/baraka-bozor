import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';

/// The board, the Operator's and the Admin's home (`DL-37` (16), (17)). Its
/// table, summary and attention list arrive with W2-10; until then it says
/// so, as every area not yet built does.
class BoardScreen extends StatelessWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Center(
      key: const ValueKey<String>('operations-board'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l10n.shellPlaceholder, textAlign: TextAlign.center),
      ),
    );
  }
}
