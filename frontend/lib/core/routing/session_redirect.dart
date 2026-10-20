import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/app_user.dart';
import '../session/session_state.dart';
import 'app_paths.dart';

/// Where a navigation to [uri] must go instead, given what the client knows
/// about its sessions, or `null` to let it through.
///
/// This is the route guard of `frontend/AGENTS.md` section 6: a direct entry
/// into an area the session does not open fails safely, and the backend
/// remains the authority on everything the guard assumes. The rules, in
/// order:
///
/// 1. until the bootstrap has an answer, everything waits on the bootstrap
///    screen, which remembers the page asked for; a bootstrap that threw is
///    treated as unreachable, so the person gets a retry rather than a
///    spinner;
/// 2. signed out, only the public screens of the surface are reachable: the
///    phone, the code and the open pages on mobile, the sign-in alone on the
///    web;
/// 3. unreachable, only the retry screen, which keeps remembering the page;
/// 4. signed in on the wrong surface, only the screen naming the right one
///    (`docs/02-user-roles.md` section 10);
/// 5. a pending staff step, only the staff password screen; a Customer who
///    has not given a name, only the name screen;
/// 6. signed in behind the first-login gate, only the password change
///    (`docs/04-user-flows.md` section 3);
/// 7. on mobile, an open page (`AppPaths.openPages`: the legal documents) is
///    reachable signed out and, past the gates above, signed in;
/// 8. otherwise the active role's areas; the page the bootstrap or the retry
///    screen remembered opens when it lies inside those areas, and anything
///    else goes to the role's home (`DL-37` (17), `DL-46` (1)).
String? sessionRedirect({
  required AsyncValue<SessionState> session,
  required Surface surface,
  required Uri uri,
}) {
  final String location = uri.path;

  if (session.hasError) {
    return _unreachable(uri);
  }

  final SessionState? state = session.value;
  if (state == null) {
    return location == AppPaths.bootstrap
        ? null
        : AppPaths.bootstrapKeeping(uri);
  }

  return switch (state) {
    SignedOut() => _signedOut(location, surface),
    SessionUnreachable() => _unreachable(uri),
    final SignedIn signedIn => _signedIn(signedIn, surface, uri),
  };
}

// Every mobile sign-in is the phone and the Telegram code; the web panel has
// the staff sign-in alone, which never asks for a code.
const Set<String> _publicMobile = <String>{
  AppPaths.auth,
  AppPaths.customerCode,
  ...AppPaths.openPages,
};

const Set<String> _publicWeb = <String>{AppPaths.auth, AppPaths.staffLogin};

String? _signedOut(String location, Surface surface) =>
    (surface == Surface.mobile ? _publicMobile : _publicWeb).contains(location)
    ? null
    : AppPaths.auth;

String? _signedIn(SignedIn state, Surface surface, Uri uri) {
  final String location = uri.path;
  final AppUser user = state.activeUser;

  if (user.role.surface != surface) {
    return _only(AppPaths.wrongSurface, location);
  }

  if (surface == Surface.mobile) {
    if (state.staffStep != null) {
      return _only(AppPaths.staffPassword, location);
    }
    if (state.activeMode == SessionMode.customer && user.fullName == null) {
      return _only(AppPaths.customerName, location);
    }
  }

  if (user.mustChangePassword) {
    return _only(AppPaths.changePassword, location);
  }

  if (surface == Surface.mobile && AppPaths.openPages.contains(location)) {
    return null;
  }

  final List<String> areas = AppPaths.areasOf(user.role);
  if (_insideAny(location, areas)) {
    return null;
  }

  if (location == AppPaths.bootstrap || location == AppPaths.unreachable) {
    final String? next = _remembered(uri, areas);
    if (next != null) {
      return next;
    }
  }

  return AppPaths.homeOf(user.role);
}

/// The retry screen, carrying the page the bootstrap remembered, so a
/// reload that met an unreachable server still returns to it once a retry
/// succeeds.
String? _unreachable(Uri uri) {
  if (uri.path == AppPaths.unreachable) {
    return null;
  }
  final String? next = uri.path == AppPaths.bootstrap
      ? uri.queryParameters['next']
      : null;
  return next == null
      ? AppPaths.unreachable
      : Uri(
          path: AppPaths.unreachable,
          queryParameters: <String, String>{'next': next},
        ).toString();
}

/// The page the bootstrap remembered, when it is a location of this app
/// inside [areas]; anything else — another host, a malformed value, a page
/// of another role — is dropped.
String? _remembered(Uri bootstrap, List<String> areas) {
  final String? next = bootstrap.queryParameters['next'];
  if (next == null) {
    return null;
  }

  final Uri? parsed = Uri.tryParse(next);
  if (parsed == null ||
      parsed.hasScheme ||
      parsed.hasAuthority ||
      !parsed.path.startsWith('/') ||
      !_insideAny(parsed.path, areas)) {
    return null;
  }

  return parsed.toString();
}

bool _insideAny(String location, List<String> areas) =>
    areas.any((String area) => AppPaths.isInside(location, area));

/// Lets [location] through only when it is [allowed].
String? _only(String allowed, String location) =>
    location == allowed ? null : allowed;
