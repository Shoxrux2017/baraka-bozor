import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/push.dart';

/// Where the device's push token comes from. The app has none until
/// `startPush` binds Firebase's.
final Provider<PushTokenSource> pushTokenSourceProvider =
    Provider<PushTokenSource>((Ref ref) => const NoPushTokenSource());

/// Pushes, taps and the permission. The app has none until `startPush` binds
/// Firebase's.
final Provider<PushInbox> pushInboxProvider = Provider<PushInbox>(
  (Ref ref) => const NoPushInbox(),
);

/// The banner for a push that arrives in the foreground. The app draws none
/// until `startPush` binds the local notifications.
final Provider<BannerDisplay> bannerDisplayProvider = Provider<BannerDisplay>(
  (Ref ref) => const NoBannerDisplay(),
);
