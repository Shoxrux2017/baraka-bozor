import 'package:dio/dio.dart';

import '../../../core/network/api_call.dart';
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
      options: _customer,
    );
  });
}
