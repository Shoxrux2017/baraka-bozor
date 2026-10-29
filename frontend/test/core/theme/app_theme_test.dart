import 'package:baraka_bozor/core/theme/app_theme.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildAppTheme', () {
    test('keeps standard density and padded targets on every platform '
        '(DL-117)', () {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      for (final TargetPlatform platform in <TargetPlatform>[
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.android,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        final ThemeData theme = buildAppTheme(Brightness.light);
        expect(
          theme.visualDensity,
          VisualDensity.standard,
          reason: '$platform',
        );
        expect(
          theme.materialTapTargetSize,
          MaterialTapTargetSize.padded,
          reason: '$platform',
        );
      }
    });

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
      expect(KitColors.primary, const Color(0xFF3A9E46));
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

    test('draws text buttons in the text green', () {
      final ThemeData theme = buildAppTheme(Brightness.light);
      expect(
        theme.textButtonTheme.style!.foregroundColor!.resolve(<WidgetState>{}),
        KitColors.primaryDark,
      );
      expect(
        theme.outlinedButtonTheme.style!.foregroundColor!.resolve(
          <WidgetState>{},
        ),
        KitColors.primaryDark,
      );
    });

    test('draws a field label in a text colour, never the fill green '
        '(DL-117)', () {
      final input = buildAppTheme(Brightness.light).inputDecorationTheme;
      TextStyle? label(Set<WidgetState> states) =>
          WidgetStateProperty.resolveAs<TextStyle?>(
            input.floatingLabelStyle,
            states,
          );
      expect(
        label(<WidgetState>{WidgetState.focused})!.color,
        KitColors.primaryDark,
      );
      expect(label(<WidgetState>{WidgetState.error})!.color, KitColors.danger);
      expect(
        label(<WidgetState>{WidgetState.focused, WidgetState.error})!.color,
        KitColors.danger,
      );
      expect(label(<WidgetState>{})!.color, KitColors.muted);
    });

    test('draws the date picker today number in the text green (DL-117)', () {
      final DatePickerThemeData picker = buildAppTheme(Brightness.light)
          .datePickerTheme;
      expect(
        picker.todayForegroundColor!.resolve(<WidgetState>{}),
        KitColors.primaryDark,
      );
      expect(
        picker.todayForegroundColor!.resolve(<WidgetState>{
          WidgetState.selected,
        }),
        Colors.white,
      );
      expect(
        picker.dayBackgroundColor!.resolve(<WidgetState>{WidgetState.selected}),
        KitColors.primary,
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
