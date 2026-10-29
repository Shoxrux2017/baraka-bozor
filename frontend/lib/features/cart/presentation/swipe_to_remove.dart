import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../core/theme/kit_colors.dart';

/// Lets a row be swiped left to remove it (`DL-119`). The row follows the
/// finger to the left; to the right it resists. A fast or long swipe slides it
/// out and calls [onRemove]; a short one springs back. A red box with a bin and
/// [label] shows behind it. While [removing] stays true the row stays out; when
/// it turns false (the removal failed) the row springs back. Screen readers get
/// [label] as an action, and with reduced motion nothing slides.
class SwipeToRemove extends StatefulWidget {
  const SwipeToRemove({
    required this.child,
    required this.label,
    required this.onRemove,
    required this.removing,
    super.key,
  });

  final Widget child;
  final String label;
  final VoidCallback onRemove;
  final bool removing;

  @override
  State<SwipeToRemove> createState() => _SwipeToRemoveState();
}

class _SwipeToRemoveState extends State<SwipeToRemove>
    with SingleTickerProviderStateMixin {
  static const Duration _slideOut = Duration(milliseconds: 280);
  static const Duration _springBack = Duration(milliseconds: 320);
  static const Curve _springCurve = Cubic(0.25, 1, 0.5, 1);

  late final AnimationController _controller = AnimationController(vsync: this)
    ..addListener(() {
      final Animation<double>? motion = _motion;
      if (motion != null) {
        setState(() => _offset = motion.value);
        if (_controller.value >= 1) {
          _arrive();
        }
      }
    });
  Animation<double>? _motion;

  /// Runs once the current movement ends, when it has one.
  VoidCallback? _then;

  /// Where the row stands, in pixels from its place; negative is to the left.
  double _offset = 0;

  /// Where the finger has dragged, before the right side's resistance.
  double _dragged = 0;

  /// The row has slid out and [SwipeToRemove.onRemove] was called.
  bool _out = false;

  double get _width => (context.size?.width ?? 0);

  @override
  void didUpdateWidget(SwipeToRemove oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.removing && !widget.removing && _out) {
      _out = false;
      _moveTo(0, _springBack, _springCurve);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _set(double offset) {
    _controller.stop();
    _motion = null;
    setState(() => _offset = offset);
  }

  void _arrive() {
    final VoidCallback? then = _then;
    _then = null;
    then?.call();
  }

  void _moveTo(
    double target,
    Duration duration,
    Curve curve, {
    VoidCallback? then,
  }) {
    _then = then;
    if (MediaQuery.disableAnimationsOf(context)) {
      _set(target);
      _arrive();
      return;
    }
    _motion = _controller.drive(
      Tween<double>(
        begin: _offset,
        end: target,
      ).chain(CurveTween(curve: curve)),
    );
    _controller.duration = duration;
    _controller.forward(from: 0);
  }

  double _resist(double x) {
    final double d = _width;
    return x * d * 0.55 / (d + 0.55 * x);
  }

  void _onStart(DragStartDetails details) {
    // A row that is sliding out stays on its way (`DL-119`).
    if (_out) {
      return;
    }
    _controller.stop();
    _motion = null;
    _then = null;
    _dragged = _offset;
  }

  void _onUpdate(DragUpdateDetails details) {
    if (_out) {
      return;
    }
    _dragged += details.delta.dx;
    setState(() => _offset = _dragged < 0 ? _dragged : _resist(_dragged));
  }

  void _onEnd(DragEndDetails details) {
    if (_out) {
      return;
    }
    final double velocity = details.primaryVelocity ?? 0;
    final double projected = _offset + velocity / 1000 * 0.998 / (1 - 0.998);
    if (projected < -0.45 * _width) {
      _slideOutAndRemove();
    } else {
      _moveTo(0, _springBack, _springCurve);
    }
  }

  void _slideOutAndRemove() {
    if (_out) {
      return;
    }
    _out = true;
    _moveTo(
      -(_width + 24),
      _slideOut,
      Curves.easeOut,
      then: () {
        if (mounted && _out) {
          widget.onRemove();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        CustomSemanticsAction(label: widget.label): _slideOutAndRemove,
      },
      child: GestureDetector(
        // Scroll actions would let a screen reader's scroll gesture remove the
        // row; the custom action above is its way (`DL-119`).
        excludeFromSemantics: true,
        onHorizontalDragStart: _onStart,
        onHorizontalDragUpdate: _onUpdate,
        onHorizontalDragEnd: _onEnd,
        child: Stack(
          fit: StackFit.passthrough,
          children: <Widget>[
            if (_offset < 0)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: KitColors.danger,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.delete_outline,
                              size: 22,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.label,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(_offset, 0),
              child: Material(color: Colors.white, child: widget.child),
            ),
          ],
        ),
      ),
    );
  }
}
