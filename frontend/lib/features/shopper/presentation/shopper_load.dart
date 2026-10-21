import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether a screen's load has settled on data, so its periodic refresh
/// may run (`DL-54` (15)).
bool loadSettled(AsyncValue<Object?> value) =>
    value.hasValue && !value.hasError && !value.isLoading;
