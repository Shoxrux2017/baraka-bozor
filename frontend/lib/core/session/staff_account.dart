import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'session_state.dart';

/// The id of the signed-in staff account, or `null` when there is none.
///
/// Every panel controller — the Admin's and the board's — watches this, so a logout or a different Admin
/// signing in rebuilds it from scratch instead of showing what the previous
/// account loaded (`docs/07-architecture.md` section 28). An operation that
/// awaits compares it before and after, and drops a completion that belongs
/// to an account no longer signed in.
final Provider<String?> staffAccountProvider = Provider<String?>((Ref ref) {
  return ref.watch(
    sessionControllerProvider.select((AsyncValue<SessionState> session) {
      final SessionState? state = session.value;
      return state is SignedIn ? state.staffUser?.id : null;
    }),
  );
});
