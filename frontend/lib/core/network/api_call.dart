import 'package:dio/dio.dart';

import 'api_failure.dart';

/// Runs one data-source call for a repository and turns what can go wrong
/// into the `ApiFailure` the application layer handles: a transport failure
/// through [ApiFailure.fromDio], and a success payload the DTO rejected as a
/// [MalformedResponseFailure].
Future<T> guardApiCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (exception) {
    throw ApiFailure.fromDio(exception);
  } on FormatException catch (exception) {
    throw MalformedResponseFailure(reason: exception.message);
  }
}
