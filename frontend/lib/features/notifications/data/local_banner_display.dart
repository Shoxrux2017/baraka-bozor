import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/theme/kit_colors.dart';
import '../domain/push.dart';
import '../domain/push_event.dart';

/// The banner for a push that arrives in the foreground, drawn with
/// `flutter_local_notifications` into the same `orders` channel the system
/// uses for pushes that arrive in the background (`DL-115` (4)).
///
/// Android has no foreground banner of its own, so the app draws it; the
/// target travels in the banner's payload, and its tap comes back through
/// [taps].
class LocalBannerDisplay implements BannerDisplay {
  LocalBannerDisplay._(this._plugin);

  /// The channel the server's pushes and these banners share; the manifest
  /// names it as Firebase's default.
  static const String channelId = 'orders';

  /// The drawable in `res/drawable` the status bar shows.
  static const String smallIcon = 'ic_stat_notify';

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<PushTarget> _taps =
      StreamController<PushTarget>.broadcast();

  /// Initialises the plugin. The Darwin settings request nothing: the
  /// permission is asked once, by the permission prompt, at the right time.
  static Future<LocalBannerDisplay> start() async {
    final FlutterLocalNotificationsPlugin plugin =
        FlutterLocalNotificationsPlugin();
    final LocalBannerDisplay display = LocalBannerDisplay._(plugin);
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(smallIcon),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: display._onResponse,
    );
    return display;
  }

  void _onResponse(NotificationResponse response) {
    final PushTarget? target = PushTarget.fromPayload(response.payload);
    if (target != null) {
      _taps.add(target);
    }
  }

  @override
  Future<void> prepare(BannerChannel channel) async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            channelId,
            channel.name,
            description: channel.description,
            importance: Importance.high,
          ),
        );
  }

  /// One banner per tag: the same push shown twice replaces itself.
  @override
  Future<void> show(IncomingPush push) => _plugin.show(
    id: 0,
    title: push.title,
    body: push.body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        push.title,
        importance: Importance.high,
        priority: Priority.high,
        color: KitColors.primaryDark,
        tag: push.tag,
      ),
      iOS: const DarwinNotificationDetails(),
    ),
    payload: push.target?.payload,
  );

  @override
  Stream<PushTarget> get taps => _taps.stream;

  @override
  Future<PushTarget?> launchTarget() async {
    final NotificationAppLaunchDetails? details = await _plugin
        .getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) {
      return null;
    }
    return PushTarget.fromPayload(details.notificationResponse?.payload);
  }
}
