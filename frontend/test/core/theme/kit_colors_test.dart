import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the rating star is the kit\'s --star', () {
    expect(KitColors.star, const Color(0xFFFFB020));
  });
}
