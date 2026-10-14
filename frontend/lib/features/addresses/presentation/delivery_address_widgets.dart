import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/theme/brand_colors.dart';
import '../application/addresses_controllers.dart';
import '../application/delivery_address.dart';
import '../domain/addresses.dart';

/// Where the order goes, under the home's search (design 4a). Tapping it
/// changes the address, adds the first one, or reloads a list that failed.
class DeliveryAddressLine extends ConsumerWidget {
  const DeliveryAddressLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final (String value, VoidCallback? onTap) = switch (ref.watch(
      deliveryAddressProvider,
    )) {
      AsyncData<Address?>(value: final Address address) => (
        address.streetLine,
        () => showDeliveryAddressSheet(context),
      ),
      AsyncData<Address?>() => (
        l10n.deliveryAddressAdd,
        () => addDeliveryAddress(
          router: GoRouter.of(context),
          container: ProviderScope.containerOf(context),
        ),
      ),
      AsyncError<Address?>() => (
        l10n.deliveryAddressRetry,
        () => ref.invalidate(addressesProvider),
      ),
      _ => ('…', null),
    };

    return InkWell(
      key: const ValueKey<String>('delivery-address'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                l10n.deliveryAddressCaption,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
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
                        color: BrandColors.lime,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.near_me_rounded,
                    size: 17,
                    color: BrandColors.lime,
                  ),
                ],
              ),
            ],
          ),
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
