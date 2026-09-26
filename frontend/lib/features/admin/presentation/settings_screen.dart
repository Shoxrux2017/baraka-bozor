import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/business_settings_controller.dart';
import '../application/payment_providers_controller.dart';
import '../domain/business_settings.dart';
import 'settings_form_rules.dart';

/// The Admin's settings screen (interview 9.0, `docs/09-api-contracts.md`
/// section 44): every business setting in one form, and the four online
/// payment providers as switches.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<BusinessSettings> settings = ref.watch(
      businessSettingsControllerProvider,
    );

    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Text(
              l10n.settingsTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            settings.when(
              skipLoadingOnReload: false,
              data: (BusinessSettings value) => _SettingsForm(
                // Every answer is a new object, so a saved row always
                // replaces the form, even one saved within the same second or
                // one the server did not need to change.
                key: ObjectKey(value),
                settings: value,
              ),
              error: (Object error, StackTrace _) => _LoadFailure(
                failure: error is ApiFailure
                    ? error
                    : const UnexpectedFailure(),
                onRetry: () =>
                    ref.invalidate(businessSettingsControllerProvider),
              ),
              loading: () => const _Loading(),
            ),
            const SizedBox(height: 32),
            const _PaymentProvidersCard(),
          ],
        ),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.settings, super.key});

  final BusinessSettings settings;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  late final TextEditingController _markup;
  late final TextEditingController _feeAmount;
  late final TextEditingController _feePercent;
  late final TextEditingController _deliveryFee;
  late final TextEditingController _minimumOrder;
  late final TextEditingController _tolerance;
  late final TextEditingController _opensAt;
  late final TextEditingController _closesAt;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _radius;
  late final TextEditingController _delay;
  late ServiceFeeMode _mode;

  /// The fields the server refused in the last save, by API name. Each is
  /// shown as refused until it is edited or the form is sent again.
  Set<String> _rejected = <String>{};

  @override
  void initState() {
    super.initState();
    final BusinessSettings s = widget.settings;
    String money(int? amount) =>
        amount == null ? '' : MoneyFormat.grouped(amount);

    _markup = TextEditingController(text: s.markupPercent);
    _feeAmount = TextEditingController(text: money(s.serviceFeeFixedUzs));
    _feePercent = TextEditingController(text: s.serviceFeePercent ?? '');
    _deliveryFee = TextEditingController(text: money(s.deliveryFeeUzs));
    _minimumOrder = TextEditingController(text: money(s.minimumOrderUzs));
    _tolerance = TextEditingController(text: s.priceTolerancePercent);
    _opensAt = TextEditingController(text: s.opensAt ?? '');
    _closesAt = TextEditingController(text: s.closesAt ?? '');
    _latitude = TextEditingController(text: s.serviceCentreLatitude ?? '');
    _longitude = TextEditingController(text: s.serviceCentreLongitude ?? '');
    _radius = TextEditingController(text: s.serviceRadiusKm ?? '');
    _delay = TextEditingController(
      text: s.deliveryDelayThresholdMinutes.toString(),
    );
    _mode = s.serviceFeeMode;
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _markup,
      _feeAmount,
      _feePercent,
      _deliveryFee,
      _minimumOrder,
      _tolerance,
      _opensAt,
      _closesAt,
      _latitude,
      _longitude,
      _radius,
      _delay,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  BusinessSettingsDraft _draft() {
    final bool fixed = _mode == ServiceFeeMode.fixed;

    return BusinessSettingsDraft(
      markupPercent: _markup.text.trim(),
      serviceFeeMode: _mode,
      serviceFeeFixedUzs: fixed
          ? SettingsFormRules.amountValue(_feeAmount.text)
          : null,
      serviceFeePercent: fixed
          ? null
          : SettingsFormRules.optional(_feePercent.text),
      deliveryFeeUzs: SettingsFormRules.amountValue(_deliveryFee.text),
      minimumOrderUzs: SettingsFormRules.amountValue(_minimumOrder.text),
      priceTolerancePercent: _tolerance.text.trim(),
      opensAt: SettingsFormRules.optional(_opensAt.text),
      closesAt: SettingsFormRules.optional(_closesAt.text),
      serviceCentreLatitude: SettingsFormRules.optional(_latitude.text),
      serviceCentreLongitude: SettingsFormRules.optional(_longitude.text),
      serviceRadiusKm: SettingsFormRules.optional(_radius.text),
      deliveryDelayThresholdMinutes: int.parse(_delay.text.trim()),
    );
  }

  Future<void> _submit() async {
    if (ref.read(saveBusinessSettingsControllerProvider).isBusy) {
      return;
    }
    _rejected = <String>{};
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BusinessSettingsDraft draft = _draft();

    if (draft == BusinessSettingsDraft.fromSettings(widget.settings)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsNoChanges)));
      return;
    }

    final bool saved = await ref
        .read(saveBusinessSettingsControllerProvider.notifier)
        .save(draft, widget.settings);
    final String savedText = l10n.settingsSaved;

    if (saved) {
      messenger.showSnackBar(SnackBar(content: Text(savedText)));
      return;
    }

    if (!mounted) {
      return;
    }
    final ApiFailure? failure = ref
        .read(saveBusinessSettingsControllerProvider)
        .failure;
    if (failure is ApiRefusal && failure.code == 'validation_failed') {
      _rejected = failure.error.errors.keys.toSet();
      _form.currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState save = ref.watch(
      saveBusinessSettingsControllerProvider,
    );
    final String currency = MoneyFormat.currency(
      AppLanguage.tryParse(Localizations.localeOf(context).languageCode) ??
          AppLanguage.uz,
    );

    String? problem(SettingsFieldProblem? found) =>
        found == null ? null : _problemText(l10n, found);

    Widget field(
      String apiKey,
      TextEditingController controller,
      String label,
      SettingsFieldProblem? Function(String text) rule, {
      String? suffix,
      String? hint,
      String? helper,
      TextInputType? keyboard,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          key: ValueKey<String>('field-$apiKey'),
          controller: controller,
          enabled: !save.isBusy,
          keyboardType: keyboard,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (String _) => _submit(),
          decoration: InputDecoration(
            labelText: label,
            suffixText: suffix,
            hintText: hint,
            helperText: helper,
            helperMaxLines: 2,
            errorMaxLines: 3,
            border: const OutlineInputBorder(),
          ),
          onChanged: (String _) => _rejected.remove(apiKey),
          validator: (String? text) =>
              problem(rule(text ?? '')) ??
              (_rejected.contains(apiKey) ? l10n.fieldRejected : null),
        ),
      );
    }

    return Form(
      key: _form,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SectionTitle(l10n.settingsPricingSection),
          field(
            'markup_percent',
            _markup,
            l10n.settingsMarkup,
            (String text) => SettingsFormRules.percent(text, required: true),
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          Text(l10n.settingsServiceFeeMode),
          const SizedBox(height: 8),
          Semantics(
            label: l10n.settingsServiceFeeMode,
            container: true,
            child: SegmentedButton<ServiceFeeMode>(
              key: const ValueKey<String>('field-service_fee_mode'),
              segments: <ButtonSegment<ServiceFeeMode>>[
                ButtonSegment<ServiceFeeMode>(
                  value: ServiceFeeMode.fixed,
                  label: Text(l10n.settingsServiceFeeFixed),
                ),
                ButtonSegment<ServiceFeeMode>(
                  value: ServiceFeeMode.percentage,
                  label: Text(l10n.settingsServiceFeePercentage),
                ),
              ],
              selected: <ServiceFeeMode>{_mode},
              onSelectionChanged: save.isBusy
                  ? null
                  : (Set<ServiceFeeMode> selected) =>
                        setState(() => _mode = selected.single),
            ),
          ),
          const SizedBox(height: 12),
          if (_mode == ServiceFeeMode.fixed)
            field(
              'service_fee_fixed_uzs',
              _feeAmount,
              l10n.settingsServiceFeeAmount,
              SettingsFormRules.amount,
              suffix: currency,
              helper: l10n.settingsOptionalHint,
              keyboard: TextInputType.number,
            )
          else
            field(
              'service_fee_percent',
              _feePercent,
              l10n.settingsServiceFeePercent,
              (String text) => SettingsFormRules.percent(text, required: false),
              helper: l10n.settingsOptionalHint,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),
          field(
            'delivery_fee_uzs',
            _deliveryFee,
            l10n.settingsDeliveryFee,
            SettingsFormRules.amount,
            suffix: currency,
            helper: l10n.settingsOptionalHint,
            keyboard: TextInputType.number,
          ),
          field(
            'minimum_order_uzs',
            _minimumOrder,
            l10n.settingsMinimumOrder,
            SettingsFormRules.amount,
            suffix: currency,
            helper: l10n.settingsOptionalHint,
            keyboard: TextInputType.number,
          ),
          field(
            'price_tolerance_percent',
            _tolerance,
            l10n.settingsPriceTolerance,
            (String text) => SettingsFormRules.percent(text, required: true),
            helper: l10n.settingsPriceToleranceHint,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          _SectionTitle(l10n.settingsHoursSection),
          field(
            'opens_at',
            _opensAt,
            l10n.settingsOpensAt,
            (String text) =>
                SettingsFormRules.time(text) ??
                SettingsFormRules.pairHalf(text, _closesAt.text),
            hint: '09:00',
            helper:
                '${l10n.settingsTashkentTimeHint}. ${l10n.settingsOptionalHint}',
            keyboard: TextInputType.datetime,
          ),
          field(
            'closes_at',
            _closesAt,
            l10n.settingsClosesAt,
            (String text) => SettingsFormRules.closesAt(text, _opensAt.text),
            hint: '21:00',
            helper:
                '${l10n.settingsTashkentTimeHint}. ${l10n.settingsOptionalHint}',
            keyboard: TextInputType.datetime,
          ),
          _SectionTitle(l10n.settingsAreaSection),
          field(
            'service_centre_latitude',
            _latitude,
            l10n.settingsCentreLatitude,
            (String text) =>
                SettingsFormRules.latitude(text) ??
                SettingsFormRules.pairHalf(text, _longitude.text),
            hint: '41.311081',
            keyboard: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            helper: l10n.settingsOptionalHint,
          ),
          field(
            'service_centre_longitude',
            _longitude,
            l10n.settingsCentreLongitude,
            (String text) =>
                SettingsFormRules.longitude(text) ??
                SettingsFormRules.pairHalf(text, _latitude.text),
            hint: '69.240562',
            keyboard: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            helper: l10n.settingsOptionalHint,
          ),
          field(
            'service_radius_km',
            _radius,
            l10n.settingsRadius,
            SettingsFormRules.radius,
            hint: '5.00',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            helper: l10n.settingsOptionalHint,
          ),
          _SectionTitle(l10n.settingsDeliverySection),
          field(
            'delivery_delay_threshold_minutes',
            _delay,
            l10n.settingsDelayThreshold,
            SettingsFormRules.minutes,
            keyboard: TextInputType.number,
          ),
          Text(
            l10n.settingsUpdatedAt(
              TashkentTime.format(widget.settings.updatedAt),
            ),
            key: const ValueKey<String>('settings-updated-at'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              key: const ValueKey<String>('settings-save'),
              onPressed: save.isBusy ? null : _submit,
              child: save.isBusy
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: l10n.settingsSaving,
                      ),
                    )
                  : Text(l10n.saveButton),
            ),
          ),
          FailureMessage(save.failure),
        ],
      ),
    );
  }

  static String _problemText(
    AppLocalizations l10n,
    SettingsFieldProblem problem,
  ) => switch (problem) {
    SettingsFieldProblem.required => l10n.fieldRequired,
    SettingsFieldProblem.percent => l10n.fieldPercent,
    SettingsFieldProblem.amount => l10n.fieldAmount,
    SettingsFieldProblem.time => l10n.fieldTime,
    SettingsFieldProblem.latitude => l10n.fieldLatitude,
    SettingsFieldProblem.longitude => l10n.fieldLongitude,
    SettingsFieldProblem.radius => l10n.fieldRadius,
    SettingsFieldProblem.minutes => l10n.fieldMinutes,
    SettingsFieldProblem.pairIncomplete => l10n.fieldPairIncomplete,
    SettingsFieldProblem.sameTime => l10n.fieldSameTime,
  };
}

class _PaymentProvidersCard extends ConsumerWidget {
  const _PaymentProvidersCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<PaymentProvidersView> providers = ref.watch(
      paymentProvidersControllerProvider,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.providersTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(l10n.providersIntro),
            const SizedBox(height: 8),
            providers.when(
              skipLoadingOnReload: false,
              data: (PaymentProvidersView view) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final PaymentProviderSetting setting
                      in view.providers) ...<Widget>[
                    SwitchListTile(
                      key: ValueKey<String>(
                        'provider-${setting.provider.code}',
                      ),
                      title: Text(setting.provider.brand),
                      value: setting.isEnabled,
                      secondary: view.busy.contains(setting.provider)
                          ? SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                semanticsLabel: l10n.settingsSaving,
                              ),
                            )
                          : null,
                      onChanged: view.busy.contains(setting.provider)
                          ? null
                          : (bool enabled) => ref
                                .read(
                                  paymentProvidersControllerProvider.notifier,
                                )
                                .setEnabled(setting.provider, enabled: enabled),
                    ),
                    FailureMessage(view.failures[setting.provider]),
                  ],
                ],
              ),
              error: (Object error, StackTrace _) => _LoadFailure(
                failure: error is ApiFailure
                    ? error
                    : const UnexpectedFailure(),
                onRetry: () =>
                    ref.invalidate(paymentProvidersControllerProvider),
              ),
              loading: () => const _Loading(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.failure, required this.onRetry});

  final ApiFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FailureMessage(failure),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onRetry,
          child: Text(AppLocalizations.of(context).retryButton),
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
