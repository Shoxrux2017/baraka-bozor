import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/state/mutation_state.dart';
import '../domain/business_settings.dart';
import 'admin_providers.dart';

/// The business settings the settings screen shows, loaded on the staff
/// session while the screen is open. Without a staff account there is
/// nothing to load: the session guard is taking the screen away.
class BusinessSettingsController extends AsyncNotifier<BusinessSettings> {
  @override
  Future<BusinessSettings> build() {
    if (ref.watch(staffAccountProvider) == null) {
      return Completer<BusinessSettings>().future;
    }
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
/// state for the form to show, field errors included. Another account
/// starts it over, and a save answered after the account changed counts as
/// cancelled — nothing is shown for it, and it is not reported as saved.
class SaveBusinessSettingsController extends MutationNotifier {
  @override
  MutationState build() {
    ref.watch(staffAccountProvider);
    return super.build();
  }

  /// Saves what [draft] changed from [base], the settings the form showed.
  Future<bool> save(BusinessSettingsDraft draft, BusinessSettings base) {
    final String? account = ref.read(staffAccountProvider);

    return run(() async {
      final BusinessSettings saved = await ref
          .read(settingsRepositoryProvider)
          .saveBusinessSettings(draft, base);

      if (!ref.mounted || ref.read(staffAccountProvider) != account) {
        throw const CancelledFailure();
      }
      ref.read(businessSettingsControllerProvider.notifier).showSaved(saved);
    });
  }
}

final NotifierProvider<SaveBusinessSettingsController, MutationState>
saveBusinessSettingsControllerProvider =
    NotifierProvider.autoDispose<SaveBusinessSettingsController, MutationState>(
      SaveBusinessSettingsController.new,
    );
