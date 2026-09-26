import 'package:dio/dio.dart';

import '../storage/token_store.dart';
import 'api_failure.dart';

/// Attaches the bearer token of the session a request belongs to, and drops
/// that session alone when the server refuses the token.
///
/// A request belongs to the active mode unless the data source says
/// otherwise through [RequestSlot]: a public endpoint carries no session, and
/// a cross-mode call names its slot. The slot is decided once, when the
/// request is sent, and stamped on the request, so a mode switch while the
/// request is in flight cannot make its answer land on the other session
/// (`docs/07-architecture.md` section 8). On `401 authentication_required` or
/// `401 account_blocked` the refused session is dropped only when the token
/// that was sent is still the one stored: an answer to a token that has
/// since been replaced by a new login says nothing about the new session.
///
/// The interceptor is endpoint-blind. Which slot a request acts for is the
/// data source's responsibility; this only sends what it is told.
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
    RequestSlot.stamp(options, slot);

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
    final SessionSlot? slot = RequestSlot.stamped(err.requestOptions);
    final ApiError? error = ApiError.fromResponse(err.response);

    if (slot != null &&
        error != null &&
        error.status == 401 &&
        revokingCodes.contains(error.code) &&
        await _sentTokenIsStillStored(err.requestOptions, slot)) {
      await _onTokenRefused(slot);
    }

    handler.next(err);
  }

  Future<bool> _sentTokenIsStillStored(
    RequestOptions options,
    SessionSlot slot,
  ) async {
    final Object? header = options.headers['Authorization'];
    if (header is! String || !header.startsWith('Bearer ')) {
      return false;
    }
    final String sent = header.substring('Bearer '.length);
    final String? stored = await _tokenStore.read(slot);
    return stored != null && stored == sent;
  }
}

/// Which session a request is made on behalf of.
///
/// A data source sets it with [of]; the interceptor resolves it once at send
/// time and stamps the result, which is what the error path reads.
abstract final class RequestSlot {
  static const String _key = 'bb_session_slot';
  static const String _explicitKey = 'bb_session_slot_explicit';
  static const String _stampKey = 'bb_session_slot_sent';

  /// Options for a request made on behalf of [slot], or of no session when
  /// [slot] is `null`.
  static Options of(SessionSlot? slot) =>
      Options(extra: <String, Object?>{_key: slot, _explicitKey: true});

  /// The slot a request should be sent for: the explicit one when the data
  /// source named it, otherwise the active mode right now.
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

  /// Records the slot the request was actually sent for.
  static void stamp(RequestOptions options, SessionSlot? slot) {
    options.extra[_stampKey] = slot;
  }

  /// The slot the request was sent for, or `null` for no session or a
  /// request that never passed through the interceptor.
  static SessionSlot? stamped(RequestOptions options) {
    final Object? slot = options.extra[_stampKey];
    return slot is SessionSlot ? slot : null;
  }
}
