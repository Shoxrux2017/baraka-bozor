import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../domain/push.dart';
import '../domain/push_event.dart';

/// The device's push token and what arrives with it, from Firebase Cloud
/// Messaging (`DL-17` (9), `DL-115`). The system shows a notification
/// message by itself while the app is in the background or closed; only the
/// foreground and the taps come through here.
class FcmPushMessaging implements PushTokenSource, PushInbox {
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

  @override
  bool get receivesPushes => true;

  @override
  Stream<IncomingPush> get foreground => FirebaseMessaging.onMessage
      .map(incomingPushOf)
      .where((IncomingPush? push) => push != null)
      .cast<IncomingPush>();

  @override
  Stream<PushTarget> get opened => FirebaseMessaging.onMessageOpenedApp
      .map((RemoteMessage message) => PushTarget.fromData(message.data))
      .where((PushTarget? target) => target != null)
      .cast<PushTarget>();

  @override
  Future<PushTarget?> launchTarget() async {
    final RemoteMessage? message = await _messaging.getInitialMessage();
    return message == null ? null : PushTarget.fromData(message.data);
  }

  @override
  Future<void> requestPermission() async {
    await _messaging.requestPermission();
  }

  /// The banner [message] asks for, or `null` for a message that carries no
  /// notification or an empty one: there is nothing to show. The tag is the
  /// one the server set (the delivery id), so a banner drawn here and the
  /// system's own for the same push replace each other.
  static IncomingPush? incomingPushOf(RemoteMessage message) {
    final RemoteNotification? notification = message.notification;
    final String? title = notification?.title;
    final String? body = notification?.body;
    if (notification == null ||
        title == null ||
        title.isEmpty ||
        body == null ||
        body.isEmpty) {
      return null;
    }
    return IncomingPush(
      title: title,
      body: body,
      tag: notification.android?.tag ?? message.messageId,
      target: PushTarget.fromData(message.data),
    );
  }
}
