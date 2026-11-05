import 'package:flutter/widgets.dart';

/// An amount that rolls from the figure it showed to the new one in 320 ms,
/// ease-out cubic, in steps of 100 and with the last figure exact
/// (`DL-132`). With reduced motion it changes at once. A screen reader hears
/// only the final amount, never a figure on the way. [waiting] dims it to
/// 0.45 over 200 ms, as `SoftChange` does.
class RollingAmount extends StatefulWidget {
  const RollingAmount({
    required this.amountUzs,
    required this.format,
    this.style,
    this.waiting = false,
    this.textKey,
    super.key,
  });

  final int amountUzs;

  /// The words for an amount, such as "≈ 27 600 so'm".
  final String Function(int amountUzs) format;
  final TextStyle? style;
  final bool waiting;

  /// The key of the `Text`, which holds the final words once settled.
  final Key? textKey;

  @override
  State<RollingAmount> createState() => _RollingAmountState();
}

class _RollingAmountState extends State<RollingAmount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );

  /// Where the roll started, and where it goes.
  late int _from = widget.amountUzs;
  late int _to = widget.amountUzs;

  /// The figure on show: a round hundred on the way, [_to] at the end.
  int get _shown {
    final double t = _controller.value;
    if (t >= 1) {
      return _to;
    }
    final double eased = Curves.easeOutCubic.transform(t);
    return (((_from + (_to - _from) * eased) / 100).round()) * 100;
  }

  @override
  void didUpdateWidget(RollingAmount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.amountUzs == _to) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      _from = _to = widget.amountUzs;
      return;
    }
    _from = _shown;
    _to = widget.amountUzs;
    _controller.forward(from: 0);
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
      child: Semantics(
        label: widget.format(widget.amountUzs),
        excludeSemantics: true,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? _) => Text(
            widget.format(_shown),
            key: widget.textKey,
            style: widget.style,
          ),
        ),
      ),
    );
  }
}
