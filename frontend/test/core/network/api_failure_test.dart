import 'dart:io';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final RequestOptions options = RequestOptions(path: '/x');

  Response<dynamic> response(
    int status,
    Object? body, {
    Map<String, List<String>>? headers,
  }) {
    return Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      data: body,
      headers: Headers.fromMap(headers ?? <String, List<String>>{}),
    );
  }

  group('ApiError.fromResponse', () {
    test('reads the envelope of docs/09 section 3, details and field errors included', () {
      final ApiError? error = ApiError.fromResponse(
        response(422, <String, Object?>{
          'message': 'Developer-facing English.',
          'code': 'minimum_order_not_reached',
          'errors': <String, Object?>{
            'phone': <String>['required'],
          },
          'details': <String, Object?>{
            'minimum_order_uzs': 50000,
            'shortfall_uzs': 12000,
          },
          'request_id': 'req_01hzz000000000000000000000',
        }),
      );

      expect(error, isNotNull);
      expect(error!.status, 422);
      expect(error.code, 'minimum_order_not_reached');
      expect(error.errors, <String, List<String>>{
        'phone': <String>['required'],
      });
      expect(error.details['minimum_order_uzs'], 50000);
      expect(error.requestId, 'req_01hzz000000000000000000000');
    });

    test('is null for anything that is not an envelope', () {
      expect(
        ApiError.fromResponse(response(502, '<html>bad gateway</html>')),
        isNull,
      );
      expect(
        ApiError.fromResponse(
          response(500, <String, Object?>{'message': 'no code'}),
        ),
        isNull,
      );
      expect(
        ApiError.fromResponse(response(500, <String, Object?>{'code': ''})),
        isNull,
      );
      expect(ApiError.fromResponse(null), isNull);
    });

    test('reads Retry-After', () {
      expect(
        ApiError.retryAfter(
          response(
            429,
            <String, Object?>{'code': 'rate_limited'},
            headers: <String, List<String>>{
              'retry-after': <String>['30'],
            },
          ),
        ),
        30,
      );
      expect(
        ApiError.retryAfter(
          response(429, <String, Object?>{'code': 'rate_limited'}),
        ),
        isNull,
      );
    });
  });

  group('ApiFailure.fromDio', () {
    test('a refusal with an envelope is an ApiRefusal carrying the code', () {
      final ApiFailure failure = ApiFailure.fromDio(
        DioException.badResponse(
          statusCode: 401,
          requestOptions: options,
          response: response(401, <String, Object?>{
            'code': 'account_blocked',
            'errors': <String, Object?>{},
          }),
        ),
      );

      expect(failure, isA<ApiRefusal>());
      expect(failure.code, 'account_blocked');
      expect((failure as ApiRefusal).isUnauthenticated, isTrue);
    });

    test('a 429 carries its Retry-After seconds', () {
      final ApiFailure failure = ApiFailure.fromDio(
        DioException.badResponse(
          statusCode: 429,
          requestOptions: options,
          response: response(
            429,
            <String, Object?>{
              'code': 'rate_limited',
              'errors': <String, Object?>{},
            },
            headers: <String, List<String>>{
              'retry-after': <String>['45'],
            },
          ),
        ),
      );

      expect((failure as ApiRefusal).retryAfterSeconds, 45);
    });

    test(
      'an error without an envelope is a malformed response, never shown as-is',
      () {
        final ApiFailure failure = ApiFailure.fromDio(
          DioException.badResponse(
            statusCode: 502,
            requestOptions: options,
            response: response(502, '<html>'),
          ),
        );

        expect(failure, isA<MalformedResponseFailure>());
        expect(failure.code, ApiFailure.malformedCode);
      },
    );

    test('no answer at all is a network failure', () {
      for (final DioExceptionType type in <DioExceptionType>[
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
        DioExceptionType.unknown,
      ]) {
        expect(
          ApiFailure.fromDio(DioException(requestOptions: options, type: type)),
          isA<NetworkFailure>(),
          reason: '$type',
        );
      }
    });

    test('a connection never made has not arrived', () {
      for (final DioException exception in <DioException>[
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        ),
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const SocketException('Failed host lookup'),
        ),
      ]) {
        final ApiFailure failure = ApiFailure.fromDio(exception);
        expect(failure, isA<NetworkFailure>(), reason: '${exception.type}');
        expect(
          (failure as NetworkFailure).mayHaveArrived,
          isFalse,
          reason: '${exception.type}',
        );
      }
    });

    test('a connection that broke may have arrived', () {
      for (final DioException exception in <DioException>[
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const HttpException(
            'Connection closed before full header was received',
          ),
        ),
        DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        ),
        DioException(
          requestOptions: options,
          type: DioExceptionType.sendTimeout,
        ),
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: const SocketException('Connection reset by peer'),
        ),
      ]) {
        final ApiFailure failure = ApiFailure.fromDio(exception);
        expect(failure, isA<NetworkFailure>(), reason: '${exception.type}');
        expect(
          (failure as NetworkFailure).mayHaveArrived,
          isTrue,
          reason: '${exception.type}',
        );
      }
      expect(const NetworkFailure().mayHaveArrived, isTrue);
    });

    test('a cancelled request is its own kind, with nothing to show', () {
      final ApiFailure failure = ApiFailure.fromDio(
        DioException(requestOptions: options, type: DioExceptionType.cancel),
      );

      expect(failure, isA<CancelledFailure>());
      expect(failure.code, ApiFailure.cancelledCode);
    });

    test('a body the JSON decoder rejected is a malformed response: the server did answer', () {
      final ApiFailure failure = ApiFailure.fromDio(
        DioException(
          requestOptions: options,
          error: const FormatException('Unexpected end of input'),
        ),
      );

      expect(failure, isA<MalformedResponseFailure>());
      expect(failure.code, ApiFailure.malformedCode);
    });
  });
}
