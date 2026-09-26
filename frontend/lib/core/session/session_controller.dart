import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../localization/app_language.dart';
import '../network/api_failure.dart';
import '../storage/token_store.dart';
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

  @override
  Future<SessionState> build() => _bootstrap();

  /// The slot requests are made on behalf of by default: the active mode's,
  /// or none while signed out.
  SessionSlot? get activeSlot => switch (state.value) {
    final SignedIn signedIn => signedIn.activeMode.slot,
    _ => null,
  };

  /// Confirms every stored token. [prefer] names the mode to open when it is
  /// among the confirmed ones; otherwise the staff mode opens first, because
  /// the person installed the app to work and Customer mode is entered
  /// deliberately.
  Future<SessionState> _bootstrap({SessionMode? prefer}) async {
    final Map<SessionSlot, String?> tokens = <SessionSlot, String?>{
      for (final SessionSlot slot in SessionSlot.values)
        slot: await _tokenStore.read(slot),
    };

    if (tokens.values.every((String? token) => token == null)) {
      return const SignedOut();
    }

    final Map<SessionSlot, AppUser> confirmed = <SessionSlot, AppUser>{};

    for (final SessionSlot slot in SessionSlot.values) {
      if (tokens[slot] == null) {
        continue;
      }
      try {
        confirmed[slot] = await _repository.me(slot);
      } on ApiRefusal catch (refusal) {
        if (!refusal.isUnauthenticated) {
          return const SessionUnreachable();
        }
        // The interceptor has already cleared the slot; clearing again is
        // harmless and keeps this correct without it.
        await _tokenStore.clear(slot);
      } on ApiFailure {
        return const SessionUnreachable();
      }
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

  /// Confirms the sessions again after an unreachable bootstrap.
  Future<void> retry() async {
    state = const AsyncLoading<SessionState>();
    state = AsyncData<SessionState>(await _bootstrap());
  }

  /// Customer login from a signed-out app.
  Future<RequestedCode> requestCustomerCode(String phone) =>
      _repository.requestCustomerCode(phone);

  Future<void> verifyCustomerCode({
    required String phone,
    required String code,
  }) async {
    final IssuedSession session = await _repository.verifyCustomerCode(
      phone: phone,
      code: code,
    );
    await _afterLogin(SessionMode.customer, session);
  }

  /// Customer mode from the staff interface: the code goes to the staff
  /// account's own phone (`docs/02-user-roles.md` section 10), so the phone is
  /// the staff user's and never typed.
  Future<RequestedCode> requestCustomerModeCode() =>
      _repository.requestCustomerCode(_staffPhone());

  Future<void> enterCustomerMode({required String code}) async {
    final IssuedSession session = await _repository.verifyCustomerCode(
      phone: _staffPhone(),
      code: code,
    );
    await _afterLogin(SessionMode.customer, session);
  }

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

  /// Ends one session and leaves the other alone
  /// (`docs/02-user-roles.md` section 10).
  Future<void> logout(SessionMode mode) async {
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

  Future<void> _afterLogin(SessionMode mode, IssuedSession session) async {
    await _tokenStore.write(mode.slot, session.token);

    final SessionState? current = state.value;

    if (current is SignedIn) {
      state = AsyncData<SessionState>(
        mode == SessionMode.staff
            ? current.copyWith(activeMode: mode, staffUser: session.user)
            : current.copyWith(activeMode: mode, customerUser: session.user),
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
        ),
      );
      return;
    }

    // Unreachable at bootstrap, and the other slot holds a token that was
    // never confirmed. The server is evidently reachable now, so confirm
    // everything rather than show one session and hide the other.
    state = AsyncData<SessionState>(await _bootstrap(prefer: mode));
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

  String _staffPhone() => _staffUser().phone;
}
