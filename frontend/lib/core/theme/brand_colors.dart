import 'package:flutter/painting.dart';

/// BarakaBozor's palette, from the Customer design the Owner chose on
/// 2026-10-14 (design 4a, `DL-74`). Every brand colour is named here, so a
/// change of colour is a change in one place (interview topic 8.3).
abstract final class BrandColors {
  /// The header's deep green, and the seed of the Material scheme.
  static const Color green = Color(0xFF0F3B2E);

  /// The delivery address on the header; later, what is in the cart.
  static const Color lime = Color(0xFFB8E35A);

  /// Counts and the screen's one main action.
  static const Color orange = Color(0xFFFF6A13);

  /// Text on white.
  static const Color ink = Color(0xFF1A1D21);

  /// Secondary text and inactive icons on white.
  static const Color muted = Color(0xFF6B7280);
}
