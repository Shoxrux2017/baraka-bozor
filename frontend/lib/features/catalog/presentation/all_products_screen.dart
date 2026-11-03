import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../cart/presentation/cart_summary_bar.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'aisles.dart';
import 'kit_product_grid.dart';
import 'sort_menu.dart';

/// "Все товары": every product the Customer may see, in the order the
/// Customer chose; the count row above the cards shows it and opens the menu
/// (`DL-127`). In the shop's order the products stand aisle by aisle under
/// headings, with a row of chips that lights the aisle in view and glides to
/// the one tapped (`DL-128`).
/// The header's search arrives with the search screen (kit stage 3).
class AllProductsScreen extends ConsumerStatefulWidget {
  const AllProductsScreen({super.key});

  @override
  ConsumerState<AllProductsScreen> createState() => _AllProductsScreenState();
}

class _AllProductsScreenState extends ConsumerState<AllProductsScreen> {
  static const Cubic _glide = Cubic(0.2, 0.8, 0.2, 1);

  final ProductAisles _aisles = ProductAisles(const <CatalogCategory>[]);
  final ScrollController _scroll = ScrollController();

  /// Counts the chip taps; a jump that is no longer the latest gives up.
  int _jump = 0;
  Timer? _unlock;

  /// The aisles are the categories that hold products.
  List<CatalogCategory> _aislesOf(List<CatalogCategory>? categories) =>
      <CatalogCategory>[
        for (final CatalogCategory c in categories ?? const <CatalogCategory>[])
          if (c.productCount > 0) c,
      ];

  @override
  void initState() {
    super.initState();
    _aisles.categories = _aislesOf(
      ref.read(catalogCategoriesProvider).value?.data,
    );
    _scroll.addListener(() {
      if (_scroll.hasClients) {
        _aisles.follow(_scroll.position.pixels);
      }
    });
    ref.listenManual(catalogCategoriesProvider, (_, next) {
      _aisles.categories = _aislesOf(next.value?.data);
    });
    // Another order starts at the top, at the first aisle.
    ref.listenManual(productSortProvider, (_, _) {
      _jump++;
      _unlock?.cancel();
      _aisles.reset();
    });
  }

  @override
  void dispose() {
    _unlock?.cancel();
    _aisles.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// A chip tap: lights the aisle, loads the pages up to it, glides to its
  /// heading and says where it is. A later tap takes over from this one.
  Future<void> _goTo(String id) async {
    final int jump = ++_jump;
    _unlock?.cancel();
    _aisles.lock();
    _aisles.current = id;
    final ProductListQuery query = ProductListQuery(
      sort: ref.read(productSortProvider),
    );
    final int need = _aisles.endOf(id);
    final int loaded =
        ref.read(productListProvider(query)).value?.items.length ?? 0;
    if (loaded < need) {
      await ref.read(productListProvider(query).notifier).loadThrough(need);
      if (!mounted || jump != _jump) {
        return;
      }
      // The headings of the new pages are reported after the frame.
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted || jump != _jump) {
        return;
      }
    }
    if (!_scroll.hasClients) {
      return;
    }
    final double? start = _aisles.starts[id];
    final ScrollPosition position = _scroll.position;
    // A page that failed stops the jump at its row, in place.
    double goal() => start == null
        ? position.maxScrollExtent
        : (start - 6).clamp(0.0, position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      position.jumpTo(goal());
    } else {
      await position.animateTo(
        goal(),
        duration: const Duration(milliseconds: 400),
        curve: _glide,
      );
    }
    // The list's length is an estimate until its last rows are laid out, so
    // the end may lie further than it did: settle at the real goal.
    for (int tries = 0; tries < 3; tries++) {
      if (!mounted || jump != _jump || !_scroll.hasClients) {
        return;
      }
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted || jump != _jump || !_scroll.hasClients) {
        return;
      }
      if ((position.pixels - goal()).abs() < 1) {
        break;
      }
      position.jumpTo(goal());
    }
    if (!mounted || jump != _jump) {
      return;
    }
    if (start != null) {
      final CatalogCategory category = _aisles.categories.firstWhere(
        (CatalogCategory c) => c.id == id,
      );
      final AppLocalizations l10n = AppLocalizations.of(context);
      announce(
        context,
        l10n.aisleHeadingSpoken(
          category.name(interfaceLanguage(context)),
          l10n.catalogProductCount(category.productCount),
        ),
      );
    }
    _unlock = Timer(const Duration(milliseconds: 700), _aisles.unlock);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ProductSort sort = ref.watch(productSortProvider);
    final ProductListQuery query = ProductListQuery(sort: sort);
    // The aisles come with the categories; the list is flat until they do.
    ref.watch(catalogCategoriesProvider);
    final bool aisleMode =
        sort == ProductSort.shop && _aisles.categories.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: kitAppBar(
        title: l10n.allProductsTitle,
        search: true,
        titleFlight: true,
      ),
      // The mode stays visible while two sessions exist (DL-75).
      // Side insets (a camera at the side, lying) are kept clear (DL-127).
      body: SafeArea(
        top: false,
        bottom: false,
        child: UnderActiveMode(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Column(
                  children: <Widget>[
                    AisleChipsFold(
                      shown: aisleMode,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          AisleChips(aisles: _aisles, onTap: _goTo),
                          const SizedBox(
                            height: 1,
                            child: ColoredBox(color: KitColors.line),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: KitProductGrid(
                        query: query,
                        controller: _scroll,
                        aisles: _aisles,
                        header: <Widget>[
                          SliverToBoxAdapter(
                            child: ProductListCountRow(
                              key: const ValueKey<String>('list-count-row'),
                              query: query,
                              sort: sort,
                              onSort: ref
                                  .read(productSortProvider.notifier)
                                  .set,
                            ),
                          ),
                        ],
                        padding: EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          16 + CartSummaryBar.reserved(context),
                        ),
                        spokenOnQuery: (ProductListQuery q, int total) =>
                            l10n.categoryShownSpoken(
                              l10n.allProductsTitle,
                              l10n.catalogProductCount(total),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: CartSummaryBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
