import 'package:flutter/painting.dart';

/// The colours of the new screen kit (stage 1 onward).
abstract final class KitColors {
  /// Brand green: buttons, links, the wordmark.
  static const Color primary = Color(0xFF5AC268);

  /// Darker green for pressed and emphasised states.
  static const Color primaryDark = Color(0xFF44BA53);

  /// Soft green for selected backgrounds and borders.
  static const Color primarySoft = Color(0xFFD5EFD9);

  /// Faint green wash for highlighted panels.
  static const Color primaryWash = Color(0xFFEEF9F0);

  /// Main text.
  static const Color ink = Color(0xFF151D16);

  /// Secondary text.
  static const Color ink2 = Color(0xFF303731);

  /// Hints, captions and disabled text.
  static const Color muted = Color(0xFF8E948F);

  /// Hairlines and field borders.
  static const Color line = Color(0xFFEEF0EF);

  /// Text field background.
  static const Color field = Color(0xFFF9F9F9);

  /// Card background.
  static const Color card = Color(0xFFFAFAFA);

  /// Errors and destructive actions.
  static const Color danger = Color(0xFFF04438);

  /// Faint red wash behind a destructive notice.
  static const Color dangerWash = Color(0xFFFDECEB);

  /// Warnings: the icon of a notice that asks for the Customer's own action.
  static const Color warning = Color(0xFFE8A317);

  /// Faint amber wash behind a warning notice.
  static const Color warningWash = Color(0xFFFFF6E5);

  /// Amber text on the amber wash.
  static const Color warningDark = Color(0xFFB7791F);

  /// A step not yet reached on an amber card: the amber at a quarter over
  /// its wash.
  static const Color warningSoft = Color(0xFFFCE9BF);
}
