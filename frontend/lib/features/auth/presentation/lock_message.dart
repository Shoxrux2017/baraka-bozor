import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../core/localization/generated/app_localizations.dart';
import 'code_entry.dart';

/// The sentence of a locked phone: three wrong codes, and how long until a
/// new one may be asked for. Renders nothing while [lockedSeconds] is zero.
///
/// The ticking text is plain text, not a live region, so a screen reader does
/// not read it again every second; the lock is announced once, when it starts.
class LockMessage extends StatefulWidget {
  const LockMessage({required this.lockedSeconds, super.key});

  final int lockedSeconds;

  @override
  State<LockMessage> createState() => _LockMessageState();
}

class _LockMessageState extends State<LockMessage> {
  @override
  void didUpdateWidget(LockMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lockedSeconds <= 0 && widget.lockedSeconds > 0) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        _sentence(context),
        Directionality.of(context),
      );
    }
  }

  String _sentence(BuildContext context) =>
      AppLocalizations.of(context)
          .codeLocked(formatCountdown(widget.lockedSeconds));

  @override
  Widget build(BuildContext context) {
    if (widget.lockedSeconds <= 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        _sentence(context),
        key: const ValueKey<String>('lock-message'),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
