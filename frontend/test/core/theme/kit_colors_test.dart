import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double lighter = la > lb ? la : lb;
  final double darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('the rating star is the kit\'s --star', () {
    expect(KitColors.star, const Color(0xFFFFB020));
  });

  test('keeps the Owner\'s palette (DL-117)', () {
    expect(KitColors.primary, const Color(0xFF3A9E46));
    expect(KitColors.primaryDark, const Color(0xFF2D7D38));
    expect(KitColors.muted, const Color(0xFF676D68));
    expect(KitColors.danger, const Color(0xFFC0362C));
    expect(KitColors.warningDark, const Color(0xFF94600A));
    expect(KitColors.starEdge, const Color(0xFF94600A));
  });

  test('text colours read at 4.5:1 on white', () {
    for (final Color c in <Color>[
      KitColors.primaryDark,
      KitColors.muted,
      KitColors.danger,
      KitColors.warningDark,
    ]) {
      expect(_contrast(c, Colors.white), greaterThanOrEqualTo(4.5));
    }
  });

  test(
    'text colours read at 4.5:1 on their washes and on a disabled button',
    () {
      expect(
        _contrast(KitColors.primaryDark, KitColors.primaryWash),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(KitColors.danger, KitColors.dangerWash),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(KitColors.warningDark, KitColors.warningWash),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(KitColors.muted, KitColors.field),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(KitColors.muted, KitColors.line),
        greaterThanOrEqualTo(4.5),
      );
    },
  );

  test('white on a green button is the Owner\'s 3.4:1', () {
    expect(
      _contrast(Colors.white, KitColors.primary),
      greaterThanOrEqualTo(3.4),
    );
    expect(
      _contrast(Colors.white, KitColors.primaryDark),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(Colors.white, KitColors.danger),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('icons and star edges stand out at 3:1', () {
    for (final Color c in <Color>[
      KitColors.primary,
      KitColors.starEdge,
      KitColors.muted,
    ]) {
      expect(_contrast(c, Colors.white), greaterThanOrEqualTo(3));
    }
  });
}
