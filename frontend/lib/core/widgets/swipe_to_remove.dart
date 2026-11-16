import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../theme/kit_colors.dart';

/// Lets a row be swiped left to remove it (`DL-119`). The row follows the
/// finger to the left; to the right it resists. A fast or long swipe slides it
/// out and calls [onRemove]; a short one springs back. A red box with a bin and
/// [label] shows behind it. While [removing] stays true the row stays out; when
/// it turns false (the removal failed) the row springs back. Screen readers get
/// [label] as an action, and with reduced motion nothing slides.
///
/// With [reveal] (`DL-137`) a medium swipe stops at -88 and shows an 88-wide
/// red button whose tap calls [onRemove] at once; only a long or fast swipe
/// removes by itself. The parent keeps [revealed] and hears
/// [onRevealChanged]; a tap on an open row closes it instead of reaching the
/// row. [semanticsAction] false leaves the action to the child's own node.
class SwipeToRemove extends StatefulWidget {
  const SwipeToRemove({
    required this.child,
    required this.label,
    required this.onRemove,
    required this.removing,
    this.reveal = false,
    this.revealed = false,
    this.onRevealChanged,
    this.radius = 14,
    this.semanticsAction = true,
    this.buttonKey,
    super.key,
  });

  final Widget child;
  final String label;
  final VoidCallback onRemove;
  final bool removing;
  final bool reveal;
  final bool revealed;
  final ValueChanged<bool>? onRevealChanged;
  final double radius;
  final bool semanticsAction;
  final Key? buttonKey;

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

  /// The row rests at -88 with the red button showing.
  bool _open = false;

  static const double _buttonWidth = 88;
  static const Duration _revealSlideOut = Duration(milliseconds: 200);
  static const Duration _revealSettle = Duration(milliseconds: 300);
  static const Curve _revealCurve = Cubic(0.2, 0.8, 0.2, 1);

  double get _width => (context.size?.width ?? 0);

  @override
  void didUpdateWidget(SwipeToRemove oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.removing && !widget.removing && _out) {
      _out = false;
      _moveTo(0, _springBack, _springCurve);
    } else if (widget.reveal &&
        oldWidget.revealed &&
        !widget.revealed &&
        _open &&
        !_out) {
      _open = false;
      _moveTo(0, _revealSettle, _revealCurve);
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
    if (widget.reveal) {
      _endReveal(velocity);
      return;
    }
    final double projected = _offset + velocity / 1000 * 0.998 / (1 - 0.998);
    if (projected < -0.45 * _width) {
      _slideOutAndRemove();
    } else {
      _moveTo(0, _springBack, _springCurve);
    }
  }

  /// Where a release goes in reveal mode (`DL-137`): out, open or back.
  void _endReveal(double velocity) {
    final double projected = _offset + velocity / 1000 * 0.99 / (1 - 0.99);
    if (_offset < -0.6 * _width ||
        (_offset < -0.35 * _width && projected < -0.9 * _width)) {
      _slideOutAndRemove();
    } else if (projected < -_buttonWidth / 2) {
      _open = true;
      _moveTo(-_buttonWidth, _revealSettle, _revealCurve);
      widget.onRevealChanged?.call(true);
    } else {
      final bool wasOpen = _open;
      _open = false;
      _moveTo(0, _revealSettle, _revealCurve);
      if (wasOpen) {
        widget.onRevealChanged?.call(false);
      }
    }
  }

  void _slideOutAndRemove() {
    if (_out) {
      return;
    }
    _out = true;
    _open = false;
    _moveTo(
      widget.reveal ? -_width : -(_width + 24),
      widget.reveal ? _revealSlideOut : _slideOut,
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
    final Widget swipe = GestureDetector(
      // Scroll actions would let a screen reader's scroll gesture remove the
      // row; the custom action above is its way (`DL-119`).
      excludeFromSemantics: true,
      onHorizontalDragStart: _onStart,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          if (_offset < 0 && widget.reveal)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: KitColors.danger,
                  borderRadius: BorderRadius.circular(widget.radius),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: _buttonWidth,
                    child: ExcludeSemantics(
                      child: GestureDetector(
                        key: widget.buttonKey,
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onRemove,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.delete_outline,
                                size: 22,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.label,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
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
              ),
            )
          else if (_offset < 0)
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
            // In reveal mode the card is the surface and the red shows past its
            // rounded corners; the cart's row is the white one.
            child: Material(
              type: widget.reveal
                  ? MaterialType.transparency
                  : MaterialType.canvas,
              color: widget.reveal ? null : Colors.white,
              child: widget.reveal
                  ? Stack(
                      fit: StackFit.passthrough,
                      children: <Widget>[
                        widget.child,
                        if (widget.revealed)
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              // The card's own node carries the actions.
                              excludeFromSemantics: true,
                              onTap: () => widget.onRevealChanged?.call(false),
                            ),
                          ),
                      ],
                    )
                  : widget.child,
            ),
          ),
        ],
      ),
    );
    if (!widget.semanticsAction) {
      return swipe;
    }
    return Semantics(
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        CustomSemanticsAction(label: widget.label): _slideOutAndRemove,
      },
      child: swipe,
    );
  }
}
