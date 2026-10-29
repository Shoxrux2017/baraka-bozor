import 'package:flutter/material.dart';

import '../../../core/formatting/address_format.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/phone_format.dart';
import '../../../core/formatting/server_text.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/orders/order_values.dart';
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

/// A 44x44 icon on the green wash.
class _IconWell extends StatelessWidget {
  const _IconWell({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: KitColors.primaryWash,
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    child: SizedBox.square(
      dimension: 44,
      child: Icon(icon, color: KitColors.primaryDark),
    ),
  );
}

/// A small text button ("Изменить", "Добавить"). With a width cap the label
/// scales down at large text, the button — and so its tap target — does not;
/// without one ([maxWidth] infinite) the label is never scaled and the button
/// is flush with its text (`DL-121`).
class CheckoutEditButton extends StatelessWidget {
  const CheckoutEditButton({
    required this.buttonKey,
    required this.label,
    required this.onPressed,
    this.maxWidth = 120,
    super.key,
  });

  static const TextStyle labelStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  final String buttonKey;
  final String label;
  final VoidCallback? onPressed;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final bool capped = maxWidth.isFinite;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: TextButton(
        key: ValueKey<String>(buttonKey),
        style: TextButton.styleFrom(
          foregroundColor: KitColors.primaryDark,
          textStyle: labelStyle,
          padding: capped ? null : EdgeInsets.zero,
          minimumSize: capped ? null : const Size(44, 44),
          alignment: capped ? null : AlignmentDirectional.centerStart,
        ),
        onPressed: onPressed,
        child: capped
            ? FittedBox(fit: BoxFit.scaleDown, child: Text(label))
            : Text(label),
      ),
    );
  }
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

/// "Куда привезти": the delivery address and the recipient (drawing 25). The
/// address and the name are never cut; the link reads "Добавить" without an
/// address and goes under the address where it does not fit beside it
/// (`DL-121`).
class CheckoutDeliveryCard extends StatelessWidget {
  const CheckoutDeliveryCard({
    required this.address,
    required this.gone,
    required this.recipient,
    required this.onChange,
    this.sentAddressLine,
    super.key,
  });

  final Address? address;

  /// The address line of a confirmation that was sent, shown when its address
  /// is no longer among the Customer's.
  final String? sentAddressLine;
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
    } else if (held == null && sentAddressLine != null) {
      title = sentAddressLine!;
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
    final String linkLabel = held == null && !gone && sentAddressLine == null
        ? l10n.checkoutAddressAdd
        : l10n.editButton;

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
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints box) {
                      final double linkWidth =
                          textWidth(
                            context,
                            linkLabel,
                            CheckoutEditButton.labelStyle,
                          ) +
                          16;
                      final bool beside = linkWidth + 8 <= box.maxWidth / 2;
                      final Widget texts = InkWell(
                        onTap: onChange,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: gone ? KitColors.danger : KitColors.ink,
                              ),
                            ),
                            if (detail != null)
                              Text(
                                detail,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: KitColors.muted,
                                ),
                              ),
                          ],
                        ),
                      );
                      final Widget link = CheckoutEditButton(
                        buttonKey: 'checkout-address-change',
                        label: linkLabel,
                        onPressed: onChange,
                        maxWidth: double.infinity,
                      );
                      if (beside) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(child: texts),
                            const SizedBox(width: 8),
                            link,
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[texts, link],
                      );
                    },
                  ),
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
/// The error shows as it is typed; the counter only from [counterFrom]
/// characters, and in the danger colour over the limit (`DL-121`).
class CheckoutWishField extends StatelessWidget {
  const CheckoutWishField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  /// The length from which the counter is shown.
  static const int counterFrom = 120;

  final TextEditingController controller;
  final FocusNode focusNode;
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
          focusNode: focusNode,
          enabled: enabled,
          autovalidateMode: AutovalidateMode.onUserInteraction,
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
            errorStyle: const TextStyle(fontSize: 12, color: KitColors.danger),
            contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            counter: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (BuildContext context, TextEditingValue value, _) {
                final int length = trimLikeServer(value.text).runes.length;
                if (length < counterFrom) {
                  return const SizedBox.shrink();
                }
                final bool over = length > CheckoutRequest.deliveryTimeNoteMax;
                return Text(
                  '$length / ${CheckoutRequest.deliveryTimeNoteMax}',
                  style: TextStyle(
                    fontSize: 11,
                    color: over ? KitColors.danger : KitColors.muted,
                    fontWeight: over ? FontWeight.w600 : null,
                  ),
                );
              },
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

/// "Способ оплаты": one cash row, and a line that online payment is coming.
/// Nothing in it is a control (`DL-121`).
class CheckoutPayment extends StatelessWidget {
  const CheckoutPayment({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Widget card = DecoratedBox(
      key: const ValueKey<String>('pay-cash'),
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
                const _IconWell(icon: Icons.payments_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.paymentCashTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: KitColors.ink,
                        ),
                      ),
                      Text(
                        l10n.paymentCashHint,
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
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        card,
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            key: const ValueKey<String>('pay-online-soon'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.schedule, size: 16, color: KitColors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.checkoutOnlineSoon,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: KitColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The amounts of the checkout, exactly the preview's (drawing 25). Without a
/// preview every figure is a grey bar of its own width, pulsing while
/// [pending]; the cart's estimates are never shown here (`DL-121`).
class CheckoutAmounts extends StatelessWidget {
  const CheckoutAmounts({
    required this.preview,
    required this.lineCount,
    required this.pending,
    this.replacedTotalUzs,
    super.key,
  });

  final CheckoutPreview? preview;

  /// The number of products in «Товары (N)» while there is no preview.
  final int lineCount;
  final bool pending;

  /// The total the Customer saw before the figures were recounted; the
  /// notice itself is the footer's (`DL-121`).
  final int? replacedTotalUzs;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final CheckoutPreview? held = preview;
    final bool estimate =
        held != null && held.totalKind != TotalKind.finalTotal;
    String sum(int amount) => MoneyFormat.uzs(amount, language);
    String figure(int amount) =>
        estimate ? l10n.cartLineEstimate(sum(amount)) : sum(amount);
    final int? replaced = replacedTotalUzs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SummaryAmountRow(
          valueKey: 'checkout-subtotal',
          label: l10n.cartGoods(held?.lines.length ?? lineCount),
          value: held == null ? '' : figure(held.merchandiseSubtotalUzs),
          pendingWidth: held == null ? 92 : null,
          pulsing: pending,
        ),
        SummaryAmountRow(
          valueKey: 'checkout-delivery',
          label: l10n.cartDelivery,
          value: held == null ? '' : sum(held.deliveryFeeUzs),
          pendingWidth: held == null ? 76 : null,
          pulsing: pending,
        ),
        SummaryAmountRow(
          valueKey: 'checkout-service-fee',
          label: l10n.cartServiceFee,
          value: held == null ? '' : sum(held.serviceFeeUzs),
          pendingWidth: held == null ? 68 : null,
          pulsing: pending,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Divider(height: 1, thickness: 1, color: KitColors.line),
        ),
        SummaryAmountRow(
          valueKey: 'checkout-total',
          label: l10n.cartTotal,
          value: held == null ? '' : figure(held.totalUzs),
          emphasised: true,
          replaced:
              held == null || replaced == null || replaced == held.totalUzs
              ? null
              : figure(replaced),
          pendingWidth: held == null ? 120 : null,
          pulsing: pending,
        ),
        const SizedBox(height: 8),
        const EstimateNote(),
      ],
    );
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
