import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/theme/kit_colors.dart';
import '../application/addresses_controllers.dart';
import '../application/delivery_address.dart';
import '../domain/addresses.dart';

/// Where the order goes, at the top of the home (the kit's drawing 10): a
/// green pin, the address's label — or its street when it has none — with a
/// chevron, and the full street line under a label. Tapping it changes the
/// address, adds the first one, or reloads a list that failed.
class DeliveryAddressLine extends ConsumerWidget {
  const DeliveryAddressLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final (String value, String? detail, VoidCallback? onTap) = switch (ref
        .watch(deliveryAddressProvider)) {
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
      _ => ('…', null, null),
    };

    return InkWell(
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          value,
                          key: const ValueKey<String>('delivery-address-value'),
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
      builder: (BuildContext sheet) => _DeliveryAddressSheet(
        router: GoRouter.of(context),
        container: ProviderScope.containerOf(context),
      ),
    );

class _DeliveryAddressSheet extends ConsumerWidget {
  const _DeliveryAddressSheet({required this.router, required this.container});

  /// The home's router and container: the sheet's own context is gone once
  /// it closes.
  final GoRouter router;
  final ProviderContainer container;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? account = ref.watch(customerAccountProvider);
    final AsyncValue<Address?> current = ref.watch(deliveryAddressProvider);
    final List<Address> addresses = current.hasValue
        ? ref.watch(addressesProvider).requireValue
        : const <Address>[];

    return SafeArea(
      child: ListView(
        key: const ValueKey<String>('delivery-address-sheet'),
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 8),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.deliveryAddressSheetTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          RadioGroup<String>(
            groupValue: current.value?.id,
            onChanged: (String? id) {
              if (id == null || account == null) {
                return;
              }
              ref
                  .read(deliveryAddressChoiceProvider(account).notifier)
                  .choose(id);
              Navigator.of(context).pop();
            },
            child: Column(
              children: <Widget>[
                for (final Address address in addresses)
                  RadioListTile<String>(
                    key: ValueKey<String>('delivery-address-${address.id}'),
                    value: address.id,
                    title: Text(address.label ?? address.streetLine),
                    subtitle: address.label == null
                        ? null
                        : Text(address.streetLine),
                  ),
              ],
            ),
          ),
          ListTile(
            key: const ValueKey<String>('delivery-address-new'),
            leading: const Icon(Icons.add_location_alt_outlined),
            title: Text(l10n.addressNew),
            onTap: () {
              Navigator.of(context).pop();
              addDeliveryAddress(router: router, container: container);
            },
          ),
        ],
      ),
    );
  }
}
