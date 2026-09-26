/// The success envelope of `docs/09-api-contracts.md` section 2, shared by
/// every data source: a single resource or a collection arrives under `data`.
abstract final class ApiEnvelope {
  /// The `data` member, or a [FormatException] when the body is not an
  /// envelope. A collection's `meta` is read by the data source that needs
  /// it.
  static Object? unwrap(Object? body) {
    if (body is! Map<String, dynamic>) {
      throw FormatException('envelope is not an object: ${body.runtimeType}');
    }
    if (!body.containsKey('data')) {
      throw const FormatException('envelope has no data member');
    }
    return body['data'];
  }
}
