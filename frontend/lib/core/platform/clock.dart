import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The instant "now" the screens read their relative dates against; the
/// device's clock by default, one the tests set.
final Provider<DateTime Function()> clockProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now);
