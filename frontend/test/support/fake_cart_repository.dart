import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/features/cart/data/cart_api.dart';
import 'package:baraka_bozor/features/cart/domain/cart.dart';

const String cartId = '0192f0a0-0000-7000-8000-00000000ca01';
const String tomatoLine = '0192f0a0-0000-7000-8000-00000000ca11';
const String breadLine = '0192f0a0-0000-7000-8000-00000000ca12';
const String tomatoProduct = '0192f0a0-0000-7000-8000-00000000cb01';
const String breadProduct = '0192f0a0-0000-7000-8000-00000000cb02';

/// A cart line as `docs/09` section 17 answers it.
Map<String, Object?> cartLineJson({
  String id = tomatoLine,
  String productId = tomatoProduct,
  String unit = 'kg',
  String quantity = '1.500',
  String priceMode = 'estimate',
  bool available = true,
  int price = 18400,
  int total = 27600,
  String? note,
  String policy = 'allow_similar_substitution',
}) => <String, Object?>{
  'id': id,
  'product_id': productId,
  'name_uz': unit == 'kg' ? 'Pomidor' : 'Non',
  'name_ru': unit == 'kg' ? 'Помидоры' : 'Хлеб',
  'unit_code': unit,
  'price_mode': priceMode,
  'image_url': null,
  'quantity': quantity,
  'customer_note': note,
  'substitution_policy': policy,
  'is_available': available,
  'customer_unit_price_uzs': available ? price : null,
  'estimated_line_total_uzs': available ? total : null,
};

Map<String, Object?> cartJson(
  List<Map<String, Object?>> lines, {
  int? subtotal,
}) => <String, Object?>{
  'id': cartId,
  'items': lines,
  'item_count': lines.length,
  'estimated_subtotal_uzs':
      subtotal ??
      lines.fold<int>(
        0,
        (int sum, Map<String, Object?> line) =>
            sum + ((line['estimated_line_total_uzs'] as int?) ?? 0),
      ),
};

Cart cartOf(List<Map<String, Object?>> lines, {int? subtotal}) =>
    CartApi.parseCart(cartJson(lines, subtotal: subtotal));

/// The cart in memory. It answers with [answer] when set — a test decides
/// what the server says — or with [current], and records every call.
class FakeCartRepository implements CartRepository {
  FakeCartRepository({Cart? cart})
    : current = cart ?? cartOf(<Map<String, Object?>>[]);

  Cart current;

  /// When set, the next change answers with it and it becomes [current].
  Cart? answer;

  /// When set, the next change fails with it.
  ApiFailure? failure;

  /// When set, every call waits for it.
  Completer<void>? hold;

  final List<String> calls = <String>[];
  final List<NewCartLine> added = <NewCartLine>[];
  final List<CartLinePatch> patches = <CartLinePatch>[];

  Future<Cart> _answer() async {
    final Completer<void>? hold = this.hold;
    if (hold != null) {
      await hold.future;
    }
    final ApiFailure? failure = this.failure;
    if (failure != null) {
      this.failure = null;
      throw failure;
    }
    final Cart? next = answer;
    if (next != null) {
      current = next;
      answer = null;
    }
    return current;
  }

  @override
  Future<Cart> cart() async {
    calls.add('cart');
    return _answer();
  }

  @override
  Future<Cart> add(NewCartLine line) async {
    calls.add('add:${line.productId}');
    added.add(line);
    return _answer();
  }

  @override
  Future<Cart> change(String lineId, CartLinePatch patch) async {
    calls.add('change:$lineId');
    patches.add(patch);
    return _answer();
  }

  @override
  Future<Cart> remove(String lineId) async {
    calls.add('remove:$lineId');
    return _answer();
  }
}
