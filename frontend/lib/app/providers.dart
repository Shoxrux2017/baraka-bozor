import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/storage/token_store.dart';
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

/// The one configured API client. Creating a second Dio anywhere is the
/// failure `frontend/AGENTS.md` section 2 names.
final Provider<Dio> apiClientProvider = Provider<Dio>((Ref ref) {
  final Dio client = createApiClient(ref.watch(apiConfigProvider));
  ref.onDispose(client.close);
  return client;
});

/// The bearer token in platform-secured storage, per
/// `docs/07-architecture.md` section 8.
final Provider<TokenStore> tokenStoreProvider = Provider<TokenStore>(
  (Ref ref) => const SecureTokenStore(),
);

/// The application's route table, built once for the process.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final GoRouter router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
});
