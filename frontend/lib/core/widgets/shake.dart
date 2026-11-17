import 'package:flutter/material.dart';

/// Shakes [child] sideways once each time [trigger] grows: x 0, -6, 5, -4, 2,
/// 0 at 0, 20, 40, 60, 80 and 100 % of 360 ms, each leg eased in and out.
/// Nothing moves when the system asks for reduced motion (`DL-138`).
class Shake extends StatefulWidget {
  const Shake({required this.trigger, required this.child, super.key});

  final int trigger;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  static final Animatable<double> _offset = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      for (final (double from, double to) in <(double, double)>[
        (0, -6),
        (-6, 5),
        (5, -4),
        (-4, 2),
        (2, 0),
      ])
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: from,
            end: to,
          ).chain(CurveTween(curve: Curves.easeInOut)),
          weight: 1,
        ),
    ],
  );

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  @override
  void didUpdateWidget(Shake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger > oldWidget.trigger &&
        !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward(from: 0);
    }
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
      builder: (BuildContext context, Widget? child) => Transform.translate(
        offset: Offset(_offset.evaluate(_controller), 0),
        child: child,
      ),
    );
  }
}
