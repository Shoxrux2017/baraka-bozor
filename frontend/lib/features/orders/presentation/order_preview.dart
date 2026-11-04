import 'package:flutter/material.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/product_image.dart';
import '../domain/customer_orders.dart';

/// What an order's lines are called on its card (`DL-131`): the first line's
/// name, the first two, or the first two and how many more there are. A name
/// is the interface language's.
String previewNames(
  AppLocalizations l10n,
  AppLanguage language,
  OrderPreview preview,
) {
  String name(OrderPreviewLine line) =>
      language == AppLanguage.ru ? line.nameRu : line.nameUz;

  final List<OrderPreviewLine> lines = preview.lines;
  if (lines.isEmpty) {
    return '';
  }
  if (lines.length == 1) {
    return name(lines[0]);
  }
  final int more = preview.lineCount - 2;
  return more <= 0
      ? l10n.orderPreviewTwo(name(lines[0]), name(lines[1]))
      : l10n.orderPreviewMore(name(lines[0]), name(lines[1]), more);
}

/// The pictures of an order's first lines (`DL-131`): a tile for each of up
/// to four lines; with more lines, three tiles and «+N» for the rest. An
/// order without lines shows one placeholder tile, and a line without a
/// picture the app's placeholder. It draws only: the card reads for it.
class OrderPictures extends StatelessWidget {
  const OrderPictures({required this.preview, super.key});

  final OrderPreview preview;

  @override
  Widget build(BuildContext context) {
    final List<OrderPreviewLine> lines = preview.lines;
    final bool more = preview.lineCount > 4;
    final int tiles = lines.isEmpty ? 1 : (more ? 3 : lines.length);

    // The tiles wrap to a second row when the room beside the status chip
    // is short, so they never overflow.
    return ExcludeSemantics(
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          for (int i = 0; i < tiles; i++)
            _Tile(url: i < lines.length ? lines[i].imageUrl : null),
          if (more) _MoreTile(count: preview.lineCount - 3),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey<String>('order-picture'),
      decoration: BoxDecoration(
        color: KitColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox.square(
        dimension: 44,
        child: Center(child: ProductImage(url: url, size: 32)),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey<String>('order-picture-more'),
      decoration: BoxDecoration(
        color: KitColors.field,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox.square(
        dimension: 44,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '+$count',
              maxLines: 1,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: KitColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
