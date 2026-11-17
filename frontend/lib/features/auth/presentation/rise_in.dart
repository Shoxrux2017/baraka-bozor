import 'package:flutter/material.dart';

/// Brings [child] in by opacity 0 → 1 and a 6 px rise, over [duration] on the
/// kit's `Cubic(0.2, 0.8, 0.2, 1)` curve; with reduced motion by opacity alone
/// in 200 ms (`DL-139`). The motion plays once, when the widget first shows.
class RiseIn extends StatefulWidget {
  const RiseIn({
    required this.child,
    this.duration = const Duration(milliseconds: 220),
    super.key,
  });

  final Widget child;
  final Duration duration;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  static const Curve _curve = Cubic(0.2, 0.8, 0.2, 1);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.duration = const Duration(milliseconds: 200);
      }
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double t = reduced
            ? _controller.value
            : _curve.transform(_controller.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, reduced ? 0 : -6 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}
