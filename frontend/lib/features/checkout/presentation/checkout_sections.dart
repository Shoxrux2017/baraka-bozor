import 'package:flutter/material.dart';

import '../../../core/formatting/address_format.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/phone_format.dart';
import '../../../core/formatting/server_text.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/product_image.dart';
import '../../addresses/domain/addresses.dart';
import '../../cart/domain/cart.dart';
import '../../cart/presentation/cart_summary.dart';
import '../../profile/domain/profile.dart';
import '../domain/checkout.dart';

const List<BoxShadow> _cardShadow = <BoxShadow>[
  BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 2)),
];

const TextStyle _heading = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w700,
  color: KitColors.ink,
);

/// A 44x44 icon on the green wash.
class _IconWell extends StatelessWidget {
  const _IconWell({required this.icon, this.opacity = 1});

  final IconData icon;
  final double opacity;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: opacity,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: KitColors.primaryWash,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: SizedBox.square(
        dimension: 44,
        child: Icon(icon, color: KitColors.primaryDark),
      ),
    ),
  );
}

/// A small "Изменить" text button, scaled down where the text is large.
class _EditButton extends StatelessWidget {
  const _EditButton({required this.buttonKey, required this.onPressed});

  final String buttonKey;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 120),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: TextButton(
        key: ValueKey<String>(buttonKey),
        style: TextButton.styleFrom(
          foregroundColor: KitColors.primaryDark,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        onPressed: onPressed,
        child: Text(AppLocalizations.of(context).editButton),
      ),
    ),
  );
}

/// A notice on a wash: an icon and a line, announced when it appears.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.noticeKey,
    required this.wash,
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final String noticeKey;
  final Color wash;
  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    container: true,
    child: DecoratedBox(
      key: ValueKey<String>(noticeKey),
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: KitColors.ink2,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// "Сейчас мы закрыты" (drawing 25а).
class CheckoutClosedBanner extends StatelessWidget {
  const CheckoutClosedBanner({required this.opensAt, super.key});

  final String opensAt;

  @override
  Widget build(BuildContext context) => _Notice(
    noticeKey: 'checkout-closed',
    wash: KitColors.warningWash,
    icon: Icons.schedule,
    iconColor: KitColors.warning,
    text: AppLocalizations.of(context).checkoutClosedBanner(opensAt),
  );
}

/// "Куда привезти": the delivery address and the recipient (drawing 25).
class CheckoutDeliveryCard extends StatelessWidget {
  const CheckoutDeliveryCard({
    required this.address,
    required this.gone,
    required this.recipient,
    required this.onChange,
    super.key,
  });

  final Address? address;
  final bool gone;
  final CustomerProfile? recipient;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Address? held = address;
    final String title;
    final String? detail;
    if (gone) {
      title = l10n.errorAddressGone;
      detail = null;
    } else if (held == null) {
      title = l10n.deliveryAddressAdd;
      detail = l10n.deliveryAddressEmptyHint;
    } else if (held.label == null) {
      title = held.streetLine;
      detail = addressApartmentPart(l10n, held.apartment);
    } else {
      title = held.label!;
      detail = addressFullLine(
        l10n,
        street: held.street,
        house: held.house,
        apartment: held.apartment,
      );
    }
    final String? name = recipient?.fullName;

    return DecoratedBox(
      key: const ValueKey<String>('checkout-address'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const _IconWell(icon: Icons.home_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: onChange,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: gone ? KitColors.danger : KitColors.ink,
                          ),
                        ),
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
                ),
                const SizedBox(width: 8),
                _EditButton(
                  buttonKey: 'checkout-address-change',
                  onPressed: onChange,
                ),
              ],
            ),
            if (name != null) ...<Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, thickness: 1, color: KitColors.line),
              ),
              Row(
                key: const ValueKey<String>('checkout-recipient'),
                children: <Widget>[
                  const _IconWell(icon: Icons.person_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: KitColors.ink,
                          ),
                        ),
                        Text(
                          formatPhone(recipient!.phone),
                          style: const TextStyle(
                            fontSize: 12,
                            color: KitColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Пожелание к доставке", up to 160 characters as the server counts them.
class CheckoutWishField extends StatelessWidget {
  const CheckoutWishField({
    required this.controller,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    const OutlineInputBorder none = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide.none,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.checkoutWishLabel,
          style: const TextStyle(fontSize: 12, color: KitColors.muted),
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: const ValueKey<String>('checkout-delivery-wish'),
          controller: controller,
          enabled: enabled,
          minLines: 1,
          maxLines: 3,
          style: const TextStyle(fontSize: 14, color: KitColors.ink),
          decoration: InputDecoration(
            hintText: l10n.checkoutWishHint,
            hintStyle: const TextStyle(fontSize: 14, color: KitColors.muted),
            filled: true,
            fillColor: KitColors.field,
            border: none,
            enabledBorder: none,
            disabledBorder: none,
            focusedBorder: none,
            errorBorder: none,
            focusedErrorBorder: none,
            contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            counter: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (BuildContext context, TextEditingValue value, _) =>
                  Text(
                    '${trimLikeServer(value.text).runes.length} / '
                    '${CheckoutRequest.deliveryTimeNoteMax}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: KitColors.muted,
                    ),
                  ),
            ),
          ),
          onChanged: onChanged,
          validator: (String? text) =>
              trimLikeServer(text ?? '').runes.length >
                  CheckoutRequest.deliveryTimeNoteMax
              ? l10n.fieldTooLong(CheckoutRequest.deliveryTimeNoteMax)
              : null,
        ),
      ],
    );
  }
}

/// "Способ оплаты": cash is chosen, online is shown and not yet open.
class CheckoutPaymentCards extends StatelessWidget {
  const CheckoutPaymentCards({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return RadioGroup<PaymentMethod>(
      groupValue: PaymentMethod.cash,
      onChanged: (PaymentMethod? _) {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _payCard(
            selected: true,
            tile: RadioListTile<PaymentMethod>(
              key: const ValueKey<String>('pay-cash'),
              value: PaymentMethod.cash,
              controlAffinity: ListTileControlAffinity.trailing,
              activeColor: KitColors.primary,
              secondary: const _IconWell(icon: Icons.payments_outlined),
              title: Text(
                l10n.paymentCashTitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: KitColors.ink,
                ),
              ),
              subtitle: Text(
                l10n.paymentCashHint,
                style: const TextStyle(fontSize: 12, color: KitColors.muted),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _payCard(
            selected: false,
            tile: RadioListTile<PaymentMethod>(
              key: const ValueKey<String>('pay-online'),
              value: PaymentMethod.online,
              enabled: false,
              controlAffinity: ListTileControlAffinity.trailing,
              secondary: const _IconWell(icon: Icons.credit_card, opacity: 0.5),
              title: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    l10n.paymentOnlineTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: KitColors.muted,
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: KitColors.line,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: Text(
                        l10n.checkoutSoon,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: KitColors.ink2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                l10n.checkoutOnlineUnavailable,
                style: const TextStyle(fontSize: 12, color: KitColors.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _payCard({required bool selected, required Widget tile}) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _cardShadow,
          border: selected
              ? Border.all(color: KitColors.primary, width: 1.5)
              : null,
        ),
        child: Material(type: MaterialType.transparency, child: tile),
      );
}

/// "Товары · N" with the pictures of the first four lines.
class CheckoutItemsStrip extends StatelessWidget {
  const CheckoutItemsStrip({
    required this.lines,
    required this.imageByCartItem,
    required this.onChange,
    super.key,
  });

  /// The most pictures the strip shows.
  static const int shown = 4;

  final List<PreviewLine> lines;
  final Map<String, String?> imageByCartItem;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<PreviewLine> visible = lines.take(shown).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.checkoutItems(lines.length),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _heading,
              ),
            ),
            const SizedBox(width: 8),
            _EditButton(
              buttonKey: 'checkout-items-change',
              onPressed: onChange,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            for (final PreviewLine line in visible)
              SizedBox(
                width: 64,
                child: Column(
                  children: <Widget>[
                    _tile(
                      ProductImage(
                        url: imageByCartItem[line.cartItemId],
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${QuantityRules.display(line.quantity)} '
                        '${CatalogLabels.unit(l10n, line.unit)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: KitColors.ink2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (lines.length > shown)
              SizedBox(
                width: 64,
                child: _tile(
                  Text(
                    '+${lines.length - shown}',
                    key: const ValueKey<String>('checkout-items-more'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: KitColors.ink2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  static Widget _tile(Widget child) => DecoratedBox(
    decoration: BoxDecoration(
      color: KitColors.card,
      borderRadius: BorderRadius.circular(14),
    ),
    child: SizedBox.square(dimension: 64, child: Center(child: child)),
  );
}

/// The amounts of the checkout, exactly the preview's (drawing 25).
class CheckoutAmounts extends StatelessWidget {
  const CheckoutAmounts({
    required this.preview,
    this.replacedTotalUzs,
    super.key,
  });

  final CheckoutPreview preview;

  /// The total the Customer saw before the figures were recounted.
  final int? replacedTotalUzs;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final bool estimate = preview.totalKind != TotalKind.finalTotal;
    String sum(int amount) => MoneyFormat.uzs(amount, language);
    String figure(int amount) =>
        estimate ? l10n.cartLineEstimate(sum(amount)) : sum(amount);
    final int? replaced = replacedTotalUzs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (replaced != null) ...<Widget>[
          _Notice(
            noticeKey: 'checkout-refreshed',
            wash: KitColors.primaryWash,
            icon: Icons.sync,
            iconColor: KitColors.primaryDark,
            text: l10n.checkoutRecounted,
          ),
          const SizedBox(height: 12),
        ],
        SummaryAmountRow(
          valueKey: 'checkout-subtotal',
          label: l10n.cartGoods(preview.lines.length),
          value: figure(preview.merchandiseSubtotalUzs),
        ),
        SummaryAmountRow(
          valueKey: 'checkout-delivery',
          label: l10n.cartDelivery,
          value: sum(preview.deliveryFeeUzs),
        ),
        SummaryAmountRow(
          valueKey: 'checkout-service-fee',
          label: l10n.cartServiceFee,
          value: sum(preview.serviceFeeUzs),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Divider(height: 1, thickness: 1, color: KitColors.line),
        ),
        SummaryAmountRow(
          valueKey: 'checkout-total',
          label: l10n.cartTotal,
          value: figure(preview.totalUzs),
          emphasised: true,
          replaced: replaced == null ? null : figure(replaced),
        ),
        const SizedBox(height: 8),
        const EstimateNote(),
      ],
    );
  }
}

/// The bar under the checkout: "≈ total | Заказать".
class CheckoutFooter extends StatelessWidget {
  const CheckoutFooter({
    required this.totalUzs,
    required this.estimate,
    required this.busy,
    required this.busyLabel,
    required this.onOrder,
    this.message,
    super.key,
  });

  final int? totalUzs;
  final bool estimate;
  final bool busy;
  final String busyLabel;
  final VoidCallback? onOrder;
  final Widget? message;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int? total = totalUzs;
    final Widget? note = message;
    const TextStyle text = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);

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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (note != null)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: note),
            FilledButton(
              key: const ValueKey<String>('checkout-confirm'),
              style: FilledButton.styleFrom(
                backgroundColor: KitColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: busy
                    ? KitColors.primary
                    : KitColors.line,
                disabledForegroundColor: busy ? Colors.white : KitColors.muted,
                minimumSize: const Size.fromHeight(54),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: busy ? null : onOrder,
              child: busy
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                        semanticsLabel: busyLabel,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (total != null) ...<Widget>[
                            Text(_amount(context, l10n, total), style: text),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 1,
                              height: 22,
                              child: ColoredBox(
                                color: onOrder != null
                                    ? Colors.white54
                                    : KitColors.muted,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Text(l10n.checkoutOrder, style: text),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _amount(BuildContext context, AppLocalizations l10n, int total) {
    final String sum = MoneyFormat.uzs(total, interfaceLanguage(context));
    return estimate ? l10n.cartLineEstimate(sum) : sum;
  }
}

/// "Товар закончился" (drawing 25б): the products that went off sale while
/// the Customer was checking out, with the way back to the cart.
Future<void> showCheckoutGoneSheet(
  BuildContext context, {
  required List<CartLine> lines,
  required VoidCallback onToCart,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (BuildContext sheet) => _GoneSheet(lines: lines, onToCart: onToCart),
);

class _GoneSheet extends StatelessWidget {
  const _GoneSheet({required this.lines, required this.onToCart});

  final List<CartLine> lines;
  final VoidCallback onToCart;

  static const ColorFilter _grey = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final int count = lines.length;
    const TextStyle body = TextStyle(
      fontSize: 14,
      height: 1.4,
      color: KitColors.ink2,
    );

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: KitColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.checkoutGoneTitle(count),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: KitColors.ink,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('checkout-gone-close'),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close, color: KitColors.ink),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, thickness: 1, color: KitColors.line),
            const SizedBox(height: 14),
            Text(l10n.checkoutGoneText(count), style: body),
            const SizedBox(height: 12),
            for (final CartLine line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: KitColors.field,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: <Widget>[
                        Opacity(
                          opacity: 0.4,
                          child: ColorFiltered(
                            colorFilter: _grey,
                            child: ProductImage(url: line.imageUrl, size: 44),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                line.name(language),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: KitColors.ink,
                                ),
                              ),
                              Text(
                                l10n.catalogUnavailable,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: KitColors.danger,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(l10n.checkoutGoneHint(count), style: body),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey<String>('checkout-gone-to-cart'),
              style: FilledButton.styleFrom(
                backgroundColor: KitColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                onToCart();
              },
              child: Text(
                l10n.checkoutGoneAction,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
