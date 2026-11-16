import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/address_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/fold.dart';
import '../../../core/widgets/skeleton_bar.dart';
import '../../../core/widgets/undo_bar.dart';
import '../application/address_removals.dart';
import '../application/addresses_controllers.dart';
import '../application/delivery_address.dart';
import '../domain/addresses.dart';
import 'address_card.dart';
import 'address_removal_flow.dart';

/// Where the order goes, at the top of the home (the kit's drawing 10): a
/// green pin, the address's label — or its street when it has none — with a
/// chevron, and the full street line under a label. Tapping it changes the
/// address, adds the first one, or reloads a list that failed.
class DeliveryAddressLine extends ConsumerWidget {
  const DeliveryAddressLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<Address?> current = ref.watch(deliveryAddressProvider);
    final bool loading =
        current is! AsyncData<Address?> && current is! AsyncError<Address?>;
    final (
      String value,
      String? detail,
      VoidCallback? onTap,
    ) = switch (current) {
      AsyncData<Address?>(value: final Address address) => (
        address.label ?? address.streetLine,
        address.label == null ? null : address.streetLine,
        () => showDeliveryAddressSheet(context),
      ),
      AsyncData<Address?>() => (
        l10n.deliveryAddressAdd,
        l10n.deliveryAddressEmptyHint,
        () => addDeliveryAddress(
          router: GoRouter.of(context),
          container: ProviderScope.containerOf(context),
        ),
      ),
      AsyncError<Address?>() => (
        l10n.deliveryAddressRetry,
        null,
        () => ref.invalidate(addressesProvider),
      ),
      _ => ('', null, null),
    };

    final Widget line = InkWell(
      key: const ValueKey<String>('delivery-address'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: <Widget>[
            const Icon(Icons.location_on, size: 26, color: KitColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (loading) ...<Widget>[
                    // Two bars stand where the label and the street will be
                    // (`DL-125`).
                    const SkeletonBar(width: 90, height: 14),
                    const SizedBox(height: 6),
                    const SkeletonBar(width: 170, height: 10),
                  ] else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            value,
                            key: const ValueKey<String>(
                              'delivery-address-value',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: KitColors.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: KitColors.ink,
                        ),
                      ],
                    ),
                  if (detail != null)
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: KitColors.muted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    // With an address the line is one button that says where the order goes
    // (`DL-125`).
    final Address? chosen = current.value;
    if (current is! AsyncData<Address?> || chosen == null) {
      return line;
    }
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: l10n.deliveryAddressSpoken(
        chosen.label == null
            ? chosen.streetLine
            : '${chosen.label}, ${chosen.streetLine}',
      ),
      onTap: onTap,
      child: line,
    );
  }
}

/// Opens the new-address form and, when the Customer saves one, makes it
/// the delivery address (`DL-75`); returns it then, otherwise `null`. A
/// Customer who changed meanwhile keeps nothing of it. Takes the router and
/// the container, not a context: the caller's may be gone when the form
/// closes.
Future<Address?> addDeliveryAddress({
  required GoRouter router,
  required ProviderContainer container,
}) async {
  final String? account = container.read(customerAccountProvider);
  final Address? added = await router.push<Address>(
    AppPaths.customerNewAddress,
  );
  if (added == null ||
      account == null ||
      container.read(customerAccountProvider) != account) {
    return null;
  }
  await container
      .read(deliveryAddressChoiceProvider(account).notifier)
      .choose(added.id);
  return added;
}

/// The Customer's active addresses to deliver to, and the way to add one.
Future<void> showDeliveryAddressSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext sheet) => _DeliveryAddressSheet(
        router: GoRouter.of(context),
        container: ProviderScope.containerOf(context),
      ),
    );

class _DeliveryAddressSheet extends ConsumerStatefulWidget {
  const _DeliveryAddressSheet({required this.router, required this.container});

  /// The home's router and container: the sheet's own context is gone once
  /// it closes.
  final GoRouter router;
  final ProviderContainer container;

  @override
  ConsumerState<_DeliveryAddressSheet> createState() =>
      _DeliveryAddressSheetState();
}

/// The bar the sheet shows for the removal it offers to take back.
final class _SheetBar {
  _SheetBar({required this.text, required this.onUndo});

  final String text;
  final VoidCallback onUndo;
  final Completer<void> ended = Completer<void>();
}

class _DeliveryAddressSheetState extends ConsumerState<_DeliveryAddressSheet> {
  _SheetBar? _bar;

  void _showBar(_SheetBar bar) {
    setState(() => _bar = bar);
  }

  /// The bar is over, however it ended; the sheet may be going away.
  void _barEnded(_SheetBar bar) {
    if (!bar.ended.isCompleted) {
      bar.ended.complete();
    }
    if (mounted && identical(_bar, bar)) {
      setState(() => _bar = null);
    }
  }

  void _remove(Address address) {
    unawaited(
      removeAddress(
        context,
        container: widget.container,
        address: address,
        offer: _SheetUndoOffer(this),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? account = ref.watch(customerAccountProvider);
    final AsyncValue<Address?> current = ref.watch(deliveryAddressProvider);
    final List<Address> addresses = current.hasValue
        ? (ref.watch(shownAddressesProvider).value ?? const <Address>[])
        : const <Address>[];
    final ({String id, ApiFailure failure})? notRemoved = ref.watch(
      addressRemovalsProvider.select(
        (AddressRemovalsState removals) => removals.notRemoved,
      ),
    );
    final _SheetBar? bar = _bar;

    void choose(String id) {
      if (account == null) {
        return;
      }
      ref.read(deliveryAddressChoiceProvider(account).notifier).choose(id);
      Navigator.of(context).pop();
    }

    return SafeArea(
      child: ListView(
        key: const ValueKey<String>('delivery-address-sheet'),
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.deliveryAddressSheetTitle,
                  style: const TextStyle(
                    color: KitColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey<String>('delivery-address-close'),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
                // A 44 square takes the tap; the drawn circle stays 28
                // (`DL-117`).
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                icon: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: KitColors.line, width: 1.5),
                  ),
                  child: const SizedBox.square(
                    dimension: 28,
                    child: Icon(Icons.close, size: 16, color: KitColors.ink),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 15, thickness: 1, color: KitColors.line),
          RadioGroup<String>(
            groupValue: current.value?.id,
            onChanged: (String? id) {
              if (id != null) {
                choose(id);
              }
            },
            child: FoldingColumn<Address>(
              items: addresses,
              keyOf: (Address address) => address.id,
              itemBuilder: (BuildContext context, Address address) =>
                  _AddressCard(
                    address: address,
                    chosen: address.id == current.value?.id,
                    notRemoved: notRemoved?.id == address.id
                        ? notRemoved!.failure
                        : null,
                    onChoose: () => choose(address.id),
                    onEdit: () {
                      Navigator.of(context).pop();
                      widget.router.push<Object?>(
                        AppPaths.customerAddress(address.id),
                      );
                    },
                    onDelete: () => _remove(address),
                  ),
            ),
          ),
          if (bar != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: InlineUndoBar(
                key: ObjectKey(bar),
                text: bar.text,
                actionLabel: l10n.undoAction,
                duration: addressUndoDuration,
                onUndo: bar.onUndo,
                onEnded: () => _barEnded(bar),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey<String>('delivery-address-new'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: KitColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            icon: const Icon(Icons.add),
            label: Text(l10n.addressAddNew),
            onPressed: () {
              Navigator.of(context).pop();
              addDeliveryAddress(
                router: widget.router,
                container: widget.container,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The sheet's own place for «Вернуть» (`DL-137`): a page's snack bar lies
/// under the sheet's barrier, so the bar stands between the cards and the add
/// button. One offer serves one removal.
final class _SheetUndoOffer implements UndoOffer {
  _SheetUndoOffer(this._sheet);

  final _DeliveryAddressSheetState _sheet;
  _SheetBar? _bar;

  @override
  Future<void> show({required String text, required VoidCallback onUndo}) {
    final _SheetBar bar = _SheetBar(text: text, onUndo: onUndo);
    _bar = bar;
    _sheet._showBar(bar);
    return bar.ended.future;
  }

  /// Ends the bar; a sheet that has closed has ended it already.
  @override
  void close() {
    final _SheetBar? bar = _bar;
    if (bar != null) {
      _sheet._barEnded(bar);
    }
  }
}

/// One address in the sheet (drawings 21, 21a): a radio, the bold label — or
/// the street line when there is none — the full line, the landmark, and the
/// menu to edit or delete it.
class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.chosen,
    required this.onChoose,
    required this.onEdit,
    required this.onDelete,
    this.notRemoved,
  });

  final Address address;
  final bool chosen;

  /// Why the last removal of this address did not go through, if it did not.
  final ApiFailure? notRemoved;
  final VoidCallback onChoose;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? label = address.label;
    final String? line = label == null
        ? addressApartmentPart(l10n, address.apartment)
        : addressFullLine(
            l10n,
            street: address.street,
            house: address.house,
            apartment: address.apartment,
          );
    final String? landmark = address.landmark?.trim();
    final ApiFailure? failure = notRemoved;
    final String? failureText = failure == null
        ? null
        : failure is NetworkFailure
        ? l10n.addressNotRemovedOffline
        : l10n.addressNotRemovedOther;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: chosen
              ? Border.all(color: KitColors.primary, width: 1.5)
              : null,
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: ValueKey<String>('delivery-address-${address.id}'),
            onTap: onChoose,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
              child: Row(
                children: <Widget>[
                  IgnorePointer(
                    child: Radio<String>(
                      value: address.id,
                      activeColor: KitColors.primary,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          label ?? address.streetLine,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: KitColors.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (line != null)
                          Text(
                            line,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: KitColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        if (failureText != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              failureText,
                              style: const TextStyle(
                                color: KitColors.danger,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (landmark != null && landmark.isNotEmpty)
                          Text(
                            l10n.addressLandmarkLine(landmark),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: KitColors.muted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  AddressMenuButton(
                    address: address,
                    keyPrefix: 'delivery-address',
                    onEdit: onEdit,
                    onDelete: onDelete,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
