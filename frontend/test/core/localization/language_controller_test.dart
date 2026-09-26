import 'dart:ui' show Locale;

import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/language_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/in_memory_stores.dart';

void main() {
  late InMemoryPreferenceStore preferences;

  ProviderContainer container(Locale device) {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        preferenceStoreProvider.overrideWithValue(preferences),
        deviceLocaleProvider.overrideWithValue(device),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    preferences = InMemoryPreferenceStore();
  });

  group('AppLanguage.forDevice', () {
    test('Russian devices get Russian, every other device gets Uzbek', () {
      expect(AppLanguage.forDevice(const Locale('ru', 'RU')), AppLanguage.ru);
      expect(AppLanguage.forDevice(const Locale('uz')), AppLanguage.uz);
      expect(AppLanguage.forDevice(const Locale('en', 'US')), AppLanguage.uz);
      expect(AppLanguage.forDevice(const Locale('kk')), AppLanguage.uz);
    });
  });

  group('LanguageController', () {
    test('defaults to the device language when nothing is stored', () async {
      expect(
        await container(const Locale('ru'))
            .read(languageControllerProvider.future),
        AppLanguage.ru,
      );
      expect(
        await container(const Locale('en'))
            .read(languageControllerProvider.future),
        AppLanguage.uz,
      );
    });

    test('a stored choice wins over the device language', () async {
      preferences.values[LanguageController.preferenceKey] = 'uz';

      expect(
        await container(const Locale('ru'))
            .read(languageControllerProvider.future),
        AppLanguage.uz,
      );
    });

    test('an unknown stored value falls back to the device language', () async {
      preferences.values[LanguageController.preferenceKey] = 'en';

      expect(
        await container(const Locale('ru'))
            .read(languageControllerProvider.future),
        AppLanguage.ru,
      );
    });

    test('selecting a language stores it and takes effect at once', () async {
      final ProviderContainer c = container(const Locale('uz'));
      await c.read(languageControllerProvider.future);

      await c.read(languageControllerProvider.notifier).select(AppLanguage.ru);

      expect(c.read(languageControllerProvider).value, AppLanguage.ru);
      expect(preferences.values[LanguageController.preferenceKey], 'ru');
    });
  });
}
