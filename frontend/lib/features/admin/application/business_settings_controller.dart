import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/mutation_state.dart';
import '../domain/business_settings.dart';
import 'admin_providers.dart';

/// The business settings the settings screen shows, loaded on the staff
/// session while the screen is open.
class BusinessSettingsController extends AsyncNotifier<BusinessSettings> {
  @override
  Future<BusinessSettings> build() {
    ref.watch(staffAccountProvider);
    return ref.read(settingsRepositoryProvider).businessSettings();
  }

  /// Shows the row the server saved, which is the new truth.
  void showSaved(BusinessSettings saved) {
    state = AsyncData<BusinessSettings>(saved);
  }
}

final AsyncNotifierProvider<BusinessSettingsController, BusinessSettings>
businessSettingsControllerProvider =
    AsyncNotifierProvider.autoDispose<
      BusinessSettingsController,
      BusinessSettings
    >(BusinessSettingsController.new);

/// Saves the settings form. A double tap sends once; a refusal stays in the
/// state for the form to show, field errors included.
class SaveBusinessSettingsController extends MutationNotifier {
  Future<bool> save(BusinessSettingsDraft draft) {
    final String? account = ref.read(staffAccountProvider);

    return run(() async {
      final BusinessSettings saved = await ref
          .read(settingsRepositoryProvider)
          .saveBusinessSettings(draft);

      // An answer that arrives after a different account signed in says
      // nothing to the screen that account now sees.
      if (ref.mounted && ref.read(staffAccountProvider) == account) {
        ref.read(businessSettingsControllerProvider.notifier).showSaved(saved);
      }
    });
  }
}

final NotifierProvider<SaveBusinessSettingsController, MutationState>
saveBusinessSettingsControllerProvider =
    NotifierProvider.autoDispose<SaveBusinessSettingsController, MutationState>(
      SaveBusinessSettingsController.new,
    );
