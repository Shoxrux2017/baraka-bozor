import 'package:dio/dio.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/storage/token_store.dart';
import '../domain/admin_customers.dart';

/// The data source for `docs/09-api-contracts.md` sections 66 and 67, on
/// the staff session, with its strict parsing. Failures leave as
/// `ApiFailure`; a refused erasure keeps the order that stands in its way
/// (`UnfinishedOrderRefusal`).
class AdminCustomersApi {
  AdminCustomersApi(this._dio);

  final Dio _dio;

  static final Options _staff = RequestSlot.of(SessionSlot.staff);
  static final RegExp _phone = RegExp(r'^\+998\d{9}$');
  static const List<String> _statuses = <String>['active', 'blocked'];

  /// The Customer accounts on [phone], active ones first.
  Future<List<AdminCustomer>> find(String phone) => guardApiCall(() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/admin/customers',
      queryParameters: <String, String>{'phone': phone},
      options: _staff,
    );
    final Object? data = ApiEnvelope.unwrap(response.data);
    if (data is! List<dynamic>) {
      throw const FormatException('the customers are not a list');
    }
    return <AdminCustomer>[for (final Object? raw in data) parse(raw)];
  });

  /// Erases the account; it answers `204`.
  Future<void> erase(String id) => guardApiCall(() async {
    await _dio.post<dynamic>(
      '/admin/customers/${Uri.encodeComponent(id)}/erase',
      options: _staff,
    );
  });

  static AdminCustomer parse(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'customer');
    final String phone = json.string('phone');
    if (!_phone.hasMatch(phone)) {
      throw const FormatException('phone is not +998 and nine digits');
    }
    final String status = json.string('status');
    if (!_statuses.contains(status)) {
      throw FormatException('status is unknown: $status');
    }
    final int orderCount = json.integer('order_count');
    if (orderCount < 0) {
      throw const FormatException('order_count is negative');
    }
    final Object? unfinished = json.member('unfinished_order');
    ({String id, int number})? unfinishedOrder;
    if (unfinished != null) {
      final JsonFields order = JsonFields.of(unfinished, 'unfinished_order');
      unfinishedOrder = (
        id: order.uuid('id'),
        number: order.integer('order_number'),
      );
    }
    return AdminCustomer(
      id: json.uuid('id'),
      phone: phone,
      fullName: json.nullableString('full_name'),
      status: status,
      createdAt: json.instant('created_at'),
      lastLoginAt: json.nullableInstant('last_login_at'),
      orderCount: orderCount,
      unfinishedOrder: unfinishedOrder,
    );
  }
}
