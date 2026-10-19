import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/report_unexpected_error.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/domain/app_user.dart';
import '../domain/account_deletion.dart';
import 'profile_controllers.dart';

/// How a deletion attempt ended.
enum DeletionOutcome { deleted, refused, unfinished }

/// Where the deletion of the account stands: the code that went to the
/// phone, how long until another may be sent, the lock after three wrong
/// codes, and whether a call is in flight.
final class AccountDeletionState {
  const AccountDeletionState({
    this.requested,
    this.resendInSeconds = 0,
    this.lockedSeconds = 0,
    this.lockOver = false,
    this.busy = false,
    this.failure,
    this.unfinished,
  });

  final RequestedCode? requested;

  /// Seconds until the server accepts another send; counts down to zero.
  final int resendInSeconds;

  /// Seconds the entry stays locked after three wrong codes.
  final int lockedSeconds;

  /// The lock has just run out: the old code is spent and a new one is due.
  final bool lockOver;

  final bool busy;

  final ApiFailure? failure;

  /// The order that stops the deletion, once the server named one.
  final UnfinishedOrder? unfinished;

  bool get locked => lockedSeconds > 0;

  /// Typing and confirming are off from the lock until a new code arrives.
  bool get entryOpen => requested != null && !locked && !lockOver;

  bool get canResend =>
      requested != null && resendInSeconds == 0 && !locked && !busy;

  AccountDeletionState copyWith({
    RequestedCode? requested,
    int? resendInSeconds,
    int? lockedSeconds,
    bool? lockOver,
    bool? busy,
    ApiFailure? failure,
    bool clearFailure = false,
    UnfinishedOrder? unfinished,
  }) {
    return AccountDeletionState(
      requested: requested ?? this.requested,
      resendInSeconds: resendInSeconds ?? this.resendInSeconds,
      lockedSeconds: lockedSeconds ?? this.lockedSeconds,
      lockOver: lockOver ?? this.lockOver,
      busy: busy ?? this.busy,
      failure: clearFailure ? null : (failure ?? this.failure),
      unfinished: unfinished ?? this.unfinished,
    );
  }
}

/// The deletion of the Customer's own account (`DL-96` item 5): the code is
/// requested first, so an unfinished order is reported before any code is
/// sent, and the code screen keeps the sign-in code's rules — resend, the
/// lock after three wrong codes, the entry closed until a new code.
///
/// Not auto-disposed: the sheet requests the code and the screen uses the
/// answer. One call runs at a time; a call while another runs returns at
/// once.
class AccountDeletionController extends Notifier<AccountDeletionState> {
  /// The lock when the server's answer carries no `Retry-After`.
  static const int _defaultLockSeconds = 60;

  int _generation = 0;
  Timer? _countdown;

  @override
  AccountDeletionState build() {
    ref.onDispose(() => _countdown?.cancel());
    return const AccountDeletionState();
  }

  AccountDeletionRepository get _repository =>
      ref.read(accountDeletionRepositoryProvider);

  /// Abandons the flow entirely.
  void reset() {
    _generation++;
    _countdown?.cancel();
    state = const AccountDeletionState();
  }

  /// Asks for a code. `true` when one was sent; a `409` leaves the order
  /// that stops the deletion in [AccountDeletionState.unfinished].
  Future<bool> requestCode() {
    if (state.busy) {
      return Future<bool>.value(false);
    }
    _countdown?.cancel();
    state = const AccountDeletionState(busy: true);
    return _send();
  }

  /// Another code. The code already on the way stays valid, so a refused
  /// resend keeps the entry and shows why.
  Future<void> resend() async {
    if (state.busy || state.requested == null) {
      return;
    }
    state = state.copyWith(busy: true, clearFailure: true);
    await _send();
  }

  /// Deletes the account with [code].
  Future<DeletionOutcome> delete(String code) async {
    if (state.busy || !state.entryOpen) {
      return DeletionOutcome.refused;
    }
    final int generation = ++_generation;
    state = state.copyWith(busy: true, clearFailure: true);

    try {
      await _repository.delete(code);
    } on ApiFailure catch (failure) {
      return _fail(generation, failure)
          ? DeletionOutcome.unfinished
          : DeletionOutcome.refused;
    } catch (error, stackTrace) {
      _fail(generation, const UnexpectedFailure());
      reportUnexpectedError(error, stackTrace, 'while deleting the account');
      return DeletionOutcome.refused;
    }

    if (!_current(generation)) {
      return DeletionOutcome.refused;
    }
    _countdown?.cancel();
    state = state.copyWith(busy: false);
    return DeletionOutcome.deleted;
  }

  Future<bool> _send() async {
    final int generation = ++_generation;
    try {
      final RequestedCode requested = await _repository.requestCode();
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
      reportUnexpectedError(
        error,
        stackTrace,
        'while requesting a deletion code',
      );
      return false;
    }
  }

  bool _current(int generation) => generation == _generation && ref.mounted;

  /// Records [failure]; `true` when it names an unfinished order.
  bool _fail(int generation, ApiFailure failure) {
    if (!_current(generation)) {
      return false;
    }
    final UnfinishedOrder? order = unfinishedOrderOf(failure);
    if (order != null) {
      state = state.copyWith(busy: false, unfinished: order);
      return true;
    }
    if (failure is ApiRefusal && failure.code == 'code_locked') {
      // The lock has its own sentence; it is not left as a failure for the
      // screen to print a second time.
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
      return false;
    }
    state = state.copyWith(busy: false, failure: failure);
    return false;
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
}

final NotifierProvider<AccountDeletionController, AccountDeletionState>
accountDeletionControllerProvider =
    NotifierProvider<AccountDeletionController, AccountDeletionState>(
      AccountDeletionController.new,
    );
