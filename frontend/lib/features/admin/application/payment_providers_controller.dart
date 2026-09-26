import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/report_unexpected_error.dart';
import '../../../core/network/api_failure.dart';
import '../domain/business_settings.dart';
import 'admin_providers.dart';

/// The four provider switches: the settings as the server last answered, the
/// providers whose change is on its way, and the last refusal to explain.
final class PaymentProvidersView {
  const PaymentProvidersView({
    required this.providers,
    this.busy = const <PaymentProvider>{},
    this.failure,
  });

  final List<PaymentProviderSetting> providers;
  final Set<PaymentProvider> busy;
  final ApiFailure? failure;

  PaymentProvidersView _with({
    List<PaymentProviderSetting>? providers,
    Set<PaymentProvider>? busy,
    required ApiFailure? failure,
  }) => PaymentProvidersView(
    providers: providers ?? this.providers,
    busy: busy ?? this.busy,
    failure: failure,
  );
}

/// Loads the providers and switches one at a time per provider. A switch
/// shows the server's answer, never the tap alone: until the answer arrives
/// the switch is busy, and a refusal leaves it where the server has it.
class PaymentProvidersController extends AsyncNotifier<PaymentProvidersView> {
  int _generation = 0;

  @override
  Future<PaymentProvidersView> build() async {
    ref.watch(staffAccountProvider);
    _generation++;
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
      view._with(
        busy: <PaymentProvider>{...view.busy, provider},
        failure: null,
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
    state = AsyncData<PaymentProvidersView>(
      current._with(
        providers: saved == null
            ? null
            : <PaymentProviderSetting>[
                for (final PaymentProviderSetting setting in current.providers)
                  setting.provider == saved.provider ? saved : setting,
              ],
        busy: <PaymentProvider>{...current.busy}..remove(provider),
        failure: failure,
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
