import 'package:flutter/material.dart';

/// Shows [child] and, when [swapKey] changes, brings the new child in with
/// `Curves.easeOut` while the old one goes: from [scaleFrom], or from [riseFrom]
/// of its height below, always with a fade. With reduced motion only a 200 ms
/// fade remains (`DL-127`, `DL-128`).
class SwapIn extends StatelessWidget {
  const SwapIn({
    required this.swapKey,
    required this.duration,
    required this.reduced,
    required this.child,
    this.scaleFrom,
    this.riseFrom,
    super.key,
  });

  final Object swapKey;
  final int duration;
  final bool reduced;
  final double? scaleFrom;
  final double? riseFrom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduced ? 200 : duration),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: <Widget>[...previous, ?current],
      ),
      transitionBuilder: (Widget child, Animation<double> animation) {
        Widget moved = child;
        final double? scale = scaleFrom;
        final double? rise = riseFrom;
        if (!reduced && scale != null) {
          moved = ScaleTransition(
            scale: Tween<double>(begin: scale, end: 1).animate(animation),
            child: moved,
          );
        }
        if (!reduced && rise != null) {
          moved = SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, rise),
              end: Offset.zero,
            ).animate(animation),
            child: moved,
          );
        }
        return FadeTransition(opacity: animation, child: moved);
      },
      child: KeyedSubtree(key: ValueKey<Object>(swapKey), child: child),
    );
  }
}
