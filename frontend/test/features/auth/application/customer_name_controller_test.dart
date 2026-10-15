import 'dart:ui' show Locale;

import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/features/auth/application/customer_name_controller.dart';
import 'package:baraka_bozor/features/profile/application/profile_controllers.dart';
import 'package:baraka_bozor/features/profile/domain/profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_customer_repositories.dart';
import '../../../support/in_memory_stores.dart';

void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository repository;
  late FakeProfileRepository profiles;

  ProviderContainer container() {
    final ProviderContainer c = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        authRepositoryProvider.overrideWithValue(repository),
        profileRepositoryProvider.overrideWithValue(profiles),
        preferenceStoreProvider.overrideWithValue(InMemoryPreferenceStore()),
        deviceLocaleProvider.overrideWithValue(const Locale('uz')),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.customer] = 'c';
    repository = FakeAuthRepository()
      ..identities[SessionSlot.customer] = user(id: 'c', fullName: null);
    profiles = FakeProfileRepository();
  });

  test(
    'saving the name renames the profile and refreshes the session user',
    () async {
      final ProviderContainer c = container();
      await c.read(sessionControllerProvider.future);

      final bool saved = await c
          .read(customerNameControllerProvider.notifier)
          .save('Aziza Karimova');

      expect(saved, isTrue);
      expect(profiles.renames, <String>['Aziza Karimova']);
      final SignedIn state =
          c.read(sessionControllerProvider).value! as SignedIn;
      expect(state.customerUser?.fullName, 'Aziza Karimova');
    },
  );

  test(
    'a profile of another account is refused and the session is untouched',
    () async {
      profiles.current = const CustomerProfile(
        id: 'someone-else',
        phone: '+998901234567',
        fullName: null,
      );
      final ProviderContainer c = container();
      await c.read(sessionControllerProvider.future);

      final bool saved = await c
          .read(customerNameControllerProvider.notifier)
          .save('Aziza Karimova');

      expect(saved, isFalse);
      expect(profiles.renames, isEmpty);
      final SignedIn state =
          c.read(sessionControllerProvider).value! as SignedIn;
      expect(state.customerUser?.fullName, isNull);
    },
  );

  test(
    'rename saves the profile and leaves the session until finish',
    () async {
      final ProviderContainer c = container();
      await c.read(sessionControllerProvider.future);
      final CustomerNameController controller = c.read(
        customerNameControllerProvider.notifier,
      );

      expect(await controller.rename('Aziza'), isTrue);

      expect(profiles.renames, <String>['Aziza']);
      SignedIn state = c.read(sessionControllerProvider).value! as SignedIn;
      expect(state.customerUser?.fullName, isNull);

      controller.finish();

      state = c.read(sessionControllerProvider).value! as SignedIn;
      expect(state.customerUser?.fullName, 'Aziza');
    },
  );

  test('finish without a rename changes nothing', () async {
    final ProviderContainer c = container();
    await c.read(sessionControllerProvider.future);

    c.read(customerNameControllerProvider.notifier).finish();

    final SignedIn state = c.read(sessionControllerProvider).value! as SignedIn;
    expect(state.customerUser?.fullName, isNull);
  });
}
