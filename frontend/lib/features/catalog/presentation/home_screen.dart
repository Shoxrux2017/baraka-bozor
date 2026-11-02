import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/accessibility/announce.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/session/session_state.dart';
import '../../../core/state/loaded.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/customer_tab_bar.dart';
import '../../../core/widgets/fade_in_sliver.dart';
import '../../../core/widgets/skeleton_bar.dart';
import '../../../core/widgets/stale_data_line.dart';
import '../../addresses/presentation/delivery_address_widgets.dart';
import '../../cart/application/cart_controllers.dart';
import '../../cart/presentation/cart_widgets.dart';
import '../../orders/application/customer_orders_controllers.dart';
import '../../orders/presentation/question_banner.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'catalog_paths.dart';
import 'category_tile.dart';
import 'recommended_row.dart';
import 'section_title.dart';
import 'store_closed_line.dart';

/// The Customer area's home in the kit's look (`DL-80`, drawings 10 and 10a),
/// one scroll: where the order goes with the cart at its right, the search
/// field, which sticks to the top and opens the search screen (`DL-83`), then
/// the categories and the recommended products, over the tab bar. The active
/// mode shows at the top while two sessions exist, with the way back to the
/// staff area on it (`DL-75`, `docs/02-user-roles.md` section 10). While data
/// loads, skeletons stand in its place; pulling reloads it, and a load that
/// fails leaves what was shown under a line that says when it is from
/// (`DL-125`).
class CatalogHomeScreen extends ConsumerStatefulWidget {
  const CatalogHomeScreen({super.key});

  @override
  ConsumerState<CatalogHomeScreen> createState() => _CatalogHomeScreenState();
}

class _CatalogHomeScreenState extends ConsumerState<CatalogHomeScreen> {
  /// The categories the home shows before "Все".
  static const int _shownCategories = 8;
  static const double _gap = 12;
  static const ProductListQuery _featured = ProductListQuery(
    featuredOnly: true,
  );

  bool _sawSkeleton = false;

  static ApiFailure? _failureOf(AsyncValue<Object?> value) {
    if (!value.hasError) {
      return null;
    }
    final Object? error = value.error;
    return error is ApiFailure ? error : const UnexpectedFailure();
  }

  static Future<Object?> _errorOf(Future<Object?> load) async {
    try {
      await load;
      return null;
    } on Object catch (error) {
      return error;
    }
  }

  /// Reloads the categories, the recommended products, the question and the
  /// cart, and tells a screen reader how it went (`DL-125`).
  Future<void> _refresh() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? account = ref.read(customerAccountProvider);
    ref.invalidate(pendingQuestionsProvider);
    final List<Object?> errors = await Future.wait(<Future<Object?>>[
      _errorOf(ref.refresh(catalogCategoriesProvider.future)),
      _errorOf(ref.refresh(productListProvider(_featured).future)),
      if (account != null)
        _errorOf(ref.read(cartProvider(account).notifier).refresh()),
    ]);
    if (!mounted) {
      return;
    }
    final Object? error = errors[0] ?? errors[1];
    String message = l10n.refreshDone;
    if (error != null) {
      final String reason = error is NetworkFailure
          ? l10n.staleOffline
          : l10n.staleFailed;
      final Loaded<List<CatalogCategory>>? kept = ref
          .read(catalogCategoriesProvider)
          .value;
      message = kept == null
          ? reason
          : l10n.staleSpoken(reason, TashkentTime.time(kept.at));
    }
    announce(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<Loaded<List<CatalogCategory>>> categories = ref.watch(
      catalogCategoriesProvider,
    );
    final AsyncValue<ProductListState> recommended = ref.watch(
      productListProvider(_featured),
    );
    final Loaded<List<CatalogCategory>>? loaded = categories.value;
    final ApiFailure? failure =
        _failureOf(categories) ?? _failureOf(recommended);

    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final double gridWidth = MediaQuery.sizeOf(context).width - safe.horizontal;
    final int columns = categoryColumns(gridWidth, scaler);
    final double tile = (gridWidth - 32 - _gap * (columns - 1)) / columns;
    final SliverGridDelegate delegate =
        SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: _gap,
          mainAxisSpacing: _gap,
          mainAxisExtent: categoryTileExtent(tile, scaler, columns),
        );
    // Skeletons pulse while a load runs, and stand still after it failed.
    final bool pulsing = !categories.hasError || categories.isLoading;
    // The one style the hint is measured and drawn in: the theme's body text
    // at 14, so a large text never clips it.
    final TextStyle hintStyle =
        (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
          fontSize: 14,
          color: KitColors.muted,
        );
    const EdgeInsets gridPadding = EdgeInsets.fromLTRB(16, 8, 16, 8);

    final Widget categoryGrid;
    if (loaded == null) {
      _sawSkeleton = true;
      categoryGrid = SliverPadding(
        key: const ValueKey<String>('category-skeletons'),
        padding: gridPadding,
        sliver: SliverGrid(
          gridDelegate: delegate,
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SkeletonBar(
                  width: tile,
                  height: tile,
                  radius: 14,
                  pulsing: pulsing,
                ),
                const SizedBox(height: 6),
                Align(
                  child: SkeletonBar(
                    width: tile * 0.6,
                    height: 10,
                    pulsing: pulsing,
                  ),
                ),
              ],
            ),
            childCount: _shownCategories,
          ),
        ),
      );
    } else if (loaded.data.isEmpty) {
      categoryGrid = SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.catalogNoProducts, textAlign: TextAlign.center),
        ),
      );
    } else {
      final List<CatalogCategory> rows = loaded.data
          .take(_shownCategories)
          .toList();
      categoryGrid = FadeInSliver(
        key: const ValueKey<String>('category-tiles'),
        animate: _sawSkeleton,
        sliver: SliverPadding(
          padding: gridPadding,
          sliver: SliverGrid(
            gridDelegate: delegate,
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) => CategoryButton(
                key: ValueKey<String>('category-${rows[index].id}'),
                category: rows[index],
                columns: columns,
                size: tile,
              ),
              childCount: rows.length,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const CustomerTabBar(current: CustomerTab.home),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: KitColors.primary,
          onRefresh: _refresh,
          child: CustomScrollView(
            key: const ValueKey<String>('home-scroll'),
            primary: true,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              const SliverToBoxAdapter(
                child: ActiveModeBar(action: _SwitchToStaffButton()),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 4, 0),
                  child: Row(
                    children: <Widget>[
                      Expanded(child: DeliveryAddressLine()),
                      SizedBox(width: 8),
                      CartButton(),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                key: const ValueKey<String>('home-search-bar'),
                pinned: true,
                delegate: _SearchHeader(
                  hint: l10n.catalogSearchHint,
                  hintStyle: hintStyle,
                  spoken: l10n.catalogSearchSpoken,
                  extent: _SearchHeader.extentFor(
                    context,
                    l10n.catalogSearchHint,
                    hintStyle,
                  ),
                  reduceMotion: MediaQuery.disableAnimationsOf(context),
                ),
              ),
              const SliverToBoxAdapter(child: StoreClosedLine()),
              const SliverToBoxAdapter(child: QuestionBanner()),
              if (failure != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: StaleDataLine(
                      key: const ValueKey<String>('stale-line'),
                      failure: failure,
                      shownAt: loaded?.at,
                      onRetry: _refresh,
                      busy: categories.isLoading || recommended.isLoading,
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: SectionTitle(
                  title: l10n.homeCategories,
                  seeAllKey: 'open-categories',
                  seeAllLabel: l10n.homeCategoriesAll,
                  onSeeAll: () => context.push<void>(CatalogPaths.categories),
                ),
              ),
              categoryGrid,
              const SliverToBoxAdapter(
                child: RecommendedRow(placeholders: true),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The pinned search of the home: white, with a shadow under it only while
/// the page scrolls beneath it (`DL-125`). Its height follows the hint at
/// the text size, so a large text never squeezes the field.
class _SearchHeader extends SliverPersistentHeaderDelegate {
  const _SearchHeader({
    required this.hint,
    required this.hintStyle,
    required this.spoken,
    required this.extent,
    required this.reduceMotion,
  });

  final String hint;
  final TextStyle hintStyle;
  final String spoken;
  final double extent;
  final bool reduceMotion;

  static const BoxShadow _shadow = BoxShadow(
    color: Color(0x59151D16),
    offset: Offset(0, 8),
    blurRadius: 12,
    spreadRadius: -10,
  );

  /// 16 of padding and the field: 50, or the hint's line plus 28 when the
  /// text is large.
  static double extentFor(BuildContext context, String hint, TextStyle style) {
    final TextPainter line = TextPainter(
      text: TextSpan(text: hint, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final double height = line.height;
    line.dispose();
    return 16 + (height + 28 > 50 ? height + 28 : 50);
  }

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return AnimatedContainer(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: shrinkOffset > 0
            ? const <BoxShadow>[_shadow]
            : const <BoxShadow>[],
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: _SearchEntry(hint: hint, style: hintStyle, spoken: spoken),
    );
  }

  @override
  bool shouldRebuild(_SearchHeader oldDelegate) =>
      hint != oldDelegate.hint ||
      hintStyle != oldDelegate.hintStyle ||
      spoken != oldDelegate.spoken ||
      extent != oldDelegate.extent ||
      reduceMotion != oldDelegate.reduceMotion;
}

/// The search field of the home: it looks like the field and opens the
/// search screen when tapped.
class _SearchEntry extends StatelessWidget {
  const _SearchEntry({
    required this.hint,
    required this.style,
    required this.spoken,
  });

  final String hint;
  final TextStyle style;
  final String spoken;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: spoken,
      excludeSemantics: true,
      onTap: () => context.push<void>(CatalogPaths.search),
      child: Material(
        color: KitColors.field,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: const ValueKey<String>('catalog-search'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push<void>(CatalogPaths.search),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 50),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.search, color: KitColors.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style,
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

/// The way back to the staff area for a Shopper or Courier in Customer
/// mode, in one step (`docs/02-user-roles.md` section 10).
class _SwitchToStaffButton extends ConsumerWidget {
  const _SwitchToStaffButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      key: const ValueKey<String>('switch-to-staff-button'),
      onPressed: () => ref
          .read(sessionControllerProvider.notifier)
          .switchMode(SessionMode.staff),
      child: Text(
        AppLocalizations.of(context).switchToStaff,
        textAlign: TextAlign.end,
      ),
    );
  }
}
