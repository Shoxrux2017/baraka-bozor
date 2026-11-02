import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/state/loaded.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/fade_in_sliver.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/skeleton_bar.dart';
import '../../../core/widgets/stale_data_line.dart';
import '../../cart/presentation/cart_summary_bar.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'category_tile.dart';

/// Every category as a grid of tiles, as many to a row as the width and the
/// text size allow (`categoryColumns`); a tile opens the category. The cart
/// bar sits at the foot while the cart holds a line. Pulling refreshes; a
/// refresh that fails keeps the tiles under a line that says when they are
/// from, and a first load that fails shows that line over still skeletons
/// (`DL-125`).
class AllCategoriesScreen extends ConsumerStatefulWidget {
  const AllCategoriesScreen({super.key});

  @override
  ConsumerState<AllCategoriesScreen> createState() =>
      _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends ConsumerState<AllCategoriesScreen> {
  static const double _gap = 12;
  static const int _skeletons = 12;

  /// The ids this screen has drawn; a later id comes in softly.
  final Set<String> _shown = <String>{};
  bool _sawSkeleton = false;

  Future<void> _refresh() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    String message;
    try {
      ref.invalidate(catalogCategoriesProvider);
      await ref.read(catalogCategoriesProvider.future);
      message = l10n.refreshDone;
    } on Object catch (error) {
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
    if (mounted) {
      announce(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<Loaded<List<CatalogCategory>>> async = ref.watch(
      catalogCategoriesProvider,
    );
    final Loaded<List<CatalogCategory>>? loaded = async.value;
    final Object? error = async.hasError ? async.error : null;
    final ApiFailure? failure = async.hasError
        ? (error is ApiFailure ? error : const UnexpectedFailure())
        : null;

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
    final EdgeInsets gridPadding = EdgeInsets.fromLTRB(
      16 + safe.left,
      16,
      16 + safe.right,
      16 + CartSummaryBar.reserved(context),
    );

    final List<Widget> slivers = <Widget>[
      if (failure != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16 + safe.left, 8, 16 + safe.right, 0),
            child: StaleDataLine(
              key: const ValueKey<String>('stale-line'),
              failure: failure,
              shownAt: loaded?.at,
              onRetry: () => ref.invalidate(catalogCategoriesProvider),
            ),
          ),
        ),
    ];
    if (loaded == null) {
      _sawSkeleton = true;
      slivers.add(
        SliverPadding(
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
                    pulsing: failure == null,
                  ),
                  const SizedBox(height: 6),
                  Align(
                    child: SkeletonBar(
                      width: tile * 0.6,
                      height: 10,
                      pulsing: failure == null,
                    ),
                  ),
                ],
              ),
              childCount: _skeletons,
            ),
          ),
        ),
      );
    } else if (loaded.data.isEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.catalogNoProducts, textAlign: TextAlign.center),
          ),
        ),
      );
    } else {
      final List<CatalogCategory> rows = loaded.data;
      final Set<String> known = Set<String>.of(_shown);
      _shown.addAll(rows.map((CatalogCategory c) => c.id));
      slivers.add(
        FadeInSliver(
          key: const ValueKey<String>('category-tiles'),
          animate: _sawSkeleton,
          sliver: SliverPadding(
            padding: gridPadding,
            sliver: SliverGrid(
              gridDelegate: delegate,
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) => _AppearTile(
                  key: ValueKey<String>('appear-${rows[index].id}'),
                  animate: known.isNotEmpty && !known.contains(rows[index].id),
                  child: CategoryButton(
                    key: ValueKey<String>('category-${rows[index].id}'),
                    category: rows[index],
                    columns: columns,
                    size: tile,
                  ),
                ),
                childCount: rows.length,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: kitAppBar(title: l10n.homeCategories, search: true),
      // The mode stays visible while two sessions exist (DL-75).
      body: UnderActiveMode(
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: RefreshIndicator(
                color: KitColors.primary,
                onRefresh: _refresh,
                child: CustomScrollView(
                  key: const ValueKey<String>('category-grid'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: slivers,
                ),
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
    );
  }
}

/// A tile new after a refresh comes in from scale 0.85 and opacity 0 over
/// 250 ms `easeOut`; with reduced motion, or an [animate] that was not set
/// when it was first built, it is there at once (`DL-125`).
class _AppearTile extends StatefulWidget {
  const _AppearTile({required this.animate, required this.child, super.key});

  final bool animate;
  final Widget child;

  @override
  State<_AppearTile> createState() => _AppearTileState();
}

class _AppearTileState extends State<_AppearTile> {
  late final bool _animate = widget.animate;

  @override
  Widget build(BuildContext context) {
    final bool still = !_animate || MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: still ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
      ),
      child: widget.child,
    );
  }
}

/// The failure of loading the categories, with the retry.
class CategoriesFailure extends StatelessWidget {
  const CategoriesFailure({
    required this.failure,
    required this.onRetry,
    super.key,
  });

  final ApiFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FailureMessage(failure),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const ValueKey<String>('retry-load'),
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).retryButton),
            ),
          ],
        ),
      ),
    );
  }
}
