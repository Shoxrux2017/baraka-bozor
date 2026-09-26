import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/api_config.dart';
import '../core/localization/app_language.dart';
import '../core/localization/language_controller.dart';
import '../core/network/api_client.dart';
import '../core/network/auth_interceptor.dart';
import '../core/session/session_controller.dart';
import '../core/session/session_state.dart';
import '../core/storage/preference_store.dart';
import '../core/storage/token_store.dart';
import '../features/auth/data/auth_api.dart';
import '../features/auth/data/auth_repository_impl.dart';
import '../features/auth/domain/auth_repository.dart';
import 'router.dart';

/// Root providers: the process-wide objects every feature may read.
///
/// Only things that must exist exactly once belong here. A provider that
/// serves one feature lives with that feature, which is why there is no
/// registry for providers the way there is for routes — a Riverpod provider is
/// reached by reference, so nothing has to collect them.

/// Transport configuration, resolved from the build-time environment.
final Provider<ApiConfig> apiConfigProvider = Provider<ApiConfig>(
  (Ref ref) => ApiConfig.fromEnvironment(),
);

/// The bearer tokens in platform-secured storage, one slot per session, per
/// `docs/07-architecture.md` section 8.
final Provider<TokenStore> tokenStoreProvider = Provider<TokenStore>(
  (Ref ref) => const SecureTokenStore(),
);

/// Per-device preferences such as the language.
final Provider<PreferenceStore> preferenceStoreProvider =
    Provider<PreferenceStore>((Ref ref) => const SecurePreferenceStore());

/// The device language, for the default interface language. Overridden in
/// tests.
final Provider<Locale> deviceLocaleProvider = Provider<Locale>(
  (Ref ref) => PlatformDispatcher.instance.locale,
);

/// The one configured API client. Creating a second Dio anywhere is the
/// failure `frontend/AGENTS.md` section 2 names. The interceptor reads the
/// session lazily, at request time, so this provider does not depend on the
/// session controller while the session controller may depend on it.
final Provider<Dio> apiClientProvider = Provider<Dio>((Ref ref) {
  final Dio client = createApiClient(ref.watch(apiConfigProvider));

  client.interceptors.add(
    AuthInterceptor(
      ref.watch(tokenStoreProvider),
      () => ref.read(sessionControllerProvider.notifier).activeSlot,
      (SessionSlot slot) =>
          ref.read(sessionControllerProvider.notifier).dropSession(slot),
    ),
  );

  ref.onDispose(client.close);
  return client;
});

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
      (Ref ref) => AuthRepositoryImpl(AuthApi(ref.watch(apiClientProvider))),
    );

/// The two sessions and which one is active.
final AsyncNotifierProvider<SessionController, SessionState>
sessionControllerProvider =
    AsyncNotifierProvider<SessionController, SessionState>(
      SessionController.new,
    );

/// The interface language.
final AsyncNotifierProvider<LanguageController, AppLanguage>
languageControllerProvider =
    AsyncNotifierProvider<LanguageController, AppLanguage>(
      LanguageController.new,
    );

/// The application's route table, built once for the process.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final GoRouter router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
});
