import 'package:flutter/material.dart';

import '../../theme/kit_colors.dart';

/// What a panel form field types in: 13 px `ink`, like the hint beside it.
const TextStyle panelFieldTextStyle = TextStyle(
  fontSize: 13,
  color: KitColors.ink,
);

/// The decoration of a panel list's search: a filled `field` box of radius 12,
/// 40 high, with a search icon at the start and an optional [suffix].
InputDecoration panelSearchDecoration({required String hint, Widget? suffix}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: KitColors.muted),
    prefixIcon: const Icon(Icons.search, size: 20),
    prefixIconColor: KitColors.muted,
    prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    suffixIcon: suffix,
    suffixIconConstraints: const BoxConstraints(minHeight: 40),
    filled: true,
    fillColor: KitColors.field,
    isDense: true,
    constraints: const BoxConstraints(minHeight: 40),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}

/// The decoration of a panel form field: white, a 1 px `line` border of radius
/// 14, `primary` 1.5 px when focused and `danger` 1.5 px on error. [helper] and
/// [counter] are 11 px `muted`, the error 12 px `danger`. A [prefix] stands at
/// the start as 13 px `ink2` text, then a `line` rule and 10 of space.
InputDecoration panelFieldDecoration({
  String? hint,
  String? suffix,
  String? prefix,
  String? helper,
  String? counter,
}) {
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color, width: width),
  );

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: KitColors.muted),
    prefixIcon: prefix == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  prefix,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: KitColors.ink2,
                  ),
                ),
                const SizedBox(width: 10),
                const SizedBox(
                  width: 1,
                  height: 20,
                  child: ColoredBox(color: KitColors.line),
                ),
              ],
            ),
          ),
    prefixIconConstraints: const BoxConstraints(),
    suffixText: suffix,
    suffixStyle: const TextStyle(fontSize: 13, color: KitColors.muted),
    helperText: helper,
    helperMaxLines: 3,
    helperStyle: const TextStyle(fontSize: 11, color: KitColors.muted),
    counterText: counter,
    counterStyle: const TextStyle(fontSize: 11, color: KitColors.muted),
    errorMaxLines: 3,
    errorStyle: const TextStyle(fontSize: 12, color: KitColors.danger),
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding: const EdgeInsets.all(14),
    border: border(KitColors.line, 1),
    enabledBorder: border(KitColors.line, 1),
    disabledBorder: border(KitColors.line, 1),
    focusedBorder: border(KitColors.primary, 1.5),
    errorBorder: border(KitColors.danger, 1.5),
    focusedErrorBorder: border(KitColors.danger, 1.5),
  );
}

/// Fields side by side — each `Expanded`, 16 apart, aligned at the top — when
/// the row is wide enough for every one to have [minFieldWidth]; one under the
/// other below that.
class PanelFieldRow extends StatelessWidget {
  const PanelFieldRow({
    required this.children,
    this.minFieldWidth = 200,
    super.key,
  });

  final List<Widget> children;
  final double minFieldWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double needed =
            children.length * minFieldWidth + (children.length - 1) * 16;

        if (constraints.maxWidth >= needed) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 16),
                Expanded(child: children[i]),
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 16),
              children[i],
            ],
          ],
        );
      },
    );
  }
}
