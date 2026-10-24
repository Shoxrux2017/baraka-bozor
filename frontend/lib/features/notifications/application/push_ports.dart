import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/push.dart';

/// Where the device's push token comes from. The app has none until
/// `startPush` binds Firebase's.
final Provider<PushTokenSource> pushTokenSourceProvider =
    Provider<PushTokenSource>((Ref ref) => const NoPushTokenSource());
