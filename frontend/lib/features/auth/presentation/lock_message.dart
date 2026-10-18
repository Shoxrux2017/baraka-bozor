import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../core/formatting/countdown_format.dart';
import '../../../core/localization/generated/app_localizations.dart';

/// The sentence of a locked phone: three wrong codes, and how long until a
/// new one may be asked for. Renders nothing while [lockedSeconds] is zero.
///
/// The ticking text is plain text, not a live region, so a screen reader does
/// not read it again every second; the lock is announced once when it
/// starts and once when it ends ([lockOver] turning on).
class LockMessage extends StatefulWidget {
  const LockMessage({
    required this.lockedSeconds,
    this.lockOver = false,
    super.key,
  });

  final int lockedSeconds;

  /// The lock has just run out; announced once, nothing is drawn for it here.
  final bool lockOver;

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
    if (!oldWidget.lockOver && widget.lockOver) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        AppLocalizations.of(context).codeLockOver,
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
