import 'package:flutter/material.dart';

import '../theme/kit_colors.dart';

/// The kit screens' app bar: a centred title on plain white, without Material
/// 3's tint and without a colour change when the body scrolls under it.
AppBar kitAppBar({
  required String title,
  bool automaticallyImplyLeading = true,
}) {
  return AppBar(
    automaticallyImplyLeading: automaticallyImplyLeading,
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    centerTitle: true,
    title: Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: KitColors.ink,
      ),
    ),
  );
}
