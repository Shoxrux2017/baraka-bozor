import 'package:baraka_bozor/features/auth/data/clipboard_code.dart';
import 'package:baraka_bozor/features/auth/data/phone_number_hint.dart';
import 'package:baraka_bozor/features/auth/data/telegram_launcher.dart';

/// A phone-number hint that answers [answer] and counts the asks (DL-139).
class FakePhoneNumberHint implements PhoneNumberHint {
  /// Creates the hint answering [answer] (nine digits, or null).
  FakePhoneNumberHint([this.answer]);

  /// What the person "picked".
  String? answer;

  /// How many times the hint was requested.
  int calls = 0;

  @override
  Future<String?> request() async {
    calls++;
    return answer;
  }
}

/// A clipboard that holds [code] when [holds], and counts both asks (DL-139).
class FakeClipboardCode implements ClipboardCode {
  /// Creates the clipboard.
  FakeClipboardCode({this.code, this.holds = true});

  /// The code read from the clipboard.
  String? code;

  /// What the silent text check answers.
  bool holds;

  /// How many times the silent check ran.
  int checks = 0;

  /// How many times the text was read.
  int reads = 0;

  @override
  Future<bool> mayHoldCode() async {
    checks++;
    return holds;
  }

  @override
  Future<String?> readCode() async {
    reads++;
    return code;
  }
}

/// A Telegram launcher that answers [opens] and counts the calls (DL-139).
class FakeTelegramLauncher implements TelegramLauncher {
  /// Creates the launcher answering [opens].
  FakeTelegramLauncher({this.opens = true});

  /// Whether Telegram "opened".
  bool opens;

  /// How many times it was asked to open.
  int calls = 0;

  @override
  Future<bool> open() async {
    calls++;
    return opens;
  }
}
