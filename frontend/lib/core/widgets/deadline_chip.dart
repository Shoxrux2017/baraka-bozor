import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// `deadlineLeftSpoken` (`DL-125`).
class DeadlineChip extends ConsumerStatefulWidget {
  const DeadlineChip({required this.deadline, super.key});

  final DateTime deadline;

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
    final Color color = minutes <= 3 ? KitColors.danger : KitColors.warningDark;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
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
                  AppLocalizations.of(context).deadlineLeft(minutes),
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
      ),
    );
  }
}
