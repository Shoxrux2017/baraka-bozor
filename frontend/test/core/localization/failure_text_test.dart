import 'dart:ui' show Locale;

import 'package:baraka_bozor/core/localization/failure_text.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final AppLocalizations uz = lookupAppLocalizations(const Locale('uz'));
  final AppLocalizations ru = lookupAppLocalizations(const Locale('ru'));

  ApiRefusal refusal(int status, String code) =>
      ApiRefusal(ApiError(status: status, code: code));

  test('every auth and common code a screen can meet has its own text', () {
    final Map<String, String Function(AppLocalizations)> texts =
        <String, String Function(AppLocalizations)>{
          'authentication_required': (AppLocalizations l) =>
              l.errorAuthenticationRequired,
          'account_blocked': (AppLocalizations l) => l.errorAccountBlocked,
          'password_change_required': (AppLocalizations l) =>
              l.errorPasswordChangeRequired,
          'invalid_credentials': (AppLocalizations l) =>
              l.errorInvalidCredentials,
          'code_invalid': (AppLocalizations l) => l.errorCodeInvalid,
          'code_expired': (AppLocalizations l) => l.errorCodeExpired,
          'code_attempts_exhausted': (AppLocalizations l) =>
              l.errorCodeAttemptsExhausted,
          'code_resend_too_soon': (AppLocalizations l) =>
              l.errorCodeResendTooSoon,
          'rate_limited': (AppLocalizations l) => l.errorRateLimited,
          'validation_failed': (AppLocalizations l) => l.errorValidationFailed,
          'forbidden': (AppLocalizations l) => l.errorForbidden,
          'resource_not_found': (AppLocalizations l) => l.errorNotFound,
          'provider_unavailable': (AppLocalizations l) =>
              l.errorProviderUnavailable,
          'payment_provider_unavailable': (AppLocalizations l) =>
              l.errorProviderUnavailable,
          'service_unavailable': (AppLocalizations l) =>
              l.errorServiceUnavailable,
          'server_error': (AppLocalizations l) => l.errorServerError,
        };

    for (final MapEntry<String, String Function(AppLocalizations)> entry
        in texts.entries) {
      // The status is deliberately one the code never comes with, so the
      // text can only have come from the code itself.
      expect(
        failureText(uz, refusal(418, entry.key)),
        entry.value(uz),
        reason: '${entry.key} in Uzbek',
      );
      expect(
        failureText(ru, refusal(418, entry.key)),
        entry.value(ru),
        reason: '${entry.key} in Russian',
      );
      expect(
        entry.value(uz),
        isNot(entry.value(ru)),
        reason: '${entry.key} must be translated, not copied',
      );
    }
  });

  test('a code without a text of its own falls back on its status', () {
    expect(failureText(uz, refusal(404, 'order_not_found')), uz.errorNotFound);
    expect(
      failureText(uz, refusal(422, 'minimum_order_not_reached')),
      uz.errorValidationFailed,
    );
    expect(failureText(uz, refusal(429, 'too_many')), uz.errorRateLimited);
    expect(
      failureText(uz, refusal(401, 'token_gone')),
      uz.errorAuthenticationRequired,
    );
    expect(failureText(uz, refusal(403, 'nope')), uz.errorForbidden);
    expect(failureText(uz, refusal(502, 'upstream')), uz.errorServerError);
  });

  test('a status without a text of its own gets the generic text', () {
    expect(
      failureText(uz, refusal(409, 'order_editing_locked')),
      uz.errorUnknown,
    );
    expect(
      failureText(ru, refusal(409, 'order_editing_locked')),
      ru.errorUnknown,
    );
  });

  test('a conflict and a body too large have texts of their own', () {
    expect(
      failureText(uz, refusal(409, 'business_conflict')),
      uz.errorBusinessConflict,
    );
    expect(
      failureText(ru, refusal(413, 'payload_too_large')),
      ru.errorPayloadTooLarge,
    );
  });

  test('client-side failures have texts too, and a cancellation has none', () {
    expect(failureText(uz, const NetworkFailure()), uz.errorNetwork);
    expect(
      failureText(uz, const MalformedResponseFailure(status: 502)),
      uz.errorServerError,
    );
    expect(failureText(uz, const CancelledFailure()), isNull);
  });
}
