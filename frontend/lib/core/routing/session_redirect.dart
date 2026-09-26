import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/app_user.dart';
import '../session/session_state.dart';
import 'app_paths.dart';

/// Where a navigation must go instead, given what the client knows about
/// its sessions, or `null` to let it through.
///
/// This is the route guard of `frontend/AGENTS.md` section 6: a direct entry
/// into an area the session does not open fails safely, and the backend
/// remains the authority on everything the guard assumes. The rules, in
/// order:
///
/// 1. until the bootstrap has an answer, everything waits on the bootstrap
///    screen; a bootstrap that threw is treated as unreachable, so the
///    person gets a retry rather than a spinner;
/// 2. signed out, only the public auth screens are reachable;
/// 3. unreachable, only the retry screen;
/// 4. signed in on the wrong surface, only the screen naming the right one
///    (`docs/02-user-roles.md` section 10);
/// 5. signed in behind the first-login gate, only the password change
///    (`docs/04-user-flows.md` section 3);
/// 6. otherwise the active role's area, plus the Customer-mode entry for a
///    Shopper or Courier who has no customer session yet.
String? sessionRedirect({
  required AsyncValue<SessionState> session,
  required Surface surface,
  required String location,
}) {
  if (session.hasError) {
    return _only(AppPaths.unreachable, location);
  }

  final SessionState? state = session.value;
  if (state == null) {
    return _only(AppPaths.bootstrap, location);
  }

  return switch (state) {
    SignedOut() => _signedOut(location),
    SessionUnreachable() => _only(AppPaths.unreachable, location),
    final SignedIn signedIn => _signedIn(signedIn, surface, location),
  };
}

const Set<String> _publicAuth = <String>{
  AppPaths.auth,
  AppPaths.customerCode,
  AppPaths.staffLogin,
};

String? _signedOut(String location) =>
    _publicAuth.contains(location) ? null : AppPaths.auth;

String? _signedIn(SignedIn state, Surface surface, String location) {
  final AppUser user = state.activeUser;

  if (user.role.surface != surface) {
    return _only(AppPaths.wrongSurface, location);
  }

  if (user.mustChangePassword) {
    return _only(AppPaths.changePassword, location);
  }

  final bool mayEnterCustomerMode =
      state.activeMode == SessionMode.staff &&
      state.canOfferCustomerMode &&
      state.customerUser == null;
  if (location == AppPaths.customerMode && mayEnterCustomerMode) {
    return null;
  }

  final String area = AppPaths.areaOf(user.role);
  return AppPaths.isInside(location, area) ? null : area;
}

/// Lets [location] through only when it is [allowed].
String? _only(String allowed, String location) =>
    location == allowed ? null : allowed;
