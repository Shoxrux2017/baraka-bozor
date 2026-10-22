import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/platform/clock.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/kit/kit_dialog.dart';
import '../../../core/widgets/panel/panel_fields.dart';
import '../../../core/widgets/panel/panel_filter_chip.dart';
import '../../../core/widgets/panel/panel_menu_button.dart';
import '../application/board_controllers.dart';
import '../domain/board.dart';

/// The board's filters (`DL-100` (3)): one row of the search, the payment,
/// Shopper and Courier menus and the days, and one of the two chips — from
/// a card [wideWidth] wide. Below it the search stands with one "Фильтры"
/// button that opens the same controls in a dialog.
class BoardFilters extends ConsumerStatefulWidget {
  const BoardFilters({super.key});

  static const double wideWidth = 820;

  /// Below this card width the search and the button stand one above the
  /// other.
  static const double stackedWidth = 480;

  @override
  ConsumerState<BoardFilters> createState() => _BoardFiltersState();
}

class _BoardFiltersState extends ConsumerState<BoardFilters> {
  late final TextEditingController _search = TextEditingController(
    text: ref.read(boardQueryProvider).search,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickDays(BuildContext context, BoardQuery query) async {
    final DateTime now = ref.read(clockProvider)();
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

  void _clear() {
    _search.clear();
    ref.read(boardQueryProvider.notifier).clear();
  }

  Future<void> _openDialog() {
    return showKitDialog<void>(
      context: context,
      dialogKey: 'board-filters-dialog',
      title: AppLocalizations.of(context).boardFilters,
      builder: (BuildContext dialog) => Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _menus(context, ref),
              const SizedBox(height: 12),
              _chips(context, ref),
            ],
          );
        },
      ),
    );
  }

  /// The payment, Shopper and Courier menus and the days, as buttons.
  Widget _menus(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BoardQuery query = ref.watch(boardQueryProvider);
    final BoardQueryController queries = ref.read(boardQueryProvider.notifier);
    final List<StaffChoice> shoppers =
        ref.watch(shopperOptionsProvider).value ?? const <StaffChoice>[];
    final List<StaffChoice> couriers =
        ref.watch(courierOptionsProvider).value ?? const <StaffChoice>[];
    final bool days = query.from != null && query.to != null;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        PanelMenuButton<PaymentMethod?>(
          buttonKey: 'board-payment-filter',
          label: query.paymentMethod == null
              ? l10n.boardColumnPayment
              : OrderLabels.paymentMethod(l10n, query.paymentMethod!),
          active: query.paymentMethod != null,
          items: <PanelMenuItem<PaymentMethod?>>[
            (value: null, label: l10n.boardAllPaymentMethods),
            for (final PaymentMethod method in PaymentMethod.values)
              (value: method, label: OrderLabels.paymentMethod(l10n, method)),
          ],
          onSelected: queries.filterByPaymentMethod,
        ),
        _personMenu(
          buttonKey: 'board-shopper-filter',
          title: l10n.boardFilterShopper,
          all: l10n.boardAllShoppers,
          unlisted: l10n.boardFilteredShopper,
          chosen: query.shopperId,
          options: shoppers,
          onSelected: queries.filterByShopper,
        ),
        _personMenu(
          buttonKey: 'board-courier-filter',
          title: l10n.boardFilterCourier,
          all: l10n.boardAllCouriers,
          unlisted: l10n.boardFilteredCourier,
          chosen: query.courierId,
          options: couriers,
          onSelected: queries.filterByCourier,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: OutlinedButton(
                key: const ValueKey<String>('board-days'),
                style: panelFilterStyle(active: days),
                onPressed: () => _pickDays(context, query),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.calendar_month, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        days
                            ? '${_day(query.from!)} – ${_day(query.to!)}'
                            : l10n.boardDays,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (query.from == null) ...const <Widget>[
                      SizedBox(width: 4),
                      Icon(Icons.expand_more, size: 18),
                    ],
                  ],
                ),
              ),
            ),
            if (query.from != null)
              IconButton(
                key: const ValueKey<String>('board-clear-days'),
                tooltip: l10n.boardClearDays,
                padding: EdgeInsets.zero,
                iconSize: 16,
                color: KitColors.ink2,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                icon: const Icon(Icons.close),
                onPressed: () => queries.filterByDays(null, null),
              ),
          ],
        ),
      ],
    );
  }

  /// A Shopper or Courier menu. A person the options do not hold — blocked
  /// since, or not loaded yet — is still the filter, and the button says one
  /// is chosen.
  Widget _personMenu({
    required String buttonKey,
    required String title,
    required String all,
    required String unlisted,
    required String? chosen,
    required List<StaffChoice> options,
    required ValueChanged<String?> onSelected,
  }) {
    final StaffChoice? listed = chosen == null
        ? null
        : options
              .where((StaffChoice choice) => choice.id == chosen)
              .firstOrNull;
    final bool missing = chosen != null && listed == null;
    String nameOf(StaffChoice choice) =>
        choice.fullName ?? formatPhone(choice.phone);

    return PanelMenuButton<String?>(
      buttonKey: buttonKey,
      label: chosen == null
          ? title
          : missing
          ? unlisted
          : nameOf(listed!),
      active: chosen != null,
      items: <PanelMenuItem<String?>>[
        (value: null, label: all),
        if (missing) (value: chosen, label: unlisted),
        for (final StaffChoice choice in options)
          (value: choice.id, label: nameOf(choice)),
      ],
      onSelected: onSelected,
    );
  }

  /// The two chips and, when the board is filtered, the clear button.
  Widget _chips(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BoardQuery query = ref.watch(boardQueryProvider);
    final BoardQueryController queries = ref.read(boardQueryProvider.notifier);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              PanelFilterChip(
                chipKey: 'board-self-orders',
                icon: Icons.person_outline,
                label: l10n.boardSelfOrdersOnly,
                selected: query.selfOrdersOnly,
                onTap: () => queries.selfOrdersOnly(!query.selfOrdersOnly),
              ),
              PanelFilterChip(
                chipKey: 'board-awaiting-customer',
                icon: Icons.help_outline,
                label: l10n.boardAwaitingCustomerOnly,
                selected: query.awaitingCustomerOnly,
                onTap: () =>
                    queries.awaitingCustomerOnly(!query.awaitingCustomerOnly),
              ),
            ],
          ),
        ),
        if (query.isFiltered)
          TextButton(
            key: const ValueKey<String>('board-clear-filters'),
            style: TextButton.styleFrom(
              foregroundColor: KitColors.muted,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              minimumSize: const Size(0, 32),
            ),
            onPressed: _clear,
            child: Text(l10n.boardClearFilters),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BoardQuery query = ref.watch(boardQueryProvider);
    final BoardQueryController queries = ref.read(boardQueryProvider.notifier);
    final bool narrowed =
        query.paymentMethod != null ||
        query.shopperId != null ||
        query.courierId != null ||
        query.from != null ||
        query.selfOrdersOnly ||
        query.awaitingCustomerOnly;

    final Widget search = TextField(
      key: const ValueKey<String>('board-search'),
      controller: _search,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 13, color: KitColors.ink),
      inputFormatters: <TextInputFormatter>[
        LengthLimitingTextInputFormatter(BoardQuery.searchMaxLength),
      ],
      decoration: panelSearchDecoration(hint: l10n.boardSearch),
      onSubmitted: queries.search,
    );

    final Widget filtersButton = OutlinedButton.icon(
      key: const ValueKey<String>('board-filters'),
      style: panelFilterStyle(active: narrowed),
      icon: const Icon(Icons.tune, size: 18),
      label: Text(l10n.boardFilters),
      onPressed: _openDialog,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= BoardFilters.wideWidth;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: wide
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        SizedBox(width: 280, child: search),
                        _menus(context, ref),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _chips(context, ref),
                  ],
                )
              : constraints.maxWidth < BoardFilters.stackedWidth
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    search,
                    const SizedBox(height: 10),
                    filtersButton,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: search),
                    const SizedBox(width: 10),
                    filtersButton,
                  ],
                ),
        );
      },
    );
  }

  static String _day(DateTime day) =>
      '${day.day.toString().padLeft(2, '0')}.'
      '${day.month.toString().padLeft(2, '0')}.${day.year}';
}
