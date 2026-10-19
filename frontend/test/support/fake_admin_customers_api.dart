import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/features/admin/data/admin_customers_api.dart';
import 'package:baraka_bozor/features/admin/domain/admin_customers.dart';
import 'package:dio/dio.dart';

/// The Customer accounts in memory, answering as the server does: a find
/// returns the accounts on the phone, an erase takes the account away.
class FakeAdminCustomersApi extends AdminCustomersApi {
  FakeAdminCustomersApi() : super(Dio());

  /// The accounts by the phone they are found on.
  final Map<String, List<AdminCustomer>> byPhone =
      <String, List<AdminCustomer>>{};

  /// Every phone asked for, in order.
  final List<String> finds = <String>[];

  /// Every id erased, in order.
  final List<String> erased = <String>[];

  ApiFailure? eraseFailure;

  static AdminCustomer customer({
    required String id,
    String phone = '+998901234567',
    String? fullName = 'Aziza Karimova',
    String status = 'active',
    ({String id, int number})? unfinishedOrder,
  }) => AdminCustomer(
    id: id,
    phone: phone,
    fullName: fullName,
    status: status,
    createdAt: DateTime.utc(2026, 9, 1, 7),
    lastLoginAt: null,
    orderCount: 3,
    unfinishedOrder: unfinishedOrder,
  );

  @override
  Future<List<AdminCustomer>> find(String phone) async {
    finds.add(phone);
    return List<AdminCustomer>.of(byPhone[phone] ?? const <AdminCustomer>[]);
  }

  @override
  Future<void> erase(String id) async {
    erased.add(id);
    final ApiFailure? failure = eraseFailure;
    if (failure != null) {
      throw failure;
    }
    for (final List<AdminCustomer> list in byPhone.values) {
      list.removeWhere((AdminCustomer c) => c.id == id);
    }
  }
}
