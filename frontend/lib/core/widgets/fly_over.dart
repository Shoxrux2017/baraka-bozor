import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';

/// Flies a copy of [child] over the screen from [from] to where [to] says,
/// both in global coordinates (`DL-129`). The copy is laid out at the size of
/// the target and scaled from the size of [from], origin at the top left, as
/// the flight page does (`DL-128`); [to] is read on every frame, so a target
/// that moves is followed. It takes no taps and says nothing to a screen
/// reader. The future completes, and the copy is removed, when it lands or when
/// [to] has no place any more.
Future<void> flyOver(
  BuildContext context, {
  required Rect from,
  required Rect? Function() to,
  required Widget child,
  Duration duration = const Duration(milliseconds: 440),
  Curve curve = const Cubic(0.2, 0.8, 0.2, 1),
}) {
  final OverlayState overlay = Overlay.of(context);
  final Completer<void> done = Completer<void>();
  late final OverlayEntry entry;
  void finish() {
    if (entry.mounted) {
      entry.remove();
    }
    entry.dispose();
    if (!done.isCompleted) {
      done.complete();
    }
  }

  entry = OverlayEntry(
    builder: (BuildContext context) => _FlyOver(
      overlay: overlay,
      from: from,
      to: to,
      duration: duration,
      curve: curve,
      onEnd: finish,
      child: child,
    ),
  );
  overlay.insert(entry);
  return done.future;
}

class _FlyOver extends StatefulWidget {
  const _FlyOver({
    required this.overlay,
    required this.from,
    required this.to,
    required this.duration,
    required this.curve,
    required this.onEnd,
    required this.child,
  });

  final OverlayState overlay;
  final Rect from;
  final Rect? Function() to;
  final Duration duration;
  final Curve curve;
  final VoidCallback onEnd;
  final Widget child;

  @override
  State<_FlyOver> createState() => _FlyOverState();
}

class _FlyOverState extends State<_FlyOver>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration)
        ..addStatusListener((AnimationStatus status) {
          if (status == AnimationStatus.completed) {
            _end();
          }
        })
        ..forward();
  bool _ended = false;

  /// The entry is removed after the frame: never while the tree is built.
  void _end() {
    if (_ended) {
      return;
    }
    _ended = true;
    SchedulerBinding.instance.addPostFrameCallback((_) => widget.onEnd());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? _) {
            final Rect? global = widget.to();
            final RenderObject? box = widget.overlay.context.findRenderObject();
            if (global == null ||
                global.isEmpty ||
                box is! RenderBox ||
                !box.hasSize) {
              if (global == null) {
                _end();
              }
              return const SizedBox.shrink();
            }
            final Offset shift = box.globalToLocal(Offset.zero);
            final Rect place = global.shift(shift);
            final Rect start = widget.from.shift(shift);
            final double t = widget.curve.transform(_controller.value);
            final double scale = lerpDouble(start.width / place.width, 1, t)!;
            final Offset corner = Offset.lerp(start.topLeft, place.topLeft, t)!;
            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  left: corner.dx,
                  top: corner.dy,
                  width: place.width,
                  height: place.height,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topLeft,
                    child: widget.child,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
