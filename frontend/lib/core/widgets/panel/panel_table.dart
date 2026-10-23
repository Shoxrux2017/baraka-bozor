import 'package:flutter/material.dart';

import '../../theme/kit_colors.dart';

/// A column of a [PanelTable]: its header [label], [width] and whether its
/// header and cells stand at the [end].
typedef PanelColumn = ({String label, TableColumnWidth width, bool end});

/// One row of a [PanelTable]. A row with an [onTap] is an `InkWell` keyed
/// [key]; one without is a box keyed [key]. A [faded] row is painted on `card`.
/// [lastCellPadding] replaces the 12 around the last cell.
class PanelTableRow {
  const PanelTableRow({
    required this.key,
    required this.cells,
    this.onTap,
    this.lastCellPadding,
    this.faded = false,
  });

  final Key key;
  final List<Widget> cells;
  final VoidCallback? onTap;
  final EdgeInsets? lastCellPadding;
  final bool faded;
}

/// The panel's table: a header on `card` between two `line` rules, then a row
/// per entry, each a table of its own under the same column widths, so a row
/// takes a hover and a tap as a whole and grows with its text.
class PanelTable extends StatelessWidget {
  const PanelTable({required this.columns, required this.rows, super.key});

  final List<PanelColumn> columns;
  final List<PanelTableRow> rows;

  @override
  Widget build(BuildContext context) {
    const BorderSide line = BorderSide(color: KitColors.line);
    final Map<int, TableColumnWidth> widths = <int, TableColumnWidth>{
      for (int i = 0; i < columns.length; i++) i: columns[i].width,
    };

    Widget header(PanelColumn column) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        column.label.toUpperCase(),
        textAlign: column.end ? TextAlign.end : TextAlign.start,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: KitColors.muted,
        ),
      ),
    );

    Widget rowOf(PanelTableRow row) {
      final int last = row.cells.length - 1;
      final Table table = Table(
        columnWidths: widths,
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: <TableRow>[
          TableRow(
            children: <Widget>[
              for (int i = 0; i <= last; i++)
                Padding(
                  padding: i == last && row.lastCellPadding != null
                      ? row.lastCellPadding!
                      : const EdgeInsets.all(12),
                  child: Align(
                    alignment: columns[i].end
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: row.cells[i],
                  ),
                ),
            ],
          ),
        ],
      );
      final VoidCallback? onTap = row.onTap;
      final BoxDecoration decoration = BoxDecoration(
        color: row.faded ? KitColors.card : null,
        border: const Border(bottom: line),
      );

      return onTap == null
          ? DecoratedBox(key: row.key, decoration: decoration, child: table)
          : DecoratedBox(
              decoration: decoration,
              child: InkWell(
                key: row.key,
                hoverColor: KitColors.field,
                onTap: onTap,
                child: table,
              ),
            );
    }

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
              columnWidths: widths,
              children: <TableRow>[
                TableRow(
                  children: <Widget>[
                    for (final PanelColumn c in columns) header(c),
                  ],
                ),
              ],
            ),
          ),
          for (final PanelTableRow row in rows) rowOf(row),
        ],
      ),
    );
  }
}
