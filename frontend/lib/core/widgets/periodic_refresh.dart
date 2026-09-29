import 'dart:async';

import 'package:flutter/widgets.dart';

/// Keeps what a screen shows current while it is shown, without push
/// (`DL-54` (15)). [interval] after each successful load, while the screen's
/// route is the top one and the app is in the foreground, it calls
/// [onRefresh]; otherwise it waits another [interval].
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

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(PeriodicRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active ||
        widget.interval != oldWidget.interval) {
      _schedule();
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
    final AppLifecycleState? lifecycle = WidgetsBinding.instance.lifecycleState;
    final bool foreground =
        lifecycle == null || lifecycle == AppLifecycleState.resumed;
    final bool shown = ModalRoute.of(context)?.isCurrent ?? true;
    // The refresh's own load makes [active] false, which cancels this; a
    // refresh that changes nothing still comes round again.
    _schedule();
    if (foreground && shown) {
      widget.onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
