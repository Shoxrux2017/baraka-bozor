import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../theme/kit_colors.dart';

/// A row of [pills]: wrapping, 6 apart, when [wrap] is true, otherwise one row
/// that scrolls sideways — by finger, by mouse drag, by wheel or by the scroll
/// bar under it — and fades at its right edge.
class PanelPillRow extends StatelessWidget {
  const PanelPillRow({required this.pills, required this.wrap, super.key});

  final List<Widget> pills;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    if (wrap) {
      return Wrap(spacing: 6, runSpacing: 6, children: pills);
    }

    return _ScrollingPills(pills: pills);
  }
}

class _ScrollingPills extends StatefulWidget {
  const _ScrollingPills({required this.pills});

  final List<Widget> pills;

  @override
  State<_ScrollingPills> createState() => _ScrollingPillsState();
}

class _ScrollingPillsState extends State<_ScrollingPills> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: const <PointerDeviceKind>{
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
        scrollbars: false,
      ),
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (Rect bounds) => const LinearGradient(
            colors: <Color>[Colors.white, Colors.white, Colors.transparent],
            stops: <double>[0, 0.9, 1],
          ).createShader(bounds),
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 32, bottom: 12),
            child: Row(
              children: <Widget>[
                for (int i = 0; i < widget.pills.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 6),
                  widget.pills[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A filter pill: white, or — [selected] — green; with an optional [count]
/// after the label, muted when it is zero.
class PanelPill extends StatelessWidget {
  const PanelPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    super.key,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color text = selected
        ? Colors.white
        : count == 0
        ? KitColors.muted
        : KitColors.ink;

    return Material(
      color: selected ? KitColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: text,
                    ),
                  ),
                ),
                if (count != null) ...<Widget>[
                  const SizedBox(width: 8),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: text,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
