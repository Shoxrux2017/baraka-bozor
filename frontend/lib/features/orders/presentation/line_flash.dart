import 'package:flutter/material.dart';

import '../../../core/theme/kit_colors.dart';

/// A wash behind [child] that reaches 6 px past it and fades out in 1400 ms
/// each time [flash] changes after the first build, to show a line the
/// Customer's answer changed (`DL-130`). With reduced motion nothing flashes.
class LineFlash extends StatefulWidget {
  const LineFlash({required this.flash, required this.child, super.key});

  final int flash;
  final Widget child;

  @override
  State<LineFlash> createState() => _LineFlashState();
}

class _LineFlashState extends State<LineFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
    value: 1,
  );

  @override
  void didUpdateWidget(LineFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flash != oldWidget.flash &&
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
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          left: -6,
          top: -6,
          right: -6,
          bottom: -6,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget? _) => DecoratedBox(
                key: const ValueKey<String>('line-flash'),
                decoration: BoxDecoration(
                  color: Color.lerp(
                    KitColors.lineFlash,
                    KitColors.lineFlash.withValues(alpha: 0),
                    Curves.easeOut.transform(_controller.value),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}
