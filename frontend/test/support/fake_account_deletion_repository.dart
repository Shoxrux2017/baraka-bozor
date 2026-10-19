import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/profile/domain/account_deletion.dart';

/// The Customer's account deletion in memory. Each failure list is consumed
/// one answer at a time; while [hold] is set, every call answers only once
/// it completes.
class FakeAccountDeletionRepository implements AccountDeletionRepository {
  RequestedCode answer = const RequestedCode(
    channel: 'telegram',
    expiresInSeconds: 300,
    resendAvailableInSeconds: 60,
  );

  final List<ApiFailure> requestFailures = <ApiFailure>[];
  final List<ApiFailure> deleteFailures = <ApiFailure>[];
  final List<String> deletes = <String>[];
  int requests = 0;
  Completer<void>? hold;

  @override
  Future<RequestedCode> requestCode() async {
    requests++;
    await hold?.future;
    if (requestFailures.isNotEmpty) {
      throw requestFailures.removeAt(0);
    }
    return answer;
  }

  @override
  Future<void> delete(String code) async {
    deletes.add(code);
    await hold?.future;
    if (deleteFailures.isNotEmpty) {
      throw deleteFailures.removeAt(0);
    }
  }
}

ApiRefusal unfinishedRefusal({String id = 'o-1', int number = 1021}) =>
    ApiRefusal(
      ApiError(
        status: 409,
        code: 'account_has_unfinished_orders',
        details: <String, Object?>{'order_id': id, 'order_number': number},
      ),
    );

ApiRefusal lockedRefusal({int? retryAfter}) => ApiRefusal(
  const ApiError(status: 429, code: 'code_locked'),
  retryAfterSeconds: retryAfter,
);

ApiRefusal wrongCodeRefusal() =>
    const ApiRefusal(ApiError(status: 422, code: 'code_invalid'));
