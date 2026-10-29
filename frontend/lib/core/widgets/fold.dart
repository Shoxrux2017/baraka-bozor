import 'dart:math' as math;

import 'package:flutter/widgets.dart';

const Cubic _foldCurve = Cubic(0.2, 0.8, 0.2, 1);

/// Folds [child]'s height and opacity away when [shown] turns false, then
/// calls [onFolded]; unfolds it again when [shown] turns true (`DL-119`). With
/// [appear] it unfolds on its first build. With reduced motion it does not
/// animate: [onFolded] is called after the first frame.
class Fold extends StatefulWidget {
  const Fold({
    required this.shown,
    required this.child,
    this.appear = false,
    this.onFolded,
    super.key,
  });

  final bool shown;
  final bool appear;
  final VoidCallback? onFolded;
  final Widget child;

  @override
  State<Fold> createState() => _FoldState();
}

class _FoldState extends State<Fold> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: widget.shown && !widget.appear ? 1 : 0,
  );
  bool _started = false;

  /// The last move was a fold; the controller runs linearly and the curves
  /// are applied when building.
  bool _folding = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (widget.shown && widget.appear) {
        _move(forward: true);
      } else if (!widget.shown) {
        _controller.value = 1;
        _move(forward: false);
      }
    }
  }

  @override
  void didUpdateWidget(Fold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shown != oldWidget.shown) {
      _move(forward: widget.shown);
    }
  }

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  void _move({required bool forward}) {
    _folding = !forward;
    if (_reduced) {
      _controller.value = forward ? 1 : 0;
      if (!forward) {
        _notifyFolded();
      }
      return;
    }
    if (forward) {
      _controller.animateTo(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.linear,
      );
    } else {
      _controller.animateBack(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.linear,
      );
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && !widget.shown) {
      _notifyFolded();
    }
  }

  void _notifyFolded() {
    final VoidCallback? onFolded = widget.onFolded;
    if (onFolded == null) {
      return;
    }
    // Not during a build or a layout that is still running.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.shown) {
        onFolded();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double v = _controller.value;
        final double size;
        final double opacity;
        if (_folding) {
          final double e = 1 - v;
          size = 1 - _foldCurve.transform(e);
          opacity = 1 - Curves.easeOut.transform(math.min(1.0, e * 260 / 200));
        } else {
          size = opacity = _foldCurve.transform(v);
        }
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: size,
            child: Opacity(opacity: opacity, child: child),
          ),
        );
      },
    );
  }
}

/// A column whose items fold in when they appear and fold away when they
/// leave, each keeping its own State (`DL-119`). The first build shows the
/// items still. A key that leaves stays at its last index, folding, and is
/// dropped when it has folded; a key that comes back while folding unfolds in
/// place.
class FoldingColumn<T> extends StatefulWidget {
  const FoldingColumn({
    required this.items,
    required this.keyOf,
    required this.itemBuilder,
    super.key,
  });

  final List<T> items;
  final Object Function(T) keyOf;
  final Widget Function(BuildContext, T) itemBuilder;

  @override
  State<FoldingColumn<T>> createState() => _FoldingColumnState<T>();
}

class _Entry<T> {
  _Entry(this.key, this.item, {required this.leaving, required this.appear});

  final Object key;
  T item;
  bool leaving;
  bool appear;
}

class _FoldingColumnState<T> extends State<FoldingColumn<T>> {
  late List<_Entry<T>> _entries = <_Entry<T>>[
    for (final T item in widget.items)
      _Entry<T>(widget.keyOf(item), item, leaving: false, appear: false),
  ];

  @override
  void didUpdateWidget(FoldingColumn<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Map<Object, _Entry<T>> before = <Object, _Entry<T>>{
      for (final _Entry<T> e in _entries) e.key: e,
    };
    final Set<Object> now = <Object>{};
    final List<_Entry<T>> next = <_Entry<T>>[];
    for (final T item in widget.items) {
      final Object key = widget.keyOf(item);
      now.add(key);
      final _Entry<T>? old = before[key];
      if (old == null) {
        next.add(_Entry<T>(key, item, leaving: false, appear: true));
      } else {
        old
          ..item = item
          ..leaving = false;
        next.add(old);
      }
    }
    // A key that left stays at its last index while it folds.
    for (int i = 0; i < _entries.length; i++) {
      final _Entry<T> e = _entries[i];
      if (!now.contains(e.key)) {
        e.leaving = true;
        next.insert(i < next.length ? i : next.length, e);
      }
    }
    _entries = next;
  }

  void _drop(Object key) {
    if (!mounted) {
      return;
    }
    setState(() {
      _entries.removeWhere((_Entry<T> e) => e.key == key && e.leaving);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final _Entry<T> e in _entries)
          KeyedSubtree(
            key: ValueKey<Object>(e.key),
            child: IgnorePointer(
              ignoring: e.leaving,
              child: ExcludeSemantics(
                excluding: e.leaving,
                child: Fold(
                  shown: !e.leaving,
                  appear: e.appear,
                  onFolded: () => _drop(e.key),
                  child: widget.itemBuilder(context, e.item),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
