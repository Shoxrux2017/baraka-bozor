import 'package:baraka_bozor/core/theme/app_theme.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildAppTheme', () {
    test('uses Material 3, as docs/07-architecture.md section 2 requires', () {
      expect(buildAppTheme(Brightness.light).useMaterial3, isTrue);
    });

    test('honours the requested brightness', () {
      expect(
        buildAppTheme(Brightness.dark).colorScheme.brightness,
        Brightness.dark,
      );
      expect(
        buildAppTheme(Brightness.light).colorScheme.brightness,
        Brightness.light,
      );
    });

    test('derives both schemes from the one declared seed colour', () {
      // One seed is what keeps the two themes recognisably the same product.
      // Asserting only that the two primaries differ would also pass if light
      // and dark were seeded from two unrelated colours, which is the mistake
      // this guards against.
      for (final Brightness brightness in Brightness.values) {
        expect(
          buildAppTheme(brightness).colorScheme,
          ColorScheme.fromSeed(
            seedColor: appSeedColor,
            brightness: brightness,
          ).copyWith(primary: KitColors.primary, onPrimary: Colors.white),
          reason: 'the $brightness scheme must come from appSeedColor',
        );
      }
    });

    test('takes its seed from the kit primary', () {
      expect(appSeedColor, KitColors.primary);
      expect(KitColors.primary, const Color(0xFF5AC268));
    });

    test('pins the kit primary in both schemes', () {
      for (final Brightness brightness in Brightness.values) {
        final ColorScheme scheme = buildAppTheme(brightness).colorScheme;
        expect(scheme.primary, KitColors.primary);
        expect(scheme.onPrimary, Colors.white);
      }
    });

    test('styles buttons and fields after the kit', () {
      final ThemeData theme = buildAppTheme(Brightness.light);
      final ButtonStyle filled = theme.filledButtonTheme.style!;
      expect(filled.minimumSize!.resolve(<WidgetState>{}), const Size(0, 56));
      expect(
        filled.shape!.resolve(<WidgetState>{}),
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      );
      final TextStyle label = filled.textStyle!.resolve(<WidgetState>{})!;
      expect(label.fontFamily, 'Montserrat');
      expect(label.fontWeight, FontWeight.w600);
      expect(label.fontSize, 16);
      final input = theme.inputDecorationTheme;
      expect(input.filled, isTrue);
      expect(input.fillColor, KitColors.field);
      expect(
        (input.focusedBorder! as OutlineInputBorder).borderSide,
        const BorderSide(color: KitColors.primary, width: 1.5),
      );
    });

    test('sets the bundled Montserrat as the font of every text style', () {
      for (final Brightness brightness in Brightness.values) {
        final TextTheme text = buildAppTheme(brightness).textTheme;
        expect(text.bodyMedium!.fontFamily, appFontFamily);
        expect(text.titleLarge!.fontFamily, appFontFamily);
      }
      expect(appFontFamily, 'Montserrat');
    });
  });
}
