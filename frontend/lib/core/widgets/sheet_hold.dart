import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// How far a sheet of height [extent] follows a finger that has dragged
/// [offset]: a rubber band that never reaches [extent] (`DL-140`).
double rubberBand(double offset, double extent) =>
    offset * extent * 0.55 / (extent + 0.55 * offset.abs());

/// Keeps a bottom sheet from being dragged shut while [holding] (`DL-140`).
///
/// Sits inside the sheet's own drag detector. While [holding], its own
/// vertical-drag recognizer, deeper in the tree, wins the gesture, so the
/// sheet never starts to close; the child follows the finger by
/// [rubberBand] and returns in 380 ms on release. Not holding, it adds no
/// recognizer and the sheet's own drag works. With reduced motion a held
/// drag is absorbed without moving the child.
class SheetHold extends StatefulWidget {
  const SheetHold({required this.holding, required this.child, super.key});

  final bool holding;
  final Widget child;

  @override
  State<SheetHold> createState() => _SheetHoldState();
}

class _SheetHoldState extends State<SheetHold>
    with SingleTickerProviderStateMixin {
  static const Curve _back = Cubic(0.2, 0.8, 0.2, 1);

  late final AnimationController _return = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    animationBehavior: AnimationBehavior.preserve,
  )..addListener(_onReturn);

  /// Where the child was when it was let go.
  double _from = 0;
  double _shown = 0;
  double _base = 0;
  double _dragged = 0;
  double _extent = 0;
  bool _dragging = false;

  void _onReturn() {
    setState(() => _shown = _from * (1 - _back.transform(_return.value)));
  }

  void _start(DragStartDetails details) {
    _return.stop();
    _dragging = true;
    _base = _shown;
    _dragged = 0;
    _extent = context.size?.height ?? 0;
  }

  void _update(DragUpdateDetails details) {
    if (!_dragging || MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _dragged += details.delta.dy;
    setState(() => _shown = _base + rubberBand(_dragged, _extent));
  }

  void _release() {
    if (!_dragging) {
      return;
    }
    _dragging = false;
    if (_shown == 0) {
      return;
    }
    _from = _shown;
    _return.forward(from: 0);
  }

  @override
  void didUpdateWidget(SheetHold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.holding) {
      _release();
    }
  }

  @override
  void dispose() {
    _return.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: widget.holding
          ? <Type, GestureRecognizerFactory>{
              VerticalDragGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    VerticalDragGestureRecognizer
                  >(VerticalDragGestureRecognizer.new, (
                    VerticalDragGestureRecognizer drag,
                  ) {
                    drag
                      ..onStart = _start
                      ..onUpdate = _update
                      ..onEnd = ((_) => _release())
                      ..onCancel = _release;
                  }),
            }
          : const <Type, GestureRecognizerFactory>{},
      child: Transform.translate(
        offset: Offset(0, _shown),
        child: widget.child,
      ),
    );
  }
}
