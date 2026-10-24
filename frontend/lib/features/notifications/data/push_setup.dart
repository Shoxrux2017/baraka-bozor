import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../../core/errors/report_unexpected_error.dart';
import '../application/push_ports.dart';
import '../domain/push.dart';
import 'fcm_push_messaging.dart';
import 'firebase_push_config.dart';

/// Starts Firebase before the app runs and answers the providers that bring
/// push to the app. On the web, on a platform without push, or in a build
/// without the Firebase values it answers nothing, and the app keeps its
/// no-push defaults. A start that fails is reported once and the app starts
/// without push: a broken push must never keep the shop closed.
Future<List<Override>> startPush() async {
  final PushPlatform? platform = switch (defaultTargetPlatform) {
    TargetPlatform.android => PushPlatform.android,
    TargetPlatform.iOS => PushPlatform.ios,
    _ => null,
  };
  final FirebaseOptions? options = FirebasePushConfig.environment.optionsFor(
    defaultTargetPlatform,
    web: kIsWeb,
  );
  if (kIsWeb || platform == null || options == null) {
    return const <Override>[];
  }
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: options);
    final FcmPushMessaging source = FcmPushMessaging(
      FirebaseMessaging.instance,
      platform,
    );
    return <Override>[pushTokenSourceProvider.overrideWithValue(source)];
  } catch (error, stackTrace) {
    reportUnexpectedError(error, stackTrace, 'while starting push');
    return const <Override>[];
  }
}
