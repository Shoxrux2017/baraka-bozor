import 'package:baraka_bozor/core/config/api_config.dart';
import 'package:baraka_bozor/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ApiConfig config = ApiConfig(
    baseUrl: 'https://api.example.test/api/v1',
    connectTimeout: Duration(seconds: 3),
    receiveTimeout: Duration(seconds: 4),
    sendTimeout: Duration(seconds: 5),
  );

  group('ApiConfig.fromEnvironment', () {
    test('falls back to the local development API when nothing is defined', () {
      // The suite runs without --dart-define, so this exercises the default.
      expect(
        ApiConfig.fromEnvironment().baseUrl,
        'http://localhost:8000/api/v1',
      );
    });

    test('keeps every timeout positive', () {
      final ApiConfig resolved = ApiConfig.fromEnvironment();

      expect(resolved.connectTimeout, greaterThan(Duration.zero));
      expect(resolved.receiveTimeout, greaterThan(Duration.zero));
      expect(resolved.sendTimeout, greaterThan(Duration.zero));
    });
  });

  group('createApiClient', () {
    test('applies the configured base URL and timeouts', () {
      final BaseOptions options = createApiClient(config).options;

      expect(options.baseUrl, 'https://api.example.test/api/v1');
      expect(options.connectTimeout, const Duration(seconds: 3));
      expect(options.receiveTimeout, const Duration(seconds: 4));
      expect(options.sendTimeout, const Duration(seconds: 5));
    });

    test('sends and accepts JSON', () {
      final BaseOptions options = createApiClient(config).options;

      expect(options.contentType, Headers.jsonContentType);
      expect(options.responseType, ResponseType.json);
      expect(options.headers[Headers.acceptHeader], Headers.jsonContentType);
    });

    test('adds no interceptor of its own, so no implicit retry can exist', () {
      // Compared against a bare Dio rather than a fixed number, so the
      // assertion survives Dio changing its own defaults but still fails the
      // moment this project adds an interceptor. frontend/AGENTS.md section 7
      // forbids automatic mutation retries without a contract that defines
      // them; the bearer-token interceptor arrives with S01-FE-002.
      expect(
        createApiClient(config).interceptors.length,
        Dio().interceptors.length,
      );
    });
  });
}
