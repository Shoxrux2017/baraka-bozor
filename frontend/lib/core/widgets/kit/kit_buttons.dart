import 'package:flutter/material.dart';

import '../../theme/kit_colors.dart';

const RoundedRectangleBorder _shape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(14)),
);

const TextStyle _label = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);

/// The kit filled button: [color] with white text, [height] high; disabled it
/// is a `line` field with `muted` text.
ButtonStyle kitFilled({Color color = KitColors.primary, double height = 54}) {
  return ButtonStyle(
    minimumSize: WidgetStatePropertyAll<Size>(Size(0, height)),
    elevation: const WidgetStatePropertyAll<double>(0),
    shape: const WidgetStatePropertyAll<OutlinedBorder>(_shape),
    textStyle: const WidgetStatePropertyAll<TextStyle>(_label),
    backgroundColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) =>
          states.contains(WidgetState.disabled) ? KitColors.line : color,
    ),
    foregroundColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) => states.contains(WidgetState.disabled)
          ? KitColors.muted
          : Colors.white,
    ),
  );
}

/// The kit outlined button: a 1 px `line` side, [foreground] text, [height]
/// high.
ButtonStyle kitOutlined({
  Color foreground = KitColors.ink,
  double height = 54,
}) {
  return ButtonStyle(
    minimumSize: WidgetStatePropertyAll<Size>(Size(0, height)),
    elevation: const WidgetStatePropertyAll<double>(0),
    shape: const WidgetStatePropertyAll<OutlinedBorder>(_shape),
    textStyle: const WidgetStatePropertyAll<TextStyle>(_label),
    side: const WidgetStatePropertyAll<BorderSide>(
      BorderSide(color: KitColors.line),
    ),
    backgroundColor: const WidgetStatePropertyAll<Color>(Colors.white),
    foregroundColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) =>
          states.contains(WidgetState.disabled) ? KitColors.muted : foreground,
    ),
  );
}
