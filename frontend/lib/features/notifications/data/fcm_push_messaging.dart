import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../domain/push.dart';

/// The device's push token from Firebase Cloud Messaging (`DL-17` (9)).
class FcmPushMessaging implements PushTokenSource {
  FcmPushMessaging(this._messaging, this._platform);

  final FirebaseMessaging _messaging;
  final PushPlatform _platform;

  // `getToken` and `onTokenRefresh` are marked deprecated in favour of
  // `register()`, which gives a Firebase Installation ID. The server sends
  // through the FCM token API (W4-8), so the token is what this app needs.
  /// `null` while Firebase has no token: no Play services, no network yet.
  /// Then there is nothing to register this time; it is not an error, and a
  /// token that arrives later comes through [changes].
  @override
  Future<PushToken?> current() async {
    try {
      // ignore: deprecated_member_use
      final String? value = await _messaging.getToken();
      if (value == null || value.isEmpty) {
        return null;
      }
      return PushToken(platform: _platform, value: value);
    } on FirebaseException {
      return null;
    }
  }

  @override
  // ignore: deprecated_member_use
  Stream<PushToken> get changes => _messaging.onTokenRefresh.map(
    (String value) => PushToken(platform: _platform, value: value),
  );
}
