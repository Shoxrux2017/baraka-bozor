import 'dart:math';

import 'api_failure.dart';

/// A fresh `Idempotency-Key` (`docs/09` section 48): a random UUID of
/// version 4, from the platform's secure generator.
String newIdempotencyKey([Random? random]) {
  final Random source = random ?? Random.secure();
  final List<int> bytes = List<int>.generate(16, (_) => source.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final String hex = bytes
      .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Whether [failure] leaves it unknown what a keyed request did — no answer,
/// a server error, or the same key still running — so its retry must send
/// the same request under the same key (`docs/09` section 48).
bool leavesOutcomeUnknown(ApiFailure? failure) =>
    failure != null &&
    (failure is! ApiRefusal ||
        failure.status >= 500 ||
        failure.code == 'idempotency_in_progress');

/// A keyed request sent without a sure answer: its `Idempotency-Key` and
/// what was sent, which a retry sends again as it was (`docs/09` section
/// 48).
final class UnansweredRequest<T> {
  const UnansweredRequest(this.key, this.sent);

  final String key;
  final T sent;
}
