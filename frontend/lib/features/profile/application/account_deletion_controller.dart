import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/report_unexpected_error.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/storage/token_store.dart';
import '../../addresses/application/delivery_address.dart';
import '../../auth/domain/app_user.dart';
import '../../catalog/application/recent_searches.dart';
import '../domain/account_deletion.dart';
import 'profile_controllers.dart';

/// The calls a deletion makes; the state names the one running and the one
/// that failed so a retry repeats it (`DL-140`).
enum DeletionAction { request, resend, delete, check }

/// How a deletion attempt ended.
enum DeletionOutcome { deleted, refused, unfinished }

/// Where the deletion of the account stands: the code that went to the
/// phone, how long until another may be sent, the lock after three wrong
/// codes, and which call, if any, is in flight.
final class AccountDeletionState {
  const AccountDeletionState({
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
    this.unfinished,
  });

  final RequestedCode? requested;

  /// Seconds until the server accepts another send; counts down to zero.
  final int resendInSeconds;

  /// Seconds the entry stays locked after three wrong codes.
  final int lockedSeconds;

  /// The lock has just run out: the old code is spent and a new one is due.
  final bool lockOver;

  /// The call in flight, if any.
  final DeletionAction? running;

  final ApiFailure? failure;

  /// The call [failure] came from, so a retry can repeat it.
  final DeletionAction? failedAction;

  /// The last code was refused as wrong (not a lock, not a failure).
  final bool wrongCode;

  /// Tries the server says are left after a wrong code.
  final int? attemptsLeft;

  /// Wrong codes since the last code was sent.
  final int misses;

  /// The order that stops the deletion, once the server named one.
  final UnfinishedOrder? unfinished;

  bool get busy => running != null;

  bool get locked => lockedSeconds > 0;

  /// Typing and confirming are off from the lock until a new code arrives.
  bool get entryOpen => requested != null && !locked && !lockOver;

  bool get canResend =>
      requested != null && resendInSeconds == 0 && !locked && !busy;

  /// The failure is a missing connection.
  bool get offline => failure is NetworkFailure;

  AccountDeletionState copyWith({
    RequestedCode? requested,
    int? resendInSeconds,
    int? lockedSeconds,
    bool? lockOver,
    DeletionAction? running,
    bool clearRunning = false,
    ApiFailure? failure,
    DeletionAction? failedAction,
    bool clearFailure = false,
    bool? wrongCode,
    int? attemptsLeft,
    bool clearAttemptsLeft = false,
    int? misses,
    UnfinishedOrder? unfinished,
  }) {
    return AccountDeletionState(
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
      unfinished: unfinished ?? this.unfinished,
    );
  }
}

/// The deletion of the Customer's own account (`DL-96` item 5, `DL-140`): the
/// code is requested first, so an unfinished order is reported before any
/// code is sent, and the code screen keeps the sign-in code's rules — resend,
/// the lock after three wrong codes, the entry closed until a new code.
///
/// Not auto-disposed: the sheet requests the code and the screen uses the
/// answer. Every call carries a generation number, so an answer to a flow
/// that was reset is dropped. One call runs at a time; a call while another
/// runs returns at once. A delete whose answer was lost asks the server
/// whether the account still exists before it says anything.
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

  /// Abandons the flow entirely; an answer still on its way is dropped.
  void reset() {
    _generation++;
    _countdown?.cancel();
    state = const AccountDeletionState();
  }

  /// Dismisses a shown failure without repeating anything.
  void clearFailure() {
    state = state.copyWith(clearFailure: true);
  }

  /// Asks for a code. `true` when one was sent; a `409` leaves the order
  /// that stops the deletion in [AccountDeletionState.unfinished].
  Future<bool> requestCode() {
    if (state.busy) {
      return Future<bool>.value(false);
    }
    _countdown?.cancel();
    state = const AccountDeletionState(running: DeletionAction.request);
    return _send(DeletionAction.request);
  }

  /// Another code. The code already on the way stays valid, so a refused
  /// resend keeps the entry and shows why.
  Future<bool> resend() {
    if (state.busy || state.requested == null) {
      return Future<bool>.value(false);
    }
    state = state.copyWith(
      running: DeletionAction.resend,
      clearFailure: true,
      wrongCode: false,
      clearAttemptsLeft: true,
    );
    return _send(DeletionAction.resend);
  }

  /// Deletes the account with [code]. A lost answer is checked against the
  /// server before it is reported; a `401 authentication_required` means the
  /// account is already gone.
  Future<DeletionOutcome> delete(String code) async {
    if (state.busy || !state.entryOpen) {
      return DeletionOutcome.refused;
    }
    final int generation = ++_generation;
    state = state.copyWith(
      running: DeletionAction.delete,
      clearFailure: true,
      wrongCode: false,
      clearAttemptsLeft: true,
    );

    try {
      await _repository.delete(code);
    } on ApiFailure catch (failure) {
      if (!_current(generation)) {
        return DeletionOutcome.refused;
      }
      if (_isGone(failure)) {
        return _deleted();
      }
      if (_mayHaveArrived(failure)) {
        return _check(generation);
      }
      return _fail(generation, failure, DeletionAction.delete)
          ? DeletionOutcome.unfinished
          : DeletionOutcome.refused;
    } catch (error, stackTrace) {
      _fail(generation, const UnexpectedFailure(), DeletionAction.delete);
      reportUnexpectedError(error, stackTrace, 'while deleting the account');
      return DeletionOutcome.refused;
    }

    if (!_current(generation)) {
      return DeletionOutcome.refused;
    }
    return _deleted();
  }

  /// Forgets what the device kept for [account] (none when the id is
  /// unknown) and drops the Customer session. The account is gone on the
  /// server, so a key that cannot be removed is reported and left: it is
  /// harmless, and the session is dropped either way.
  Future<void> forgetAccount(String? account) async {
    try {
      if (account != null) {
        final store = ref.read(preferenceStoreProvider);
        for (final String key in <String>[
          RecentSearches.preferenceKey(account),
          DeliveryAddressChoice.preferenceKey(account),
        ]) {
          try {
            await store.remove(key);
          } catch (error, stackTrace) {
            reportUnexpectedError(
              error,
              stackTrace,
              'while forgetting a key of the deleted account',
            );
          }
        }
      }
    } finally {
      await ref
          .read(sessionControllerProvider.notifier)
          .dropSession(SessionSlot.customer);
    }
  }

  /// The answer to the delete was lost: asks whether the account is still
  /// there. Gone means deleted; alive, or no answer, means the deletion did
  /// not happen as far as the Customer can tell.
  Future<DeletionOutcome> _check(int generation) async {
    state = state.copyWith(running: DeletionAction.check);
    try {
      final bool exists = await _repository.stillExists();
      if (!_current(generation)) {
        return DeletionOutcome.refused;
      }
      if (!exists) {
        return _deleted();
      }
    } on ApiFailure catch (failure) {
      if (!_current(generation)) {
        return DeletionOutcome.refused;
      }
      if (_isGone(failure)) {
        return _deleted();
      }
    } catch (error, stackTrace) {
      reportUnexpectedError(error, stackTrace, 'while checking the account');
      if (!_current(generation)) {
        return DeletionOutcome.refused;
      }
    }
    state = state.copyWith(
      clearRunning: true,
      failure: const NetworkFailure(),
      failedAction: DeletionAction.delete,
    );
    return DeletionOutcome.refused;
  }

  /// The delete's answer was lost, or only a gateway answered for the server
  /// (`502`–`504`, or a page that is not the API's): the erasure may have
  /// committed, so the account is asked about before anything is said.
  bool _mayHaveArrived(ApiFailure failure) {
    if (failure is NetworkFailure) {
      return failure.mayHaveArrived;
    }
    if (failure is ApiRefusal) {
      return failure.status >= 502 && failure.status <= 504;
    }
    if (failure is MalformedResponseFailure) {
      final int? status = failure.status;
      return status == null || status >= 500;
    }
    return false;
  }

  /// A `401 authentication_required` from the deletion's own calls: the
  /// token was revoked with the account.
  bool _isGone(ApiFailure failure) =>
      failure is ApiRefusal &&
      failure.status == 401 &&
      failure.code == 'authentication_required';

  DeletionOutcome _deleted() {
    _countdown?.cancel();
    state = state.copyWith(clearRunning: true);
    return DeletionOutcome.deleted;
  }

  Future<bool> _send(DeletionAction action) async {
    final int generation = ++_generation;
    try {
      final RequestedCode requested = await _repository.requestCode();
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
  bool _fail(int generation, ApiFailure failure, DeletionAction action) {
    if (!_current(generation)) {
      return false;
    }
    final UnfinishedOrder? order = unfinishedOrderOf(failure);
    if (order != null) {
      state = state.copyWith(clearRunning: true, unfinished: order);
      return true;
    }
    if (failure is ApiRefusal && failure.code == 'code_locked') {
      // The lock has its own sentence; it is not left as a failure for the
      // screen to print a second time.
      final int? retryAfter = failure.retryAfterSeconds;
      state = state.copyWith(
        clearRunning: true,
        lockedSeconds: retryAfter == null || retryAfter <= 0
            ? _defaultLockSeconds
            : retryAfter,
        lockOver: false,
        clearFailure: true,
        wrongCode: false,
        clearAttemptsLeft: true,
      );
      _runCountdown();
      return false;
    }
    if (failure is ApiRefusal && failure.code == 'code_invalid') {
      // A wrong code is an answer, not a failure: the boxes say so, with the
      // tries left when the server counted them.
      final Object? left = failure.error.details['attempts_left'];
      state = state.copyWith(
        clearRunning: true,
        clearFailure: true,
        wrongCode: true,
        attemptsLeft: left is int ? left : null,
        clearAttemptsLeft: left is! int,
        misses: state.misses + 1,
      );
      return false;
    }
    state = state.copyWith(
      clearRunning: true,
      failure: failure,
      failedAction: action,
    );
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
