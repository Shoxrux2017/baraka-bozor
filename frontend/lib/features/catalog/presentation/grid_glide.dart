import 'package:flutter/material.dart';

/// Where a card stands in the list, by its index.
typedef GridCellPlace = Offset Function(int index);

/// The top-left of the card at each index: [columns] to a row, a column
/// [cellWidth] apart and a row [rowExtent] apart (each with its gap). Cards
/// from [tailStart] on start a new row, [tailTop] lower, for the heading that
/// stands over them (`DL-129`).
GridCellPlace gridCellPlace({
  required int columns,
  required double cellWidth,
  required double rowExtent,
  int? tailStart,
  double tailTop = 0,
}) {
  return (int index) {
    if (tailStart != null && index >= tailStart) {
      final int at = index - tailStart;
      final int soldRows = (tailStart + columns - 1) ~/ columns;
      return Offset(
        (at % columns) * cellWidth,
        (soldRows + at ~/ columns) * rowExtent + tailTop,
      );
    }
    return Offset(
      (index % columns) * cellWidth,
      (index ~/ columns) * rowExtent,
    );
  };
}

/// For every id in both lists whose place changed, its old place less its
/// new one: where it starts, relative to where it now stands (`DL-129`).
Map<String, Offset> glideOffsets({
  required List<String> before,
  required List<String> after,
  required GridCellPlace placeBefore,
  required GridCellPlace placeAfter,
}) {
  final Map<String, int> was = <String, int>{
    for (int i = 0; i < before.length; i++) before[i]: i,
  };
  final Map<String, Offset> offsets = <String, Offset>{};
  for (int i = 0; i < after.length; i++) {
    final int? from = was[after[i]];
    if (from == null) {
      continue;
    }
    final Offset moved = placeBefore(from) - placeAfter(i);
    if (moved != Offset.zero) {
      offsets[after[i]] = moved;
    }
  }
  return offsets;
}

/// The curve of every move of the grid: a glide, and an arrival (`DL-129`).
const Cubic gridMotionCurve = Cubic(0.2, 0.8, 0.2, 1);

/// Where the cards in motion stand now, so a change that moves a card to a
/// new row, and so to a new widget, goes on from where it is drawn (`DL-129`).
class GridMotionRegistry {
  final Map<
    String,
    ({Object owner, Offset Function() remaining, double Function() arrived})
  >
  _live =
      <
        String,
        ({Object owner, Offset Function() remaining, double Function() arrived})
      >{};

  void _attach(
    String id,
    Object owner,
    Offset Function() remaining,
    double Function() arrived,
  ) => _live[id] = (owner: owner, remaining: remaining, arrived: arrived);

  void _detach(String id, Object owner) {
    if (_live[id]?.owner == owner) {
      _live.remove(id);
    }
  }

  /// How far the card with this id is still from its place.
  Offset remaining(String id) => _live[id]?.remaining() ?? Offset.zero;

  /// How far its arrival has come: 1 when done or not arriving.
  double arrived(String id) => _live[id]?.arrived() ?? 1;
}

/// One card of the grid in motion (`DL-129`). A card that [leaving] melts in
/// 190 ms (`easeIn`) to nothing and takes no taps. A card with [glideFrom]
/// starts that far from where it stands and glides there in 280 ms, from the
/// offset it had when the glide began, whatever later builds pass. A card with
/// [arriveFrom] grows from 0.9 and fades in over 260 ms, from that progress.
/// With reduced motion nothing glides, an arrival fades in over 200 ms and a
/// card fades out over 150 ms.
class GridCardMotion extends StatefulWidget {
  const GridCardMotion({
    required this.id,
    required this.registry,
    required this.child,
    this.glideFrom,
    this.arriveFrom,
    this.leaving = false,
    super.key,
  });

  final String id;
  final GridMotionRegistry registry;
  final Widget child;
  final Offset? glideFrom;
  final double? arriveFrom;
  final bool leaving;

  @override
  State<GridCardMotion> createState() => _GridCardMotionState();
}

class _GridCardMotionState extends State<GridCardMotion>
    with TickerProviderStateMixin {
  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 1,
  );
  late final AnimationController _arrive = AnimationController(
    vsync: this,
    value: 1,
  );
  late final AnimationController _melt = AnimationController(vsync: this);
  bool _started = false;
  bool _reduced = false;

  /// The offset the running glide started from.
  Offset _from = Offset.zero;

  Offset get _remaining =>
      _from * (1 - gridMotionCurve.transform(_glide.value));

  @override
  void initState() {
    super.initState();
    widget.registry._attach(
      widget.id,
      this,
      () => _remaining,
      () => _arrive.value,
    );
  }

  void _startGlide(Offset from) {
    _from = from;
    _glide
      ..value = 0
      ..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    _reduced = MediaQuery.disableAnimationsOf(context);
    _arrive.duration = Duration(milliseconds: _reduced ? 200 : 260);
    _melt.duration = Duration(milliseconds: _reduced ? 150 : 190);
    final double? arriveFrom = widget.arriveFrom;
    if (arriveFrom != null && arriveFrom < 1) {
      _arrive
        ..value = arriveFrom
        ..forward();
    }
    if (widget.glideFrom != null && !_reduced) {
      _startGlide(widget.glideFrom!);
    }
    if (widget.leaving) {
      _melt.forward();
    }
  }

  @override
  void didUpdateWidget(GridCardMotion old) {
    super.didUpdateWidget(old);
    if (widget.leaving != old.leaving) {
      widget.leaving ? _melt.forward() : _melt.reverse();
    }
    final Offset? from = widget.glideFrom;
    if (from != null && from != old.glideFrom && !_reduced) {
      _startGlide(from);
    }
  }

  @override
  void dispose() {
    widget.registry._detach(widget.id, this);
    _glide.dispose();
    _arrive.dispose();
    _melt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_glide, _arrive, _melt]),
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double arrive = _reduced
            ? Curves.easeOut.transform(_arrive.value)
            : gridMotionCurve.transform(_arrive.value);
        final double melt = Curves.easeIn.transform(_melt.value);
        final double scale =
            (_reduced ? 1.0 : 0.9 + 0.1 * arrive) *
            (_reduced ? 1.0 : 1 - 0.12 * melt);
        return IgnorePointer(
          ignoring: widget.leaving,
          child: Transform.translate(
            offset: _remaining,
            child: Transform.scale(
              scale: scale,
              child: Opacity(opacity: arrive * (1 - melt), child: child),
            ),
          ),
        );
      },
    );
  }
}
