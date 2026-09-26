/// Strict readers for the members of a JSON object, shared by every DTO —
/// `frontend/AGENTS.md` section 8: a malformed success payload is a failure,
/// never a half-filled model. A member the contract names is required, even
/// when its value may be `null`; members it does not name are ignored, so the
/// server may add fields without breaking installed clients.
///
/// Every reader throws a [FormatException], which a repository turns into a
/// `MalformedResponseFailure`.
extension type const JsonFields(Map<String, dynamic> _json) {
  /// The object [raw] as fields, or a [FormatException] naming [what].
  static JsonFields of(Object? raw, String what) {
    if (raw is Map<String, dynamic>) {
      return JsonFields(raw);
    }
    throw FormatException('$what is not an object: ${raw.runtimeType}');
  }

  /// The member [key] whatever its type, required to be present.
  Object? member(String key) {
    if (!_json.containsKey(key)) {
      throw FormatException('$key is missing');
    }
    return _json[key];
  }

  String string(String key) {
    final Object? value = member(key);
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw FormatException('$key is not a non-empty string');
  }

  String? nullableString(String key) {
    final Object? value = member(key);
    if (value == null) {
      return null;
    }
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw FormatException('$key is not a non-empty string or null');
  }

  int integer(String key) {
    final Object? value = member(key);
    if (value is int) {
      return value;
    }
    throw FormatException('$key is not an integer');
  }

  int? nullableInteger(String key) {
    final Object? value = member(key);
    if (value == null || value is int) {
      return value as int?;
    }
    throw FormatException('$key is not an integer or null');
  }

  bool boolean(String key) {
    final Object? value = member(key);
    if (value is bool) {
      return value;
    }
    throw FormatException('$key is not a boolean');
  }

  /// An instant in the ISO-8601 UTC form every resource uses
  /// (`2026-09-26T10:00:00Z`).
  DateTime instant(String key) => _instant(key, string(key));

  DateTime? nullableInstant(String key) {
    final String? value = nullableString(key);
    return value == null ? null : _instant(key, value);
  }

  /// A machine value parsed by [parse], which answers `null` for a value it
  /// does not know.
  T choice<T>(String key, T? Function(String value) parse) {
    final String value = string(key);
    final T? parsed = parse(value);
    if (parsed == null) {
      throw FormatException('$key is not a known value: $value');
    }
    return parsed;
  }

  static DateTime _instant(String key, String value) {
    // The contract's form ends in `Z`; an offset such as `+05:00` names the
    // same instant but is not what the API promises, so it is refused.
    final DateTime? parsed = value.endsWith('Z')
        ? DateTime.tryParse(value)
        : null;
    if (parsed == null || !parsed.isUtc) {
      throw FormatException('$key is not a UTC instant: $value');
    }
    return parsed;
  }
}
