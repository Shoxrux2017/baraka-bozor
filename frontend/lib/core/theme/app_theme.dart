import 'package:flutter/material.dart';

import 'brand_colors.dart';

/// The seed every Material colour in the client is derived from: the brand
/// green of design 4a (`DL-75`).
///
/// Public so a test can prove both schemes really come from this one value
/// rather than merely differing from each other.
const Color appSeedColor = BrandColors.green;

/// The interface font, bundled with the app (`assets/fonts`), so text looks
/// the same offline and on every device.
const String appFontFamily = 'Manrope';

/// Builds the Material 3 theme for [brightness]: one seed, the brand font.
/// Screens redesigned after design 4a take their brand colours from
/// [BrandColors]; component themes arrive with the parts that need them.
ThemeData buildAppTheme(Brightness brightness) {
  return ThemeData(
    useMaterial3: true,
    fontFamily: appFontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: appSeedColor,
      brightness: brightness,
    ),
  );
}
