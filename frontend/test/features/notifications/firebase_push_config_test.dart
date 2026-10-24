import 'package:baraka_bozor/features/notifications/data/firebase_push_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const FirebasePushConfig complete = FirebasePushConfig(
    projectId: 'bb-project',
    messagingSenderId: '1234567890',
    androidAppId: '1:1234567890:android:abc',
    androidApiKey: 'android-key',
    iosAppId: '1:1234567890:ios:def',
    iosApiKey: 'ios-key',
    iosBundleId: 'uz.barakabozor.app',
  );

  const FirebasePushConfig androidOnly = FirebasePushConfig(
    projectId: 'bb-project',
    messagingSenderId: '1234567890',
    androidAppId: '1:1234567890:android:abc',
    androidApiKey: 'android-key',
    iosAppId: '',
    iosApiKey: '',
    iosBundleId: '',
  );

  test('a build without the values has no options', () {
    const FirebasePushConfig empty = FirebasePushConfig(
      projectId: '',
      messagingSenderId: '',
      androidAppId: '',
      androidApiKey: '',
      iosAppId: '',
      iosApiKey: '',
      iosBundleId: '',
    );

    expect(empty.optionsFor(TargetPlatform.android, web: false), isNull);
    expect(empty.optionsFor(TargetPlatform.iOS, web: false), isNull);
  });

  test('android options come from the shared and the android values', () {
    final options = complete.optionsFor(TargetPlatform.android, web: false);

    expect(options, isNotNull);
    expect(options!.projectId, 'bb-project');
    expect(options.messagingSenderId, '1234567890');
    expect(options.appId, '1:1234567890:android:abc');
    expect(options.apiKey, 'android-key');
  });

  test('the web never has options', () {
    expect(complete.optionsFor(TargetPlatform.android, web: true), isNull);
  });

  test('ios without its own values has none', () {
    expect(androidOnly.optionsFor(TargetPlatform.iOS, web: false), isNull);
    expect(
      complete.optionsFor(TargetPlatform.iOS, web: false)?.iosBundleId,
      'uz.barakabozor.app',
    );
  });

  test('one missing android value means no options', () {
    const FirebasePushConfig noKey = FirebasePushConfig(
      projectId: 'bb-project',
      messagingSenderId: '1234567890',
      androidAppId: '1:1234567890:android:abc',
      androidApiKey: '',
      iosAppId: '',
      iosApiKey: '',
      iosBundleId: '',
    );

    expect(noKey.optionsFor(TargetPlatform.android, web: false), isNull);
  });
}
