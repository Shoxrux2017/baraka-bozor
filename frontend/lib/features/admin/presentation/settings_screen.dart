import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/platform/map_links.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../../core/widgets/kit/kit_card.dart';
import '../../../core/widgets/kit/kit_fields.dart';
import '../../../core/widgets/kit/kit_note.dart';
import '../../../core/widgets/panel/panel_card.dart';
import '../../../core/widgets/panel/panel_fields.dart';
import '../../../core/widgets/panel/panel_layout.dart';
import '../../../core/widgets/panel/panel_page_header.dart';
import '../../../core/widgets/panel/panel_segmented.dart';
import '../application/business_settings_controller.dart';
import '../application/payment_providers_controller.dart';
import '../domain/business_settings.dart';
import 'catalog_widgets.dart';
import 'settings_form_rules.dart';

/// The Admin's settings screen (interview 9.0, `docs/09-api-contracts.md`
/// section 44): every business setting in four cards, and the four online
/// payment providers as switches in a card beside them (`DL-102` (6)).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  /// The page content width from which the payment card stands beside the
  /// form; below it the card comes last.
  static const double twoColumnsWidth = 1000;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Keeps the form's state — what was typed — when the window crosses the
  /// two-column width and the form moves between a row and a column.
  final GlobalKey _formKey = GlobalKey(debugLabel: 'settings form');

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<BusinessSettings> settings = ref.watch(
      businessSettingsControllerProvider,
    );
    final BusinessSettings? loaded = settings.asData?.value;

    final Widget form = KeyedSubtree(
      key: _formKey,
      child: settings.when(
        skipLoadingOnReload: false,
        skipLoadingOnRefresh: !settings.hasError,
        data: (BusinessSettings value) => _SettingsForm(
          // Every answer is a new object, so a saved row always replaces the
          // form, even one saved within the same second or one the server did
          // not need to change.
          key: ObjectKey(value),
          settings: value,
        ),
        error: (Object error, StackTrace _) => _LoadFailure(
          failure: error is ApiFailure ? error : const UnexpectedFailure(),
          onRetry: () => ref.invalidate(businessSettingsControllerProvider),
        ),
        loading: () => const _Loading(),
      ),
    );

    return ListView(
      padding: panelPagePadding(MediaQuery.sizeOf(context).width),
      children: <Widget>[
        PanelPageHeader(
          title: l10n.settingsTitle,
          subtitle: loaded == null
              ? null
              : l10n.settingsUpdatedAt(TashkentTime.format(loaded.updatedAt)),
          subtitleKey: const ValueKey<String>('settings-updated-at'),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            if (constraints.maxWidth >= SettingsScreen.twoColumnsWidth) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: form),
                  const SizedBox(width: 20),
                  const SizedBox(width: 372, child: _PaymentProvidersCard()),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                form,
                const SizedBox(height: 16),
                const _PaymentProvidersCard(),
              ],
            );
          },
        ),
      ],
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
  late final TextEditingController _supportPhone;
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
    _supportPhone = TextEditingController(text: s.supportPhone ?? '');
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
      _supportPhone,
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
      supportPhone: SettingsFormRules.optional(_supportPhone.text),
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

  Future<void> _showOnMap() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? latitude = widget.settings.serviceCentreLatitude;
    final String? longitude = widget.settings.serviceCentreLongitude;
    if (latitude == null || longitude == null) {
      return;
    }

    // The saved centre opens, not the text being typed (`DL-102` (6)).
    final bool opened = await ref
        .read(mapPointLinksProvider)
        .open(latitude, longitude);
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsMapFailed)));
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
      Widget? suffixIcon,
      TextInputType? keyboard,
    }) {
      return KitLabeledField(
        label: label,
        field: TextFormField(
          key: ValueKey<String>('field-$apiKey'),
          controller: controller,
          enabled: !save.isBusy,
          keyboardType: keyboard,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (String _) => _submit(),
          style: const TextStyle(fontSize: 14, color: KitColors.ink),
          decoration: panelFieldDecoration(
            hint: hint,
            suffix: suffix,
            helper: helper,
          ).copyWith(suffixIcon: suffixIcon),
          onChanged: (String _) => _rejected.remove(apiKey),
          validator: (String? text) =>
              problem(rule(text ?? '')) ??
              (_rejected.contains(apiKey) ? l10n.fieldRejected : null),
        ),
      );
    }

    final Widget feeValue = _mode == ServiceFeeMode.fixed
        ? field(
            'service_fee_fixed_uzs',
            _feeAmount,
            l10n.settingsServiceFeeAmount,
            SettingsFormRules.amount,
            suffix: currency,
            helper: l10n.settingsOptionalHint,
            keyboard: TextInputType.number,
          )
        : field(
            'service_fee_percent',
            _feePercent,
            l10n.settingsServiceFeePercent,
            (String text) => SettingsFormRules.percent(text, required: false),
            helper: l10n.settingsOptionalHint,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          );
    const Icon clock = Icon(Icons.schedule, size: 20, color: KitColors.muted);
    const TextInputType coordinate = TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    );
    final bool hasCentre =
        widget.settings.serviceCentreLatitude != null &&
        widget.settings.serviceCentreLongitude != null;

    return Form(
      key: _form,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PanelCard(
            title: l10n.settingsPricingSection,
            children: <Widget>[
              const SizedBox(height: 16),
              PanelFieldRow(
                children: <Widget>[
                  field(
                    'markup_percent',
                    _markup,
                    l10n.settingsMarkup,
                    (String text) =>
                        SettingsFormRules.percent(text, required: true),
                    keyboard: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  field(
                    'price_tolerance_percent',
                    _tolerance,
                    l10n.settingsPriceTolerance,
                    (String text) =>
                        SettingsFormRules.percent(text, required: true),
                    helper: l10n.settingsPriceToleranceHint,
                    keyboard: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              KitLabeledField(
                label: l10n.settingsServiceFeeMode,
                field: Align(
                  alignment: Alignment.centerLeft,
                  child: PanelSegmented<ServiceFeeMode>(
                    key: const ValueKey<String>('field-service_fee_mode'),
                    segments: <PanelSegment<ServiceFeeMode>>[
                      (
                        value: ServiceFeeMode.fixed,
                        label: l10n.settingsServiceFeeFixed,
                        key: const ValueKey<String>('fee-mode-fixed'),
                        dot: null,
                      ),
                      (
                        value: ServiceFeeMode.percentage,
                        label: l10n.settingsServiceFeePercentage,
                        key: const ValueKey<String>('fee-mode-percentage'),
                        dot: null,
                      ),
                    ],
                    selected: _mode,
                    onSelected: save.isBusy
                        ? null
                        : (ServiceFeeMode mode) => setState(() => _mode = mode),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PanelFieldRow(
                minFieldWidth: 180,
                children: <Widget>[
                  feeValue,
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
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          PanelCard(
            title: l10n.settingsHoursSection,
            children: <Widget>[
              const SizedBox(height: 4),
              _CardHint(l10n.settingsHoursHint),
              const SizedBox(height: 16),
              PanelFieldRow(
                children: <Widget>[
                  field(
                    'opens_at',
                    _opensAt,
                    l10n.settingsOpensAt,
                    (String text) =>
                        SettingsFormRules.time(text) ??
                        SettingsFormRules.pairHalf(text, _closesAt.text),
                    hint: '09:00',
                    suffixIcon: clock,
                    keyboard: TextInputType.datetime,
                  ),
                  field(
                    'closes_at',
                    _closesAt,
                    l10n.settingsClosesAt,
                    (String text) =>
                        SettingsFormRules.closesAt(text, _opensAt.text),
                    hint: '21:00',
                    suffixIcon: clock,
                    keyboard: TextInputType.datetime,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          PanelCard(
            title: l10n.settingsAreaSection,
            children: <Widget>[
              const SizedBox(height: 4),
              _CardHint(l10n.settingsAreaHint),
              const SizedBox(height: 16),
              PanelFieldRow(
                minFieldWidth: 180,
                children: <Widget>[
                  field(
                    'service_centre_latitude',
                    _latitude,
                    l10n.settingsCentreLatitude,
                    (String text) =>
                        SettingsFormRules.latitude(text) ??
                        SettingsFormRules.pairHalf(text, _longitude.text),
                    hint: '41.311081',
                    keyboard: coordinate,
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
                    keyboard: coordinate,
                    helper: l10n.settingsOptionalHint,
                  ),
                  field(
                    'service_radius_km',
                    _radius,
                    l10n.settingsRadius,
                    SettingsFormRules.radius,
                    hint: '5.00',
                    keyboard: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    helper: l10n.settingsOptionalHint,
                  ),
                ],
              ),
              if (hasCentre) ...<Widget>[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey<String>('settings-map-link'),
                    style: TextButton.styleFrom(
                      foregroundColor: KitColors.primaryDark,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: _showOnMap,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(l10n.settingsShowOnMap),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          PanelCard(
            title: l10n.settingsDeliverySection,
            children: <Widget>[
              const SizedBox(height: 16),
              PanelFieldRow(
                children: <Widget>[
                  field(
                    'delivery_delay_threshold_minutes',
                    _delay,
                    l10n.settingsDelayThreshold,
                    SettingsFormRules.minutes,
                    keyboard: TextInputType.number,
                  ),
                  field(
                    'support_phone',
                    _supportPhone,
                    l10n.settingsSupportPhone,
                    SettingsFormRules.supportPhone,
                    hint: '+998712000000',
                    helper: l10n.settingsSupportPhoneHint,
                    keyboard: TextInputType.phone,
                  ),
                ],
              ),
            ],
          ),
          FailureMessage(save.failure),
          const SizedBox(height: 16),
          KitCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.settingsSaveNote,
                    style: const TextStyle(
                      fontSize: 12,
                      color: KitColors.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  key: const ValueKey<String>('settings-save'),
                  style: kitFilled(height: 46),
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
              ],
            ),
          ),
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
    SettingsFieldProblem.supportPhone => l10n.fieldSupportPhone,
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

    return PanelCard(
      key: const ValueKey<String>('providers-card'),
      title: l10n.providersTitle,
      children: <Widget>[
        const SizedBox(height: 4),
        _CardHint(l10n.providersIntro),
        const SizedBox(height: 14),
        KitNote(
          icon: Icons.schedule,
          tone: KitTone.amber,
          text: Text(l10n.providersCashOnlyNote),
        ),
        const SizedBox(height: 6),
        providers.when(
          skipLoadingOnReload: false,
          skipLoadingOnRefresh: !providers.hasError,
          data: (PaymentProvidersView view) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final PaymentProviderSetting setting
                  in view.providers) ...<Widget>[
                _ProviderRow(
                  setting: setting,
                  busy: view.busy.contains(setting.provider),
                  onChanged: (bool enabled) => ref
                      .read(paymentProvidersControllerProvider.notifier)
                      .setEnabled(setting.provider, enabled: enabled),
                ),
                FailureMessage(view.failures[setting.provider]),
              ],
              const SizedBox(height: 8),
              _CardHint(l10n.providersInstant, size: 11),
            ],
          ),
          error: (Object error, StackTrace _) => _LoadFailure(
            failure: error is ApiFailure ? error : const UnexpectedFailure(),
            onRetry: () => ref.invalidate(paymentProvidersControllerProvider),
          ),
          loading: () => const _Loading(),
        ),
      ],
    );
  }
}

/// One provider: its two letters on a `field` square (a spinner in place of
/// them while a switch is on its way), and the switch row with the brand and
/// whether it is on.
class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.setting,
    required this.busy,
    required this.onChanged,
  });

  final PaymentProviderSetting setting;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String brand = setting.provider.brand;

    return Row(
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: KitColors.field,
            borderRadius: BorderRadius.circular(11),
          ),
          child: SizedBox.square(
            dimension: 40,
            child: Center(
              child: busy
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: l10n.settingsSaving,
                      ),
                    )
                  : Text(
                      _monogram(setting.provider),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: KitColors.ink2,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CatalogSwitchRow(
            key: ValueKey<String>('provider-${setting.provider.code}'),
            switchKey: ValueKey<String>(
              'provider-${setting.provider.code}-switch',
            ),
            title: brand,
            hint: setting.isEnabled ? l10n.providerOn : l10n.providerOff,
            value: setting.isEnabled,
            onChanged: busy ? null : onChanged,
          ),
        ),
      ],
    );
  }
}

/// The two letters of a provider's square.
String _monogram(PaymentProvider provider) => switch (provider) {
  PaymentProvider.payme => 'Pm',
  PaymentProvider.click => 'Cl',
  PaymentProvider.paynet => 'Pn',
  PaymentProvider.xazna => 'xz',
};

/// A 12 px `muted` line under a card's title.
class _CardHint extends StatelessWidget {
  const _CardHint(this.text, {this.size = 12});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: size, color: KitColors.muted),
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
