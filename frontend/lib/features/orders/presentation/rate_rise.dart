import 'dart:async';

import 'package:flutter/material.dart';

const Cubic _settle = Cubic(0.2, 0.8, 0.2, 1);

/// [child] rising 8 px with a fade in 260 ms when it first stands; with
/// reduced motion it only fades, in 200 ms (`DL-134`). The one rise of the
/// rating screen and the order page's rating cards.
class RateRise extends StatefulWidget {
  const RateRise({required this.child, super.key});

  final Widget child;

  @override
  State<RateRise> createState() => _RateRiseState();
}

class _RateRiseState extends State<RateRise>
    with SingleTickerProviderStateMixin {
  // Reduced motion changes how it arrives, not how long it takes, so the
  // platform's shortening of controllers is switched off.
  late final AnimationController _run = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _run.duration = Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 200 : 260,
      );
      unawaited(_run.forward());
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _run,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double t = (reduced ? Curves.easeOut : _settle).transform(
          _run.value,
        );
        return Opacity(
          opacity: t,
          child: reduced
              ? child
              : Transform.translate(
                  offset: Offset(0, (1 - t) * 8),
                  child: child,
                ),
        );
      },
    );
  }
}
