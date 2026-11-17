import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the Telegram app (DL-139).
abstract interface class TelegramLauncher {
  /// Whether Telegram opened.
  Future<bool> open();
}

/// Opens `tg://` through `url_launcher`.
class UrlTelegramLauncher implements TelegramLauncher {
  /// Creates the launcher; [launch] defaults to `launchUrl`.
  UrlTelegramLauncher({
    Future<bool> Function(Uri uri, {LaunchMode mode})? launch,
  }) : _launch = launch ?? launchUrl;

  final Future<bool> Function(Uri uri, {LaunchMode mode}) _launch;

  @override
  Future<bool> open() async {
    try {
      return await _launch(
        Uri.parse('tg://'),
        mode: LaunchMode.externalApplication,
      );
    } on PlatformException {
      return false;
    }
  }
}

/// The Telegram launcher.
final Provider<TelegramLauncher> telegramLauncherProvider =
    Provider<TelegramLauncher>((ref) => UrlTelegramLauncher());
