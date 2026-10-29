import 'package:flutter/widgets.dart';

/// Lets [child] rise softly when [value] changes: from opacity 0.2 and 4 px
/// lower, in 240 ms (`DL-119`). [waiting] dims it to 0.45 over 200 ms. It
/// keeps one child, so a finder by the child's key still works. With reduced
/// motion the new value shows at once.
class SoftChange extends StatefulWidget {
  const SoftChange({
    required this.value,
    required this.child,
    this.waiting = false,
    super.key,
  });

  final Object value;
  final bool waiting;
  final Widget child;

  @override
  State<SoftChange> createState() => _SoftChangeState();
}

class _SoftChangeState extends State<SoftChange>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );

  @override
  void didUpdateWidget(SoftChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value &&
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
    return AnimatedOpacity(
      opacity: widget.waiting ? 0.45 : 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (BuildContext context, Widget? child) {
          final double t = Curves.easeOut.transform(_controller.value);
          return Opacity(
            opacity: 0.2 + 0.8 * t,
            child: Transform.translate(
              offset: Offset(0, 4 * (1 - t)),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
