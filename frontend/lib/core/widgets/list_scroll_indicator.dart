import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/kit_colors.dart';

/// The thin scroll thumb over the right edge of a vertical list (`DL-127`).
///
/// It sizes and places itself by [fullExtent], the length the whole list will
/// have once every page is loaded, so it does not jump as pages arrive. It
/// shows while the list scrolls and fades out over 300 ms, 900 ms after the
/// last scroll; with reduced motion it goes at once. [bottomInset] keeps the
/// track clear of a bar over the list's end. It takes no touch and is not
/// announced.
class ListScrollIndicator extends StatefulWidget {
  const ListScrollIndicator({
    required this.child,
    required this.fullExtent,
    this.bottomInset = 0,
    super.key,
  });

  final Widget child;

  /// The full length of the list's content, loaded or not.
  final double Function(ScrollMetrics metrics) fullExtent;
  final double bottomInset;

  @override
  State<ListScrollIndicator> createState() => _ListScrollIndicatorState();
}

class _ListScrollIndicatorState extends State<ListScrollIndicator>
    with SingleTickerProviderStateMixin {
  static const double _leastLength = 32;
  static const Duration _total = Duration(milliseconds: 1200);

  /// Time since the last scroll, 0 to 1 over [_total]; the fade is its last
  /// quarter.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: _total,
  );
  late final Animation<double> _opacity = ReverseAnimation(
    CurvedAnimation(
      parent: _clock,
      curve: const Interval(0.75, 1, curve: Curves.easeOut),
    ),
  );
  ScrollMetrics? _metrics;

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is ScrollUpdateNotification ||
        (notification is ScrollEndNotification && _metrics != null)) {
      setState(() => _metrics = notification.metrics);
      _clock.forward(from: 0);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    final ScrollMetrics? metrics = _metrics;
    Widget? thumb;
    if (metrics != null) {
      final double viewport = metrics.viewportDimension;
      final double full = math.max(
        widget.fullExtent(metrics),
        metrics.maxScrollExtent + viewport,
      );
      final double track = viewport - 8 - widget.bottomInset;
      // A track shorter than the thumb's least length takes no thumb: it
      // would run against the scroll.
      if (full > viewport && track >= _leastLength) {
        final double length = math.max(_leastLength, track * viewport / full);
        final double progress = ((metrics.pixels) / (full - viewport)).clamp(
          0,
          1,
        );
        final Widget bar = DecoratedBox(
          key: const ValueKey<String>('scroll-indicator'),
          decoration: BoxDecoration(
            color: KitColors.ink.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(2),
          ),
        );
        thumb = Positioned(
          top: 4 + math.max(0, track - length) * progress,
          right: 2,
          width: 3,
          height: length,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: FadeTransition(
                opacity: reduced
                    ? ReverseAnimation(
                        CurvedAnimation(
                          parent: _clock,
                          curve: const Interval(0.75, 0.7501),
                        ),
                      )
                    : _opacity,
                child: bar,
              ),
            ),
          ),
        );
      }
    }
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[widget.child, ?thumb],
      ),
    );
  }
}
