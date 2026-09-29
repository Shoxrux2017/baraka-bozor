import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/idempotency_key.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which failures leave a keyed request's outcome unknown, so its retry must
/// send the same request under the same key (`docs/09` section 48).
void main() {
  test(
    'no answer, a server error or the key still running leave it unknown',
    () {
      for (final ApiFailure failure in <ApiFailure>[
        const NetworkFailure(),
        const UnexpectedFailure(),
        const MalformedResponseFailure(),
        const ApiRefusal(ApiError(status: 500, code: 'server_error')),
        const ApiRefusal(ApiError(status: 503, code: 'service_unavailable')),
        const ApiRefusal(
          ApiError(status: 409, code: 'idempotency_in_progress'),
        ),
      ]) {
        expect(leavesOutcomeUnknown(failure), isTrue, reason: '$failure');
      }
    },
  );

  test('a refusal, or no failure, is a sure answer', () {
    for (final ApiFailure? failure in <ApiFailure?>[
      null,
      const ApiRefusal(ApiError(status: 409, code: 'item_already_resolved')),
      const ApiRefusal(ApiError(status: 404, code: 'resource_not_found')),
      const ApiRefusal(ApiError(status: 422, code: 'validation_failed')),
      const ApiRefusal(ApiError(status: 499, code: 'unknown')),
    ]) {
      expect(leavesOutcomeUnknown(failure), isFalse, reason: '$failure');
    }
  });
}
