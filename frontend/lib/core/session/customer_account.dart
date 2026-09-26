import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'session_state.dart';

/// The id of the signed-in Customer account, or `null`. Every Customer-area
/// provider watches it, so another account — a Customer-mode entry of a
/// different person, a logout — starts over instead of showing what the
/// previous one loaded (`docs/07-architecture.md` section 28).
final Provider<String?> customerAccountProvider = Provider<String?>((Ref ref) {
  return ref.watch(
    sessionControllerProvider.select((AsyncValue<SessionState> session) {
      final SessionState? state = session.value;
      return state is SignedIn ? state.customerUser?.id : null;
    }),
  );
});
