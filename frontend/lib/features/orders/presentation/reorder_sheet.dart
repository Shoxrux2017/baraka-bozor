import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/failure_text.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/product_image.dart';
import '../../cart/application/cart_controllers.dart';
import '../../cart/domain/cart.dart';
import '../../cart/presentation/cart_paths.dart';
import '../application/customer_orders_controllers.dart';
import '../domain/customer_orders.dart';

/// Puts the order's products into the cart again and says what happened: the
/// sheet when an answer came, a message when it did not. A retry after a
/// lost answer is the same request (`DL-92` item 2).
Future<void> repeatOrder(
  BuildContext context,
  WidgetRef ref, {
  required String orderId,
  required int orderNumber,
}) async {
  final ReorderResult? result = await ref
      .read(reorderProvider(orderId).notifier)
      .reorder();
  if (!context.mounted) {
    return;
  }
  if (result != null) {
    await showReorderSheet(context, result: result, orderNumber: orderNumber);
    return;
  }
  final ApiFailure? failure = ref.read(reorderProvider(orderId)).failure;
  final String? text = failure == null
      ? null
      : failureText(AppLocalizations.of(context), failure);
  if (text != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

/// What the reorder did to the cart (drawing 28a).
Future<void> showReorderSheet(
  BuildContext context, {
  required ReorderResult result,
  required int orderNumber,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (BuildContext sheet) =>
      _ReorderSheet(result: result, orderNumber: orderNumber),
);

/// The small filled "Повторить" of an order's card, or the page's outlined
/// "Повторить заказ" when [wide].
class RepeatOrderButton extends ConsumerWidget {
  const RepeatOrderButton({
    required this.orderId,
    required this.orderNumber,
    required this.wide,
    super.key,
  });

  final String orderId;
  final int orderNumber;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool busy = ref.watch(reorderProvider(orderId)).isBusy;
    final VoidCallback? onPressed = busy
        ? null
        : () => repeatOrder(
            context,
            ref,
            orderId: orderId,
            orderNumber: orderNumber,
          );
    final Widget spinner = Semantics(
      label: l10n.reorderSending,
      child: const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );

    if (wide) {
      return OutlinedButton(
        key: const ValueKey<String>('order-repeat'),
        style: _sheetButtonStyle(filled: false),
        onPressed: onPressed,
        child: busy
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  spinner,
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      l10n.reorderSending,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _buttonText,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.refresh, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n.reorderRepeatOrder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _buttonText,
                    ),
                  ),
                ],
              ),
      );
    }
    return FilledButton(
      key: ValueKey<String>('order-repeat-$orderId'),
      style: FilledButton.styleFrom(
        backgroundColor: KitColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
      child: busy
          ? spinner
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.refresh, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l10n.reorderRepeat,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

const TextStyle _buttonText = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w600,
);

ButtonStyle _sheetButtonStyle({required bool filled}) => ButtonStyle(
  minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 54)),
  shape: WidgetStatePropertyAll<OutlinedBorder>(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
  backgroundColor: WidgetStatePropertyAll<Color>(
    filled ? KitColors.primary : Colors.white,
  ),
  foregroundColor: WidgetStatePropertyAll<Color>(
    filled ? Colors.white : KitColors.ink,
  ),
  side: WidgetStatePropertyAll<BorderSide>(
    filled ? BorderSide.none : const BorderSide(color: KitColors.line),
  ),
);

class _ReorderSheet extends ConsumerWidget {
  const _ReorderSheet({required this.result, required this.orderNumber});

  final ReorderResult result;
  final int orderNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final Cart? cart = ref.watch(currentCartProvider).value;
    final bool added = result.added.isNotEmpty;

    CartLine? inCart(ReorderItem item) {
      for (final CartLine line in cart?.lines ?? const <CartLine>[]) {
        if (line.productId == item.productId) {
          return line;
        }
      }
      return null;
    }

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
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Semantics(
                      header: true,
                      child: Text(
                        added ? l10n.reorderTitle : l10n.reorderNothingTitle,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: KitColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('reorder-close'),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close, color: KitColors.ink),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            if (added) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                l10n.reorderAdded(result.added.length, orderNumber),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: KitColors.ink2,
                ),
              ),
            ],
            if (result.skipped.isNotEmpty)
              _Section(
                title: l10n.reorderSkippedTitle,
                rows: <Widget>[
                  for (final ReorderItem item in result.skipped)
                    _Row(
                      name: item.name(language),
                      imageUrl: inCart(item)?.imageUrl,
                      subtitle: switch (inCart(item)) {
                        null => null,
                        final CartLine line => l10n.reorderInCart(
                          '${QuantityRules.display(line.quantity)} '
                          '${CatalogLabels.unit(l10n, line.unit)}',
                        ),
                      },
                    ),
                ],
              ),
            if (result.unavailable.isNotEmpty)
              _Section(
                title: l10n.reorderUnavailableTitle,
                rows: <Widget>[
                  for (final ReorderItem item in result.unavailable)
                    _Row(
                      name: item.name(language),
                      subtitle: l10n.catalogUnavailable,
                      danger: true,
                      grey: true,
                    ),
                ],
              ),
            if (result.cartFull.isNotEmpty)
              _Section(
                title: l10n.reorderCartFullTitle,
                rows: <Widget>[
                  for (final ReorderItem item in result.cartFull)
                    _Row(name: item.name(language)),
                ],
              ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey<String>('reorder-stay'),
                    style: _sheetButtonStyle(filled: false),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      l10n.reorderStay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _buttonText,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey<String>('reorder-to-cart'),
                    style: _sheetButtonStyle(filled: true),
                    onPressed: () {
                      final GoRouter router = GoRouter.of(context);
                      Navigator.of(context).pop();
                      router.push(CartPaths.cart);
                    },
                    child: Text(
                      l10n.reorderToCart,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _buttonText,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 16),
        const Divider(height: 1, thickness: 1, color: KitColors.line),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: KitColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 10),
        ...rows,
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.name,
    this.imageUrl,
    this.subtitle,
    this.danger = false,
    this.grey = false,
  });

  final String name;
  final String? imageUrl;
  final String? subtitle;
  final bool danger;
  final bool grey;

  static const ColorFilter _greyFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final String? subtitle = this.subtitle;
    Widget picture = DecoratedBox(
      decoration: BoxDecoration(
        color: KitColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SizedBox.square(
        dimension: 52,
        child: Center(child: ProductImage(url: imageUrl, size: 44)),
      ),
    );
    if (grey) {
      picture = Opacity(
        opacity: 0.5,
        child: ColorFiltered(colorFilter: _greyFilter, child: picture),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          picture,
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
                    fontWeight: FontWeight.w500,
                    color: KitColors.ink,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: danger ? KitColors.danger : KitColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
