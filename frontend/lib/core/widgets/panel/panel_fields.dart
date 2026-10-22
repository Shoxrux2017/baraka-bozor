import 'package:flutter/material.dart';

import '../../theme/kit_colors.dart';

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
/// [counter] are 11 px `muted`, the error 12 px `danger`.
InputDecoration panelFieldDecoration({
  String? hint,
  String? suffix,
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
