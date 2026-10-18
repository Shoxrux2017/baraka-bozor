/// Seconds as `m:ss`, the way the resend and lock countdowns read.
String formatCountdown(int seconds) {
  final int clamped = seconds < 0 ? 0 : seconds;
  return '${clamped ~/ 60}:${(clamped % 60).toString().padLeft(2, '0')}';
}
