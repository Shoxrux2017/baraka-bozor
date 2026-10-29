import 'package:flutter/material.dart';

import '../theme/kit_colors.dart';

/// A grey bar that stands where a figure is not known yet (`DL-121`). While
/// [pulsing] it fades from opacity 1 to 0.45 and back over 1.2 s, repeating;
/// with reduced motion, or when still, it does not move. It says nothing to a
/// screen reader.
class SkeletonBar extends StatefulWidget {
  const SkeletonBar({
    required this.width,
    this.height = 14,
    this.pulsing = true,
    super.key,
  });

  final double width;
  final double height;
  final bool pulsing;

  @override
  State<SkeletonBar> createState() => _SkeletonBarState();
}

class _SkeletonBarState extends State<SkeletonBar>
    with SingleTickerProviderStateMixin {
  // Half a period: the controller runs 1 -> 0.45 and back with `reverse`.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(SkeletonBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final bool pulse =
        widget.pulsing && !MediaQuery.disableAnimationsOf(context);
    if (pulse && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!pulse && (_controller.isAnimating || _controller.value != 0)) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) => Opacity(
          opacity: 1 - 0.55 * Curves.easeInOut.transform(_controller.value),
          child: child,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: KitColors.line,
            borderRadius: BorderRadius.circular(widget.height / 2),
          ),
          child: SizedBox(width: widget.width, height: widget.height),
        ),
      ),
    );
  }
}
