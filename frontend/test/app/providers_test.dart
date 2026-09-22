import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/config/api_config.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer containerWith(ApiConfig config) {
    final ProviderContainer container = ProviderContainer(
      overrides: [apiConfigProvider.overrideWithValue(config)],
    );
    addTearDown(container.dispose);
    return container;
  }

  const ApiConfig config = ApiConfig(
    baseUrl: 'https://api.example.test/api/v1',
    connectTimeout: Duration(seconds: 3),
    receiveTimeout: Duration(seconds: 4),
    sendTimeout: Duration(seconds: 5),
  );

  group('apiClientProvider', () {
    test('builds the client from the configuration rather than a bare Dio', () {
      // Without this, replacing createApiClient(ref.watch(apiConfigProvider))
      // with a plain Dio() would leave the whole suite green while the client
      // silently lost its base URL and timeouts.
      final Dio client = containerWith(config).read(apiClientProvider);

      expect(client.options.baseUrl, 'https://api.example.test/api/v1');
      expect(client.options.connectTimeout, const Duration(seconds: 3));
      expect(client.options.receiveTimeout, const Duration(seconds: 4));
      expect(client.options.sendTimeout, const Duration(seconds: 5));
    });

    test('hands out one instance, not one per read', () {
      // frontend/AGENTS.md section 2 allows exactly one configured client.
      final ProviderContainer container = containerWith(config);

      expect(
        identical(
          container.read(apiClientProvider),
          container.read(apiClientProvider),
        ),
        isTrue,
      );
    });
  });

  group('apiConfigProvider', () {
    test('resolves from the build environment by default', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(apiConfigProvider).baseUrl,
        ApiConfig.defaultBaseUrl,
      );
    });
  });

  group('tokenStoreProvider', () {
    test('exposes the port, so no feature can reach the storage plugin', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final TokenStore store = container.read(tokenStoreProvider);

      expect(store, isA<SecureTokenStore>());
    });
  });
}
