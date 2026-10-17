import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import '../../addresses/application/addresses_controllers.dart';
import '../../addresses/application/delivery_address.dart';
import '../../addresses/domain/addresses.dart';
import '../../addresses/presentation/delivery_address_widgets.dart';

/// Where the order goes (drawing 19), with "Изменить". It follows the same
/// delivery address as the home and the checkout, and the same states: none
/// yet, failed and loading.
class CartAddressCard extends ConsumerWidget {
  const CartAddressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final (
      Widget title,
      String? detail,
      String? action,
      VoidCallback? onTap,
    ) = switch (ref.watch(deliveryAddressProvider)) {
      AsyncData<Address?>(value: final Address address) => (
        _delivery(l10n, address.label ?? address.streetLine),
        address.label == null ? null : address.streetLine,
        l10n.editButton,
        () => showDeliveryAddressSheet(context),
      ),
      AsyncData<Address?>() => (
        _plain(l10n.deliveryAddressAdd),
        l10n.deliveryAddressEmptyHint,
        null,
        () => addDeliveryAddress(
          router: GoRouter.of(context),
          container: ProviderScope.containerOf(context),
        ),
      ),
      AsyncError<Address?>() => (
        _plain(l10n.deliveryAddressRetry),
        null,
        null,
        () => ref.invalidate(addressesProvider),
      ),
      _ => (_plain('…'), null, null, null),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
            key: const ValueKey<String>('cart-address'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      color: KitColors.primaryWash,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: SizedBox.square(
                      dimension: 44,
                      child: Icon(
                        Icons.home_outlined,
                        color: KitColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        title,
                        if (detail != null)
                          Text(
                            detail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: KitColors.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (action != null) ...<Widget>[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: TextButton(
                          key: const ValueKey<String>('cart-address-change'),
                          style: TextButton.styleFrom(
                            foregroundColor: KitColors.primaryDark,
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: onTap,
                          child: Text(action),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _plain(String text) => Text(
    text,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: KitColors.ink,
    ),
  );

  /// "Доставка: <b>label</b>".
  static Widget _delivery(AppLocalizations l10n, String value) => Text.rich(
    TextSpan(
      style: const TextStyle(fontSize: 14, color: KitColors.ink2),
      children: <InlineSpan>[
        TextSpan(text: '${l10n.cartDeliveryTo} '),
        TextSpan(
          text: value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: KitColors.ink,
          ),
        ),
      ],
    ),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  );
}
