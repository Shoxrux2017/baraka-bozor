import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/account_mutation.dart';
import 'admin_providers.dart';

/// A change the Admin makes in the panel: an [AccountMutation] for the
/// staff account, the base of every catalog and staff controller.
abstract class AdminMutation extends AccountMutation {
  @override
  Provider<String?> get account => staffAccountProvider;
}
