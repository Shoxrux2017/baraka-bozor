import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../application/code_login_controller.dart';
import 'code_entry.dart';

/// The sentence of a locked phone: three wrong codes, and how long until a
/// new one may be asked for. Renders nothing while the phone is not locked.
class LockMessage extends StatelessWidget {
  const LockMessage(this.state, {super.key});

  final CodeLoginState state;

  @override
  Widget build(BuildContext context) {
    if (!state.locked) {
      return const SizedBox.shrink();
    }

    final AppLocalizations l10n = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          l10n.codeLocked(formatCountdown(state.lockedSeconds)),
          key: const ValueKey<String>('lock-message'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}
