import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'app_language.dart';

/// The interface language: chosen in the app, defaulting to the device
/// language, remembered on the device (interview topic 8.2), and reported to
/// the server for every confirmed session so push texts arrive in it.
///
/// Dependencies come from the root providers, so a test overrides
/// `preferenceStoreProvider` and `deviceLocaleProvider`.
class LanguageController extends AsyncNotifier<AppLanguage> {
  static const String preferenceKey = 'language';

  @override
  Future<AppLanguage> build() async {
    final AppLanguage? stored = AppLanguage.tryParse(
      await ref.read(preferenceStoreProvider).read(preferenceKey),
    );
    return stored ?? AppLanguage.forDevice(ref.read(deviceLocaleProvider));
  }

  Future<void> select(AppLanguage language) async {
    await ref.read(preferenceStoreProvider).write(preferenceKey, language.code);
    state = AsyncData<AppLanguage>(language);
    await ref.read(sessionControllerProvider.notifier).reportLanguage(language);
  }
}
