import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/features/auth/data/user_dto.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The identity object exactly as docs/09 section 7 shows it.
  Map<String, Object?> identity() => <String, Object?>{
    'id': '3f1e9d2c-7c0a-4d6c-9a11-2a9b0f3c4d5e',
    'role': 'customer',
    'phone': '+998901234567',
    'full_name': null,
    'status': 'active',
    'must_change_password': false,
    'preferred_language': 'uz',
  };

  group('UserDto.parse', () {
    test('reads the identity object of docs/09 section 7', () {
      final AppUser user = UserDto.parse(identity());

      expect(user.id, '3f1e9d2c-7c0a-4d6c-9a11-2a9b0f3c4d5e');
      expect(user.role, UserRole.customer);
      expect(user.phone, '+998901234567');
      expect(user.fullName, isNull);
      expect(user.status, AccountStatus.active);
      expect(user.mustChangePassword, isFalse);
      expect(user.preferredLanguage, AppLanguage.uz);
    });

    test('reads a staff identity with the gate set', () {
      final AppUser user = UserDto.parse(<String, Object?>{
        ...identity(),
        'role': 'shopper',
        'full_name': 'Dilnoza',
        'must_change_password': true,
        'preferred_language': 'ru',
      });

      expect(user.role, UserRole.shopper);
      expect(user.role.isStaff, isTrue);
      expect(user.fullName, 'Dilnoza');
      expect(user.mustChangePassword, isTrue);
      expect(user.preferredLanguage, AppLanguage.ru);
    });

    test('a missing key is a failure, not a default', () {
      for (final String key in identity().keys) {
        final Map<String, Object?> json = identity()..remove(key);
        expect(() => UserDto.parse(json), throwsFormatException, reason: key);
      }
    });

    test('an unknown role, status or language is a failure', () {
      expect(
        () => UserDto.parse(<String, Object?>{...identity(), 'role': 'owner'}),
        throwsFormatException,
      );
      expect(
        () =>
            UserDto.parse(<String, Object?>{...identity(), 'status': 'sleepy'}),
        throwsFormatException,
      );
      expect(
        () => UserDto.parse(<String, Object?>{
          ...identity(),
          'preferred_language': 'en',
        }),
        throwsFormatException,
      );
    });

    test('a wrong type is a failure', () {
      expect(
        () => UserDto.parse(<String, Object?>{
          ...identity(),
          'must_change_password': 'no',
        }),
        throwsFormatException,
      );
      expect(
        () => UserDto.parse(<String, Object?>{...identity(), 'id': 42}),
        throwsFormatException,
      );
      expect(() => UserDto.parse('not an object'), throwsFormatException);
    });
  });

  group('the other objects', () {
    test('a requested code carries the channel and the timers', () {
      final RequestedCode code = UserDto.parseRequestedCode(<String, Object?>{
        'channel': 'telegram',
        'expires_in_seconds': 300,
        'resend_available_in_seconds': 60,
      });

      expect(code.channel, 'telegram');
      expect(code.expiresInSeconds, 300);
      expect(code.resendAvailableInSeconds, 60);
    });

    test('an issued session carries the token and the user', () {
      final IssuedSession session = UserDto.parseIssuedSession(
        <String, Object?>{'token': '1|abc', 'user': identity()},
      );

      expect(session.token, '1|abc');
      expect(session.user.role, UserRole.customer);
      expect(
        () => UserDto.parseIssuedSession(<String, Object?>{
          'token': '',
          'user': identity(),
        }),
        throwsFormatException,
      );
    });
  });

  group('UserRole', () {
    test('maps each role to its surface per docs/02 section 10', () {
      expect(UserRole.customer.surface, Surface.mobile);
      expect(UserRole.shopper.surface, Surface.mobile);
      expect(UserRole.courier.surface, Surface.mobile);
      expect(UserRole.operator.surface, Surface.web);
      expect(UserRole.admin.surface, Surface.web);
      expect(UserRole.manager.surface, Surface.web);
    });
  });
}
