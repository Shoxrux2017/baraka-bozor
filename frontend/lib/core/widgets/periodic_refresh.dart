import 'dart:async';

import 'package:flutter/widgets.dart';

/// Keeps what a screen shows current while it is shown, without push
/// (`DL-54` (15)). [interval] after each successful load, while the screen's
/// route is the top one and the app is in the foreground, it calls
/// [onRefresh]; otherwise it waits another [interval]. A tab the tabs shell
/// keeps and a route another covers have their tickers off, and so wait too
/// (`DL-118` (6)). A tick that found the screen hidden is remembered: when
/// the screen is shown again it refreshes at once, not an interval later.
///
/// It waits while [active] is false: while a load runs, and after one
/// failed. A refresh that fails therefore stops the refreshing, the screen
/// says so with a retry the person presses, and a refresh is never a retry
/// of a failed load.
class PeriodicRefresh extends StatefulWidget {
  const PeriodicRefresh({
    required this.active,
    required this.onRefresh,
    required this.child,
    this.interval = const Duration(seconds: 10),
    super.key,
  });

  final bool active;
  final VoidCallback onRefresh;
  final Duration interval;
  final Widget child;

  @override
  State<PeriodicRefresh> createState() => _PeriodicRefreshState();
}

class _PeriodicRefreshState extends State<PeriodicRefresh> {
  Timer? _timer;

  /// A tick found the screen hidden, so what it shows may be stale.
  bool _skipped = false;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_skipped && widget.active && _shown && _foreground) {
      _skipped = false;
      _schedule();
      // Not during the build that showed the screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active) {
          widget.onRefresh();
        }
      });
    }
  }

  @override
  void didUpdateWidget(PeriodicRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active ||
        widget.interval != oldWidget.interval) {
      _schedule();
    }
    if (!widget.active) {
      _skipped = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = widget.active ? Timer(widget.interval, _tick) : null;
  }

  void _tick() {
    if (!mounted) {
      return;
    }
    final bool shown = _shown;
    // The refresh's own load makes [active] false, which cancels this; a
    // refresh that changes nothing still comes round again.
    _schedule();
    if (!shown) {
      _skipped = true;
    } else if (_foreground) {
      widget.onRefresh();
    }
  }

  bool get _foreground {
    final AppLifecycleState? lifecycle = WidgetsBinding.instance.lifecycleState;
    return lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  /// The screen's route is the top one and its tickers are on.
  bool get _shown =>
      (ModalRoute.of(context)?.isCurrent ?? true) &&
      TickerMode.valuesOf(context).enabled;

  @override
  Widget build(BuildContext context) => widget.child;
}
