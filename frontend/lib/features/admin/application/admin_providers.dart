import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/session/session_state.dart';
import '../data/settings_api.dart';
import '../data/settings_repository_impl.dart';
import '../domain/settings_repository.dart';

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
      (Ref ref) =>
          SettingsRepositoryImpl(SettingsApi(ref.watch(apiClientProvider))),
    );

/// The id of the signed-in staff account, or `null` when there is none.
///
/// Every admin controller watches this, so a logout or a different Admin
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
