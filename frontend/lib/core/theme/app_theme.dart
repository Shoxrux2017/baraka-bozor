import 'package:flutter/material.dart';

import 'kit_colors.dart';

/// The seed every Material colour in the client is derived from: the kit
/// primary green.
///
/// Public so a test can prove both schemes really come from this one value
/// rather than merely differing from each other.
const Color appSeedColor = KitColors.primary;

/// The interface font, bundled with the app (`assets/fonts`), so text looks
/// the same offline and on every device.
const String appFontFamily = 'Montserrat';

/// Builds the Material 3 theme for [brightness]: one seed with the brand
/// primary pinned, the brand font, and the kit's button and field shapes.
ThemeData buildAppTheme(Brightness brightness) {
  final RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );
  const TextStyle buttonText = TextStyle(
    fontFamily: appFontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 16,
  );
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color, width: width),
  );
  return ThemeData(
    useMaterial3: true,

    /// Standard density on every platform, as phones have it (DL-117).
    visualDensity: VisualDensity.standard,

    /// Padded tap targets on every platform, so desktop browsers get 44 too (DL-117).
    materialTapTargetSize: MaterialTapTargetSize.padded,
    fontFamily: appFontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: appSeedColor,
      brightness: brightness,
    ).copyWith(primary: KitColors.primary, onPrimary: Colors.white),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 56),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 56),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: KitColors.primaryDark),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: KitColors.primaryDark),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KitColors.field,
      border: border(KitColors.line, 1),
      enabledBorder: border(KitColors.line, 1),
      focusedBorder: border(KitColors.primary, 1.5),
    ),
  );
}
