import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Calls placed from the phone's own dialer (`DL-54` (16)): the Shopper to
/// the Customer while shopping, and later the Courier to the recipient.
abstract interface class PhoneCalls {
  /// Opens the dialer on [phone]; `false` when nothing on the device opens
  /// it, and the screen then says so and shows the number to dial by hand.
  Future<bool> call(String phone);
}

/// The dialer through a `tel:` link; Android 11 and later see the apps that
/// open one through the manifest's `<queries>`.
class DialerPhoneCalls implements PhoneCalls {
  const DialerPhoneCalls();

  @override
  Future<bool> call(String phone) async {
    try {
      return await launchUrl(Uri(scheme: 'tel', path: phone));
    } on PlatformException {
      return false;
    }
  }
}

final Provider<PhoneCalls> phoneCallsProvider = Provider<PhoneCalls>(
  (Ref ref) => const DialerPhoneCalls(),
);
