import 'package:baraka_bozor/core/network/auth_interceptor.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/admin/data/admin_staff_api.dart';
import 'package:baraka_bozor/features/admin/data/admin_staff_repository_impl.dart';
import 'package:baraka_bozor/features/admin/domain/admin_staff.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const String staffId = '7d1c2b3a-4e5f-4a6b-8c7d-9e0f1a2b3c4d';

/// A staff account as `docs/09-api-contracts.md` section 43 returns it.
Map<String, Object?> memberJson({String role = 'shopper'}) => <String, Object?>{
  'id': staffId,
  'role': role,
  'phone': '+998901112233',
  'full_name': 'Dilnoza Karimova',
  'status': 'active',
  'must_change_password': true,
  'last_login_at': null,
  'blocked_at': null,
  'created_at': '2026-09-26T05:00:00Z',
  'updated_at': '2026-09-26T05:00:00Z',
};

void main() {
  group('parsing', () {
    test('a staff account', () {
      final StaffMember member = AdminStaffApi.parseMember(memberJson());
      expect(member.role, UserRole.shopper);
      expect(member.status, AccountStatus.active);
      expect(member.mustChangePassword, isTrue);
      expect(member.lastLoginAt, isNull);
    });

    test('an issued password carries the account and the password', () {
      final IssuedPassword issued = AdminStaffApi.parseIssued(<String, Object?>{
        'user': memberJson(),
        'temporary_password': '7pQx9KmT3wZe',
      });
      expect(issued.password, '7pQx9KmT3wZe');
      expect(issued.staff.id, staffId);
    });

    test('a customer, an unknown role or a missing password is refused', () {
      expect(
        () => AdminStaffApi.parseMember(memberJson(role: 'customer')),
        throwsFormatException,
      );
      expect(
        () => AdminStaffApi.parseMember(memberJson(role: 'boss')),
        throwsFormatException,
      );
      expect(
        () =>
            AdminStaffApi.parseIssued(<String, Object?>{'user': memberJson()}),
        throwsFormatException,
      );
      expect(
        () => AdminStaffApi.parseIssued(<String, Object?>{
          'user': memberJson(),
          'temporary_password': '',
        }),
        throwsFormatException,
      );
    });

    test('an id, a phone or a blocked state off the contract is refused', () {
      for (final Map<String, Object?> broken in <Map<String, Object?>>[
        <String, Object?>{...memberJson(), 'id': 's-1'},
        <String, Object?>{...memberJson(), 'phone': '901112233'},
        <String, Object?>{...memberJson(), 'phone': '+99890111223'},
        <String, Object?>{...memberJson(), 'phone': '+7901112233'},
        // A blocked account has the time it was blocked (the database's
        // `users_blocked_at_check`).
        <String, Object?>{...memberJson(), 'status': 'blocked'},
      ]) {
        expect(() => AdminStaffApi.parseMember(broken), throwsFormatException);
      }
      expect(
        AdminStaffApi.parseMember(<String, Object?>{
          ...memberJson(),
          'status': 'blocked',
          'blocked_at': '2026-09-26T06:00:00Z',
        }).status,
        AccountStatus.blocked,
      );
    });
  });

  group('requests', () {
    late FakeHttpClientAdapter adapter;
    late AdminStaffRepositoryImpl repository;

    setUp(() {
      adapter = FakeHttpClientAdapter((RequestOptions options) {
        if (options.method == 'GET') {
          return jsonReply(200, <String, Object?>{
            'data': <Object?>[memberJson()],
            'meta': <String, Object?>{
              'pagination': <String, int>{
                'page': 1,
                'per_page': 20,
                'total': 1,
                'last_page': 1,
              },
            },
          });
        }
        final bool issues =
            options.path.endsWith('/reset-password') ||
            options.path == '/admin/staff';
        return jsonReply(
          options.path == '/admin/staff' ? 201 : 200,
          <String, Object?>{
            'data': issues
                ? <String, Object?>{
                    'user': memberJson(),
                    'temporary_password': '7pQx9KmT3wZe',
                  }
                : memberJson(),
          },
        );
      });
      repository = AdminStaffRepositoryImpl(AdminStaffApi(dioWith(adapter)));
    });

    SessionSlot? slotOf(RequestOptions options) =>
        RequestSlot.resolve(options, () => SessionSlot.customer);

    test('the list sends only the filters that are set', () async {
      await repository.staff(const StaffQuery());
      await repository.staff(
        const StaffQuery(
          page: 2,
          role: UserRole.courier,
          status: AccountStatus.blocked,
        ),
      );

      expect(adapter.requests.first.queryParameters, <String, Object>{
        'page': 1,
      });
      expect(adapter.requests.last.queryParameters, <String, Object>{
        'page': 2,
        'role': 'courier',
        'status': 'blocked',
      });
    });

    test('each change goes to its own path with its own body, on the staff session', () async {
      final IssuedPassword created = await repository.create(
        const NewStaffMember(
          fullName: 'Dilnoza Karimova',
          phone: '+998901112233',
          role: UserRole.shopper,
        ),
      );
      await repository.rename(created.staff, 'Dilnoza K.');
      await repository.block(staffId);
      await repository.activate(staffId);
      final IssuedPassword reset = await repository.resetPassword(staffId);

      expect(
        adapter.requests.map((RequestOptions o) => '${o.method} ${o.path}'),
        <String>[
          'POST /admin/staff',
          'PATCH /admin/staff/$staffId',
          'POST /admin/staff/$staffId/block',
          'POST /admin/staff/$staffId/activate',
          'POST /admin/staff/$staffId/reset-password',
        ],
      );
      expect(adapter.requests.first.data, <String, String>{
        'full_name': 'Dilnoza Karimova',
        'phone': '+998901112233',
        'role': 'shopper',
      });
      expect(adapter.requests[1].data, <String, String>{
        'full_name': 'Dilnoza K.',
      });
      expect(created.password, '7pQx9KmT3wZe');
      expect(reset.password, '7pQx9KmT3wZe');
      for (final RequestOptions request in adapter.requests) {
        expect(slotOf(request), SessionSlot.staff);
      }
    });

    test('an unchanged name is not sent', () async {
      final StaffMember member = AdminStaffApi.parseMember(memberJson());

      expect(await repository.rename(member, 'Dilnoza Karimova'), same(member));
      expect(adapter.requests, isEmpty);
    });
  });
}
