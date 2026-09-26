import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/addresses_controllers.dart';
import '../domain/addresses.dart';
import 'map/map_picker.dart';

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

/// A new address, or an edit of [addressId]: the pin on the map, then the
/// street, the house and the rest. A point outside the service area is
/// refused with both distances, as the server answers (`BR-AREA-001`).
class AddressFormScreen extends ConsumerWidget {
  const AddressFormScreen({required this.addressId, super.key});

  final String? addressId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? id = addressId;
    final String title = id == null ? l10n.addressNew : l10n.addressEdit;

    if (id == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const SafeArea(
          child: UnderActiveMode(child: _AddressForm(address: null)),
        ),
      );
    }

    final AsyncValue<List<Address>> addresses = ref.watch(addressesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: UnderActiveMode(
          child: addresses.when(
            skipLoadingOnReload: false,
            // A retry after a failed load shows progress; a reload after a
            // save keeps the form.
            skipLoadingOnRefresh: !addresses.hasError,
            data: (List<Address> addresses) {
              final Address? address = addresses
                  .where((Address a) => a.id == id)
                  .firstOrNull;
              return address == null
                  ? Center(child: Text(l10n.errorNotFound))
                  : _AddressForm(address: address);
            },
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
}

class _AddressForm extends ConsumerStatefulWidget {
  const _AddressForm({required this.address});

  final Address? address;

  @override
  ConsumerState<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends ConsumerState<_AddressForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _label = TextEditingController(
    text: widget.address?.label ?? '',
  );
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

  /// The point of the last save, so a refusal of the area is shown only
  /// while the pin is still where it was refused.
  GeoPoint? _sentPoint;

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

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Address? address = widget.address;
    final AddressDraft draft = AddressDraft(
      label: _optional(_label.text),
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
    // The Customer may have gone back while the save ran; where they went
    // stays on screen.
    if (!mounted || saved == null) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(savedText)));
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppPaths.customerAddresses);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState change = ref.watch(addressFormControllerProvider);
    final MapPickerBuilder picker = ref.watch(mapPickerProvider);

    Widget field(
      String key,
      TextEditingController controller,
      String label,
      int max, {
      bool required = false,
      int maxLines = 1,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          key: ValueKey<String>('field-$key'),
          controller: controller,
          enabled: !change.isBusy,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          validator: (String? text) {
            final String value = (text ?? '').trim();
            if (required && value.isEmpty) {
              return l10n.fieldRequired;
            }
            return value.runes.length > max ? l10n.fieldTooLong(max) : null;
          },
        ),
      );
    }

    return Form(
      key: _form,
      child: ListView(
        key: const ValueKey<String>('address-form'),
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(l10n.addressMapHint),
          const SizedBox(height: 8),
          picker(
            initial: _point,
            enabled: !change.isBusy,
            onMoved: (GeoPoint point) => setState(() => _point = point),
          ),
          const SizedBox(height: 16),
          field('street', _street, l10n.addressStreet, 160, required: true),
          field('house', _house, l10n.addressHouse, 40, required: true),
          field('apartment', _apartment, l10n.addressApartment, 40),
          field('landmark', _landmark, l10n.addressLandmark, 160),
          field('label', _label, l10n.addressLabel, 60),
          field(
            'delivery_note',
            _note,
            l10n.addressDeliveryNote,
            300,
            maxLines: 3,
          ),
          FilledButton(
            key: const ValueKey<String>('address-save'),
            onPressed: change.isBusy ? null : _submit,
            child: Text(l10n.saveButton),
          ),
          _SaveFailure(change.failure, samePoint: _point == _sentPoint),
        ],
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
        padding: const EdgeInsets.only(top: 12),
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
