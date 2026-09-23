import 'package:dio/dio.dart';

import '../config/api_config.dart';

/// Builds the one configured API client the whole application shares.
///
/// It owns transport concerns only — base URL, timeouts, JSON negotiation. It
/// knows no endpoint, parses no response envelope and adds no interceptor:
/// data sources own paths and bodies, and the bearer-token interceptor is
/// attached by the session task. A second Dio instance anywhere is the failure
/// `frontend/AGENTS.md` section 2 names, so this is created once, by the root
/// provider, and injected.
Dio createApiClient(ApiConfig config) {
  return Dio(
    BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
      sendTimeout: config.sendTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      headers: <String, String>{Headers.acceptHeader: Headers.jsonContentType},
    ),
  );
}
