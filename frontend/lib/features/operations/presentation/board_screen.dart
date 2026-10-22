import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/platform/clock.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../../core/widgets/panel/panel_layout.dart';
import '../../../core/widgets/panel/panel_page_header.dart';
import '../application/board_controllers.dart';
import '../domain/board.dart';
import 'board_attention.dart';
import 'board_orders.dart';
import 'board_summary.dart';

/// The board, the Operator's and the Admin's home (`docs/09` section 38,
/// `DL-37` (16), `DL-100` (2)): the day's tiles and the status row above,
/// the orders as a server-paginated table with its filters and search, and
/// the attention list beside them — above them on a narrow board. An order
/// opens on its own page.
class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key});

  /// From this board width — the content, without its padding — the
  /// attention list stands at the right of the orders, [attentionWidth] wide
  /// and [attentionGap] apart. Below it the list goes above the orders.
  static const double attentionBeside = 1140;
  static const double attentionWidth = 300;
  static const double attentionGap = 20;

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  /// When the summary last arrived, for "updated at" in the header.
  DateTime? _loadedAt;

  @override
  void initState() {
    super.initState();
    // A summary kept from an earlier visit is loaded again once, after the
    // first frame; "updated at" then shows when that load completed.
    final bool kept = ref.read(boardSummaryProvider).hasValue;
    ref.listenManual<AsyncValue<BoardSummary>>(boardSummaryProvider, (
      AsyncValue<BoardSummary>? _,
      AsyncValue<BoardSummary> next,
    ) {
      if (next.hasValue && !next.isLoading) {
        setState(() => _loadedAt = ref.read(clockProvider)());
      }
    });
    if (kept) {
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (mounted) {
          ref.invalidate(boardSummaryProvider);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateTime? loadedAt = _loadedAt;
    final EdgeInsets padding = panelPagePadding(
      MediaQuery.sizeOf(context).width,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double content = constraints.maxWidth - padding.horizontal;
        final bool beside = content >= BoardScreen.attentionBeside;
        final bool labelled = content >= boardCompactWidth;

        return ListView(
          key: const ValueKey<String>('operations-board'),
          padding: padding,
          children: <Widget>[
            PanelPageHeader(
              title: l10n.panelSectionBoard,
              subtitle: loadedAt == null
                  ? null
                  : l10n.boardUpdatedAt(TashkentTime.time(loadedAt)),
              trailing: labelled
                  ? OutlinedButton.icon(
                      key: const ValueKey<String>('board-refresh'),
                      style: kitOutlined(height: 40),
                      icon: const Icon(Icons.refresh, size: 20),
                      label: Text(l10n.boardRefresh),
                      onPressed: () => refreshBoard(ref),
                    )
                  : Tooltip(
                      message: l10n.boardRefresh,
                      child: OutlinedButton(
                        key: const ValueKey<String>('board-refresh'),
                        style: kitOutlined(height: 40).copyWith(
                          minimumSize: const WidgetStatePropertyAll<Size>(
                            Size(40, 40),
                          ),
                          padding: const WidgetStatePropertyAll<EdgeInsets>(
                            EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                        onPressed: () => refreshBoard(ref),
                        child: const Icon(Icons.refresh, size: 20),
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            const BoardSummaryTiles(),
            const SizedBox(height: 16),
            const BoardStatusPills(),
            const SizedBox(height: 16),
            if (beside)
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[BoardOrders()],
                    ),
                  ),
                  SizedBox(width: BoardScreen.attentionGap),
                  SizedBox(
                    width: BoardScreen.attentionWidth,
                    child: BoardAttention(beside: true),
                  ),
                ],
              )
            else ...const <Widget>[
              BoardAttention(beside: false),
              SizedBox(height: 16),
              BoardOrders(),
            ],
          ],
        );
      },
    );
  }
}
