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
/// refused token is cleared alone; an unreachable server keeps the tokens and
/// reports [SessionUnreachable]. Every later change — a login, a mode switch,
/// a logout, a token the interceptor saw refused — goes through here, so the
/// interface always renders from one source of truth.
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

  Future<SessionState> _bootstrap() async {
    final Map<SessionSlot, String?> tokens = <SessionSlot, String?>{
      for (final SessionSlot slot in SessionSlot.values)
        slot: await _tokenStore.read(slot),
    };

    if (tokens.values.every((String? token) => token == null)) {
      return const SignedOut();
    }

    AppUser? staffUser;
    AppUser? customerUser;
    bool unreachable = false;

    for (final SessionSlot slot in SessionSlot.values) {
      if (tokens[slot] == null) {
        continue;
      }
      try {
        final AppUser user = await _repository.me(slot);
        if (slot == SessionSlot.staff) {
          staffUser = user;
        } else {
          customerUser = user;
        }
      } on ApiRefusal catch (refusal) {
        if (refusal.isUnauthenticated) {
          // The interceptor has already cleared the slot; clearing again is
          // harmless and keeps this correct without it.
          await _tokenStore.clear(slot);
        } else {
          unreachable = true;
        }
      } on ApiFailure {
        unreachable = true;
      }
    }

    if (staffUser == null && customerUser == null) {
      return unreachable ? const SessionUnreachable() : const SignedOut();
    }

    // With both sessions the staff one opens first: the person installed the
    // app to work, and Customer mode is entered deliberately.
    return SignedIn(
      activeMode: staffUser != null ? SessionMode.staff : SessionMode.customer,
      staffUser: staffUser,
      customerUser: customerUser,
    );
  }

  /// Confirms the sessions again after an unreachable bootstrap.
  Future<void> retry() async {
    state = const AsyncLoading<SessionState>();
    state = AsyncData<SessionState>(await _bootstrap());
  }

  Future<RequestedCode> requestCustomerCode(String phone) =>
      _repository.requestCustomerCode(phone);

  /// Verifies a code and opens the customer session. From the staff
  /// interface this is how Customer mode is entered; from a signed-out app
  /// it is the customer login.
  Future<void> verifyCustomerCode({
    required String phone,
    required String code,
  }) async {
    final IssuedSession session = await _repository.verifyCustomerCode(
      phone: phone,
      code: code,
    );
    await _tokenStore.write(SessionSlot.customer, session.token);
    _merge(SessionMode.customer, session.user);
  }

  Future<void> staffLogin({
    required String phone,
    required String password,
  }) async {
    final IssuedSession session = await _repository.staffLogin(
      phone: phone,
      password: password,
    );
    await _tokenStore.write(SessionSlot.staff, session.token);
    _merge(SessionMode.staff, session.user);
  }

  /// Switches between the two stored sessions in one step; nothing is
  /// requested from the server.
  void switchMode(SessionMode mode) {
    final SessionState? current = state.value;
    if (current is! SignedIn) {
      return;
    }
    final bool available = mode == SessionMode.staff
        ? current.hasStaff
        : current.hasCustomer;
    if (available) {
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
  }) async {
    final SessionState? current = state.value;
    if (current is! SignedIn || current.staffUser == null) {
      throw StateError('no staff session');
    }
    await _repository.changePassword(
      SessionSlot.staff,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    state = AsyncData<SessionState>(
      current.copyWith(
        staffUser: current.staffUser!.copyWith(mustChangePassword: false),
      ),
    );
  }

  /// Reports the chosen language for every confirmed session, so push texts
  /// arrive in it; a failure here is not worth surfacing.
  Future<void> reportLanguage(AppLanguage language) async {
    final SessionState? current = state.value;
    if (current is! SignedIn) {
      return;
    }
    SignedIn updated = current;
    for (final SessionMode mode in SessionMode.values) {
      final bool present = mode == SessionMode.staff
          ? current.hasStaff
          : current.hasCustomer;
      if (!present) {
        continue;
      }
      try {
        final AppUser user = await _repository.updateLanguage(
          mode.slot,
          language,
        );
        updated = mode == SessionMode.staff
            ? updated.copyWith(staffUser: user)
            : updated.copyWith(customerUser: user);
      } on ApiFailure {
        // The device keeps the choice; the server learns it next time.
      }
    }
    state = AsyncData<SessionState>(updated);
  }

  void _merge(SessionMode mode, AppUser user) {
    final SessionState? current = state.value;
    final SignedIn base = current is SignedIn
        ? current
        : SignedIn(
            activeMode: mode,
            staffUser: mode == SessionMode.staff ? user : null,
            customerUser: mode == SessionMode.customer ? user : null,
          );

    state = AsyncData<SessionState>(
      mode == SessionMode.staff
          ? base.copyWith(activeMode: mode, staffUser: user)
          : base.copyWith(activeMode: mode, customerUser: user),
    );
  }
}
