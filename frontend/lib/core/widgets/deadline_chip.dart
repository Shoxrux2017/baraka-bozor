import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../formatting/tashkent_time.dart';
import '../localization/generated/app_localizations.dart';
import '../platform/clock.dart';
import '../theme/kit_colors.dart';

/// Whole minutes from [now] to [deadline], rounded up; `0` at or after it
/// (`DL-125`).
int minutesLeft(DateTime deadline, DateTime now) {
  final int microseconds = deadline.difference(now).inMicroseconds;
  if (microseconds <= 0) {
    return 0;
  }
  const int minute = Duration.microsecondsPerMinute;
  return (microseconds + minute - 1) ~/ minute;
}

/// "Осталось N мин" in a white pill, red from three minutes on. It counts
/// down on `clockProvider`, redrawing at each change of N, and is gone at the
/// deadline. It says nothing to a screen reader: its parent speaks
/// `deadlineLeftSpoken` (`DL-125`). On a question card ([onCard]) it sits on
/// a wash of the card's colour, red from three minutes on, and also says the
/// time it ends; with a [spokenTitle] it is the one node the card's header
/// reads as, `questionHeaderSpoken` (`DL-130`).
class DeadlineChip extends ConsumerStatefulWidget {
  const DeadlineChip({
    required this.deadline,
    this.onCard = false,
    this.spokenTitle,
    super.key,
  });

  final DateTime deadline;
  final bool onCard;

  /// The title the card's header speaks before the minutes left.
  final String? spokenTitle;

  @override
  ConsumerState<DeadlineChip> createState() => _DeadlineChipState();
}

class _DeadlineChipState extends ConsumerState<DeadlineChip> {
  Timer? _timer;

  void _schedule(DateTime now, int minutes) {
    _timer?.cancel();
    _timer = null;
    if (minutes == 0) {
      return;
    }
    // `minutes` turns into `minutes - 1` when that many whole minutes remain.
    final Duration wait =
        widget.deadline.difference(now) - Duration(minutes: minutes - 1);
    _timer = Timer(wait, () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = ref.watch(clockProvider)();
    final int minutes = minutesLeft(widget.deadline, now);
    _schedule(now, minutes);
    if (minutes == 0) {
      return const SizedBox.shrink();
    }
    final bool urgent = minutes <= 3;
    final Color color = urgent ? KitColors.danger : KitColors.warningDark;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? spokenTitle = widget.spokenTitle;
    final Widget chip = DecoratedBox(
      decoration: BoxDecoration(
        color: widget.onCard
            ? (urgent ? KitColors.dangerWash : KitColors.warningWash)
            : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.timer, size: 16, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                widget.onCard
                    ? l10n.deadlineLeftUntil(
                        minutes,
                        TashkentTime.time(widget.deadline),
                      )
                    : l10n.deadlineLeft(minutes),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (spokenTitle != null) {
      return Semantics(
        container: true,
        label: l10n.questionHeaderSpoken(
          spokenTitle,
          l10n.deadlineLeftSpoken(minutes),
        ),
        excludeSemantics: true,
        child: chip,
      );
    }
    return ExcludeSemantics(child: chip);
  }
}
