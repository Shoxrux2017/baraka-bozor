import 'package:flutter/material.dart';

/// The seed every colour in the client is derived from.
///
/// Public so a test can prove both schemes really come from this one value
/// rather than merely differing from each other.
const Color appSeedColor = Color(0xFF1B6C3A);

/// Builds the Material 3 theme for [brightness].
///
/// Deliberately minimal at this stage: one seed and Material 3. Design tokens,
/// typography and component themes arrive with the first surface that has a
/// design to honour, not before it.
ThemeData buildAppTheme(Brightness brightness) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: appSeedColor,
      brightness: brightness,
    ),
  );
}
