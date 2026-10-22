import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/phone_format.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/network/paged.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/kit/kit_card.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/panel/panel_card.dart';
import '../../../core/widgets/panel/panel_pager.dart';
import '../application/board_controllers.dart';
import '../domain/board.dart';
import 'board_filters.dart';
import 'board_widgets.dart';
import 'operations_paths.dart';

/// The orders card (`DL-100` (3)): the filters, then the page of orders — a
/// table from a card [tableWidth] wide, cards below it — and the pager.
class BoardOrders extends ConsumerWidget {
  const BoardOrders({super.key});

  /// From this card width the orders are a table whose six columns all
  /// show; below it, cards, which show the same.
  static const double tableWidth = 760;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<Paged<BoardRow>> page = ref.watch(boardPageProvider);
    final bool filtered = ref.watch(
      boardQueryProvider.select((BoardQuery query) => query.isFiltered),
    );

    return PanelCard(
      flush: true,
      children: <Widget>[
        const BoardFilters(),
        page.when(
          skipLoadingOnReload: false,
          skipLoadingOnRefresh: !page.hasError,
          data: (Paged<BoardRow> page) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (page.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    filtered ? l10n.boardEmptyFiltered : l10n.boardEmpty,
                  ),
                )
              else
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) =>
                      constraints.maxWidth >= tableWidth
                      ? _OrdersTable(rows: page.items)
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                          child: Column(
                            children: <Widget>[
                              for (final BoardRow row in page.items)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _OrderCard(row: row),
                                ),
                            ],
                          ),
                        ),
                ),
              PanelPager(
                page: page,
                onPage: ref.read(boardQueryProvider.notifier).goToPage,
              ),
            ],
          ),
          error: (Object error, StackTrace _) => LoadFailure(
            error: error,
            onRetry: () => ref.invalidate(boardPageProvider),
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }
}

const Map<int, TableColumnWidth> _columns = <int, TableColumnWidth>{
  0: FlexColumnWidth(1),
  1: FlexColumnWidth(2),
  2: FlexColumnWidth(2),
  3: FlexColumnWidth(1.1),
  4: FlexColumnWidth(1.5),
  5: FlexColumnWidth(1.8),
};

const TextStyle _text = TextStyle(fontSize: 13, color: KitColors.ink);
const TextStyle _strong = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w700,
  color: KitColors.ink,
);
const TextStyle _small = TextStyle(fontSize: 12, color: KitColors.muted);

/// The table: a header on `card` between two `line` rules, then a row per
/// order, each a table of its own under the same column widths, so a row
/// takes a hover and a tap as a whole and grows with its text.
class _OrdersTable extends StatelessWidget {
  const _OrdersTable({required this.rows});

  final List<BoardRow> rows;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    const BorderSide line = BorderSide(color: KitColors.line);

    Widget header(String text, {TextAlign align = TextAlign.start}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: KitColors.muted,
        ),
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DecoratedBox(
            decoration: const BoxDecoration(
              color: KitColors.card,
              border: Border.symmetric(horizontal: line),
            ),
            child: Table(
              columnWidths: _columns,
              children: <TableRow>[
                TableRow(
                  children: <Widget>[
                    header(l10n.boardColumnOrder),
                    header(l10n.boardColumnCustomer),
                    header(l10n.boardColumnStatus),
                    header(l10n.boardColumnPayment),
                    header(l10n.boardColumnTotal, align: TextAlign.end),
                    header(l10n.boardColumnPeople),
                  ],
                ),
              ],
            ),
          ),
          for (final BoardRow row in rows) _OrderRow(row: row),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.row});

  final BoardRow row;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    Widget cell(Widget child, {Alignment align = Alignment.centerLeft}) =>
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(alignment: align, child: child),
        );

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KitColors.line)),
      ),
      child: InkWell(
        key: ValueKey<String>('board-row-${row.id}'),
        hoverColor: KitColors.field,
        onTap: () => context.go(OperationsPaths.order(row.id)),
        child: Table(
          columnWidths: _columns,
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: <TableRow>[
            TableRow(
              children: <Widget>[
                cell(_NumberAndTime(row: row)),
                cell(_Customer(row: row)),
                cell(_StatusAndQuestions(row: row)),
                cell(
                  Text(
                    OrderLabels.paymentMethod(l10n, row.paymentMethod),
                    style: _text,
                  ),
                ),
                cell(
                  _TotalAndCount(row: row, align: CrossAxisAlignment.end),
                  align: Alignment.centerRight,
                ),
                cell(_People(row: row)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.row});

  final BoardRow row;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return KitCard(
      key: ValueKey<String>('board-row-${row.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () => context.go(OperationsPaths.order(row.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(child: _NumberAndTime(row: row, inline: true)),
              const SizedBox(width: 12),
              Flexible(child: OrderStatusChip(row.status)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _Customer(row: row)),
              const SizedBox(width: 12),
              Flexible(
                child: _TotalAndCount(
                  row: row,
                  align: CrossAxisAlignment.end,
                  withCount: false,
                ),
              ),
            ],
          ),
          if (row.pendingApprovalCount > 0) ...<Widget>[
            const SizedBox(height: 6),
            _Questions(row: row),
          ],
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(child: _People(row: row)),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '${OrderLabels.paymentMethod(l10n, row.paymentMethod)} · '
                  '${l10n.boardItemCount(row.itemCount)}',
                  textAlign: TextAlign.end,
                  style: _small,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The order's number over its time, or beside it on a card.
class _NumberAndTime extends StatelessWidget {
  const _NumberAndTime({required this.row, this.inline = false});

  final BoardRow row;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Text number = Text(
      l10n.boardOrderNumber('${row.orderNumber}'),
      style: _strong,
    );
    final Text time = Text(TashkentTime.time(row.createdAt), style: _small);

    if (inline) {
      return Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[number, time],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[number, time],
    );
  }
}

/// Who ordered: the name over the phone, or that the Customer's data is
/// gone.
class _Customer extends StatelessWidget {
  const _Customer({required this.row});

  final BoardRow row;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? phone = row.customerPhone;
    final bool erased = row.customerErased || phone == null;

    return Column(
      key: ValueKey<String>('board-customer-${row.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (erased)
          Text(
            l10n.orderCustomerErased,
            style: _small.copyWith(fontStyle: FontStyle.italic),
          )
        else ...<Widget>[
          Text(row.customerName ?? l10n.customerNoName, style: _text),
          Text(formatPhone(phone), style: _small),
        ],
      ],
    );
  }
}

/// The status, and under it the Customer's open questions when there are
/// any.
class _StatusAndQuestions extends StatelessWidget {
  const _StatusAndQuestions({required this.row});

  final BoardRow row;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        OrderStatusChip(row.status),
        if (row.pendingApprovalCount > 0) ...<Widget>[
          const SizedBox(height: 6),
          _Questions(row: row),
        ],
      ],
    );
  }
}

class _Questions extends StatelessWidget {
  const _Questions({required this.row});

  final BoardRow row;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.help_outline,
            size: 14,
            color: KitColors.warningDark,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            l10n.boardPendingQuestions(row.pendingApprovalCount),
            key: ValueKey<String>('board-questions-${row.id}'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: KitColors.warningDark,
            ),
          ),
        ),
      ],
    );
  }
}

/// The total over the number of items.
class _TotalAndCount extends StatelessWidget {
  const _TotalAndCount({
    required this.row,
    required this.align,
    this.withCount = true,
  });

  final BoardRow row;
  final CrossAxisAlignment align;
  final bool withCount;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          totalText(context, l10n, row.totalUzs, row.totalKind),
          textAlign: TextAlign.end,
          style: _strong,
        ),
        if (withCount)
          Text(
            l10n.boardItemCount(row.itemCount),
            textAlign: TextAlign.end,
            style: _small,
          ),
      ],
    );
  }
}

/// The Shopper and, once there is one, the Courier the row names, with the
/// self-order mark (`DL-62` (4)). An order with nobody yet says so once.
class _People extends StatelessWidget {
  const _People({required this.row});

  final BoardRow row;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final PersonRef? shopper = row.shopper;
    final PersonRef? courier = row.courier;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _Person(
              icon: Icons.shopping_basket_outlined,
              text: shopper == null
                  ? l10n.boardNoShopper
                  : nameOf(l10n, shopper),
              muted: shopper == null,
            ),
            if (row.isSelfOrder) const SelfOrderMark(),
          ],
        ),
        if (courier != null || shopper != null) ...<Widget>[
          const SizedBox(height: 4),
          _Person(
            key: ValueKey<String>('board-courier-${row.id}'),
            icon: Icons.two_wheeler,
            text: courier == null ? l10n.boardNoCourier : nameOf(l10n, courier),
            muted: courier == null,
            semanticLabel: courier == null
                ? null
                : l10n.boardCourierNamed(nameOf(l10n, courier)),
          ),
        ],
      ],
    );
  }
}

class _Person extends StatelessWidget {
  const _Person({
    required this.icon,
    required this.text,
    required this.muted,
    this.semanticLabel,
    super.key,
  });

  final IconData icon;
  final String text;
  final bool muted;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Color color = muted ? KitColors.muted : KitColors.ink;

    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 14, color: KitColors.muted),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text, style: TextStyle(fontSize: 13, color: color)),
          ),
        ],
      ),
    );
  }
}
