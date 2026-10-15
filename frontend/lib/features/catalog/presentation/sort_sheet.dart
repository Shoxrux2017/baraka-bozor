import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import '../domain/catalog.dart';

/// The words of a sort, as the sheet and the sort chip show them.
String sortLabel(AppLocalizations l10n, ProductSort sort) => switch (sort) {
  ProductSort.shop => l10n.sortShop,
  ProductSort.priceAsc => l10n.sortPriceAsc,
  ProductSort.priceDesc => l10n.sortPriceDesc,
};

const Map<ProductSort, String> _keys = <ProductSort, String>{
  ProductSort.shop: 'sort-shop',
  ProductSort.priceAsc: 'sort-price-asc',
  ProductSort.priceDesc: 'sort-price-desc',
};

/// Asks the Customer for the order of the product lists; `null` when the
/// sheet is dismissed.
Future<ProductSort?> showSortSheet(BuildContext context, ProductSort current) =>
    showModalBottomSheet<ProductSort>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) => _SortSheet(current: current),
    );

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.current});

  final ProductSort current;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
            Text(
              l10n.sortTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: KitColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            for (final ProductSort sort in ProductSort.values)
              _SortRow(
                key: ValueKey<String>(_keys[sort]!),
                label: sortLabel(l10n, sort),
                chosen: sort == current,
                last: sort == ProductSort.values.last,
                onTap: () => Navigator.of(context).pop(sort),
              ),
          ],
        ),
      ),
    );
  }
}

class _SortRow extends StatelessWidget {
  const _SortRow({
    required this.label,
    required this.chosen,
    required this.last,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool chosen;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: KitColors.line)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: chosen ? FontWeight.w600 : FontWeight.w500,
                  color: KitColors.ink,
                ),
              ),
            ),
            if (chosen)
              const Icon(Icons.check_circle, color: KitColors.primary),
          ],
        ),
      ),
    );
  }
}
