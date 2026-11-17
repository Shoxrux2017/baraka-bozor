import 'package:flutter/material.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/formatting/countdown_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import 'rise_in.dart';

/// The lock of a code that was typed wrong three times (`DL-139`): a big
/// countdown on a red card, then, when it runs out, a green card that says a
/// new code can be asked for.
///
/// The reader gets one stop that says the pause once, not a live region that
/// would read every second. The start of the lock and its end are each
/// announced once.
class LockCard extends StatefulWidget {
  const LockCard({required this.lockedSeconds, required this.over, super.key});

  final int lockedSeconds;

  /// The lock has run out.
  final bool over;

  @override
  State<LockCard> createState() => _LockCardState();
}

class _LockCardState extends State<LockCard> {
  @override
  void initState() {
    super.initState();
    if (!widget.over) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          announce(context, _spoken(AppLocalizations.of(context)));
        }
      });
    }
  }

  @override
  void didUpdateWidget(LockCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.over && widget.over) {
      announce(context, AppLocalizations.of(context).codeLockDoneSpoken);
    }
  }

  String _spoken(AppLocalizations l10n) => widget.over
      ? l10n.codeLockDoneSpoken
      : l10n.codeLocked(formatCountdown(widget.lockedSeconds));

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool over = widget.over;
    final Color tone = over ? KitColors.primaryDark : KitColors.danger;
    final String time = formatCountdown(widget.lockedSeconds);

    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: RiseIn(
        duration: const Duration(milliseconds: 250),
        child: Semantics(
          key: const ValueKey<String>('code-lock-card'),
          container: true,
          label: over ? l10n.codeLockDoneSpoken : l10n.codeLockSpoken(time),
          excludeSemantics: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: over ? KitColors.primaryWash : KitColors.dangerWash,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: <Widget>[
                  Icon(
                    over ? Icons.check_circle : Icons.timer,
                    size: 22,
                    color: tone,
                  ),
                  Text(
                    over ? l10n.codeLockDoneTime : time,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                      color: tone,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    over ? l10n.codeLockDoneText : l10n.codeLockText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                      color: KitColors.ink2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
