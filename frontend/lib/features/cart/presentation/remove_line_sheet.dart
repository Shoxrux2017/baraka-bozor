import 'package:flutter/material.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/product_image.dart';
import '../domain/cart.dart';

/// Asks before the last step of a line takes it out of the cart (drawing 20).
/// Answers `true` only on "Убрать"; dismissing the sheet answers `false`.
Future<bool> confirmRemoveLine(BuildContext context, CartLine line) async {
  final bool? answer = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext context) => _RemoveLineSheet(line: line),
  );
  return answer ?? false;
}

class _RemoveLineSheet extends StatelessWidget {
  const _RemoveLineSheet({required this.line});

  final CartLine line;

  ButtonStyle _style({required bool filled}) => ButtonStyle(
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final int? total = line.estimatedLineTotalUzs;
    final String quantity =
        '${QuantityRules.display(line.quantity)} '
        '${CatalogLabels.unit(l10n, line.unit)}';
    final String summary = total == null
        ? quantity
        : '$quantity · ${l10n.cartLineEstimate(MoneyFormat.uzs(total, language))}';

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
            Semantics(
              header: true,
              child: Text(
                l10n.cartRemoveTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: KitColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 1, color: KitColors.line),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: KitColors.card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SizedBox.square(
                    dimension: 72,
                    child: Center(
                      child: ProductImage(url: line.imageUrl, size: 56),
                    ),
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
                          fontWeight: FontWeight.w500,
                          color: KitColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: KitColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey<String>('remove-cancel'),
                    style: _style(filled: false),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      l10n.cancelButton,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey<String>('remove-confirm'),
                    style: _style(filled: true),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      l10n.cartRemoveConfirm,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
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
