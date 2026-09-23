/// Transport configuration for the one API client.
///
/// The base URL is supplied at build time with
/// `--dart-define=BB_API_BASE_URL=...`. The default points at the local
/// development backend; note that `docker/compose.yaml` publishes no HTTP port
/// today, so nothing listens there until the integration task needs it.
class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
    required this.connectTimeout,
    required this.receiveTimeout,
    required this.sendTimeout,
  });

  factory ApiConfig.fromEnvironment() => const ApiConfig(
    baseUrl: String.fromEnvironment(
      baseUrlVariable,
      defaultValue: defaultBaseUrl,
    ),
    connectTimeout: Duration(seconds: 15),
    receiveTimeout: Duration(seconds: 30),
    sendTimeout: Duration(seconds: 30),
  );

  static const String baseUrlVariable = 'BB_API_BASE_URL';
  static const String defaultBaseUrl = 'http://localhost:8000/api/v1';

  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
}
