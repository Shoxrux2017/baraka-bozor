import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../application/addresses_controllers.dart';
import '../domain/addresses.dart';
import 'address_label_chips.dart';
import 'address_point_step.dart';
import 'map/address_map.dart';

/// The Customer's addresses (`docs/09-api-contracts.md` section 13): the
/// list, a new one, an edit, and removal after a confirmation.
class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<Address>> addresses = ref.watch(addressesProvider);
    final MutationState actions = ref.watch(addressListActionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addressesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey<String>('address-new'),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(l10n.addressNew),
        onPressed: () => context.push(AppPaths.customerNewAddress),
      ),
      body: SafeArea(
        child: UnderActiveMode(
          child: addresses.when(
            skipLoadingOnReload: false,
            skipLoadingOnRefresh: !addresses.hasError,
            data: (List<Address> addresses) => ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: <Widget>[
                FailureMessage(actions.failure),
                if (addresses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.addressNone, textAlign: TextAlign.center),
                  ),
                for (final Address address in addresses)
                  ListTile(
                    key: ValueKey<String>('address-${address.id}'),
                    leading: const Icon(Icons.place_outlined),
                    title: Text(
                      address.label ?? '${address.street}, ${address.house}',
                    ),
                    subtitle: address.label == null
                        ? null
                        : Text('${address.street}, ${address.house}'),
                    onTap: () =>
                        context.push(AppPaths.customerAddress(address.id)),
                    trailing: IconButton(
                      key: ValueKey<String>('address-remove-${address.id}'),
                      tooltip: l10n.addressRemove,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: actions.isBusy
                          ? null
                          : () => _remove(context, ref, address),
                    ),
                  ),
              ],
            ),
            error: (Object error, StackTrace _) => _Retry(
              failure: error is ApiFailure ? error : const UnexpectedFailure(),
              onRetry: () => ref.invalidate(addressesProvider),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }

  static Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    Address address,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            content: Text(l10n.addressRemoveConfirm),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancelButton),
              ),
              FilledButton(
                key: const ValueKey<String>('address-remove-confirm'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.addressRemove),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) {
      await ref.read(addressListActionsProvider.notifier).remove(address.id);
    }
  }
}

/// A new address, or an edit of [addressId]. A new address is two steps on
/// one screen: the point on the map, then the details under a still preview
/// of it; an edit opens on the details. A point outside the service area is
/// refused with both distances, as the server answers (`BR-AREA-001`).
class AddressFormScreen extends ConsumerWidget {
  const AddressFormScreen({required this.addressId, super.key});

  final String? addressId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? id = addressId;

    if (id == null) {
      return const _AddressForm(address: null);
    }

    final AsyncValue<List<Address>> addresses = ref.watch(addressesProvider);
    return addresses.when(
      skipLoadingOnReload: false,
      // A retry after a failed load shows progress; a reload after a
      // save keeps the form.
      skipLoadingOnRefresh: !addresses.hasError,
      data: (List<Address> addresses) {
        final Address? address = addresses
            .where((Address a) => a.id == id)
            .firstOrNull;
        return address == null
            ? _Plain(child: Center(child: Text(l10n.errorNotFound)))
            : _AddressForm(address: address);
      },
      error: (Object error, StackTrace _) => _Plain(
        child: _Retry(
          failure: error is ApiFailure ? error : const UnexpectedFailure(),
          onRetry: () => ref.invalidate(addressesProvider),
        ),
      ),
      loading: () =>
          const _Plain(child: Center(child: CircularProgressIndicator())),
    );
  }
}

/// The edit screen while its address is not there to show.
class _Plain extends StatelessWidget {
  const _Plain({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: kitAppBar(title: AppLocalizations.of(context).addressEdit),
      body: SafeArea(child: UnderActiveMode(child: child)),
    );
  }
}

enum _Step { point, details }

class _AddressForm extends ConsumerStatefulWidget {
  const _AddressForm({required this.address});

  final Address? address;

  @override
  ConsumerState<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends ConsumerState<_AddressForm> {
  static const int _streetMax = 160;

  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _label = TextEditingController();
  late final TextEditingController _street = TextEditingController(
    text: widget.address?.street ?? '',
  );
  late final TextEditingController _house = TextEditingController(
    text: widget.address?.house ?? '',
  );
  late final TextEditingController _apartment = TextEditingController(
    text: widget.address?.apartment ?? '',
  );
  late final TextEditingController _landmark = TextEditingController(
    text: widget.address?.landmark ?? '',
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.address?.deliveryNote ?? '',
  );
  late GeoPoint _point = widget.address?.point ?? defaultMapCentre;

  /// A new address starts on the map, an edit on the details.
  late _Step _step = _isNew ? _Step.point : _Step.details;

  /// Chosen from the address's label once the language is known.
  AddressLabelKind? _kind;

  /// The point of the last save, so a refusal of the area is shown only
  /// while the pin is still where it was refused.
  GeoPoint? _sentPoint;

  /// The words the street was last filled with from the map step.
  String? _filledWords;

  /// The map step was opened from the details of a new address, so back
  /// from it returns there.
  bool _backToDetails = false;

  bool get _isNew => widget.address == null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_kind == null) {
      final String? label = widget.address?.label;
      final AddressLabelKind kind = addressLabelKindOf(
        label,
        AppLocalizations.of(context),
      );
      if (kind == AddressLabelKind.custom) {
        _label.text = label ?? '';
      }
      _kind = kind;
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _label,
      _street,
      _house,
      _apartment,
      _landmark,
      _note,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  static String? _optional(String text) {
    final String value = text.trim();
    return value.isEmpty ? null : value;
  }

  /// The word, or the Customer's own text, the address is named by.
  String? _labelValue(AppLocalizations l10n) =>
      switch (_kind ?? AddressLabelKind.none) {
        AddressLabelKind.none => null,
        AddressLabelKind.home => l10n.addressLabelHome,
        AddressLabelKind.work => l10n.addressLabelWork,
        AddressLabelKind.custom => _optional(_label.text),
      };

  /// The words may fill the street on a new address while it is empty or
  /// still holds what the words filled before, unedited.
  bool get _streetTakesWords =>
      _isNew && (_street.text.trim().isEmpty || _street.text == _filledWords);

  /// The Customer confirmed the pin: the details follow. The words they typed
  /// fill the street where [_streetTakesWords] allows.
  void _confirmed(AddressPointResult result) {
    setState(() {
      _point = result.point;
      final String? words = result.words;
      if (words != null && _streetTakesWords) {
        final String filled = String.fromCharCodes(
          words.runes.take(_streetMax),
        );
        _street.text = filled;
        _filledWords = filled;
      }
      _backToDetails = false;
      _step = _Step.details;
    });
  }

  /// Back walks the steps; nothing moves while a save runs.
  void _back(bool didPop) {
    if (didPop || ref.read(addressFormControllerProvider).isBusy) {
      return;
    }
    setState(() {
      _step = _isNew && !_backToDetails ? _Step.point : _Step.details;
      _backToDetails = false;
    });
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Address? address = widget.address;
    final AddressDraft draft = AddressDraft(
      label: _labelValue(l10n),
      point: _point,
      street: _street.text.trim(),
      house: _house.text.trim(),
      apartment: _optional(_apartment.text),
      landmark: _optional(_landmark.text),
      deliveryNote: _optional(_note.text),
    );
    // An edit that changes nothing sends nothing and says so (`DL-27` (3)).
    if (address != null && draft.sameAs(address)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.noChanges)));
      return;
    }
    final String savedText = l10n.addressSaved;
    setState(() => _sentPoint = _point);

    final Address? saved = await ref
        .read(addressFormControllerProvider.notifier)
        .save(address, draft);
    // The Customer may have signed out while the save ran; where they went
    // stays on screen.
    if (!mounted || saved == null) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(savedText)));
    if (context.canPop()) {
      // A new address goes back to whoever asked for it (`DL-75`).
      context.pop<Address>(address == null ? saved : null);
    } else {
      context.go(AppPaths.customerAddresses);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState change = ref.watch(addressFormControllerProvider);
    final bool onPoint = _step == _Step.point;
    final String title = onPoint
        ? l10n.addressPointTitle
        : _isNew
        ? l10n.addressNew
        : l10n.addressEdit;

    return PopScope(
      canPop:
          !change.isBusy && (_isNew ? onPoint && !_backToDetails : !onPoint),
      onPopInvokedWithResult: (bool didPop, Object? _) => _back(didPop),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: kitAppBar(title: title),
        body: UnderActiveMode(
          child: onPoint
              ? AddressPointStep(
                  key: const ValueKey<String>('address-point-step'),
                  initial: _point,
                  keepsWords: _streetTakesWords,
                  onConfirmed: _confirmed,
                )
              : _details(l10n, change),
        ),
      ),
    );
  }

  Widget _details(AppLocalizations l10n, MutationState change) {
    final bool custom = _kind == AddressLabelKind.custom;
    return Form(
      key: _form,
      child: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              key: const ValueKey<String>('address-form'),
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _preview(l10n, change),
                const SizedBox(height: 16),
                _field(
                  'street',
                  _street,
                  l10n.addressFieldStreet,
                  _streetMax,
                  enabled: !change.isBusy,
                  required: true,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _field(
                        'house',
                        _house,
                        l10n.addressHouse,
                        40,
                        enabled: !change.isBusy,
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        'apartment',
                        _apartment,
                        l10n.addressFieldApartment,
                        40,
                        enabled: !change.isBusy,
                      ),
                    ),
                  ],
                ),
                _field(
                  'landmark',
                  _landmark,
                  l10n.addressLandmark,
                  160,
                  enabled: !change.isBusy,
                  hint: l10n.addressLandmarkHint,
                ),
                _field(
                  'delivery_note',
                  _note,
                  l10n.addressFieldNote,
                  300,
                  enabled: !change.isBusy,
                  hint: l10n.addressNoteHint,
                  maxLines: 3,
                  counter: true,
                ),
                Text(
                  l10n.addressLabelTitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: KitColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                AddressLabelChips(
                  kind: _kind ?? AddressLabelKind.none,
                  enabled: !change.isBusy,
                  onChanged: (AddressLabelKind kind) =>
                      setState(() => _kind = kind),
                ),
                if (custom) ...<Widget>[
                  const SizedBox(height: 14),
                  _field(
                    'label',
                    _label,
                    l10n.addressLabelName,
                    60,
                    enabled: !change.isBusy,
                  ),
                ],
              ],
            ),
          ),
          _footer(l10n, change),
        ],
      ),
    );
  }

  /// The still map of the point with "Изменить точку" over its corner.
  Widget _preview(AppLocalizations l10n, MutationState change) {
    final AddressMap map = ref.watch(addressMapProvider);
    return SizedBox(
      height: 118,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) => Stack(
            fit: StackFit.expand,
            children: <Widget>[
              IgnorePointer(child: map.preview(point: _point)),
              Positioned(
                right: 10,
                bottom: 10,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: box.maxWidth * 0.6 - 11,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Material(
                      color: Colors.white,
                      elevation: 2,
                      shadowColor: const Color(0x33000000),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        key: const ValueKey<String>('address-change-point'),
                        borderRadius: BorderRadius.circular(10),
                        onTap: change.isBusy
                            ? null
                            : () => setState(() {
                                _backToDetails = _isNew;
                                _step = _Step.point;
                              }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.edit_location_alt_outlined,
                                size: 16,
                                color: change.isBusy
                                    ? KitColors.muted
                                    : KitColors.primaryDark,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  l10n.addressChangePoint,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: change.isBusy
                                        ? KitColors.muted
                                        : KitColors.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A field of the kit: the label above, a soft fill, radius 14.
  Widget _field(
    String key,
    TextEditingController controller,
    String label,
    int max, {
    required bool enabled,
    bool required = false,
    int maxLines = 1,
    String? hint,
    bool counter = false,
  }) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            required ? '$label *' : label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: KitColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: ValueKey<String>('field-$key'),
            controller: controller,
            enabled: enabled,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 14, color: KitColors.ink),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 14, color: KitColors.muted),
              filled: true,
              fillColor: KitColors.field,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
              border: border(KitColors.line),
              enabledBorder: border(KitColors.line),
              disabledBorder: border(KitColors.line),
              focusedBorder: border(KitColors.primary),
              errorBorder: border(KitColors.danger),
              focusedErrorBorder: border(KitColors.danger),
              errorStyle: const TextStyle(
                fontSize: 12,
                color: KitColors.danger,
              ),
            ),
            validator: (String? text) {
              final String value = (text ?? '').trim();
              if (required && value.isEmpty) {
                return l10n.fieldRequired;
              }
              return value.runes.length > max ? l10n.fieldTooLong(max) : null;
            },
          ),
          if (counter)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder:
                      (BuildContext _, TextEditingValue value, Widget? _) =>
                          Text(
                            '${value.text.runes.length} / $max',
                            key: ValueKey<String>('counter-$key'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: KitColors.muted,
                            ),
                          ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The bar under the form (the cart's footer look): a refusal above the
  /// save button.
  Widget _footer(AppLocalizations l10n, MutationState change) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: _SaveFailure(
                    change.failure,
                    samePoint: _point == _sentPoint,
                  ),
                ),
              ),
              FilledButton(
                key: const ValueKey<String>('address-save'),
                onPressed: change.isBusy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: KitColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: KitColors.line,
                  disabledForegroundColor: KitColors.muted,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(l10n.addressSaveButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A refused save: outside the service area it says how far and how far is
/// served, from the answer's `details` — while the pin is still where it
/// was refused; anything else as its code says.
class _SaveFailure extends StatelessWidget {
  const _SaveFailure(this.failure, {required this.samePoint});

  final ApiFailure? failure;
  final bool samePoint;

  /// Two decimals, as `details` carries them (`docs/09` section 13).
  static final RegExp _kilometres = RegExp(r'^\d+\.\d{2}$');

  @override
  Widget build(BuildContext context) {
    final ApiFailure? failure = this.failure;
    if (failure is ApiRefusal &&
        failure.code == 'address_outside_service_area') {
      if (!samePoint) {
        return const SizedBox.shrink();
      }
      final AppLocalizations l10n = AppLocalizations.of(context);
      final Object? distance = failure.error.details['distance_km'];
      final Object? max = failure.error.details['max_distance_km'];
      // Kilometres with the decimal comma of both languages; without
      // readable numbers the refusal is said without them.
      final String text =
          distance is String &&
              max is String &&
              _kilometres.hasMatch(distance) &&
              _kilometres.hasMatch(max)
          ? l10n.addressOutsideArea(
              distance.replaceAll('.', ','),
              max.replaceAll('.', ','),
            )
          : l10n.addressOutsideAreaPlain;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          key: const ValueKey<String>('address-outside-area'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    return FailureMessage(failure);
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.failure, required this.onRetry});

  final ApiFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FailureMessage(failure),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).retryButton),
            ),
          ],
        ),
      ),
    );
  }
}
