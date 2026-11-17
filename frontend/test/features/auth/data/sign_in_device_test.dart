import 'package:baraka_bozor/features/auth/data/clipboard_code.dart';
import 'package:baraka_bozor/features/auth/data/phone_number_hint.dart';
import 'package:baraka_bozor/features/auth/data/telegram_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

/// The sign-in device helpers (DL-139).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('nationalDigitsFromHint', () {
    test('takes the nine digits after 998, with or without a plus', () {
      expect(nationalDigitsFromHint('+998901234567'), '901234567');
      expect(nationalDigitsFromHint('998 90 123 45 67'), '901234567');
    });

    test('refuses a number outside Uzbekistan or without the prefix', () {
      expect(nationalDigitsFromHint('+79001234567'), isNull);
      expect(nationalDigitsFromHint('901234567'), isNull);
    });
  });

  group('SystemClipboardCode', () {
    final calls = <String>[];
    String? clipboardText;
    var hasStrings = true;

    setUp(() {
      calls.clear();
      hasStrings = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            calls.add(call.method);
            if (call.method == 'Clipboard.hasStrings') {
              return <String, dynamic>{'value': hasStrings};
            }
            if (call.method == 'Clipboard.getData') {
              return clipboardText == null
                  ? null
                  : <String, dynamic>{'text': clipboardText};
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('readCode finds the six digits in a message', () async {
      clipboardText = 'Код для входа: 481527. Никому не сообщайте.';
      expect(await const SystemClipboardCode().readCode(), '481527');
    });

    test('readCode ignores runs that are not exactly six digits', () async {
      const code = SystemClipboardCode();
      clipboardText = '1234567';
      expect(await code.readCode(), isNull);
      clipboardText = '12 345 6';
      expect(await code.readCode(), isNull);
      clipboardText = '';
      expect(await code.readCode(), isNull);
      clipboardText = null;
      expect(await code.readCode(), isNull);
    });

    test('mayHoldCode asks hasStrings and never reads the data', () async {
      expect(await const SystemClipboardCode().mayHoldCode(), isTrue);
      hasStrings = false;
      expect(await const SystemClipboardCode().mayHoldCode(), isFalse);
      expect(calls, ['Clipboard.hasStrings', 'Clipboard.hasStrings']);
    });
  });

  group('UrlTelegramLauncher', () {
    test('opens tg:// in an external application', () async {
      Uri? opened;
      LaunchMode? usedMode;
      final launcher = UrlTelegramLauncher(
        launch: (uri, {mode = LaunchMode.platformDefault}) async {
          opened = uri;
          usedMode = mode;
          return true;
        },
      );
      expect(await launcher.open(), isTrue);
      expect(opened, Uri.parse('tg://'));
      expect(usedMode, LaunchMode.externalApplication);
    });

    test('answers false when the launch says false or throws', () async {
      expect(
        await UrlTelegramLauncher(
          launch: (_, {mode = LaunchMode.platformDefault}) async => false,
        ).open(),
        isFalse,
      );
      expect(
        await UrlTelegramLauncher(
          launch: (_, {mode = LaunchMode.platformDefault}) async =>
              throw PlatformException(code: 'nope'),
        ).open(),
        isFalse,
      );
    });
  });
}
