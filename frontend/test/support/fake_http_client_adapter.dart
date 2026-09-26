import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A Dio transport that answers from a handler instead of the network, so a
/// data-source test asserts the exact request and controls the exact reply.
class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter(this._handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) _handler;

  /// Every request the client sent, in order.
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return await _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// A JSON reply with the given status.
ResponseBody jsonReply(
  int status,
  Object body, {
  Map<String, List<String>> headers = const <String, List<String>>{},
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      ...headers,
    },
  );
}

/// An error envelope reply, `docs/09` section 3.
ResponseBody errorReply(
  int status,
  String code, {
  Map<String, Object?> details = const <String, Object?>{},
  Map<String, List<String>> errors = const <String, List<String>>{},
  Map<String, List<String>> headers = const <String, List<String>>{},
}) {
  return jsonReply(status, <String, Object?>{
    'message': 'Developer-facing English.',
    'code': code,
    'errors': errors,
    if (details.isNotEmpty) 'details': details,
    'request_id': 'req_01hzz000000000000000000000',
  }, headers: headers);
}

/// A reply with no body at all, such as `204`.
ResponseBody emptyReply(int status) => ResponseBody.fromString('', status);

/// Builds a Dio that talks to [adapter] only.
Dio dioWith(
  FakeHttpClientAdapter adapter, {
  String baseUrl = 'https://api.test/api/v1',
}) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );
  dio.httpClientAdapter = adapter;
  return dio;
}
