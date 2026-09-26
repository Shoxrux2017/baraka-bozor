import 'package:dio/dio.dart';

import '../storage/token_store.dart';
import 'api_failure.dart';

/// Attaches the bearer token of the session a request belongs to, and drops
/// that session alone when the server refuses the token.
///
/// A request belongs to the active mode unless it says otherwise through
/// [RequestSlot]: verifying a customer code from inside the staff interface
/// is a request with no session, and a request queued before a mode switch
/// still carries the mode that issued it (`docs/07-architecture.md`
/// section 8). On `401 authentication_required` or `401 account_blocked`
/// only the refused slot is cleared; the other session, if any, continues.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStore, this._activeSlot, this._onTokenRefused);

  final TokenStore _tokenStore;
  final SessionSlot? Function() _activeSlot;
  final Future<void> Function(SessionSlot slot) _onTokenRefused;

  /// The codes after which the token is dead and the client must sign that
  /// session out, per `docs/09-api-contracts.md` section 8.
  static const Set<String> revokingCodes = <String>{
    'authentication_required',
    'account_blocked',
  };

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final SessionSlot? slot = RequestSlot.resolve(options, _activeSlot);

    if (slot != null) {
      final String? token = await _tokenStore.read(slot);
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final SessionSlot? slot = RequestSlot.resolve(
      err.requestOptions,
      _activeSlot,
    );
    final ApiError? error = ApiError.fromResponse(err.response);

    if (slot != null &&
        error != null &&
        error.status == 401 &&
        revokingCodes.contains(error.code)) {
      await _onTokenRefused(slot);
    }

    handler.next(err);
  }
}

/// Which session a request is made on behalf of.
///
/// Set by the data source; read by the interceptor. Absent means the active
/// mode; present with `null` means no session at all.
abstract final class RequestSlot {
  static const String _key = 'bb_session_slot';
  static const String _explicitKey = 'bb_session_slot_explicit';

  /// Options for a request made on behalf of [slot], or of no session when
  /// [slot] is `null`.
  static Options of(SessionSlot? slot) =>
      Options(extra: <String, Object?>{_key: slot, _explicitKey: true});

  static SessionSlot? resolve(
    RequestOptions options,
    SessionSlot? Function() activeSlot,
  ) {
    if (options.extra[_explicitKey] == true) {
      final Object? slot = options.extra[_key];
      return slot is SessionSlot ? slot : null;
    }
    return activeSlot();
  }
}
