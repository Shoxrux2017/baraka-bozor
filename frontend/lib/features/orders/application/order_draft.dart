import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../../core/catalog/catalog_values.dart';
import '../../../core/formatting/server_text.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/orders/estimate_preview.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../cart/application/card_quantity.dart';
import '../../catalog/domain/catalog.dart';
import '../domain/customer_orders.dart';
import 'customer_orders_controllers.dart';

/// What the Customer settled in a line's sheet: the quantity as the API
/// takes it, the note (`null` when empty) and the rule.
typedef OrderLineChoice = ({
  String quantity,
  String? note,
  SubstitutionPolicy policy,
});

const Object _keep = Object();

/// What the Customer sets on one line of the editor: a line already ordered,
/// or a product this edit adds (`DL-132`). It never changes; the draft
/// replaces it.
@immutable
final class DraftLine {
  DraftLine.ordered(CustomerOrderLine this.line)
    : product = null,
      productId = line.productId,
      unit = line.unit,
      quantity = QuantityRules.normalize(line.unit, line.quantity) ?? '',
      note = line.customerNote,
      policy = line.substitutionPolicy,
      removed = false,
      unavailable = false;

  DraftLine.added(CatalogProduct this.product)
    : line = null,
      productId = product.id,
      unit = product.unitCode,
      quantity = '1',
      note = null,
      policy = SubstitutionPolicy.allowSimilar,
      removed = false,
      unavailable = false;

  const DraftLine._(
    this.line,
    this.product,
    this.productId,
    this.unit,
    this.quantity,
    this.note,
    this.policy,
    this.removed,
    this.unavailable,
  );

  /// The line as the editor found it, or `null` for a product this edit
  /// adds.
  final CustomerOrderLine? line;

  /// The product this edit adds, at its price now, or `null` for a line
  /// already ordered.
  final CatalogProduct? product;
  final String productId;
  final UnitCode unit;

  /// As the API takes it, or empty when the line's own quantity is one its
  /// unit no longer takes: the Customer sets it anew.
  final String quantity;
  final String? note;
  final SubstitutionPolicy policy;

  /// An ordered line taken out; a line this edit added is dropped instead.
  final bool removed;

  /// The latest `product_unavailable` named the product.
  final bool unavailable;

  /// What its row and buttons are known by.
  String get key => line?.id ?? 'added-$productId';

  bool get added => line == null;

  String name(AppLanguage language) =>
      line?.name(language) ?? product!.name(language);

  String? get imageUrl => line?.imageUrl ?? product?.imageUrl;

  /// What one unit costs: the price the order holds for a line already
  /// ordered, the product's price now for one this edit adds.
  int get unitPriceUzs =>
      line?.customerUnitPriceUzs ?? product!.customerUnitPriceUzs;

  /// How the price is fixed: an estimate carries "≈", a fixed price none.
  PriceMode get priceMode => line?.priceMode ?? product!.priceMode;

  /// Whether [quantity] is one the server would take.
  bool get quantityValid => QuantityRules.normalize(unit, quantity) != null;

  /// What the line would cost at its quantity, or `null` while that is not
  /// a quantity (`EstimatePreview`; the server prices the order).
  int? get previewUzs =>
      quantityValid ? EstimatePreview.lineUzs(unitPriceUzs, quantity) : null;

  /// Whether sending this line adds it to [order]: a product picked here, or
  /// a line the order no longer holds — taken out by a save whose answer was
  /// lost — which the server adds anew at the current price (`DL-43`).
  bool adds(CustomerOrder order) {
    final String id = productId.toLowerCase();
    return !order.openLines.any(
      (CustomerOrderLine line) => line.productId.toLowerCase() == id,
    );
  }

  OrderEditLine toEdit() {
    final String text = trimLikeServer(note ?? '');
    return OrderEditLine(
      productId: productId,
      quantity: QuantityRules.normalize(unit, quantity)!,
      customerNote: text.isEmpty ? null : text,
      substitutionPolicy: policy,
    );
  }

  DraftLine copyWith({
    String? quantity,
    Object? note = _keep,
    SubstitutionPolicy? policy,
    bool? removed,
    bool? unavailable,
  }) => DraftLine._(
    line,
    product,
    productId,
    unit,
    quantity ?? this.quantity,
    identical(note, _keep) ? this.note : note as String?,
    policy ?? this.policy,
    removed ?? this.removed,
    unavailable ?? this.unavailable,
  );
}

/// The editor's lines (`DL-132`), shared by the editor, the summary and the
/// picker.
@immutable
final class OrderDraft {
  const OrderDraft({
    required this.lines,
    this.arriving = const <String>{},
    this.version = 0,
  });

  /// The order's lines, then the products added, in order.
  final List<DraftLine> lines;

  /// The keys of lines added in the picker, held out of the editor's list
  /// until they are settled.
  final Set<String> arriving;

  /// Bumps on every change of what the lines would send; marks and arrivals
  /// do not bump it.
  final int version;

  /// The lines not taken out.
  List<DraftLine> get kept =>
      lines.where((DraftLine line) => !line.removed).toList();

  /// The kept lines the latest `product_unavailable` named.
  List<DraftLine> get marked =>
      kept.where((DraftLine line) => line.unavailable).toList();

  OrderDraft _with({
    List<DraftLine>? lines,
    Set<String>? arriving,
    bool bump = false,
  }) => OrderDraft(
    lines: lines ?? this.lines,
    arriving: arriving ?? this.arriving,
    version: bump ? version + 1 : version,
  );
}

/// The draft of one order's edit. It is seeded once from the order as it
/// loaded; a reload never reseeds it (`DL-132`).
class OrderDraftController extends Notifier<OrderDraft> {
  OrderDraftController(this.orderId);

  final String orderId;

  @override
  OrderDraft build() {
    final CustomerOrder? order = ref.read(customerOrderProvider(orderId)).value;
    if (order == null) {
      throw StateError('the order $orderId has not loaded; nothing to edit');
    }
    return OrderDraft(
      lines: <DraftLine>[
        for (final CustomerOrderLine line in order.openLines)
          DraftLine.ordered(line),
      ],
    );
  }

  DraftLine? _find(String key) {
    for (final DraftLine line in state.lines) {
      if (line.key == key) {
        return line;
      }
    }
    return null;
  }

  void _replace(DraftLine next) {
    state = state._with(
      lines: <DraftLine>[
        for (final DraftLine line in state.lines)
          if (line.key == next.key) next else line,
      ],
      bump: true,
    );
  }

  /// One step of the line's quantity; the minus at the minimum takes the
  /// line out.
  void step(String key, {required bool up}) {
    final DraftLine? line = _find(key);
    if (line == null || line.removed || !line.quantityValid) {
      return;
    }
    final String? quantity = up
        ? CardQuantity.next(line.unit, line.quantity)
        : CardQuantity.previous(line.unit, line.quantity);
    if (quantity != null) {
      if (quantity != line.quantity) {
        _replace(line.copyWith(quantity: quantity));
      }
    } else if (!up) {
      remove(key);
    }
  }

  void setQuantity(String key, String quantity) {
    final DraftLine? line = _find(key);
    if (line != null && line.quantity != quantity) {
      _replace(line.copyWith(quantity: quantity));
    }
  }

  void setOptions(String key, OrderLineChoice choice) {
    final DraftLine? line = _find(key);
    if (line == null ||
        (line.quantity == choice.quantity &&
            line.note == choice.note &&
            line.policy == choice.policy)) {
      return;
    }
    _replace(
      line.copyWith(
        quantity: choice.quantity,
        note: choice.note,
        policy: choice.policy,
      ),
    );
  }

  /// Takes an ordered line out; a line this edit added is dropped.
  void remove(String key) {
    final DraftLine? line = _find(key);
    if (line == null) {
      return;
    }
    if (line.added) {
      state = state._with(
        lines: <DraftLine>[
          for (final DraftLine other in state.lines)
            if (other.key != key) other,
        ],
        arriving: <String>{...state.arriving}..remove(key),
        bump: true,
      );
    } else if (!line.removed) {
      _replace(line.copyWith(removed: true));
    }
  }

  void restore(String key) {
    final DraftLine? line = _find(key);
    if (line != null && line.removed) {
      _replace(line.copyWith(removed: false));
    }
  }

  /// Adds [product] as a new line (1, no note, similar), or keeps its line
  /// again when the order has it; answers that line. A new line added while
  /// [arriving] waits in [OrderDraft.arriving].
  DraftLine add(CatalogProduct product, {bool arriving = false}) {
    final String id = product.id.toLowerCase();
    for (final DraftLine line in state.lines) {
      if (line.productId.toLowerCase() == id) {
        if (!line.removed) {
          return line;
        }
        final DraftLine kept = line.copyWith(removed: false);
        _replace(kept);
        return kept;
      }
    }
    final DraftLine line = DraftLine.added(product);
    state = state._with(
      lines: <DraftLine>[...state.lines, line],
      arriving: arriving ? <String>{...state.arriving, line.key} : null,
      bump: true,
    );
    return line;
  }

  /// Marks the kept lines of [productIds] (lower case) as unavailable,
  /// replacing the marks before; the lines to send do not change.
  void setUnavailable(Set<String> productIds) {
    final bool same = state.lines.every(
      (DraftLine line) =>
          line.unavailable == productIds.contains(line.productId.toLowerCase()),
    );
    if (same) {
      return;
    }
    state = state._with(
      lines: <DraftLine>[
        for (final DraftLine line in state.lines)
          line.copyWith(
            unavailable: productIds.contains(line.productId.toLowerCase()),
          ),
      ],
    );
  }

  /// Takes out every marked line.
  void removeMarked() {
    for (final DraftLine line in state.marked) {
      remove(line.key);
    }
  }

  /// Answers the keys that arrived in the picker and are still kept, in
  /// order, and clears the set.
  List<String> settleArrivals() {
    final List<String> keys = <String>[
      for (final DraftLine line in state.kept)
        if (state.arriving.contains(line.key)) line.key,
    ];
    if (state.arriving.isNotEmpty) {
      state = state._with(arriving: const <String>{});
    }
    return keys;
  }
}

final NotifierProviderFamily<OrderDraftController, OrderDraft, String>
orderDraftProvider = NotifierProvider.autoDispose
    .family<OrderDraftController, OrderDraft, String>(OrderDraftController.new);

enum DraftChangeKind { added, removed, quantity, note, rule, wish }

/// One change the draft would make to the order, for the exit sheet and the
/// lock view.
typedef DraftChange = ({
  DraftChangeKind kind,
  String nameUz,
  String nameRu,
  UnitCode? unit,
  String? from,
  String? to,
  SubstitutionPolicy? rule,
});

String? _noteOf(String? note) {
  final String text = trimLikeServer(note ?? '');
  return text.isEmpty ? null : text;
}

Map<String, CustomerOrderLine> _openByProduct(CustomerOrder order) =>
    <String, CustomerOrderLine>{
      for (final CustomerOrderLine line in order.openLines)
        line.productId.toLowerCase(): line,
    };

/// The changes the draft makes to [order] as last loaded: the kept lines in
/// the draft's order — added, removed, quantity, note, rule — then any open
/// line the draft no longer holds, then the [wish] when it differs from the
/// order's (trimmed like the server, `null` when empty).
List<DraftChange> draftChanges(
  OrderDraft draft,
  CustomerOrder order,
  String? wish,
) {
  final Map<String, CustomerOrderLine> open = _openByProduct(order);
  final Set<String> seen = <String>{};
  final List<DraftChange> changes = <DraftChange>[];

  for (final DraftLine line in draft.lines) {
    final String id = line.productId.toLowerCase();
    seen.add(id);
    final CustomerOrderLine? now = open[id];
    final String nameUz = line.line?.nameUz ?? line.product!.nameUz;
    final String nameRu = line.line?.nameRu ?? line.product!.nameRu;
    if (line.removed) {
      if (now != null) {
        changes.add((
          kind: DraftChangeKind.removed,
          nameUz: now.nameUz,
          nameRu: now.nameRu,
          unit: null,
          from: null,
          to: null,
          rule: null,
        ));
      }
    } else if (now == null) {
      changes.add((
        kind: DraftChangeKind.added,
        nameUz: nameUz,
        nameRu: nameRu,
        unit: line.unit,
        from: null,
        to: QuantityRules.normalize(line.unit, line.quantity) ?? '',
        rule: null,
      ));
    } else {
      final String before =
          QuantityRules.normalize(now.unit, now.quantity) ?? now.quantity;
      final String? after = QuantityRules.normalize(line.unit, line.quantity);
      if (after != null &&
          QuantityRules.thousandths(after) !=
              QuantityRules.thousandths(before)) {
        changes.add((
          kind: DraftChangeKind.quantity,
          nameUz: now.nameUz,
          nameRu: now.nameRu,
          unit: now.unit,
          from: before,
          to: after,
          rule: null,
        ));
      }
      if (_noteOf(line.note) != _noteOf(now.customerNote)) {
        changes.add((
          kind: DraftChangeKind.note,
          nameUz: now.nameUz,
          nameRu: now.nameRu,
          unit: null,
          from: null,
          to: _noteOf(line.note),
          rule: null,
        ));
      }
      if (line.policy != now.substitutionPolicy) {
        changes.add((
          kind: DraftChangeKind.rule,
          nameUz: now.nameUz,
          nameRu: now.nameRu,
          unit: null,
          from: null,
          to: null,
          rule: line.policy,
        ));
      }
    }
  }
  for (final MapEntry<String, CustomerOrderLine> entry in open.entries) {
    if (!seen.contains(entry.key)) {
      changes.add((
        kind: DraftChangeKind.removed,
        nameUz: entry.value.nameUz,
        nameRu: entry.value.nameRu,
        unit: null,
        from: null,
        to: null,
        rule: null,
      ));
    }
  }

  final String? wanted = _noteOf(wish);
  if (wanted != order.deliveryTimeNote) {
    changes.add((
      kind: DraftChangeKind.wish,
      nameUz: '',
      nameRu: '',
      unit: null,
      from: order.deliveryTimeNote,
      to: wanted,
      rule: null,
    ));
  }
  return changes;
}

/// Whether the draft's kept lines are other than the lines [order] holds
/// now — the order as last loaded, not as the editor found it, since the
/// answer to an earlier save may have been lost after the server made it.
/// A quantity to be set anew is a change.
bool linesChange(OrderDraft draft, CustomerOrder order) {
  final Map<String, CustomerOrderLine> open = _openByProduct(order);
  final List<DraftLine> kept = draft.kept;
  if (open.length != kept.length) {
    return true;
  }
  for (final DraftLine line in kept) {
    final CustomerOrderLine? now = open[line.productId.toLowerCase()];
    final String? quantity = QuantityRules.normalize(line.unit, line.quantity);
    if (now == null ||
        quantity == null ||
        QuantityRules.thousandths(quantity) !=
            QuantityRules.thousandths(now.quantity) ||
        _noteOf(line.note) != _noteOf(now.customerNote) ||
        line.policy != now.substitutionPolicy) {
      return true;
    }
  }
  return false;
}
