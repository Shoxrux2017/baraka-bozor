import 'package:flutter/painting.dart';

/// A text scaler as Android 14 and later gives: small sizes scale fully and
/// sizes near 100 hardly at all. At [factor] 2: 12 becomes about 22.6, 88
/// about 98.6 and 150 stays 150 (`DL-126`). `textScaleFactorTestValue` only
/// gives a linear scaler, which hides what this one shows.
final class NonlinearTextScaler extends TextScaler {
  const NonlinearTextScaler(this.factor);

  final double factor;

  @override
  double scale(double fontSize) =>
      fontSize * (1 + (factor - 1) * (1 - fontSize / 100).clamp(0.0, 1.0));

  // ignore: deprecated_member_use
  @override
  double get textScaleFactor => scale(14) / 14;
}
