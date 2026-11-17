import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/report_unexpected_error.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/session/session_controller.dart';
import '../domain/app_user.dart';

/// The three calls a code login makes; the state names the one running and
/// the one that failed so a retry repeats it (`DL-139`).
enum CodeLoginAction { request, resend, verify }

/// How long the "code accepted" moment shows before the session opens
/// (`DL-139`); it holds with reduced motion too.
const Duration codeAcceptedHold = Duration(milliseconds: 700);

/// Where a code login stands: which phone the code went to, what the server
/// said about it, how long until another may be sent, and which call, if any,
/// is in flight.
final class CodeLoginState {
  const CodeLoginState({
    this.phone,
    this.requested,
    this.resendInSeconds = 0,
    this.lockedSeconds = 0,
    this.lockOver = false,
    this.running,
    this.failure,
    this.failedAction,
    this.wrongCode = false,
    this.attemptsLeft,
    this.misses = 0,
    this.accepted = false,
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

  /// The call in flight, if any.
  final CodeLoginAction? running;

  final ApiFailure? failure;

  /// The call [failure] came from, so a retry can repeat it.
  final CodeLoginAction? failedAction;

  /// The last code was refused as wrong (not a lock, not a failure).
  final bool wrongCode;

  /// Tries the server says are left after a wrong code; null when it did not
  /// say.
  final int? attemptsLeft;

  /// Wrong codes since the last code was sent.
  final int misses;

  /// The right code was answered and the session is about to open.
  final bool accepted;

  bool get busy => running != null;

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
    CodeLoginAction? running,
    bool clearRunning = false,
    ApiFailure? failure,
    CodeLoginAction? failedAction,
    bool clearFailure = false,
    bool? wrongCode,
    int? attemptsLeft,
    bool clearAttemptsLeft = false,
    int? misses,
    bool? accepted,
  }) {
    return CodeLoginState(
      phone: phone ?? this.phone,
      requested: requested ?? this.requested,
      resendInSeconds: resendInSeconds ?? this.resendInSeconds,
      lockedSeconds: lockedSeconds ?? this.lockedSeconds,
      lockOver: lockOver ?? this.lockOver,
      running: clearRunning ? null : (running ?? this.running),
      failure: clearFailure ? null : (failure ?? this.failure),
      failedAction: clearFailure ? null : (failedAction ?? this.failedAction),
      wrongCode: wrongCode ?? this.wrongCode,
      attemptsLeft: clearAttemptsLeft
          ? null
          : (attemptsLeft ?? this.attemptsLeft),
      misses: misses ?? this.misses,
      accepted: accepted ?? this.accepted,
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

  /// The code the last verify sent, for [retry].
  String? _lastCode;

  @override
  CodeLoginState build() {
    ref.onDispose(() => _countdown?.cancel());
    return const CodeLoginState();
  }

  SessionController get _session =>
      ref.read(sessionControllerProvider.notifier);

  /// Customer login: asks for a code for [phone].
  Future<bool> requestCode(String phone) => _request(
    phone: phone,
    send: () => _session.requestCustomerCode(phone),
    action: CodeLoginAction.request,
  );

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
      action: CodeLoginAction.resend,
    );
  }

  /// Verifies [code]; on success the "accepted" moment shows for
  /// [codeAcceptedHold], then the session changes and the router moves on, so
  /// this flow is over and its state is cleared.
  Future<bool> verify(String code) async {
    final String? phone = state.phone;
    if (phone == null || state.busy || state.accepted || !state.entryOpen) {
      return false;
    }
    final int generation = ++_generation;
    _lastCode = code;
    state = state.copyWith(
      running: CodeLoginAction.verify,
      clearFailure: true,
      wrongCode: false,
      clearAttemptsLeft: true,
    );

    try {
      await _session.verifyCustomerCode(
        phone: phone,
        code: code,
        beforeOpen: () async {
          if (!_current(generation)) {
            return;
          }
          state = state.copyWith(accepted: true, clearRunning: true);
          await Future<void>.delayed(codeAcceptedHold);
        },
      );
    } on ApiFailure catch (failure) {
      _fail(generation, failure, CodeLoginAction.verify);
      return false;
    } catch (error, stackTrace) {
      _fail(generation, const UnexpectedFailure(), CodeLoginAction.verify);
      reportUnexpectedError(error, stackTrace, 'while verifying a login code');
      return false;
    }

    if (!_current(generation)) {
      return false;
    }
    _clear();
    return true;
  }

  /// Repeats the call that failed: the phone, the resend or the last code.
  Future<bool> retry() {
    final CodeLoginAction? action = state.failedAction;
    final String? phone = state.phone;
    if (action == null || phone == null || state.busy || state.accepted) {
      return Future<bool>.value(false);
    }
    final String? code = _lastCode;
    return switch (action) {
      CodeLoginAction.request => requestCode(phone),
      CodeLoginAction.resend => resend(),
      CodeLoginAction.verify =>
        code == null ? Future<bool>.value(false) : verify(code),
    };
  }

  /// Dismisses a shown failure without repeating anything.
  void clearFailure() {
    state = state.copyWith(clearFailure: true);
  }

  /// Back to the phone entry, with the phone kept for editing. A running lock
  /// is kept with its timer: the phone screen binds it to the number it was
  /// taken for, so any other number stays free. Refused while the accepted
  /// moment shows: the session is about to open.
  void changePhone() {
    if (state.accepted) {
      return;
    }
    _generation++;
    _lastCode = null;
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
    required CodeLoginAction action,
  }) async {
    if (state.busy || state.accepted) {
      return false;
    }

    final int generation = ++_generation;
    if (action == CodeLoginAction.resend) {
      state = state.copyWith(
        running: action,
        clearFailure: true,
        wrongCode: false,
        clearAttemptsLeft: true,
      );
    } else {
      _countdown?.cancel();
      _lastCode = null;
      state = CodeLoginState(phone: phone, running: action);
    }

    try {
      final RequestedCode requested = await send();
      if (!_current(generation)) {
        return false;
      }
      state = state.copyWith(
        requested: requested,
        lockOver: false,
        clearRunning: true,
        misses: 0,
      );
      _startCountdown(requested.resendAvailableInSeconds);
      return true;
    } on ApiFailure catch (failure) {
      _fail(generation, failure, action);
      return false;
    } catch (error, stackTrace) {
      _fail(generation, const UnexpectedFailure(), action);
      reportUnexpectedError(error, stackTrace, 'while requesting a login code');
      return false;
    }
  }

  /// Whether a completion still belongs to the current request of a live
  /// controller.
  bool _current(int generation) => generation == _generation && ref.mounted;

  void _fail(int generation, ApiFailure failure, CodeLoginAction action) {
    if (!_current(generation)) {
      return;
    }
    if (failure is ApiRefusal && failure.code == 'code_locked') {
      // The lock has its own sentence; it is not left as a failure for the
      // screens to print a second time.
      final int? retryAfter = failure.retryAfterSeconds;
      state = state.copyWith(
        clearRunning: true,
        accepted: false,
        lockedSeconds: retryAfter == null || retryAfter <= 0
            ? _defaultLockSeconds
            : retryAfter,
        lockOver: false,
        clearFailure: true,
        wrongCode: false,
        clearAttemptsLeft: true,
      );
      _runCountdown();
      return;
    }
    if (failure is ApiRefusal && failure.code == 'code_invalid') {
      // A wrong code is an answer, not a failure: the boxes say so, with the
      // tries left when the server counted them (`DL-139`).
      final Object? left = failure.error.details['attempts_left'];
      state = state.copyWith(
        clearRunning: true,
        accepted: false,
        clearFailure: true,
        wrongCode: true,
        attemptsLeft: left is int ? left : null,
        clearAttemptsLeft: left is! int,
        misses: state.misses + 1,
      );
      return;
    }
    state = state.copyWith(
      clearRunning: true,
      accepted: false,
      failure: failure,
      failedAction: action,
    );
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
    _lastCode = null;
    state = const CodeLoginState();
  }
}

final NotifierProvider<CodeLoginController, CodeLoginState>
codeLoginControllerProvider =
    NotifierProvider<CodeLoginController, CodeLoginState>(
      CodeLoginController.new,
    );
