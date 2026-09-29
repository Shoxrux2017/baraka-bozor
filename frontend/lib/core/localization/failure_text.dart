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
    UnexpectedFailure() => l10n.errorUnknown,
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
    'business_conflict' => l10n.errorBusinessConflict,
    'payload_too_large' => l10n.errorPayloadTooLarge,
    'self_block_not_allowed' => l10n.errorSelfBlockNotAllowed,
    'last_active_admin_required' => l10n.errorLastActiveAdminRequired,
    'self_reset_not_allowed' => l10n.errorSelfResetNotAllowed,
    'phone_already_active' => l10n.errorPhoneAlreadyActive,
    'checkout_configuration_incomplete' => l10n.errorConfigurationIncomplete,
    'order_state_conflict' => l10n.errorOrderStateConflict,
    'cart_item_already_exists' => l10n.errorCartItemAlreadyExists,
    'cart_full' => l10n.errorCartFull,
    'product_unavailable' => l10n.errorProductUnavailable,
    'customer_profile_incomplete' => l10n.errorProfileIncomplete,
    'address_incomplete' => l10n.errorAddressIncomplete,
    'address_outside_service_area' => l10n.addressOutsideAreaPlain,
    'cart_empty' => l10n.errorCartEmpty,
    'minimum_order_not_reached' => l10n.errorMinimumOrderPlain,
    'payment_method_unavailable' => l10n.errorPaymentMethodUnavailable,
    'checkout_snapshot_stale' => l10n.errorCheckoutStale,
    'order_editing_locked' => l10n.errorOrderEditingLocked,
    'order_cancellation_not_allowed' => l10n.errorOrderCancellationNotAllowed,
    'idempotency_in_progress' => l10n.errorInProgress,
    'staff_not_active' => l10n.errorStaffNotActive,
    'approval_not_expired' => l10n.errorApprovalNotExpired,
    'approval_already_resolved' => l10n.errorApprovalAlreadyResolved,
    'cancellation_request_already_decided' => l10n.errorRequestAlreadyDecided,
    'cancellation_already_pending' => l10n.errorCancellationAlreadyPending,
    'price_correction_locked' => l10n.errorPriceCorrectionLocked,
    'price_correction_not_applicable' => l10n.errorPriceCorrectionNotApplicable,
    'price_correction_above_ceiling' => l10n.errorPriceAboveCeilingPlain,
    'shopping_not_active' => l10n.errorShoppingNotActive,
    'item_already_resolved' => l10n.errorItemAlreadyResolved,
    'customer_approval_required' => l10n.errorCustomerApprovalRequired,
    'approval_not_needed' => l10n.errorApprovalNotNeeded,
    'substitution_not_allowed' => l10n.errorSubstitutionNotAllowed,
    'shopping_incomplete' => l10n.errorShoppingIncomplete,
    'approval_expired' => l10n.errorApprovalExpired,
    'delivery_state_conflict' => l10n.errorDeliveryStateConflict,
    'cash_amount_mismatch' => l10n.errorCashAmountMismatch,
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
