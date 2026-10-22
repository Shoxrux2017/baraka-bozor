import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/phone_format.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/platform/clock.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/network/paged.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/widgets/list_widgets.dart';
import '../application/board_controllers.dart';
import '../domain/board.dart';
import 'board_attention.dart';
import 'board_summary.dart';
import 'board_widgets.dart';
import 'operations_paths.dart';

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
    ref.listenManual<AsyncValue<BoardSummary>>(
      boardSummaryProvider,
      fireImmediately: true,
      (AsyncValue<BoardSummary>? _, AsyncValue<BoardSummary> next) {
        if (next.hasValue && !next.isLoading) {
          setState(() => _loadedAt = ref.read(clockProvider)());
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateTime? loadedAt = _loadedAt;
    final bool compact = MediaQuery.sizeOf(context).width < 1200;
    final EdgeInsets padding = compact
        ? const EdgeInsets.fromLTRB(24, 20, 24, 24)
        : const EdgeInsets.fromLTRB(28, 26, 28, 28);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool beside =
            constraints.maxWidth - padding.horizontal >=
            BoardScreen.attentionBeside;

        return ListView(
          key: const ValueKey<String>('operations-board'),
          padding: padding,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.panelSectionBoard,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: KitColors.ink,
                        ),
                      ),
                      if (loadedAt != null)
                        Text(
                          l10n.boardUpdatedAt(TashkentTime.time(loadedAt)),
                          style: const TextStyle(
                            fontSize: 12,
                            color: KitColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Tooltip(
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
              ],
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
                      children: <Widget>[
                        _Filters(),
                        SizedBox(height: 16),
                        _Orders(),
                      ],
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
              _Filters(),
              SizedBox(height: 16),
              _Orders(),
            ],
          ],
        );
      },
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
    final List<StaffChoice> shoppers =
        ref.watch(shopperOptionsProvider).value ?? const <StaffChoice>[];
    final String? shopperId = query.shopperId;
    // A Shopper the options do not hold — blocked since, or not loaded
    // yet — is still the filter, and the control says one is chosen.
    final bool shopperUnlisted =
        shopperId != null &&
        !shoppers.any((StaffChoice shopper) => shopper.id == shopperId);
    final List<StaffChoice> couriers =
        ref.watch(courierOptionsProvider).value ?? const <StaffChoice>[];
    final String? courierId = query.courierId;
    final bool courierUnlisted =
        courierId != null &&
        !couriers.any((StaffChoice courier) => courier.id == courierId);

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
              for (final StaffChoice shopper in shoppers)
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
        _Labelled(
          label: l10n.boardFilterCourier,
          width: 260,
          child: DropdownButton<String?>(
            key: const ValueKey<String>('board-courier-filter'),
            isExpanded: true,
            value: courierId,
            items: <DropdownMenuItem<String?>>[
              DropdownMenuItem<String?>(
                child: Text(
                  l10n.boardAllCouriers,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (courierUnlisted)
                DropdownMenuItem<String?>(
                  value: courierId,
                  child: Text(
                    l10n.boardFilteredCourier,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              for (final StaffChoice courier in couriers)
                DropdownMenuItem<String?>(
                  value: courier.id,
                  child: Text(
                    courier.fullName ?? formatPhone(courier.phone),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: queries.filterByCourier,
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
        FilterChip(
          key: const ValueKey<String>('board-awaiting-customer'),
          label: Text(l10n.boardAwaitingCustomerOnly),
          selected: query.awaitingCustomerOnly,
          onSelected: queries.awaitingCustomerOnly,
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

class _Table extends StatefulWidget {
  const _Table({required this.rows});

  /// About the most the table takes in a desktop font: it measured 1 125 px
  /// on the real stack in either language, and the Customer's cell and the
  /// people's — the Shopper above the Courier, so the Courier adds no column
  /// — the ones names widen, wrap at [nameWidth] and [peopleWidth]. The
  /// Customer's open questions go under the status: they may widen the
  /// column on a page of short statuses, but never past its widest status,
  /// as measured in both languages (`DL-53` (2), `DL-67` (3)).
  static const double usualWidth = 1200;
  static const double nameWidth = 180;
  static const double peopleWidth = 170;

  final List<BoardRow> rows;

  @override
  State<_Table> createState() => _TableState();
}

class _TableState extends State<_Table> {
  // A table wider than its room shows that it scrolls sideways, which on the
  // web a mouse would otherwise not reveal.
  final ScrollController _sideways = ScrollController();

  @override
  void dispose() {
    _sideways.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scrollbar(
      controller: _sideways,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _sideways,
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
            DataColumn(label: Text(l10n.boardColumnPeople)),
          ],
          rows: <DataRow>[
            for (final BoardRow row in widget.rows)
              DataRow(
                onSelectChanged: (_) =>
                    context.go(OperationsPaths.order(row.id)),
                cells: <DataCell>[
                  DataCell(
                    Text(
                      l10n.boardOrderNumber('${row.orderNumber}'),
                      key: ValueKey<String>('board-row-${row.id}'),
                    ),
                  ),
                  DataCell(Text(TashkentTime.format(row.createdAt))),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _Table.nameWidth,
                      ),
                      child: Text(
                        _customerOf(l10n, row, '\n'),
                        key: ValueKey<String>('board-customer-${row.id}'),
                      ),
                    ),
                  ),
                  DataCell(_StatusCell(row: row)),
                  DataCell(
                    Text(OrderLabels.paymentMethod(l10n, row.paymentMethod)),
                  ),
                  DataCell(
                    Text(
                      '${totalText(context, l10n, row.totalUzs, row.totalKind)}'
                      '\n${l10n.boardItemCount(row.itemCount)}',
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _Table.peopleWidth,
                      ),
                      child: _PeopleCell(row: row),
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

/// The status, and under it the Customer's open questions when there are
/// any, so they add a line and the column is as wide as its widest line.
class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.row});

  final BoardRow row;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        OrderStatusChip(row.status),
        if (row.pendingApprovalCount > 0) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            l10n.boardPendingQuestions(row.pendingApprovalCount),
            key: ValueKey<String>('board-questions-${row.id}'),
          ),
        ],
      ],
    );
  }
}

/// The Shopper and, once there is one, the Courier the row names, with the
/// self-order mark (`DL-62` (4)).
class _PeopleCell extends StatelessWidget {
  const _PeopleCell({required this.row});

  final BoardRow row;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final PersonRef? shopper = row.shopper;
    final PersonRef? courier = row.courier;

    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(shopper == null ? l10n.boardNoShopper : nameOf(l10n, shopper)),
            if (courier != null)
              Text(
                l10n.boardCourierNamed(nameOf(l10n, courier)),
                key: ValueKey<String>('board-courier-${row.id}'),
              ),
          ],
        ),
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
            Text(_customerOf(l10n, row, ' · ')),
            Text(OrderLabels.paymentMethod(l10n, row.paymentMethod)),
            Text(totalText(context, l10n, row.totalUzs, row.totalKind)),
            Text(l10n.boardItemCount(row.itemCount)),
            if (row.pendingApprovalCount > 0)
              Text(l10n.boardPendingQuestions(row.pendingApprovalCount)),
            _PeopleCell(row: row),
          ],
        ),
        onTap: () => context.go(OperationsPaths.order(row.id)),
      ),
    );
  }
}

/// Who ordered, as a row says it: the name and phone, or that the Customer's
/// data is gone.
String _customerOf(AppLocalizations l10n, BoardRow row, String separator) {
  final String? phone = row.customerPhone;
  if (row.customerErased || phone == null) {
    return l10n.orderCustomerErased;
  }
  final String name = row.customerName ?? l10n.customerNoName;
  return '$name$separator${formatPhone(phone)}';
}
