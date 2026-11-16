import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/kit_colors.dart';

/// The "BarakaBozor" name in the brand green, used on the splash and the
/// sign-in screens. It keeps its size at large text: one line that ignores
/// the text scale, so the launch wordmark and the sign-in's are the same
/// mark at any setting (`DL-136` (17)).
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.size = 34});

  /// Font size in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        'BarakaBozor',
        maxLines: 1,
        softWrap: false,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontFamily: appFontFamily,
          fontWeight: FontWeight.w700,
          fontSize: size,
          color: KitColors.primary,
        ),
      ),
    );
  }
}
