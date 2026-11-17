import 'package:dio/dio.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/storage/token_store.dart';
import '../../auth/data/user_dto.dart';
import '../../auth/domain/app_user.dart';
import '../domain/account_deletion.dart';

/// `POST /customer/account/deletion-code` and `/customer/account/delete`
/// (`docs/09` sections 64 and 65) on the Customer session.
class AccountDeletionApi implements AccountDeletionRepository {
  AccountDeletionApi(this._dio);

  final Dio _dio;

  static final Options _customer = RequestSlot.of(SessionSlot.customer);

  /// The deletion and its check read `authentication_required` as a deleted
  /// account, so they keep the session on it (`DL-140`).
  static final Options _keeping = RequestSlot.of(
    SessionSlot.customer,
    keepOnUnauthenticated: true,
  );

  @override
  Future<RequestedCode> requestCode() => guardApiCall(() async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/customer/account/deletion-code',
      options: _customer,
    );
    return UserDto.parseRequestedCode(ApiEnvelope.unwrap(response.data));
  });

  @override
  Future<void> delete(String code) => guardApiCall(() async {
    await _dio.post<dynamic>(
      '/customer/account/delete',
      data: <String, String>{'code': code},
      options: _keeping,
    );
  });

  @override
  Future<bool> stillExists() => guardApiCall(() async {
    try {
      await _dio.get<dynamic>('/customer/profile', options: _keeping);
      return true;
    } on DioException catch (error) {
      final ApiError? refusal = ApiError.fromResponse(error.response);
      if (refusal?.status == 401 &&
          refusal?.code == 'authentication_required') {
        return false;
      }
      rethrow;
    }
  });
}
