import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_auth/smart_auth.dart';

/// Asks the phone for its own number (DL-139, `vhod-2`).
abstract interface class PhoneNumberHint {
  /// The nine national digits of the number the person picked, or null when
  /// they cancelled, there is no number, it is not `+998`, the platform
  /// failed or the platform has no such picker.
  Future<String?> request();
}

/// Keeps the nine digits of a `+998` number; null for anything else.
String? nationalDigitsFromHint(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 12 || !digits.startsWith('998')) {
    return null;
  }
  return digits.substring(3);
}

/// Android's Phone Number Hint through `smart_auth`.
class SmartAuthPhoneNumberHint implements PhoneNumberHint {
  /// Creates the hint over [smartAuth], or the package's own instance.
  SmartAuthPhoneNumberHint({SmartAuth? smartAuth})
    : _smartAuth = smartAuth ?? SmartAuth.instance;

  final SmartAuth _smartAuth;

  @override
  Future<String?> request() async {
    try {
      final result = await _smartAuth.requestPhoneNumberHint();
      final number = result.data;
      if (!result.hasData || number == null) {
        return null;
      }
      return nationalDigitsFromHint(number);
    } on Object {
      return null;
    }
  }
}

/// The hint where the platform has none: always null.
class NoPhoneNumberHint implements PhoneNumberHint {
  /// Creates the empty hint.
  const NoPhoneNumberHint();

  @override
  Future<String?> request() async => null;
}

/// The hint for this platform: Android's own, nothing elsewhere.
final Provider<PhoneNumberHint> phoneNumberHintProvider =
    Provider<PhoneNumberHint>((ref) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        return SmartAuthPhoneNumberHint();
      }
      return const NoPhoneNumberHint();
    });
