import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/report_unexpected_error.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/session/session_controller.dart';
import '../domain/app_user.dart';

/// Where a code login stands: which phone the code went to, what the server
/// said about it, how long until another may be sent, and whether a request
/// is in flight.
final class CodeLoginState {
  const CodeLoginState({
    this.phone,
    this.requested,
    this.resendInSeconds = 0,
    this.lockedSeconds = 0,
    this.lockOver = false,
    this.busy = false,
    this.failure,
  });

  /// The E.164 phone the code was requested for.
  final String? phone;

  final RequestedCode? requested;

  /// Seconds until the server accepts another send; counts down to zero.
  final int resendInSeconds;

  /// Seconds the phone stays locked after three wrong codes; counts down to
  /// zero. While it runs nothing can be verified or requested.
  final int lockedSeconds;

  /// The lock has just run out: the old code is spent and a new one is due.
  final bool lockOver;

  final bool busy;

  final ApiFailure? failure;

  bool get hasCode => requested != null;

  bool get locked => lockedSeconds > 0;

  /// Entering a code and confirming are off from the lock until a new code
  /// arrives: after three wrong codes the current one is spent for good.
  bool get entryOpen => !locked && !lockOver;

  bool get canResend => hasCode && resendInSeconds == 0 && !locked && !busy;

  CodeLoginState copyWith({
    String? phone,
    RequestedCode? requested,
    int? resendInSeconds,
    int? lockedSeconds,
    bool? lockOver,
    bool? busy,
    ApiFailure? failure,
    bool clearFailure = false,
  }) {
    return CodeLoginState(
      phone: phone ?? this.phone,
      requested: requested ?? this.requested,
      resendInSeconds: resendInSeconds ?? this.resendInSeconds,
      lockedSeconds: lockedSeconds ?? this.lockedSeconds,
      lockOver: lockOver ?? this.lockOver,
      busy: busy ?? this.busy,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// The code login of `docs/04-user-flows.md` section 2, the one way into the
/// app for every role.
///
/// Every request carries a generation number; an answer to a request this
/// controller has since superseded — a changed phone, a reset — is discarded
/// (`docs/07-architecture.md` section 28). Only one request runs at a time.
/// A new request starts from a clean state, so nothing of an earlier flow —
/// another phone, the other mode — survives into it; a resend keeps the
/// code it repeats. Whatever a call throws, the screen is usable afterwards.
class CodeLoginController extends Notifier<CodeLoginState> {
  /// The lock when the server's answer carries no `Retry-After`.
  static const int _defaultLockSeconds = 60;

  int _generation = 0;
  Timer? _countdown;

  @override
  CodeLoginState build() {
    ref.onDispose(() => _countdown?.cancel());
    return const CodeLoginState();
  }

  SessionController get _session =>
      ref.read(sessionControllerProvider.notifier);

  /// Customer login: asks for a code for [phone].
  Future<bool> requestCode(String phone) =>
      _request(phone: phone, send: () => _session.requestCustomerCode(phone));

  /// Another code for the same phone. The code already on the way stays
  /// valid, so a refused resend keeps the entry screen and shows why.
  Future<bool> resend() {
    final String? phone = state.phone;
    if (phone == null || !state.hasCode) {
      return Future<bool>.value(false);
    }
    return _request(
      phone: phone,
      send: () => _session.requestCustomerCode(phone),
      resend: true,
    );
  }

  /// Verifies [code]; on success the session changes and the router moves
  /// on, so this flow is over and its state is cleared.
  Future<bool> verify(String code) async {
    final String? phone = state.phone;
    if (phone == null || state.busy || !state.entryOpen) {
      return false;
    }
    final int generation = ++_generation;
    state = state.copyWith(busy: true, clearFailure: true);

    try {
      await _session.verifyCustomerCode(phone: phone, code: code);
    } on ApiFailure catch (failure) {
      _fail(generation, failure);
      return false;
    } catch (error, stackTrace) {
      _fail(generation, const UnexpectedFailure());
      reportUnexpectedError(error, stackTrace, 'while verifying a login code');
      return false;
    }

    if (!_current(generation)) {
      return false;
    }
    _clear();
    return true;
  }

  /// Back to the phone entry, with the phone kept for editing. A running lock
  /// is kept with its timer: the phone screen binds it to the number it was
  /// taken for, so any other number stays free.
  void changePhone() {
    _generation++;
    state = CodeLoginState(
      phone: state.phone,
      lockedSeconds: state.lockedSeconds,
    );
    if (state.locked) {
      _runCountdown();
    } else {
      _countdown?.cancel();
    }
  }

  /// Abandons the flow entirely.
  void reset() {
    _generation++;
    _clear();
  }

  Future<bool> _request({
    required String phone,
    required Future<RequestedCode> Function() send,
    bool resend = false,
  }) async {
    if (state.busy) {
      return false;
    }

    final int generation = ++_generation;
    if (resend) {
      state = state.copyWith(busy: true, clearFailure: true);
    } else {
      _countdown?.cancel();
      state = CodeLoginState(phone: phone, busy: true);
    }

    try {
      final RequestedCode requested = await send();
      if (!_current(generation)) {
        return false;
      }
      state = state.copyWith(
        requested: requested,
        lockOver: false,
        busy: false,
      );
      _startCountdown(requested.resendAvailableInSeconds);
      return true;
    } on ApiFailure catch (failure) {
      _fail(generation, failure);
      return false;
    } catch (error, stackTrace) {
      _fail(generation, const UnexpectedFailure());
      reportUnexpectedError(error, stackTrace, 'while requesting a login code');
      return false;
    }
  }

  /// Whether a completion still belongs to the current request of a live
  /// controller.
  bool _current(int generation) => generation == _generation && ref.mounted;

  void _fail(int generation, ApiFailure failure) {
    if (!_current(generation)) {
      return;
    }
    if (failure is ApiRefusal && failure.code == 'code_locked') {
      // The lock has its own sentence; it is not left as a failure for the
      // screens to print a second time.
      final int? retryAfter = failure.retryAfterSeconds;
      state = state.copyWith(
        busy: false,
        lockedSeconds: retryAfter == null || retryAfter <= 0
            ? _defaultLockSeconds
            : retryAfter,
        lockOver: false,
        clearFailure: true,
      );
      _runCountdown();
      return;
    }
    state = state.copyWith(busy: false, failure: failure);
  }

  void _startCountdown(int seconds) {
    state = state.copyWith(resendInSeconds: seconds < 0 ? 0 : seconds);
    _runCountdown();
  }

  /// One timer counts the resend wait and the lock down together.
  void _runCountdown() {
    _countdown?.cancel();
    if (state.resendInSeconds <= 0 && state.lockedSeconds <= 0) {
      return;
    }
    _countdown = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      final int resend = state.resendInSeconds - 1;
      final int lock = state.lockedSeconds - 1;
      state = state.copyWith(
        resendInSeconds: resend < 0 ? 0 : resend,
        lockedSeconds: lock < 0 ? 0 : lock,
        lockOver: state.lockOver || (state.lockedSeconds > 0 && lock <= 0),
      );
      if (state.resendInSeconds == 0 && state.lockedSeconds == 0) {
        timer.cancel();
      }
    });
  }

  void _clear() {
    _countdown?.cancel();
    state = const CodeLoginState();
  }
}

final NotifierProvider<CodeLoginController, CodeLoginState>
codeLoginControllerProvider =
    NotifierProvider<CodeLoginController, CodeLoginState>(
      CodeLoginController.new,
    );
