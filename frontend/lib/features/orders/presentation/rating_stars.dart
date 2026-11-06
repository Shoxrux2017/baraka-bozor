import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/kit/kit_star.dart';

/// How a rating was chosen: [tap] on release, [slide] by a finger moving
/// across the stars, [reader] by a screen reader's increase or decrease.
enum RatingInput { tap, slide, reader }

const Cubic _ease = Cubic(0.2, 0.8, 0.2, 1);
const int _stepMs = 35;
const int _growMs = 260;
const int _popMs = 380;
const int _fadeMs = 150;

/// Five stars the Customer rates with (`DL-134`). With [adjustable] false
/// (the order card) they are five buttons that choose on release; with it
/// true (the rating screen) a finger may also slide across them and a screen
/// reader meets one adjustable value. A change of [value] lights the stars
/// between the old and the new one by one and pops the chosen star; the chosen
/// star tapped again pops alone. [onChanged] hears every choice and how it was
/// made; the host owns [value].
class RatingStars extends StatefulWidget {
  const RatingStars({
    required this.value,
    required this.onChanged,
    this.adjustable = false,
    this.cell = 52,
    this.glyph = 44,
    this.spacing = 0,
    this.keyPrefix = 'rate-star',
    this.enabled = true,
    super.key,
  });

  final int? value;
  final void Function(int stars, RatingInput how) onChanged;
  final bool adjustable;
  final double cell;
  final double glyph;
  final double spacing;
  final String keyPrefix;
  final bool enabled;

  @override
  State<RatingStars> createState() => _RatingStarsState();
}

class _RatingStarsState extends State<RatingStars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );

  int _prev = 0;
  int _chosen = 0;
  int _totalMs = _popMs;
  bool _reduced = false;

  int? _pressed;
  int? _downStar;
  int? _lastSlide;
  bool _slid = false;

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RatingStars oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int? next = widget.value;
    if (next != null && next != oldWidget.value) {
      _play(oldWidget.value ?? 0, next);
    }
  }

  /// Runs the cascade from [prev] to [next]; with [prev] equal to [next] the
  /// pop alone.
  void _play(int prev, int next) {
    _reduced = MediaQuery.disableAnimationsOf(context);
    _prev = prev;
    _chosen = next;
    _totalMs = _reduced
        ? _fadeMs
        : (next > prev ? (next - prev - 1) * _stepMs : 0) + _popMs;
    _run.duration = Duration(milliseconds: _totalMs);
    unawaited(_run.forward(from: 0));
  }

  static double _clamp01(double t) => t.clamp(0.0, 1.0);

  /// The star's scale [t] of the way through its pop: 1 → 1.18 at 35 %,
  /// 0.97 at 70 %, 1 at the end.
  static double _popScale(double t) {
    if (t <= 0 || t >= 1) {
      return 1;
    }
    final (double from, double to, double a, double b) = t < 0.35
        ? (1, 1.18, 0, 0.35)
        : t < 0.7
        ? (1.18, 0.97, 0.35, 0.7)
        : (0.97, 1, 0.7, 1);
    return from + (to - from) * _ease.transform((t - a) / (b - a));
  }

  /// Scale and opacity of star [i] at this moment of the run.
  (double, double) _look(int i) {
    if (!_run.isAnimating) {
      return (1, 1);
    }
    final double elapsed = _run.value * _totalMs;
    if (_reduced) {
      if (i > _prev && i <= _chosen) {
        final double t = _clamp01(elapsed / _fadeMs);
        return (1, 0.35 + 0.65 * Curves.easeOut.transform(t));
      }
      return (1, 1);
    }
    if (i == _chosen) {
      final double delay = _chosen > _prev
          ? (_chosen - _prev - 1) * _stepMs.toDouble()
          : 0;
      return (_popScale((elapsed - delay) / _popMs), 1);
    }
    if (i > _prev && i < _chosen) {
      final double delay = (i - _prev - 1) * _stepMs.toDouble();
      final double c = _ease.transform(_clamp01((elapsed - delay) / _growMs));
      return (0.55 + 0.45 * c, 0.35 + 0.65 * c);
    }
    return (1, 1);
  }

  /// The star under a finger at [dx] from the row's start.
  int _starAt(double dx) {
    final int star = (dx / (widget.cell + widget.spacing)).floor() + 1;
    return star.clamp(1, 5);
  }

  void _tapped(int star) {
    if (!widget.enabled) {
      return;
    }
    unawaited(HapticFeedback.lightImpact());
    if (star == widget.value) {
      _play(star, star);
    }
    widget.onChanged(star, RatingInput.tap);
  }

  void _slideTo(int star) {
    if (!widget.enabled || star == _lastSlide) {
      return;
    }
    _lastSlide = star;
    unawaited(HapticFeedback.selectionClick());
    widget.onChanged(star, RatingInput.slide);
  }

  void _step(int by) {
    final int? now = widget.value;
    final int next = ((now ?? (by > 0 ? 0 : 2)) + by).clamp(1, 5);
    if (next != now) {
      widget.onChanged(next, RatingInput.reader);
    }
  }

  void _press(int? star) {
    if (_pressed != star) {
      setState(() => _pressed = star);
    }
  }

  Widget _cell(int star) {
    final bool lit = widget.value != null && star <= widget.value!;
    final (double scale, double opacity) = _look(star);
    final bool pressed =
        _pressed == star && !MediaQuery.disableAnimationsOf(context);
    return SizedBox.square(
      key: ValueKey<String>('${widget.keyPrefix}-$star'),
      dimension: widget.cell,
      child: Center(
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale * (pressed ? 0.9 : 1),
            child: KitStar(filled: lit, size: widget.glyph),
          ),
        ),
      ),
    );
  }

  Widget _row(AppLocalizations l10n) {
    final bool card = !widget.adjustable;
    return AnimatedBuilder(
      animation: _run,
      builder: (BuildContext context, Widget? _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int star = 1; star <= 5; star++) ...<Widget>[
            if (star > 1 && widget.spacing > 0) SizedBox(width: widget.spacing),
            if (card)
              Semantics(
                container: true,
                button: true,
                label: l10n.rateStarsLabel(star),
                onTap: widget.enabled ? () => _tapped(star) : null,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: widget.enabled ? (_) => _press(star) : null,
                  onTapCancel: () => _press(null),
                  onTapUp: widget.enabled
                      ? (_) {
                          _press(null);
                          _tapped(star);
                        }
                      : null,
                  child: _cell(star),
                ),
              )
            else
              _cell(star),
          ],
        ],
      ),
    );
  }

  String _spoken(AppLocalizations l10n, int stars) {
    final List<String> words = <String>[
      l10n.rateStar1,
      l10n.rateStar2,
      l10n.rateStar3,
      l10n.rateStar4,
      l10n.rateStar5,
    ];
    return l10n.rateStarsValue(stars, words[stars - 1]);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (!widget.adjustable) {
      return _row(l10n);
    }
    final int? value = widget.value;
    final double width = widget.cell * 5 + widget.spacing * 4;
    return Semantics(
      container: true,
      label: l10n.rateStarsSpokenLabel,
      value: value == null ? l10n.rateStarsNone : _spoken(l10n, value),
      increasedValue: _spoken(l10n, ((value ?? 0) + 1).clamp(1, 5)),
      decreasedValue: _spoken(l10n, ((value ?? 2) - 1).clamp(1, 5)),
      onIncrease: widget.enabled ? () => _step(1) : null,
      onDecrease: widget.enabled ? () => _step(-1) : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled
            ? (TapDownDetails d) => _press(_starAt(d.localPosition.dx))
            : null,
        onTapCancel: () => _press(null),
        onTapUp: widget.enabled
            ? (TapUpDetails d) {
                _press(null);
                _tapped(_starAt(d.localPosition.dx));
              }
            : null,
        onHorizontalDragDown: widget.enabled
            ? (DragDownDetails d) => _downStar = _starAt(d.localPosition.dx)
            : null,
        onHorizontalDragStart: widget.enabled
            ? (DragStartDetails d) {
                _press(null);
                _lastSlide = widget.value;
                _slid = false;
              }
            : null,
        // A drag that moves only up or down wins the arena when nothing else
        // claims it, but it has no horizontal travel and chooses nothing.
        onHorizontalDragUpdate: widget.enabled
            ? (DragUpdateDetails d) {
                if (!_slid && d.delta.dx == 0) {
                  return;
                }
                if (!_slid) {
                  _slid = true;
                  _slideTo(_downStar ?? _starAt(d.localPosition.dx));
                }
                _slideTo(_starAt(d.localPosition.dx));
              }
            : null,
        child: SizedBox(width: width, height: widget.cell, child: _row(l10n)),
      ),
    );
  }
}
