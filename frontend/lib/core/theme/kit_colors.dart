import 'package:flutter/painting.dart';

/// The colours of the new screen kit (stage 1 onward).
abstract final class KitColors {
  /// Brand green for fills, icons and borders; white on it is 3.4:1, the
  /// Owner's choice (`DL-117`). Never text.
  static const Color primary = Color(0xFF3A9E46);

  /// Green text and links, and the pressed fill (`DL-117`).
  static const Color primaryDark = Color(0xFF2D7D38);

  /// Soft green for selected backgrounds and borders.
  static const Color primarySoft = Color(0xFFD5EFD9);

  /// Faint green wash for highlighted panels.
  static const Color primaryWash = Color(0xFFEEF9F0);

  /// Main text.
  static const Color ink = Color(0xFF151D16);

  /// Secondary text.
  static const Color ink2 = Color(0xFF303731);

  /// Hints, captions and disabled text.
  static const Color muted = Color(0xFF676D68);

  /// Hairlines and field borders.
  static const Color line = Color(0xFFEEF0EF);

  /// Text field background.
  static const Color field = Color(0xFFF9F9F9);

  /// The panel's page behind its cards.
  static const Color page = Color(0xFFF6F7F6);

  /// Card background.
  static const Color card = Color(0xFFFAFAFA);

  /// Red: errors, destructive actions, their text and icons (`DL-117`).
  static const Color danger = Color(0xFFC0362C);

  /// Faint red wash behind a destructive notice.
  static const Color dangerWash = Color(0xFFFDECEB);

  /// Amber icons, borders and fills. Never text (`DL-117`).
  static const Color warning = Color(0xFFE8A317);

  /// Faint amber wash behind a warning notice.
  static const Color warningWash = Color(0xFFFFF6E5);

  /// Amber text (`DL-117`).
  static const Color warningDark = Color(0xFF94600A);

  /// A step not yet reached on an amber card: the amber at a quarter over
  /// its wash.
  static const Color warningSoft = Color(0xFFFCE9BF);

  /// The soft shadow of a raised white piece on a grey one, such as the
  /// chosen segment of a switch.
  static const Color shadow = Color(0x1F151D16);

  /// A filled rating star.
  static const Color star = Color(0xFFFFB020);

  /// The edge of a filled rating star (`DL-117`).
  static const Color starEdge = Color(0xFF94600A);
}
