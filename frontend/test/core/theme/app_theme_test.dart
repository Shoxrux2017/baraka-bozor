import 'package:baraka_bozor/core/theme/app_theme.dart';
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
          ColorScheme.fromSeed(seedColor: appSeedColor, brightness: brightness),
          reason: 'the $brightness scheme must come from appSeedColor',
        );
      }
    });
  });
}
