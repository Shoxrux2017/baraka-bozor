import 'package:flutter/widgets.dart';

/// A strip the page shows for a moment and takes away (`DL-132`, `DL-133`).
///
/// [fromBelow] false: it comes down from above in 420 ms from 1.4 of its own
/// height, stays until 4 s have passed and goes up with a fade in 300 ms.
/// [fromBelow] true: it rises 16 px with a fade in 360 ms and sinks 12 px with
/// a fade in 280 ms `Curves.easeIn`. With reduced motion either only fades,
/// 250 ms each way. Reduced motion changes how it moves, not how long it
/// stays. It shrinks to nothing when done.
class TimedBanner extends StatefulWidget {
  const TimedBanner({required this.child, required this.fromBelow, super.key});

  final Widget child;

  /// Whether the strip stands at the bottom and rises, rather than hangs from
  /// the top and comes down.
  final bool fromBelow;

  @override
  State<TimedBanner> createState() => _TimedBannerState();
}

class _TimedBannerState extends State<TimedBanner>
    with SingleTickerProviderStateMixin {
  static const Cubic _settle = Cubic(0.2, 0.8, 0.2, 1);
  static const double _stay = 4000;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    // Reduced motion changes how the banner moves, not how long it stays.
    animationBehavior: AnimationBehavior.preserve,
  );
  late bool _reduced;
  late double _inMs;
  late double _outMs;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (widget.fromBelow) {
      _inMs = _reduced ? 250 : 360;
      _outMs = _reduced ? 250 : 280;
    } else {
      _inMs = _reduced ? 250 : 420;
      _outMs = _reduced ? 250 : 300;
    }
    _controller.duration = Duration(milliseconds: (_stay + _outMs).round());
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        if (_controller.isCompleted) {
          return const SizedBox.shrink();
        }
        final double ms = _controller.value * (_stay + _outMs);
        return widget.fromBelow
            ? _fromBelow(ms, child!)
            : _fromAbove(ms, child!);
      },
    );
  }

  Widget _fromAbove(double ms, Widget child) {
    double rise = 0;
    double opacity = 1;
    if (ms < _inMs) {
      final double t = ms / _inMs;
      if (_reduced) {
        opacity = Curves.easeOut.transform(t);
      } else {
        rise = -1.4 * (1 - _settle.transform(t));
      }
    } else if (ms > _stay) {
      final double eased = Curves.easeIn.transform(
        ((ms - _stay) / _outMs).clamp(0, 1),
      );
      opacity = 1 - eased;
      if (!_reduced) {
        rise = -1.4 * eased;
      }
    }
    return Opacity(
      opacity: opacity,
      child: FractionalTranslation(translation: Offset(0, rise), child: child),
    );
  }

  Widget _fromBelow(double ms, Widget child) {
    double drop = 0;
    double opacity = 1;
    if (ms < _inMs) {
      final double t = ms / _inMs;
      if (_reduced) {
        opacity = Curves.easeOut.transform(t);
      } else {
        final double eased = _settle.transform(t);
        opacity = eased;
        drop = 16 * (1 - eased);
      }
    } else if (ms > _stay) {
      final double eased = Curves.easeIn.transform(
        ((ms - _stay) / _outMs).clamp(0, 1),
      );
      opacity = 1 - eased;
      if (!_reduced) {
        drop = 12 * eased;
      }
    }
    return Opacity(
      opacity: opacity,
      child: Transform.translate(offset: Offset(0, drop), child: child),
    );
  }
}
