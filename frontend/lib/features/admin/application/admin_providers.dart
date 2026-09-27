import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/settings_api.dart';
import '../data/settings_repository_impl.dart';
import '../domain/settings_repository.dart';

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
      (Ref ref) =>
          SettingsRepositoryImpl(SettingsApi(ref.watch(apiClientProvider))),
    );
