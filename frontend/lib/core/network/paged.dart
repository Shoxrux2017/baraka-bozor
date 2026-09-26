import 'json_fields.dart';

/// One page of a list in the envelope of `docs/09-api-contracts.md`
/// section 2: `{"data":[...],"meta":{"pagination":{...}}}`.
final class Paged<T> {
  const Paged({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  final List<T> items;
  final int page;
  final int perPage;
  final int total;
  final int lastPage;

  bool get hasPrevious => page > 1;

  bool get hasNext => page < lastPage;

  /// Parses a whole response body with [item] for each element; any element
  /// that breaks the contract fails the page.
  static Paged<T> parse<T>(Object? body, T Function(Object? raw) item) {
    final JsonFields envelope = JsonFields.of(body, 'page');
    final Object? data = envelope.member('data');
    if (data is! List<dynamic>) {
      throw FormatException('page data is not a list: ${data.runtimeType}');
    }

    final JsonFields meta = JsonFields.of(envelope.member('meta'), 'meta');
    final JsonFields pagination = JsonFields.of(
      meta.member('pagination'),
      'pagination',
    );
    final int page = pagination.integer('page');
    final int perPage = pagination.integer('per_page');
    final int total = pagination.integer('total');
    final int lastPage = pagination.integer('last_page');

    if (page < 1 || perPage < 1 || total < 0 || lastPage < 1) {
      throw const FormatException('pagination values are out of range');
    }

    return Paged<T>(
      items: data.map(item).toList(growable: false),
      page: page,
      perPage: perPage,
      total: total,
      lastPage: lastPage,
    );
  }
}
