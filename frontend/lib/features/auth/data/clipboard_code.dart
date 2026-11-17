import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A sign-in code that may sit in the clipboard (DL-139).
abstract interface class ClipboardCode {
  /// Whether the clipboard holds text, asked without reading it, so the
  /// system's paste notice stays quiet.
  Future<bool> mayHoldCode();

  /// The first six-digit run of the clipboard's text, or null.
  Future<String?> readCode();
}

/// The system clipboard.
class SystemClipboardCode implements ClipboardCode {
  /// Creates the clipboard reader.
  const SystemClipboardCode();

  static final RegExp _code = RegExp(r'(?<!\d)\d{6}(?!\d)');

  @override
  Future<bool> mayHoldCode() => Clipboard.hasStrings();

  @override
  Future<String?> readCode() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return _code.firstMatch(data?.text ?? '')?.group(0);
  }
}

/// The clipboard reader.
final Provider<ClipboardCode> clipboardCodeProvider = Provider<ClipboardCode>(
  (ref) => const SystemClipboardCode(),
);
