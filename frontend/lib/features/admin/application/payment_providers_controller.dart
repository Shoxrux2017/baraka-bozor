import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/report_unexpected_error.dart';
import '../../../core/network/api_failure.dart';
import '../domain/business_settings.dart';
import 'admin_providers.dart';

/// The four provider switches: the settings as the server last answered, the
/// providers whose change is on its way, and each provider's last refusal.
final class PaymentProvidersView {
  const PaymentProvidersView({
    required this.providers,
    this.busy = const <PaymentProvider>{},
    this.failures = const <PaymentProvider, ApiFailure>{},
  });

  final List<PaymentProviderSetting> providers;
  final Set<PaymentProvider> busy;

  /// Kept per provider, so one switch's success does not erase why another
  /// was refused.
  final Map<PaymentProvider, ApiFailure> failures;
}

/// Loads the providers and switches one at a time per provider. A switch
/// shows the server's answer, never the tap alone: until the answer arrives
/// the switch is busy, and a refusal leaves it where the server has it.
class PaymentProvidersController extends AsyncNotifier<PaymentProvidersView> {
  int _generation = 0;

  @override
  Future<PaymentProvidersView> build() async {
    _generation++;
    if (ref.watch(staffAccountProvider) == null) {
      return Completer<PaymentProvidersView>().future;
    }
    return PaymentProvidersView(
      providers: await ref.read(settingsRepositoryProvider).paymentProviders(),
    );
  }

  Future<void> setEnabled(
    PaymentProvider provider, {
    required bool enabled,
  }) async {
    final PaymentProvidersView? view = state.value;
    if (view == null || view.busy.contains(provider)) {
      return;
    }

    final int generation = _generation;
    state = AsyncData<PaymentProvidersView>(
      PaymentProvidersView(
        providers: view.providers,
        busy: <PaymentProvider>{...view.busy, provider},
        failures: <PaymentProvider, ApiFailure>{...view.failures}
          ..remove(provider),
      ),
    );

    ApiFailure? failure;
    PaymentProviderSetting? saved;
    try {
      saved = await ref
          .read(settingsRepositoryProvider)
          .setPaymentProviderEnabled(provider, enabled: enabled);
    } on ApiFailure catch (refusal) {
      failure = refusal;
    } catch (error, stackTrace) {
      failure = const UnexpectedFailure();
      reportUnexpectedError(
        error,
        stackTrace,
        'while switching a payment provider',
      );
    }

    // A rebuild — another account, the screen left and reopened — started
    // over; this answer belongs to the state it replaced.
    if (!ref.mounted || generation != _generation) {
      return;
    }

    final PaymentProvidersView current = state.requireValue;
    final PaymentProviderSetting? answer = saved;
    state = AsyncData<PaymentProvidersView>(
      PaymentProvidersView(
        providers: answer == null
            ? current.providers
            : <PaymentProviderSetting>[
                for (final PaymentProviderSetting setting in current.providers)
                  setting.provider == answer.provider ? answer : setting,
              ],
        busy: <PaymentProvider>{...current.busy}..remove(provider),
        failures: <PaymentProvider, ApiFailure>{
          ...current.failures,
          ...?(failure == null
              ? null
              : <PaymentProvider, ApiFailure>{provider: failure}),
        },
      ),
    );
  }
}

final AsyncNotifierProvider<PaymentProvidersController, PaymentProvidersView>
paymentProvidersControllerProvider =
    AsyncNotifierProvider.autoDispose<
      PaymentProvidersController,
      PaymentProvidersView
    >(PaymentProvidersController.new);
