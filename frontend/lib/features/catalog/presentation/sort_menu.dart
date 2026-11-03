import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/press_scale.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';

/// The words of a sort, as the menu and the count row show them.
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

/// Asks the Customer for the order of the product lists with a menu that
/// opens under [anchor] (`DL-127`); `null` when it is dismissed.
Future<ProductSort?> showSortMenu(BuildContext anchor, ProductSort current) {
  final NavigatorState navigator = Navigator.of(anchor);
  final RenderBox box = anchor.findRenderObject()! as RenderBox;
  final RenderBox overlay =
      navigator.overlay!.context.findRenderObject()! as RenderBox;
  final Rect from =
      box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;

  return navigator.push<ProductSort>(
    _SortMenuRoute(
      anchor: from,
      current: current,
      title: AppLocalizations.of(anchor).sortTitle,
      barrierLabel: MaterialLocalizations.of(anchor).modalBarrierDismissLabel,
      reducedMotion: MediaQuery.disableAnimationsOf(anchor),
    ),
  );
}

/// The menu's route: no dim, a tap outside closes it. It grows from its
/// top-end corner in 180 ms and closes by a 150 ms fade; with reduced motion
/// it only fades (200 ms in).
class _SortMenuRoute extends PopupRoute<ProductSort> {
  _SortMenuRoute({
    required this.anchor,
    required this.current,
    required this.title,
    required this.barrierLabel,
    required this.reducedMotion,
  });

  final Rect anchor;
  final ProductSort current;
  final String title;
  final bool reducedMotion;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration =>
      Duration(milliseconds: reducedMotion ? 200 : 180);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: CustomSingleChildLayout(
        delegate: _MenuLayout(
          anchor: anchor,
          inset: MediaQuery.paddingOf(context),
          textDirection: Directionality.of(context),
        ),
        child: _SortMenu(current: current),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const Cubic curve = Cubic(0.2, 0.8, 0.2, 1);
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (BuildContext context, Widget? child) {
        final bool closing = animation.status == AnimationStatus.reverse;
        final double eased = closing
            ? animation.value
            : curve.transform(animation.value);
        final bool grows = !reducedMotion && !closing;
        return Opacity(
          opacity: eased,
          child: Transform.scale(
            scale: grows ? 0.86 + 0.14 * eased : 1,
            alignment: AlignmentDirectional.topEnd.resolve(
              Directionality.of(context),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// Puts the menu 2 under the anchor with its end 6 inside the anchor's end,
/// kept 8 inside the screen's safe area.
class _MenuLayout extends SingleChildLayoutDelegate {
  const _MenuLayout({
    required this.anchor,
    required this.inset,
    required this.textDirection,
  });

  final Rect anchor;
  final EdgeInsets inset;
  final TextDirection textDirection;

  static const double _edge = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(
          constraints.maxWidth - inset.horizontal - 2 * _edge,
          constraints.maxHeight - inset.vertical - 2 * _edge,
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final double wanted = textDirection == TextDirection.ltr
        ? anchor.right - 6 - childSize.width
        : anchor.left + 6;
    final double left = wanted.clamp(
      inset.left + _edge,
      size.width - inset.right - _edge - childSize.width,
    );
    final double top = (anchor.bottom + 2).clamp(
      inset.top + _edge,
      size.height - inset.bottom - _edge - childSize.height,
    );
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_MenuLayout old) =>
      old.anchor != anchor ||
      old.inset != inset ||
      old.textDirection != textDirection;
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.current});

  final ProductSort current;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return DecoratedBox(
      key: const ValueKey<String>('sort-menu'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33151D16),
            offset: Offset(0, 12),
            blurRadius: 32,
          ),
          BoxShadow(color: Color(0x0F151D16), spreadRadius: 1),
        ],
      ),
      child: SizedBox(
        width: 232,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final ProductSort sort in ProductSort.values)
                    _SortItem(
                      key: ValueKey<String>(_keys[sort]!),
                      label: sortLabel(l10n, sort),
                      chosen: sort == current,
                      last: sort == ProductSort.values.last,
                      onTap: () => Navigator.of(context).pop(sort),
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

class _SortItem extends StatelessWidget {
  const _SortItem({
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
    return Semantics(
      button: true,
      selected: chosen,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: const Color(0xFFF3F4F3),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: last
                  ? null
                  : const Border(bottom: BorderSide(color: KitColors.line)),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 10, end: 16),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 24,
                    child: chosen
                        ? const Icon(
                            Icons.check,
                            size: 20,
                            color: KitColors.primaryDark,
                          )
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: chosen
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: KitColors.ink,
                        ),
                      ),
                    ),
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

/// The row above the cards of a product list (`DL-127`): how many products
/// there are, and the current order as a button that opens [showSortMenu].
/// It counts the products of [query]'s list; while another order of the same
/// products loads it keeps the last total, and nothing is counted before any
/// is known. [countText] words the count instead of `catalogProductCount`
/// (the number in it is drawn in ink); with [keepAcrossSearch] the last total
/// stays while another search of the same filter loads and goes when it fails
/// (`DL-128`).
class ProductListCountRow extends ConsumerWidget {
  const ProductListCountRow({
    required this.query,
    required this.sort,
    required this.onSort,
    this.countText,
    this.keepAcrossSearch = false,
    super.key,
  });

  final ProductListQuery query;
  final ProductSort sort;
  final ValueChanged<ProductSort> onSort;
  final String Function(int count)? countText;
  final bool keepAcrossSearch;

  Future<void> _open(BuildContext anchor) async {
    final ProductSort? chosen = await showSortMenu(anchor, sort);
    if (chosen != null && chosen != sort) {
      onSort(chosen);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ListTotalMemo memo = ref.read(
      listTotalMemoProvider(
        ProductListQuery(
          categoryId: query.categoryId,
          search: keepAcrossSearch ? '' : query.search,
          featuredOnly: query.featuredOnly,
        ),
      ),
    );
    final AsyncValue<ProductListState> list = ref.watch(
      productListProvider(query),
    );
    final int? known = list.value?.total;
    if (known != null) {
      memo.total = known;
    } else if (keepAcrossSearch && list.hasError) {
      memo.total = null;
    }
    final int? count = known ?? memo.total;
    final String label = sortLabel(l10n, sort);
    final String Function(int count) words =
        countText ?? l10n.catalogProductCount;

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, end: 6),
      // The button takes at most 60 % so a long order name wraps at large
      // text and the count keeps the rest.
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) => Row(
          children: <Widget>[
            Expanded(
              child: count == null
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _Count(text: words(count)),
                    ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * 0.6),
              child: Builder(
                builder: (BuildContext anchor) => PressScale(
                  key: const ValueKey<String>('list-sort'),
                  label: l10n.sortSpoken(label),
                  onTap: () => _open(anchor),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 10,
                        end: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: KitColors.primaryDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.expand_more,
                            size: 20,
                            color: KitColors.primaryDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "24 товара" or "Найдено: 4 товара" with the number in ink and the rest
/// muted.
class _Count extends StatelessWidget {
  const _Count({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final Match? found = RegExp(r'\d+').firstMatch(text);
    final int from = found?.start ?? 0;
    final int to = found?.end ?? 0;
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: text.substring(0, from)),
          TextSpan(
            text: text.substring(from, to),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: KitColors.ink,
            ),
          ),
          TextSpan(text: text.substring(to)),
        ],
      ),
      style: const TextStyle(fontSize: 13, height: 1.3, color: KitColors.muted),
    );
  }
}
