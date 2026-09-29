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

/// The dialer through a `tel:` link. The link opens the phone's own app
/// directly; the manifest's `<queries>` only lets the app ask first whether
/// one exists.
class DialerPhoneCalls implements PhoneCalls {
  const DialerPhoneCalls({this.launch = launchUrl});

  /// Opens a link on the device; `url_launcher`'s own, but for tests.
  final Future<bool> Function(Uri url) launch;

  @override
  Future<bool> call(String phone) async {
    try {
      return await launch(Uri(scheme: 'tel', path: phone));
    } on PlatformException {
      return false;
    }
  }
}

final Provider<PhoneCalls> phoneCallsProvider = Provider<PhoneCalls>(
  (Ref ref) => const DialerPhoneCalls(),
);
