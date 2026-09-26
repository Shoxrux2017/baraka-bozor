import '../network/api_failure.dart';
import 'generated/app_localizations.dart';

/// The text a screen shows for a failure, in the interface language.
///
/// `docs/07-architecture.md` section 27: the client owns every user-facing
/// string and renders it from the machine `code`, never from the API
/// `message`. A code without a text of its own falls back on its HTTP status,
/// and a status without one on the generic text, so nothing is ever shown
/// raw. `null` means there is nothing to show at all — a request the client
/// itself cancelled.
String? failureText(AppLocalizations l10n, ApiFailure failure) {
  return switch (failure) {
    CancelledFailure() => null,
    NetworkFailure() => l10n.errorNetwork,
    MalformedResponseFailure() => l10n.errorServerError,
    ApiRefusal(:final String code, :final int status) => _refusalText(
      l10n,
      code,
      status,
    ),
  };
}

String _refusalText(AppLocalizations l10n, String code, int status) {
  return switch (code) {
    'authentication_required' => l10n.errorAuthenticationRequired,
    'account_blocked' => l10n.errorAccountBlocked,
    'password_change_required' => l10n.errorPasswordChangeRequired,
    'invalid_credentials' => l10n.errorInvalidCredentials,
    'code_invalid' => l10n.errorCodeInvalid,
    'code_expired' => l10n.errorCodeExpired,
    'code_attempts_exhausted' => l10n.errorCodeAttemptsExhausted,
    'code_resend_too_soon' => l10n.errorCodeResendTooSoon,
    'rate_limited' => l10n.errorRateLimited,
    'validation_failed' => l10n.errorValidationFailed,
    'forbidden' => l10n.errorForbidden,
    'resource_not_found' => l10n.errorNotFound,
    'provider_unavailable' ||
    'payment_provider_unavailable' => l10n.errorProviderUnavailable,
    'service_unavailable' => l10n.errorServiceUnavailable,
    'server_error' => l10n.errorServerError,
    _ => _statusText(l10n, status),
  };
}

String _statusText(AppLocalizations l10n, int status) {
  return switch (status) {
    401 => l10n.errorAuthenticationRequired,
    403 => l10n.errorForbidden,
    404 => l10n.errorNotFound,
    422 => l10n.errorValidationFailed,
    429 => l10n.errorRateLimited,
    >= 500 => l10n.errorServerError,
    _ => l10n.errorUnknown,
  };
}
