import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../errors/report_unexpected_error.dart';
import '../localization/app_language.dart';
import '../network/api_failure.dart';
import '../platform/clock.dart';
import '../storage/token_store.dart';
import 'session_end_hook.dart';
import 'session_state.dart';

/// Owns the two sessions of `docs/07-architecture.md` section 8.
///
/// Bootstrap reads both slots and confirms each token with `/auth/me`. A
/// refused token is cleared alone; a server that cannot confirm one keeps
/// every token and reports [SessionUnreachable], so the interface never shows
/// a session as absent while its token is still stored. Every later change —
/// a login, a mode switch, a logout, a token the interceptor saw refused —
/// goes through here, so the interface always renders from one source of
/// truth. A result that arrives after the state it was computed from has
/// moved on is applied only to what still matches (`docs/07` section 28).
///
/// Dependencies come from the root providers, so a test overrides
/// `tokenStoreProvider` and `authRepositoryProvider` with fakes.
class SessionController extends AsyncNotifier<SessionState> {
  TokenStore get _tokenStore => ref.read(tokenStoreProvider);

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  /// The longest one check of the stored sessions may take (`DL-136` (10)).
  static const Duration checkCap = Duration(seconds: 8);

  /// How long a pressed check shows «Проверяем…» at the least, so a quick
  /// answer is still seen (`DL-136` (14)).
  static const Duration leastPressedCheck = Duration(milliseconds: 800);

  /// The check running now, if any; a second request joins it.
  Future<void>? _check;

  /// Completes [leastPressedCheck] after the press the running check is held
  /// for.
  Completer<void>? _pressedHold;

  final Set<Timer> _timers = <Timer>{};
  bool _disposed = false;

  @override
  Future<SessionState> build() {
    // A rebuilt provider keeps this object: its retries must not be dead.
    _disposed = false;
    _check = null;
    _pressedHold = null;
    ref.onDispose(() {
      _disposed = true;
      for (final Timer timer in _timers) {
        timer.cancel();
      }
      _timers.clear();
    });
    return _bootstrap();
  }

  Timer _timer(Duration after, void Function() action) {
    late final Timer timer;
    timer = Timer(after, () {
      _timers.remove(timer);
      action();
    });
    _timers.add(timer);
    return timer;
  }

  /// The slot requests are made on behalf of by default: the active mode's,
  /// or none while signed out.
  SessionSlot? get activeSlot => switch (state.value) {
    final SignedIn signedIn => signedIn.activeMode.slot,
    _ => null,
  };

  /// Confirms every stored token, all at once. [prefer] names the mode to
  /// open when it is among the confirmed ones; otherwise the staff mode opens
  /// first, because the person installed the app to work and Customer mode is
  /// entered deliberately. Past [checkCap] the check gives up as offline,
  /// keeping every token; an answer that comes later changes nothing except a
  /// `401`, which still clears its own slot (`DL-136` (10)).
  Future<SessionState> _bootstrap({SessionMode? prefer}) async {
    final TokenStore store = _tokenStore;
    final AuthRepository repository = _repository;
    final Map<SessionSlot, String?> tokens = <SessionSlot, String?>{
      for (final SessionSlot slot in SessionSlot.values)
        slot: await store.read(slot),
    };

    if (tokens.values.every((String? token) => token == null)) {
      return const SignedOut();
    }

    final Map<SessionSlot, Future<_Answer>> asked =
        <SessionSlot, Future<_Answer>>{
          for (final SessionSlot slot in SessionSlot.values)
            if (tokens[slot] != null)
              slot: _ask(slot, tokens[slot]!, store, repository),
        };

    final Completer<void> capped = Completer<void>();
    final Timer capTimer = _timer(checkCap, capped.complete);
    bool overdue = false;
    try {
      await Future.any(<Future<void>>[
        Future.wait(asked.values),
        capped.future.then((_) => overdue = true),
      ]);
    } finally {
      capTimer.cancel();
      _timers.remove(capTimer);
    }
    if (overdue) {
      unawaited(_applyLateAnswers(asked, prefer));
      return const SessionUnreachable();
    }
    return _assemble(asked, prefer);
  }

  /// A check that hit the cap keeps listening: when every slot has answered
  /// later, a `SignedIn` or `SignedOut` result opens the app if the state is
  /// still unreachable. A late failure changes nothing (`DL-136` (10)).
  Future<void> _applyLateAnswers(
    Map<SessionSlot, Future<_Answer>> asked,
    SessionMode? prefer,
  ) async {
    try {
      await Future.wait(asked.values);
      final SessionState result = await _assemble(asked, prefer);
      if (_disposed || result is SessionUnreachable) {
        return;
      }
      if (_unreachableShown() != null) {
        state = AsyncData<SessionState>(result);
      }
    } catch (error, stackTrace) {
      reportUnexpectedError(
        error,
        stackTrace,
        'while confirming the stored sessions late',
      );
    }
  }

  /// What the answers say, as one state.
  Future<SessionState> _assemble(
    Map<SessionSlot, Future<_Answer>> asked,
    SessionMode? prefer,
  ) async {
    final Map<SessionSlot, AppUser> confirmed = <SessionSlot, AppUser>{};
    ApiFailure? failure;
    for (final MapEntry<SessionSlot, Future<_Answer>> entry in asked.entries) {
      final _Answer answer = await entry.value;
      final AppUser? user = answer.user;
      if (user != null) {
        confirmed[entry.key] = user;
      }
      final ApiFailure? failed = answer.failure;
      if (failed != null && (failure == null || failed is NetworkFailure)) {
        failure = failed;
      }
    }
    if (failure != null) {
      return SessionUnreachable(
        cause: failure is NetworkFailure
            ? UnreachableCause.offline
            : UnreachableCause.server,
      );
    }

    if (confirmed.isEmpty) {
      return const SignedOut();
    }

    final AppUser? staffUser = confirmed[SessionSlot.staff];
    final AppUser? customerUser = confirmed[SessionSlot.customer];

    final SessionMode active =
        prefer != null && confirmed.containsKey(prefer.slot)
        ? prefer
        : (staffUser != null ? SessionMode.staff : SessionMode.customer);

    return SignedIn(
      activeMode: active,
      staffUser: staffUser,
      customerUser: customerUser,
    );
  }

  /// One `/auth/me` for [slot] made with [token]. A `401` clears the slot
  /// here, so it clears it even when the check has already given up, but only
  /// while the store still holds [token] (`DL-136` (10)).
  Future<_Answer> _ask(
    SessionSlot slot,
    String token,
    TokenStore store,
    AuthRepository repository,
  ) async {
    try {
      return _Answer(user: await repository.me(slot));
    } on ApiRefusal catch (refusal) {
      if (!refusal.isUnauthenticated) {
        return _Answer(failure: refusal);
      }
      // The interceptor has already cleared the slot; clearing again is
      // harmless and keeps this correct without it.
      if (await store.read(slot) == token) {
        await store.clear(slot);
      }
      return const _Answer();
    } on ApiFailure catch (failure) {
      return _Answer(failure: failure);
    }
  }

  /// Confirms the sessions again after an unreachable check (`DL-136` (10),
  /// (14)). A pressed retry marks the state `retrying` at once and shows its
  /// result no sooner than [leastPressedCheck] after the press; a [quiet] one
  /// changes nothing on screen until it finds something. One check runs at a
  /// time: a second call joins it, and a press joining a quiet check turns it
  /// into a pressed one. A check that throws is reported and leaves the retry
  /// offered, never a wait with no way out.
  Future<void> retry({bool quiet = false}) {
    final SessionUnreachable? current = _unreachableShown();
    if (current == null) {
      return Future<void>.value();
    }
    if (!quiet) {
      _press(current);
    }
    return _check ??= _runCheck();
  }

  /// The unreachable state shown, or a plain one when the start itself threw
  /// and nothing is loading (`DL-136` (10)); null in any other state.
  SessionUnreachable? _unreachableShown() {
    final SessionState? value = state.value;
    if (value is SessionUnreachable) {
      return value;
    }
    if (value == null && state.hasError && !state.isLoading) {
      return const SessionUnreachable();
    }
    return null;
  }

  void _press(SessionUnreachable current) {
    if (_pressedHold != null) {
      return;
    }
    final Completer<void> hold = Completer<void>();
    _pressedHold = hold;
    _timer(leastPressedCheck, hold.complete);
    state = AsyncData<SessionState>(
      SessionUnreachable(
        retrying: true,
        cause: current.cause,
        checkedAt: current.checkedAt,
      ),
    );
  }

  Future<void> _runCheck() async {
    SessionState? result;
    Object? error;
    StackTrace? stackTrace;
    try {
      result = await _bootstrap();
    } catch (thrown, trace) {
      error = thrown;
      stackTrace = trace;
    }
    await _pressedHold?.future;
    if (_disposed) {
      return;
    }

    final bool pressed = _pressedHold != null;
    _pressedHold = null;
    _check = null;

    if (error != null) {
      // Something other than the server failed — storage, a platform
      // channel.
      reportUnexpectedError(
        error,
        stackTrace!,
        'while confirming the stored sessions',
      );
    }
    final SessionUnreachable? shown = _unreachableShown();
    if (shown == null) {
      return;
    }
    if (result != null && result is! SessionUnreachable) {
      state = AsyncData<SessionState>(result);
      return;
    }
    final DateTime? checkedAt = pressed || shown.checkedAt != null
        ? ref.read(clockProvider)()
        : null;
    state = AsyncData<SessionState>(
      SessionUnreachable(
        cause: result is SessionUnreachable
            ? result.cause
            : UnreachableCause.offline,
        checkedAt: error != null ? shown.checkedAt : checkedAt,
      ),
    );
  }

  /// Customer login from a signed-out app.
  Future<RequestedCode> requestCustomerCode(String phone) =>
      _repository.requestCustomerCode(phone);

  /// Every sign-in starts as the Customer. A Shopper or Courier comes back
  /// with a pending staff step, which [completeStaffStep] finishes with the
  /// password. [beforeOpen] runs after the server's answer and before the
  /// token is written and the state changes (`DL-139`).
  Future<void> verifyCustomerCode({
    required String phone,
    required String code,
    Future<void> Function()? beforeOpen,
  }) async {
    final VerifiedLogin login = await _repository.verifyCustomerCode(
      phone: phone,
      code: code,
    );
    await beforeOpen?.call();
    await _afterLogin(
      SessionMode.customer,
      login.customer,
      staffStep: login.staffStep,
    );
  }

  /// Exchanges the pending step and the password for the staff session. A
  /// refused password keeps the step; a step the server calls expired or
  /// invalid is cleared and the person stays the Customer. An answer that
  /// arrives after the Customer session or its step moved on is discarded.
  Future<void> completeStaffStep(String password) async {
    final SignedIn? before = _signedIn();
    final StaffStep? step = before?.staffStep;
    final String? customerId = before?.customerUser?.id;
    if (step == null || customerId == null) {
      throw StateError('no pending staff step');
    }

    final IssuedSession session;
    try {
      session = await _repository.staffStep(
        token: step.token,
        password: password,
      );
    } on ApiRefusal catch (refusal) {
      // The server spends the step on a blocked account too.
      if (refusal.code == 'staff_step_expired' ||
          refusal.code == 'staff_step_invalid' ||
          refusal.code == 'account_blocked') {
        _clearStep(step);
      }
      rethrow;
    }

    final SignedIn? now = _signedIn();
    if (now == null ||
        !identical(now.staffStep, step) ||
        now.customerUser?.id != customerId) {
      return;
    }
    await _tokenStore.write(SessionSlot.staff, session.token);
    state = AsyncData<SessionState>(
      SignedIn(
        activeMode: SessionMode.staff,
        staffUser: session.user,
        customerUser: now.customerUser,
      ),
    );
  }

  /// Leaves the staff step: the person stays the Customer.
  void dismissStaffStep() {
    final SignedIn? current = _signedIn();
    if (current?.staffStep != null) {
      state = AsyncData<SessionState>(current!.withoutStaffStep());
    }
  }

  void _clearStep(StaffStep step) {
    final SignedIn? current = _signedIn();
    if (current != null && identical(current.staffStep, step)) {
      state = AsyncData<SessionState>(current.withoutStaffStep());
    }
  }

  /// Replaces the Customer's user with a fresher one from the server (a
  /// saved name, say), only while that same account is still signed in.
  void replaceCustomerUser(AppUser user) {
    _updateUser(SessionMode.customer, user.id, (AppUser _) => user);
  }

  SignedIn? _signedIn() => switch (state.value) {
    final SignedIn signedIn => signedIn,
    _ => null,
  };

  Future<void> staffLogin({
    required String phone,
    required String password,
  }) async {
    final IssuedSession session = await _repository.staffLogin(
      phone: phone,
      password: password,
    );
    await _afterLogin(SessionMode.staff, session);
  }

  /// Switches between the two confirmed sessions in one step; nothing is
  /// requested from the server.
  void switchMode(SessionMode mode) {
    final SessionState? current = state.value;
    if (current is SignedIn && current.userIn(mode) != null) {
      state = AsyncData<SessionState>(current.copyWith(activeMode: mode));
    }
  }

  /// The logout running for each slot: a second one joins it rather than
  /// overtaking its session-end hooks.
  final Map<SessionSlot, Future<void>> _loggingOut =
      <SessionSlot, Future<void>>{};

  /// Ends one session and leaves the other alone
  /// (`docs/02-user-roles.md` section 10). The session-end hooks run first,
  /// while the session still works; none of them can stop the logout, and
  /// a logout already running for the slot is joined, not repeated.
  Future<void> logout(SessionMode mode) =>
      _loggingOut[mode.slot] ??= _logout(mode).whenComplete(() {
        // A block body: `remove` answers the very future being completed,
        // which `whenComplete` would otherwise wait for.
        _loggingOut.remove(mode.slot);
      });

  Future<void> _logout(SessionMode mode) async {
    final SessionEndHooks hooks = ref.read(sessionEndHooksProvider);
    for (final SessionEndHook hook in hooks.all) {
      try {
        // Past the limit the hook finishes on its own, or not at all; a
        // timeout the hook throws itself is reported like any failure.
        await hook
            .beforeLogout(mode.slot)
            .timeout(hooks.limit, onTimeout: () {});
      } catch (error, stackTrace) {
        reportUnexpectedError(error, stackTrace, 'while ending a session');
      }
    }

    try {
      await _repository.logout(mode.slot);
    } on ApiFailure {
      // The token is dropped either way; the server's copy expires unused.
    }
    await dropSession(mode.slot);
  }

  /// Forgets the session in [slot] without a server call — what the
  /// interceptor asks for after a refused token.
  Future<void> dropSession(SessionSlot slot) async {
    await _tokenStore.clear(slot);

    final SessionState? current = state.value;
    if (current is! SignedIn) {
      return;
    }

    final AppUser? staffUser = slot == SessionSlot.staff
        ? null
        : current.staffUser;
    final AppUser? customerUser = slot == SessionSlot.customer
        ? null
        : current.customerUser;

    if (staffUser == null && customerUser == null) {
      state = const AsyncData<SessionState>(SignedOut());
      return;
    }

    // Built in one step so no intermediate state points its active mode at
    // the session that was just dropped.
    state = AsyncData<SessionState>(
      SignedIn(
        activeMode: staffUser != null
            ? SessionMode.staff
            : SessionMode.customer,
        staffUser: staffUser,
        customerUser: customerUser,
      ),
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final String staffId = _staffUser().id;

    await _repository.changePassword(
      SessionSlot.staff,
      currentPassword: currentPassword,
      newPassword: newPassword,
      newPasswordConfirmation: newPasswordConfirmation,
    );

    _updateUser(
      SessionMode.staff,
      staffId,
      (AppUser user) => user.copyWith(mustChangePassword: false),
    );
  }

  /// Reports the chosen language for every confirmed session, so push texts
  /// arrive in it; a failure here is not worth surfacing.
  Future<void> reportLanguage(AppLanguage language) async {
    final SessionState? current = state.value;
    if (current is! SignedIn) {
      return;
    }
    for (final SessionMode mode in SessionMode.values) {
      if (current.userIn(mode) == null) {
        continue;
      }
      try {
        final AppUser updated = await _repository.updateLanguage(
          mode.slot,
          language,
        );
        _updateUser(mode, updated.id, (AppUser _) => updated);
      } on ApiFailure {
        // The device keeps the choice; the server learns it next time.
      }
    }
  }

  Future<void> _afterLogin(
    SessionMode mode,
    IssuedSession session, {
    StaffStep? staffStep,
  }) async {
    await _tokenStore.write(mode.slot, session.token);

    final SessionState? current = state.value;

    if (current is SignedIn) {
      // A step belongs to the login that brought it; a new login drops any
      // earlier one.
      final SignedIn base = current.withoutStaffStep();
      state = AsyncData<SessionState>(
        mode == SessionMode.staff
            ? base.copyWith(activeMode: mode, staffUser: session.user)
            : base.copyWith(
                activeMode: mode,
                customerUser: session.user,
                staffStep: staffStep,
              ),
      );
      return;
    }

    final SessionSlot other = mode == SessionMode.staff
        ? SessionSlot.customer
        : SessionSlot.staff;
    if (await _tokenStore.read(other) == null) {
      state = AsyncData<SessionState>(
        SignedIn(
          activeMode: mode,
          staffUser: mode == SessionMode.staff ? session.user : null,
          customerUser: mode == SessionMode.customer ? session.user : null,
          staffStep: staffStep,
        ),
      );
      return;
    }

    // Unreachable at bootstrap, and the other slot holds a token that was
    // never confirmed. The server is evidently reachable now, so confirm
    // everything rather than show one session and hide the other.
    final SessionState confirmed = await _bootstrap(prefer: mode);
    state = AsyncData<SessionState>(
      confirmed is SignedIn && staffStep != null
          ? confirmed.copyWith(staffStep: staffStep)
          : confirmed,
    );
  }

  /// Applies a server answer to the session it was made for, and only while
  /// that session still holds the account it was made for: an answer for a
  /// session dropped, replaced or signed out in the meantime is discarded.
  void _updateUser(
    SessionMode mode,
    String userId,
    AppUser Function(AppUser current) change,
  ) {
    final SessionState? current = state.value;
    if (current is! SignedIn) {
      return;
    }
    final AppUser? user = current.userIn(mode);
    if (user == null || user.id != userId) {
      return;
    }
    state = AsyncData<SessionState>(
      mode == SessionMode.staff
          ? current.copyWith(staffUser: change(user))
          : current.copyWith(customerUser: change(user)),
    );
  }

  AppUser _staffUser() {
    final SessionState? current = state.value;
    if (current is SignedIn && current.staffUser != null) {
      return current.staffUser!;
    }
    throw StateError('no confirmed staff session');
  }
}

/// One slot's answer to `/auth/me`: a user, a failure, or neither when the
/// token was refused and cleared.
final class _Answer {
  const _Answer({this.user, this.failure});

  final AppUser? user;
  final ApiFailure? failure;
}
