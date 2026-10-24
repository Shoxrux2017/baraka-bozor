import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// The Firebase project's values a build is given with `--dart-define`
/// (`frontend/.env.firebase`, never committed). A build without them has no
/// push: the app starts and works, and the device registers nothing.
class FirebasePushConfig {
  const FirebasePushConfig({
    required this.projectId,
    required this.messagingSenderId,
    required this.androidAppId,
    required this.androidApiKey,
    required this.iosAppId,
    required this.iosApiKey,
    required this.iosBundleId,
  });

  /// The values this build was compiled with.
  static const FirebasePushConfig environment = FirebasePushConfig(
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    androidAppId: String.fromEnvironment('FIREBASE_ANDROID_APP_ID'),
    androidApiKey: String.fromEnvironment('FIREBASE_ANDROID_API_KEY'),
    iosAppId: String.fromEnvironment('FIREBASE_IOS_APP_ID'),
    iosApiKey: String.fromEnvironment('FIREBASE_IOS_API_KEY'),
    iosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
  );

  final String projectId;
  final String messagingSenderId;
  final String androidAppId;
  final String androidApiKey;
  final String iosAppId;
  final String iosApiKey;
  final String iosBundleId;

  /// The options for [platform], or `null` when push is not available there:
  /// on the web (the web panel has no push, `DL-104` (12)), on a platform
  /// other than Android and iOS, or when a value that platform needs is empty.
  FirebaseOptions? optionsFor(TargetPlatform platform, {required bool web}) {
    if (web) {
      return null;
    }
    switch (platform) {
      case TargetPlatform.android:
        if (_anyEmpty(<String>[
          projectId,
          messagingSenderId,
          androidAppId,
          androidApiKey,
        ])) {
          return null;
        }
        return FirebaseOptions(
          apiKey: androidApiKey,
          appId: androidAppId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
        );
      case TargetPlatform.iOS:
        if (_anyEmpty(<String>[
          projectId,
          messagingSenderId,
          iosAppId,
          iosApiKey,
          iosBundleId,
        ])) {
          return null;
        }
        return FirebaseOptions(
          apiKey: iosApiKey,
          appId: iosAppId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          iosBundleId: iosBundleId,
        );
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return null;
    }
  }

  static bool _anyEmpty(List<String> values) =>
      values.any((String value) => value.isEmpty);
}
