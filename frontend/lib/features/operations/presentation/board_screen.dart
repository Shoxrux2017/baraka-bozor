import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/phone_format.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/network/paged.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/widgets/list_widgets.dart';
import '../application/board_controllers.dart';
import '../domain/board.dart';
import 'board_widgets.dart';
import 'operations_paths.dart';

/// The board, the Operator's and the Admin's home (`docs/09` section 38,
/// `DL-37` (16)): the day's summary above, the orders as a server-paginated
/// table with its filters and search, and the attention list beside it —
/// under the summary on a narrow window. An order opens on its own page.
class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});

  /// From this width the attention list stands beside the orders and the
  /// table beside it still shows every column, the Shopper's included: the
  /// table's usual width, the gap, the list and the board's padding. Below
  /// it the list goes above the orders, which keep the whole width.
  static const double sideBySide = _Table.usualWidth + 16 + 320 + 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= sideBySide;

        return ListView(
          key: const ValueKey<String>('operations-board'),
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  l10n.panelSectionBoard,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                OutlinedButton.icon(
                  key: const ValueKey<String>('board-refresh'),
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.boardRefresh),
                  onPressed: () => refreshBoard(ref),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _SummaryStrip(),
            const SizedBox(height: 16),
            const _Filters(),
            const SizedBox(height: 16),
            if (wide)
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: _Orders()),
                  SizedBox(width: 16),
                  SizedBox(width: 320, child: _AttentionList()),
                ],
              )
            else ...const <Widget>[
              _AttentionList(),
              SizedBox(height: 16),
              _Orders(),
            ],
          ],
        );
      },
    );
  }
}

/// The day's numbers: the open orders by status — each a way to filter the
/// board by it — and today's completed, cancelled, sales and attention.
class _SummaryStrip extends ConsumerWidget {
  const _SummaryStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<BoardSummary> summary = ref.watch(boardSummaryProvider);
    final BoardQueryController queries = ref.read(boardQueryProvider.notifier);
    final OrderStatus? filtered = ref.watch(
      boardQueryProvider.select((BoardQuery query) => query.status),
    );

    return summary.when(
      skipLoadingOnRefresh: !summary.hasError,
      data: (BoardSummary summary) => Wrap(
        key: const ValueKey<String>('board-summary'),
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final MapEntry<OrderStatus, int> open
              in summary.openByStatus.entries)
            FilterChip(
              key: ValueKey<String>('summary-${open.key.code}'),
              label: Text(
                '${OrderLabels.status(l10n, open.key)}: ${open.value}',
              ),
              selected: filtered == open.key,
              onSelected: (bool selected) =>
                  queries.filterByStatus(selected ? open.key : null),
            ),
          Chip(
            key: const ValueKey<String>('summary-completed'),
            label: Text(
              '${l10n.summaryCompletedToday}: ${summary.completedToday}',
            ),
          ),
          Chip(
            key: const ValueKey<String>('summary-cancelled'),
            label: Text(
              '${l10n.summaryCancelledToday}: ${summary.cancelledToday}',
            ),
          ),
          Chip(
            key: const ValueKey<String>('summary-sales'),
            label: Text(
              '${l10n.summarySalesToday}: '
              '${MoneyFormat.uzs(summary.salesTodayUzs, interfaceLanguage(context))}',
            ),
          ),
          Chip(
            key: const ValueKey<String>('summary-attention'),
            label: Text('${l10n.summaryAttention}: ${summary.attentionCount}'),
          ),
        ],
      ),
      error: (Object error, StackTrace _) => LoadFailure(
        error: error,
        onRetry: () => ref.invalidate(boardSummaryProvider),
      ),
      loading: () => const LinearProgressIndicator(),
    );
  }
}

class _Filters extends ConsumerStatefulWidget {
  const _Filters();

  @override
  ConsumerState<_Filters> createState() => _FiltersState();
}

class _FiltersState extends ConsumerState<_Filters> {
  late final TextEditingController _search = TextEditingController(
    text: ref.read(boardQueryProvider).search,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickDays(BoardQuery query) async {
    final DateTime now = DateTime.now();
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: query.from != null && query.to != null
          ? DateTimeRange(start: query.from!, end: query.to!)
          : null,
    );
    if (range != null && mounted) {
      ref
          .read(boardQueryProvider.notifier)
          .filterByDays(range.start, range.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BoardQuery query = ref.watch(boardQueryProvider);
    final BoardQueryController queries = ref.read(boardQueryProvider.notifier);
    final List<ShopperChoice> shoppers =
        ref.watch(shopperOptionsProvider).value ?? const <ShopperChoice>[];
    final String? shopperId = query.shopperId;
    // A Shopper the options do not hold — blocked since, or not loaded
    // yet — is still the filter, and the control says one is chosen.
    final bool shopperUnlisted =
        shopperId != null &&
        !shoppers.any((ShopperChoice shopper) => shopper.id == shopperId);

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 320,
          child: TextField(
            key: const ValueKey<String>('board-search'),
            controller: _search,
            textInputAction: TextInputAction.search,
            inputFormatters: <TextInputFormatter>[
              LengthLimitingTextInputFormatter(BoardQuery.searchMaxLength),
            ],
            decoration: InputDecoration(
              labelText: l10n.boardSearch,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: queries.search,
          ),
        ),
        _Labelled(
          label: l10n.boardFilterStatus,
          width: 240,
          child: DropdownButton<OrderStatus?>(
            key: const ValueKey<String>('board-status-filter'),
            isExpanded: true,
            value: query.status,
            items: <DropdownMenuItem<OrderStatus?>>[
              DropdownMenuItem<OrderStatus?>(
                child: Text(l10n.boardAllStatuses),
              ),
              for (final OrderStatus status in OrderStatus.values)
                DropdownMenuItem<OrderStatus?>(
                  value: status,
                  child: Text(
                    OrderLabels.status(l10n, status),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: queries.filterByStatus,
          ),
        ),
        _Labelled(
          label: l10n.boardFilterPayment,
          width: 220,
          child: DropdownButton<PaymentMethod?>(
            key: const ValueKey<String>('board-payment-filter'),
            isExpanded: true,
            value: query.paymentMethod,
            items: <DropdownMenuItem<PaymentMethod?>>[
              DropdownMenuItem<PaymentMethod?>(
                child: Text(
                  l10n.boardAllPaymentMethods,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              for (final PaymentMethod method in PaymentMethod.values)
                DropdownMenuItem<PaymentMethod?>(
                  value: method,
                  child: Text(OrderLabels.paymentMethod(l10n, method)),
                ),
            ],
            onChanged: queries.filterByPaymentMethod,
          ),
        ),
        _Labelled(
          label: l10n.boardFilterShopper,
          width: 260,
          child: DropdownButton<String?>(
            key: const ValueKey<String>('board-shopper-filter'),
            isExpanded: true,
            value: shopperId,
            items: <DropdownMenuItem<String?>>[
              DropdownMenuItem<String?>(
                child: Text(
                  l10n.boardAllShoppers,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (shopperUnlisted)
                DropdownMenuItem<String?>(
                  value: shopperId,
                  child: Text(
                    l10n.boardFilteredShopper,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              for (final ShopperChoice shopper in shoppers)
                DropdownMenuItem<String?>(
                  value: shopper.id,
                  child: Text(
                    shopper.fullName ?? formatPhone(shopper.phone),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: queries.filterByShopper,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            OutlinedButton.icon(
              key: const ValueKey<String>('board-days'),
              icon: const Icon(Icons.date_range),
              label: Text(
                query.from != null && query.to != null
                    ? '${_day(query.from!)} – ${_day(query.to!)}'
                    : l10n.boardDays,
              ),
              onPressed: () => _pickDays(query),
            ),
            if (query.from != null)
              IconButton(
                key: const ValueKey<String>('board-clear-days'),
                tooltip: l10n.boardClearDays,
                icon: const Icon(Icons.close),
                onPressed: () => queries.filterByDays(null, null),
              ),
          ],
        ),
        FilterChip(
          key: const ValueKey<String>('board-self-orders'),
          label: Text(l10n.boardSelfOrdersOnly),
          selected: query.selfOrdersOnly,
          onSelected: queries.selfOrdersOnly,
        ),
        if (query.isFiltered)
          TextButton(
            key: const ValueKey<String>('board-clear-filters'),
            onPressed: () {
              _search.clear();
              queries.clear();
            },
            child: Text(l10n.boardClearFilters),
          ),
      ],
    );
  }

  static String _day(DateTime day) =>
      '${day.day.toString().padLeft(2, '0')}.'
      '${day.month.toString().padLeft(2, '0')}.${day.year}';
}

/// A filter's control framed with its name, which stays visible — and is
/// read out — once a value is chosen.
class _Labelled extends StatelessWidget {
  const _Labelled({
    required this.label,
    required this.width,
    required this.child,
  });

  final String label;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: DropdownButtonHideUnderline(child: child),
      ),
    );
  }
}

/// The page of orders: a table on a wide window, cards on a narrow one.
class _Orders extends ConsumerWidget {
  const _Orders();

  /// From this width the orders are a table whose columns all show; below
  /// it, cards, which show the same (`DL-53` (2)).
  static const double tableWidth = _Table.usualWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<Paged<BoardRow>> page = ref.watch(boardPageProvider);
    final bool filtered = ref.watch(
      boardQueryProvider.select((BoardQuery query) => query.isFiltered),
    );

    return page.when(
      skipLoadingOnReload: false,
      skipLoadingOnRefresh: !page.hasError,
      data: (Paged<BoardRow> page) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (page.items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(filtered ? l10n.boardEmptyFiltered : l10n.boardEmpty),
            )
          else
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) =>
                  constraints.maxWidth >= tableWidth
                  ? _Table(rows: page.items)
                  : Column(
                      children: <Widget>[
                        for (final BoardRow row in page.items) _Card(row: row),
                      ],
                    ),
            ),
          PaginationBar(
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
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.rows});

  /// About what the table takes with its usual rows in a desktop font — it
  /// measured 1 125 px on the real stack in either language; longer names
  /// scroll it sideways.
  static const double usualWidth = 1150;

  final List<BoardRow> rows;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        columnSpacing: 24,
        // A row grows with its two-line cells, so large text is never cut.
        dataRowMinHeight: kMinInteractiveDimension,
        dataRowMaxHeight: double.infinity,
        columns: <DataColumn>[
          DataColumn(label: Text(l10n.boardColumnNumber)),
          DataColumn(label: Text(l10n.boardColumnPlaced)),
          DataColumn(label: Text(l10n.boardColumnCustomer)),
          DataColumn(label: Text(l10n.boardColumnStatus)),
          DataColumn(label: Text(l10n.boardColumnPayment)),
          DataColumn(label: Text(l10n.boardColumnTotal)),
          DataColumn(label: Text(l10n.boardColumnShopper)),
        ],
        rows: <DataRow>[
          for (final BoardRow row in rows)
            DataRow(
              onSelectChanged: (_) => context.go(OperationsPaths.order(row.id)),
              cells: <DataCell>[
                DataCell(
                  Text(
                    l10n.boardOrderNumber('${row.orderNumber}'),
                    key: ValueKey<String>('board-row-${row.id}'),
                  ),
                ),
                DataCell(Text(TashkentTime.format(row.createdAt))),
                DataCell(
                  Text(
                    '${row.customerName}\n${formatPhone(row.customerPhone)}',
                  ),
                ),
                DataCell(OrderStatusChip(row.status)),
                DataCell(
                  Text(OrderLabels.paymentMethod(l10n, row.paymentMethod)),
                ),
                DataCell(
                  Text(
                    '${totalText(context, l10n, row.totalUzs, row.totalKind)}'
                    '\n${l10n.boardItemCount(row.itemCount)}',
                  ),
                ),
                DataCell(_ShopperCell(row: row)),
              ],
            ),
        ],
      ),
    );
  }
}

class _ShopperCell extends StatelessWidget {
  const _ShopperCell({required this.row});

  final BoardRow row;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final PersonRef? shopper = row.shopper;

    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(shopper == null ? l10n.boardNoShopper : nameOf(l10n, shopper)),
        if (row.isSelfOrder) const SelfOrderMark(),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.row});

  final BoardRow row;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Card(
      child: ListTile(
        key: ValueKey<String>('board-row-${row.id}'),
        title: Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(l10n.boardOrderNumber('${row.orderNumber}')),
            OrderStatusChip(row.status),
          ],
        ),
        subtitle: Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(TashkentTime.format(row.createdAt)),
            Text('${row.customerName} · ${formatPhone(row.customerPhone)}'),
            Text(OrderLabels.paymentMethod(l10n, row.paymentMethod)),
            Text(totalText(context, l10n, row.totalUzs, row.totalKind)),
            Text(l10n.boardItemCount(row.itemCount)),
            _ShopperCell(row: row),
          ],
        ),
        onTap: () => context.go(OperationsPaths.order(row.id)),
      ),
    );
  }
}

/// What an Operator should look at, the longest-waiting first.
class _AttentionList extends ConsumerWidget {
  const _AttentionList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<AttentionItem>> items = ref.watch(attentionProvider);

    return Card(
      key: const ValueKey<String>('board-attention'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.attentionTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            items.when(
              skipLoadingOnRefresh: !items.hasError,
              data: (List<AttentionItem> items) => items.isEmpty
                  ? Text(l10n.attentionEmpty)
                  : Column(
                      children: <Widget>[
                        for (final AttentionItem item in items)
                          ListTile(
                            key: ValueKey<String>('attention-${item.orderId}'),
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person_pin_outlined),
                            title: Text(
                              '${l10n.boardOrderNumber('${item.orderNumber}')}'
                              ' · ${_describe(l10n, item)}',
                            ),
                            subtitle: Text(
                              '${nameOf(l10n, item.shopper)} · '
                              '${l10n.attentionSince(TashkentTime.format(item.since))}',
                            ),
                            onTap: () =>
                                context.go(OperationsPaths.order(item.orderId)),
                          ),
                      ],
                    ),
              error: (Object error, StackTrace _) => LoadFailure(
                error: error,
                onRetry: () => ref.invalidate(attentionProvider),
              ),
              loading: () => const LinearProgressIndicator(),
            ),
          ],
        ),
      ),
    );
  }

  static String _describe(AppLocalizations l10n, AttentionItem item) =>
      switch (item.type) {
        AttentionType.selfOrder => l10n.selfOrderExplained,
      };
}
