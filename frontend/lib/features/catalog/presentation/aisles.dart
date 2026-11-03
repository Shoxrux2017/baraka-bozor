import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/press_scale.dart';
import '../domain/catalog.dart';

const Cubic _aisleCurve = Cubic(0.2, 0.8, 0.2, 1);

/// Which aisle of «Все товары» is in view, and where each aisle's heading
/// stands in the scroll view (`DL-128`). The grid writes [starts] after each
/// layout; the screen feeds [follow] the scroll position; a chip tap [lock]s
/// the choice while the list glides, so the aisles it passes do not light up.
class ProductAisles extends ChangeNotifier {
  ProductAisles(List<CatalogCategory> categories) : _categories = categories {
    _current = categories.isEmpty ? null : categories.first.id;
  }

  List<CatalogCategory> _categories;
  String? _current;
  Map<String, double> _starts = const <String, double>{};
  bool _locked = false;

  /// The aisles in the shop's order.
  List<CatalogCategory> get categories => _categories;

  set categories(List<CatalogCategory> value) {
    _categories = value;
    if (!value.any((CatalogCategory c) => c.id == _current)) {
      _current = value.isEmpty ? null : value.first.id;
    }
    notifyListeners();
  }

  /// The aisle that is lit, or null without aisles.
  String? get current => _current;

  set current(String? id) {
    if (id == _current) {
      return;
    }
    _current = id;
    notifyListeners();
  }

  /// Each aisle's heading offset in the scroll view.
  Map<String, double> get starts => _starts;

  /// How many products stand up to and including the aisle [id].
  int endOf(String id) {
    int total = 0;
    for (final CatalogCategory c in _categories) {
      total += c.productCount;
      if (c.id == id) {
        break;
      }
    }
    return total;
  }

  /// Replaces the heading offsets with those the grid just laid out.
  void report(Map<String, double> starts) {
    if (mapEquals(_starts, starts)) {
      return;
    }
    _starts = Map<String, double>.unmodifiable(starts);
    notifyListeners();
  }

  /// Lights the last aisle whose heading is at or above [pixels] (10 px of
  /// slack); the first one before any is reached. Ignored while locked.
  void follow(double pixels) {
    if (_locked) {
      return;
    }
    String? best = _categories.isEmpty ? null : _categories.first.id;
    for (final CatalogCategory c in _categories) {
      final double? start = _starts[c.id];
      if (start != null && start <= pixels + 10) {
        best = c.id;
      }
    }
    current = best;
  }

  void lock() => _locked = true;

  void unlock() => _locked = false;

  /// Back to the first aisle with no offsets, for another order of the list.
  void reset() {
    _locked = false;
    _starts = const <String, double>{};
    _current = _categories.isEmpty ? null : _categories.first.id;
    notifyListeners();
  }
}

/// One row of the aisle list: a heading, or a row of cards (indexes into the
/// loaded products).
final class AisleRow {
  const AisleRow.heading(CatalogCategory this.category, {required this.first})
    : cards = const <int>[];

  const AisleRow.cards(this.cards) : category = null, first = false;

  final CatalogCategory? category;
  final bool first;
  final List<int> cards;
}

/// The rows of [items], which the server sends aisle by aisle: a heading
/// before each run of one known category, then its cards [columns] to a row.
/// The last row of a run may be half full. A category not in [categories]
/// gets no heading.
List<AisleRow> aisleRows(
  List<CatalogProduct> items,
  List<CatalogCategory> categories,
  int columns,
) {
  final Map<String, CatalogCategory> known = <String, CatalogCategory>{
    for (final CatalogCategory c in categories) c.id: c,
  };
  final Set<String> headed = <String>{};
  final List<AisleRow> rows = <AisleRow>[];
  int start = 0;
  while (start < items.length) {
    final String id = items[start].categoryId;
    int end = start;
    while (end < items.length && items[end].categoryId == id) {
      end++;
    }
    final CatalogCategory? category = known[id];
    if (category != null && headed.add(id)) {
      rows.add(AisleRow.heading(category, first: rows.isEmpty));
    }
    for (int k = start; k < end; k += columns) {
      rows.add(
        AisleRow.cards(<int>[
          for (int n = k; n < math.min(k + columns, end); n++) n,
        ]),
      );
    }
    start = end;
  }
  return rows;
}

/// The length the aisles still to come will add once their products are
/// loaded: the rows of each aisle not yet complete, and a heading for each
/// aisle not begun.
double aisleExtentToCome({
  required List<CatalogCategory> categories,
  required List<CatalogProduct> items,
  required int columns,
  required double rowExtent,
  required double Function(CatalogCategory category) headingExtent,
}) {
  final Map<String, int> loaded = <String, int>{};
  for (final CatalogProduct p in items) {
    loaded[p.categoryId] = (loaded[p.categoryId] ?? 0) + 1;
  }
  int rowsOf(int count) => (count + columns - 1) ~/ columns;
  double toCome = 0;
  for (final CatalogCategory c in categories) {
    final int have = loaded[c.id] ?? 0;
    toCome += math.max(0, rowsOf(c.productCount) - rowsOf(have)) * rowExtent;
    if (have == 0 && c.productCount > 0) {
      toCome += headingExtent(c);
    }
  }
  return toCome;
}

const String _gapMark = '​';

TextSpan _headingSpan(String name, int count) {
  const double line = 1.3;
  return TextSpan(
    children: <InlineSpan>[
      TextSpan(
        text: name,
        style: const TextStyle(
          fontFamily: appFontFamily,
          fontSize: 17,
          height: line,
          fontWeight: FontWeight.w700,
          color: KitColors.ink,
        ),
      ),
      // The 6 px between the name and the count: a zero-width mark that is
      // spaced out, so the pair is one paragraph that wraps as a whole.
      const TextSpan(
        text: _gapMark,
        style: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 13,
          height: line,
          letterSpacing: 6,
        ),
      ),
      TextSpan(
        text: '$count',
        style: const TextStyle(
          fontFamily: appFontFamily,
          fontSize: 13,
          height: line,
          fontWeight: FontWeight.w500,
          color: KitColors.muted,
        ),
      ),
    ],
  );
}

double _headingTop({required bool first}) => first ? 2 : 14;

const double _headingBottom = 10;

/// The height of the heading of [c] in a row [width] wide: its text measured
/// as the heading draws it, and its padding.
double aisleHeadingExtent(
  CatalogCategory c,
  double width,
  TextScaler scaler,
  TextDirection direction, {
  required AppLanguage language,
  required bool first,
}) {
  final TextPainter painter = TextPainter(
    text: _headingSpan(c.name(language), c.productCount),
    textDirection: direction,
    textScaler: scaler,
  )..layout(maxWidth: width);
  final double height = painter.height;
  painter.dispose();
  return _headingTop(first: first) + height + _headingBottom;
}

/// The heading before an aisle's run of products: the name, and how many
/// products the aisle holds (`DL-128`). One heading for a screen reader.
class AisleHeading extends StatelessWidget {
  AisleHeading({required this.category, this.first = false, Key? key})
    : super(key: key ?? ValueKey<String>('aisle-${category.id}'));

  final CatalogCategory category;

  /// The heading at the top of the list stands closer to what is above it.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String name = category.name(interfaceLanguage(context));
    return Semantics(
      header: true,
      label: l10n.aisleHeadingSpoken(
        name,
        l10n.catalogProductCount(category.productCount),
      ),
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.only(
          top: _headingTop(first: first),
          bottom: _headingBottom,
        ),
        child: RichText(
          text: _headingSpan(name, category.productCount),
          textScaler: MediaQuery.textScalerOf(context),
        ),
      ),
    );
  }
}

/// The aisles as a row of chips (`DL-128`); the lit one follows [aisles] and
/// is scrolled into view over 250 ms `easeOut`, at once with reduced motion.
class AisleChips extends StatefulWidget {
  const AisleChips({required this.aisles, required this.onTap, Key? key})
    : super(key: key ?? const ValueKey<String>('aisle-chips'));

  final ProductAisles aisles;
  final ValueChanged<String> onTap;

  @override
  State<AisleChips> createState() => _AisleChipsState();
}

class _AisleChipsState extends State<AisleChips> {
  final Map<String, GlobalKey> _itemKeys = <String, GlobalKey>{};
  String? _shown;

  GlobalKey _keyOf(String id) => _itemKeys.putIfAbsent(id, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _shown = widget.aisles.current;
    widget.aisles.addListener(_onAisles);
    WidgetsBinding.instance.addPostFrameCallback((_) => _show(centred: true));
  }

  @override
  void didUpdateWidget(AisleChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aisles != widget.aisles) {
      oldWidget.aisles.removeListener(_onAisles);
      widget.aisles.addListener(_onAisles);
    }
  }

  @override
  void dispose() {
    widget.aisles.removeListener(_onAisles);
    super.dispose();
  }

  void _onAisles() {
    if (!mounted) {
      return;
    }
    setState(() {});
    if (widget.aisles.current != _shown) {
      _shown = widget.aisles.current;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _show(centred: false),
      );
    }
  }

  void _show({required bool centred}) {
    final String? id = widget.aisles.current;
    final BuildContext? target = id == null ? null : _keyOf(id).currentContext;
    if (!mounted || target == null || !target.mounted) {
      return;
    }
    final bool still = centred || MediaQuery.disableAnimationsOf(context);
    Scrollable.ensureVisible(
      target,
      alignment: 0.5,
      alignmentPolicy: centred
          ? ScrollPositionAlignmentPolicy.explicit
          : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      duration: still ? Duration.zero : const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final Duration fade = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final List<CatalogCategory> categories = widget.aisles.categories;
    final String? current = widget.aisles.current;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < categories.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 6),
            Builder(
              builder: (BuildContext context) {
                final CatalogCategory category = categories[i];
                final bool selected = category.id == current;
                final String name = category.name(language);
                return PressScale(
                  key: ValueKey<String>('aisle-chip-${category.id}'),
                  label: l10n.aisleChipSpoken(name, i + 1, categories.length),
                  selected: selected,
                  onTap: () => widget.onTap(category.id),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Center(
                      child: AnimatedContainer(
                        key: _keyOf(category.id),
                        duration: fade,
                        constraints: const BoxConstraints(minHeight: 34),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? KitColors.primaryWash
                              : KitColors.chip,
                          borderRadius: BorderRadius.circular(17),
                        ),
                        foregroundDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: selected
                                ? KitColors.primaryDark
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: AnimatedDefaultTextStyle(
                          duration: fade,
                          style: TextStyle(
                            fontFamily: appFontFamily,
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? KitColors.primaryDark
                                : KitColors.ink2,
                          ),
                          child: Text(name, maxLines: 1, softWrap: false),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Folds [child] away in 220 ms and unfolds it again as [shown] changes
/// (`DL-128`); at once with reduced motion. While folded it is not built, so
/// the chips come back at their start.
class AisleChipsFold extends StatefulWidget {
  const AisleChipsFold({required this.shown, required this.child, super.key});

  final bool shown;
  final Widget child;

  @override
  State<AisleChipsFold> createState() => _AisleChipsFoldState();
}

class _AisleChipsFoldState extends State<AisleChipsFold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: widget.shown ? 1 : 0,
  );

  @override
  void didUpdateWidget(AisleChipsFold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shown == oldWidget.shown) {
      return;
    }
    final double target = widget.shown ? 1 : 0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = target;
    } else {
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: _aisleCurve,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double v = _controller.value;
        if (v == 0) {
          return const SizedBox(width: double.infinity);
        }
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: v,
            child: Opacity(opacity: v, child: child),
          ),
        );
      },
    );
  }
}
