import 'package:dio/dio.dart';

/// The error envelope of `docs/09-api-contracts.md` section 3, as the client
/// reads it. `code` is what the client branches on; `message` is developer
/// English and is never shown to a user, so it is not even kept.
final class ApiError {
  const ApiError({
    required this.status,
    required this.code,
    this.errors = const <String, List<String>>{},
    this.details = const <String, Object?>{},
    this.requestId,
  });

  /// Reads the envelope from a response body, or returns `null` when the body
  /// is not an envelope — a proxy error page, an empty body, a wrong shape.
  static ApiError? fromResponse(Response<dynamic>? response) {
    final Object? body = response?.data;
    final int? status = response?.statusCode;

    if (status == null || body is! Map<String, dynamic>) {
      return null;
    }

    final Object? code = body['code'];
    if (code is! String || code.isEmpty) {
      return null;
    }

    return ApiError(
      status: status,
      code: code,
      errors: _fieldErrors(body['errors']),
      details: switch (body['details']) {
        final Map<String, dynamic> details => Map<String, Object?>.from(
          details,
        ),
        _ => const <String, Object?>{},
      },
      requestId: switch (body['request_id']) {
        final String id => id,
        _ => null,
      },
    );
  }

  static Map<String, List<String>> _fieldErrors(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return const <String, List<String>>{};
    }
    return raw.map<String, List<String>>(
      (String field, dynamic messages) => MapEntry<String, List<String>>(
        field,
        messages is List
            ? messages.map((Object? m) => m.toString()).toList()
            : <String>[messages.toString()],
      ),
    );
  }

  final int status;
  final String code;

  /// Field errors of a `validation_failed` response, keyed by field.
  final Map<String, List<String>> errors;

  /// Machine-readable values a message would otherwise need, for example the
  /// minimum order amount.
  final Map<String, Object?> details;

  final String? requestId;

  /// The `Retry-After` seconds of a `429`, when the response carried one.
  static int? retryAfter(Response<dynamic>? response) {
    final String? header = response?.headers.value('retry-after');
    return header == null ? null : int.tryParse(header);
  }
}

/// Every way a request can fail, as the application layer sees it.
///
/// Repositories throw these; controllers keep them in state; screens map
/// [code] to localized text through `failureText`. Nothing above the data
/// layer sees a `DioException` or a raw response.
sealed class ApiFailure implements Exception {
  const ApiFailure();

  /// The machine code screens map to text: the envelope's code for an API
  /// refusal, or one of the client-side codes below.
  String get code;

  static const String networkCode = 'network';
  static const String malformedCode = 'malformed_response';
  static const String cancelledCode = 'cancelled';

  /// Translates a transport failure into the failure the application sees.
  static ApiFailure fromDio(DioException exception) {
    if (exception.type == DioExceptionType.cancel) {
      return const CancelledFailure();
    }

    if (exception.error is FormatException) {
      // The server answered, but with a body the JSON decoder rejected. Dio
      // reports that without the response, so it is caught before the
      // "no answer" reading below.
      return MalformedResponseFailure(
        status: exception.response?.statusCode,
        reason: 'undecodable body',
      );
    }

    final Response<dynamic>? response = exception.response;

    if (response == null) {
      // No answer at all: a timeout, a refused connection, a bad certificate,
      // an interrupted transfer. All of them read as "the server could not
      // be reached" to the person holding the phone.
      return const NetworkFailure();
    }

    final ApiError? error = ApiError.fromResponse(response);
    if (error == null) {
      return MalformedResponseFailure(status: response.statusCode);
    }

    return ApiRefusal(error, retryAfterSeconds: ApiError.retryAfter(response));
  }
}

/// The server answered with the error envelope.
final class ApiRefusal extends ApiFailure {
  const ApiRefusal(this.error, {this.retryAfterSeconds});

  final ApiError error;

  final int? retryAfterSeconds;

  @override
  String get code => error.code;

  int get status => error.status;

  bool get isUnauthenticated => status == 401;
}

/// The server could not be reached, or the connection broke.
final class NetworkFailure extends ApiFailure {
  const NetworkFailure();

  @override
  String get code => ApiFailure.networkCode;
}

/// The request was cancelled by the client; nothing to show.
final class CancelledFailure extends ApiFailure {
  const CancelledFailure();

  @override
  String get code => ApiFailure.cancelledCode;
}

/// A response that is not what the contract promises: an error without an
/// envelope, or a success payload the DTO could not parse. Treated as a
/// server failure, because the client cannot act on it.
final class MalformedResponseFailure extends ApiFailure {
  const MalformedResponseFailure({this.status, this.reason});

  final int? status;

  /// For logs and tests only; never shown.
  final String? reason;

  @override
  String get code => ApiFailure.malformedCode;
}
