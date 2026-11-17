import 'package:flutter/material.dart';

import '../../../../core/theme/kit_colors.dart';

/// The delivery pin over a map (`DL-138`): it fills its parent and its tip
/// stands at the parent's centre. It lifts while [lifted] and, when [drops]
/// grows with [lifted] false, drops with a squash. With reduced motion it
/// stays still.
class MapPin extends StatefulWidget {
  const MapPin({required this.lifted, required this.drops, super.key});

  final bool lifted;

  /// Counts the drops asked for; each increase plays one.
  final int drops;

  @override
  State<MapPin> createState() => _MapPinState();
}

class _MapPinState extends State<MapPin> with TickerProviderStateMixin {
  static const double _size = 48;
  static const double _lift = 14;

  late final AnimationController _up = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );
  late final AnimationController _drop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  @override
  void initState() {
    super.initState();
    if (widget.lifted) {
      _up.value = 1;
    }
  }

  @override
  void didUpdateWidget(MapPin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lifted && !oldWidget.lifted) {
      _drop.stop();
      _drop.value = 0;
      _up.forward();
    } else if (!widget.lifted && oldWidget.lifted) {
      _up.value = 0;
      if (widget.drops != oldWidget.drops) {
        _drop.forward(from: 0);
      }
    } else if (!widget.lifted && widget.drops != oldWidget.drops) {
      _drop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _up.dispose();
    _drop.dispose();
    super.dispose();
  }

  /// Height of the pin above rest, in logical pixels, and its squash.
  ({double rise, double scaleX, double scaleY}) _pose() {
    if (_drop.isAnimating) {
      const double hit = 0.7;
      final double t = _drop.value;
      if (t < hit) {
        final double k = Curves.easeIn.transform(t / hit);
        return (
          rise: _lift * (1 - k),
          scaleX: 1 + 0.07 * k,
          scaleY: 1 - 0.12 * k,
        );
      }
      final double k = Curves.easeIn.transform((t - hit) / (1 - hit));
      return (rise: 0, scaleX: 1.07 - 0.07 * k, scaleY: 0.88 + 0.12 * k);
    }
    final double k = const Cubic(0.2, 0.8, 0.2, 1).transform(_up.value);
    return (rise: _lift * k, scaleX: 1, scaleY: 1);
  }

  @override
  Widget build(BuildContext context) {
    final bool still = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_up, _drop]),
        builder: (BuildContext context, Widget? child) {
          final pose = still ? (rise: 0.0, scaleX: 1.0, scaleY: 1.0) : _pose();
          final double raised = pose.rise / _lift;
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Opacity(
                opacity: 1 - 0.6 * raised,
                child: Transform.scale(
                  scale: 1 + 0.7 * raised,
                  child: const SizedBox(
                    width: 14,
                    height: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0x47151D16),
                        borderRadius: BorderRadius.all(
                          Radius.elliptical(14, 6),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: _size),
                child: Transform(
                  key: const ValueKey<String>('map-pin-icon'),
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.identity()
                    ..translateByDouble(0, -pose.rise, 0, 1)
                    ..scaleByDouble(pose.scaleX, pose.scaleY, 1, 1),
                  child: const Icon(
                    Icons.location_on,
                    size: _size,
                    color: KitColors.primary,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
